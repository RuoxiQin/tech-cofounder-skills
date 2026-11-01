# Firebase, Firestore rules, and App Check

Use this workflow for a tc app that uses Firebase from the web: Firebase
registration, Firestore rules and settings, Identity Platform sign-in, and
App Check. For an iOS client, also read
[Firebase iOS registration and App Check](firebase-ios.md).

For apps using Firebase, manage the supported resources in the app's Terraform
module. Use the default `google` and `google-beta` providers, pinned to `= 6.50.0`
(the worker's installed versions). Firebase project/web-app registration uses
Google Beta:

```hcl
provider "google-beta" {
  project               = var.tc_project_id
  region                = var.tc_region
  user_project_override = true
}

resource "google_firebase_project" "app" {
  provider = google-beta
  project  = var.tc_project_id
}

resource "google_firebase_web_app" "app" {
  provider     = google-beta
  project      = google_firebase_project.app.project
  display_name = var.tc_app_id
}

resource "google_firebaserules_ruleset" "app" {
  project = var.tc_project_id
  source {
    files {
      name    = "firestore.rules"
      content = file("${path.module}/firestore.rules")
    }
  }
  depends_on = [google_firestore_database.app]
}

resource "google_firebaserules_release" "firestore" {
  project      = var.tc_project_id
  name         = "cloud.firestore"
  ruleset_name = google_firebaserules_ruleset.app.name
}
```

The snippet assumes both providers are declared in `required_providers` and a
`google_firestore_database.app` resource defines the database. Set every resource's
project to `var.tc_project_id` or the registered Firebase project's known project;
using another project is rejected. tc provisions APIs and worker permissions;
client Terraform must not manage project creation, API enablement, or project IAM.

- **Files:** Keep `firestore.rules` and other `file()` inputs in `infra/terraform/`
  (or the manifest's configured Terraform directory), declare them in
  `supporting_files`, and deploy them through Terraform. An optional root
  `firebase.json` can point Firebase tooling/emulators to
  `infra/terraform/firestore.rules`; tc does not read `firebase.json`.
- **Database location:** Choose the immutable Firestore location explicitly. It
  need not match the Cloud Run region; the verified example uses `nam5` with
  compute in `us-central1`. Preserve an existing database's location and data.
- **TTL/indexes:** `google_firestore_field` supports `ttl_config {}` and
  `index_config {}` (empty index configuration exempts the field). TTL activation
  and eventual deletion are asynchronous; removing TTL configuration disables it.
- **Auth:** Use `google_identity_platform_config` to enable the intended sign-in
  methods and authorize the deployed hostname. Keep existing users/UIDs and data
  migration separate from infrastructure setup.
- **App Check:** Register a reCAPTCHA Enterprise SCORE key and
  `google_firebase_app_check_recaptcha_enterprise_config` for the Firebase web app.
  Authorize the actual deployed hostname; include localhost only if used locally.
  Configure the browser SDK before enforcement. Use
  `google_firebase_app_check_service_config` for service enforcement; removing
  that resource turns enforcement off. The verified counter enforces
  `firestore.googleapis.com` and leaves `identitytoolkit.googleapis.com` unenforced.
  Its `token_ttl` is `604800s`. Provider 6.50.0 cannot configure the Enterprise
  minimum score; readback confirmed Firebase's default `minValidScore: 0.5`.
- **Runtime settings:** Supply public Firebase web configuration and the reCAPTCHA
  site key to the browser. With one image built before Terraform apply, a dynamic
  runtime endpoint can expose public Cloud Run environment settings. Do not expose
  service-account credentials or secrets. Avoid a Terraform cycle between the
  Cloud Run URI and Firebase configuration injected into that same service.
- **Verify:** Run `tc validate`, deploy a pushed commit, and test real browser Auth,
  App Check, reads/writes, reload persistence, and unchanged redeployment. A valid
  Auth ID token without App Check should be rejected when Firestore enforcement
  is enabled; operator/Admin credentials cannot prove client rules/enforcement.
  Use an emulator separately for invalid-write rules tests. A newly registered
  web app may need propagation time: inspect a token-exchange error, then explicitly
  retry after propagation rather than weakening enforcement or looping indefinitely.
