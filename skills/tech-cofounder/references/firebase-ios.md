# Firebase iOS registration and App Check

Use this workflow for an iOS client sharing a tc app's Firebase project. The tc
manifest and its single Cloud Run service are still required. The iOS binary is
built with Xcode; `tc deploy` deploys the backend and Terraform resources.

These capabilities require the updated platform worker and provisioning worker
to be released. The Terraform providers remain pinned to `= 6.50.0`; no new CLI
command is required. For an existing ready app, run
`tc apps create <TC_APP_ID> --hard-fix --json` after that release to add the
debug-token role and binding. Provisioning grants them automatically for new apps.

## Register the Apple app with Terraform

Alongside the Firebase project and required Cloud Run service, add:

```hcl
resource "google_firebase_apple_app" "ios" {
  provider     = google-beta
  project      = google_firebase_project.app.project
  display_name = "${var.tc_app_id} iOS"
  bundle_id    = "com.example.myapp" # Use the Xcode target's bundle ID.
}
```

Use the default Google Beta provider and a known app project. Apple registration
can omit `team_id` while developing with the debug provider. Validate locally,
push the commit, and deploy it through tc before retrieving the Firebase app ID.
Do not manage API enablement or the operator's IAM role in app Terraform.

## Connect the iOS SDK

Run the shell examples in Bash with `gcloud`, `jq`, and `curl` available. Keep
them in the same session and stop on a failed command. Obtain the existing
operator credential without printing it:

```bash
set -euo pipefail
TC_APP_ID='my-app' # The tc application ID, not the Firebase app ID.
TC_GCP_CREDENTIALS=$(tc apps gcp-credentials "$TC_APP_ID" --json)
CLOUDSDK_AUTH_ACCESS_TOKEN=$(printf '%s' "$TC_GCP_CREDENTIALS" | jq -er '.access_token')
CLOUDSDK_CORE_PROJECT=$(printf '%s' "$TC_GCP_CREDENTIALS" | jq -er '.gcp_project')
export CLOUDSDK_AUTH_ACCESS_TOKEN CLOUDSDK_CORE_PROJECT
unset TC_GCP_CREDENTIALS

curl --fail-with-body --silent --show-error \
  -H "Authorization: Bearer $CLOUDSDK_AUTH_ACCESS_TOKEN" \
  "https://firebase.googleapis.com/v1beta1/projects/$CLOUDSDK_CORE_PROJECT/iosApps" \
  | jq '{apps: [.apps[]? | {appId, displayName, bundleId}], nextPageToken}'
```

Select the entry with the target bundle ID; if `nextPageToken` is present,
request subsequent pages using `pageToken`. Use its `appId` below. This Firebase
ID (such as `1:123456789:ios:abcdef`) is different from `TC_APP_ID`.

```bash
FIREBASE_APP_ID='1:123456789:ios:abcdef' # Replace with the returned appId.
curl --fail-with-body --silent --show-error \
  -H "Authorization: Bearer $CLOUDSDK_AUTH_ACCESS_TOKEN" \
  "https://firebase.googleapis.com/v1beta1/projects/$CLOUDSDK_CORE_PROJECT/iosApps/$FIREBASE_APP_ID/config" \
  | jq -er '.configFileContents' | base64 --decode > GoogleService-Info.plist
```

Add this plist to the matching Xcode target and add the Firebase SDK, including
FirebaseAppCheck. In debug builds, install the debug factory **before** Firebase
initialization:

```swift
import FirebaseCore
import FirebaseAppCheck

#if DEBUG
AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
#endif
FirebaseApp.configure()
```

Run the simulator or test device and copy the App Check debug token from Xcode's
console. Treat that log as secret. This development path does not require App
Attest configuration. Configure a production provider before shipping a release.

## Register, inspect, and revoke a debug token

The operator's project-local `tcAppCheckDebugTokenManager` role grants only
`firebaseappcheck.debugTokens.get` and `.update`. It permits token management
without adding writes to App Check provider configuration or enforcement.

Use the project **number**, not its ID, in App Check resource names:

```bash
GCP_PROJECT_NUMBER=$(gcloud projects describe "$CLOUDSDK_CORE_PROJECT" --format='value(projectNumber)')
APP_CHECK_PARENT="projects/$GCP_PROJECT_NUMBER/apps/$FIREBASE_APP_ID"

# Read the Xcode token without echoing it or putting its value in shell history.
# Keep shell tracing disabled while handling credentials and tokens.
printf 'Paste the Xcode App Check debug token: '
IFS= read -r -s APP_CHECK_DEBUG_TOKEN
printf '\n'
printf '%s' "$APP_CHECK_DEBUG_TOKEN" \
  | jq -Rs '{displayName: "Local iOS development", token: .}' \
  | curl --fail-with-body --silent --show-error -X POST \
      -H "Authorization: Bearer $CLOUDSDK_AUTH_ACCESS_TOKEN" \
      -H 'Content-Type: application/json' --data-binary @- \
      "https://firebaseappcheck.googleapis.com/v1/$APP_CHECK_PARENT/debugTokens" \
  | jq '{name, displayName}'
unset APP_CHECK_DEBUG_TOKEN
```

Save the returned resource `name` for revocation. The secret must be a UUIDv4;
Firebase never returns it in responses and cannot change it in place. For CI,
generate a UUIDv4 locally, register it in the same way, and keep it in the CI
secret store; provide it to the iOS debug build as `AppCheckDebugToken`.
Rotate by registering a new secret and revoking the old resource.

```bash
# List token metadata; the secret values are never returned.
curl --fail-with-body --silent --show-error \
  -H "Authorization: Bearer $CLOUDSDK_AUTH_ACCESS_TOKEN" \
  "https://firebaseappcheck.googleapis.com/v1/$APP_CHECK_PARENT/debugTokens?pageSize=20"

# Revoke one selected token. Use its resource ID, not its UUID secret.
APP_CHECK_DEBUG_TOKEN_ID='replace-with-debug-token-resource-id'
curl --fail-with-body --silent --show-error -X DELETE \
  -H "Authorization: Bearer $CLOUDSDK_AUTH_ACCESS_TOKEN" \
  "https://firebaseappcheck.googleapis.com/v1/$APP_CHECK_PARENT/debugTokens/$APP_CHECK_DEBUG_TOKEN_ID"
```

If listing returns `nextPageToken`, continue with `pageToken` and the same
`pageSize`. An app supports at most 20 tokens. Refresh the operator credential
after its one-hour expiry. On permission denial, inspect provisioning checkpoints
and the app's IAM grant; do not request App Check Admin access.

Keep debug secrets out of Terraform, state, source files, shared logs, and release
builds. Do not use `google_firebase_app_check_debug_token`; tc rejects it.

## Move to App Attest

Once the Apple setup is ready, set the real `team_id` on the existing Apple app
and add:

```hcl
resource "google_firebase_app_check_app_attest_config" "ios" {
  provider  = google-beta
  project   = var.tc_project_id
  app_id    = google_firebase_apple_app.ios.app_id
  token_ttl = "3600s"
}
```

Configure the Xcode App Attest capability/entitlement and the production App
Attest provider factory before `FirebaseApp.configure()`. The debug snippet above
does not configure the release provider. Keep debug tokens confined to development.
If App Check has not yet recognized a new Apple registration, inspect the error
and explicitly retry deployment after propagation. The `time` provider is not
supported by tc.

Enforcement remains in `google_firebase_app_check_service_config`. It applies to
the Firebase service across the project, including the existing web client. Keep
the working web App Check setup intact. Verify iOS access with its intended
provider and verify rejection of requests without App Check before enabling new
enforcement; do not disable existing enforcement to make the debug build work.

References: [Apple debug provider](https://firebase.google.com/docs/app-check/ios/debug-provider),
[debug-token API](https://firebase.google.com/docs/reference/appcheck/rest/v1/projects.apps.debugTokens),
[iOS SDK config API](https://firebase.google.com/docs/reference/firebase-management/rest/v1beta1/projects.iosApps/getConfig),
[App Attest SDK setup](https://firebase.google.com/docs/app-check/ios/app-attest-provider).
