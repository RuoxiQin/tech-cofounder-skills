---
name: tech-cofounder
description: Guide for LLM coding agents to interact with the tech-cofounder platform via the `tc` CLI. Use this skill to install the CLI, authenticate users, create applications, retrieve scoped GitHub repository tokens, push commits, refresh tokens, and manage application lifecycle safely.
---

# Tech-Cofounder Platform Skill

The `tc` CLI provides command-line access to the **tech-cofounder** hosting platform. It currently allows agents to register applications, provision private GitHub repositories, and obtain short-lived scoped credentials without requiring personal GitHub or cloud accounts. It can validate app Terraform and deploy a pushed commit to Cloud Run.

---

## 1. CLI Installation & Updates

**Always ensure you are running the latest `tc` CLI release.** Platform APIs and features evolve continuously; using an outdated CLI binary can result in missing commands or unsupported workflows.

Before executing platform commands:
1. Verify `tc` is available on your PATH: `command -v tc`.
2. Inspect the currently installed version: run `tc --version` (or `tc -v`).
3. If `tc` is not installed or when new capabilities are added, update to the latest release using the official installer:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/RuoxiQin/tech-cofounder-cli/main/install.sh | bash
   export PATH="$HOME/.local/bin:$PATH"
   ```
   *(The installer automatically queries GitHub Releases for the latest release and installs it to `~/.local/bin/tc`).*

---

## 2. Authentication & Login

The CLI requires a platform token to authenticate API calls.

### Check Current Authentication Status
```bash
tc whoami --json
```

- **If authenticated:** Returns JSON containing `{ "client_id": "...", "auth_mechanism": "..." }`.
- **If unauthenticated / token expired:** The command exits with code `3` (authentication failure).

### Handling Authentication
If unauthenticated:
1. **Prompt the user:** Ask the user to provide their tech-cofounder login token.
   > *"To connect with tech-cofounder and set up your repository, please provide your tech-cofounder authentication token."*
2. **Save credentials:**
   ```bash
   tc login --token "<USER_PROVIDED_TOKEN>"
   ```
   *(By default, credentials are saved to workspace configuration at `./.tech-cofounder/config.json`. To target global user credentials in `~/.config/tech-cofounder/config.json`, pass `--global`).*

### Credential Resolution & Hygiene
- **Workspace Discovery:** `tc` searches up the directory tree to the repository root for `./.tech-cofounder/config.json`. If no workspace configuration is found, it falls back to the global user configuration (`~/.config/tech-cofounder/config.json`).
- **Global Targeting:** Use the `--global` flag with `tc login` or `tc logout` to explicitly target global credentials instead of the workspace.
- **Git Hygiene:** Always include `.tech-cofounder/` in the project's `.gitignore` to prevent committing API tokens or workspace configurations.

---

## 3. Discovering Commands & Tooling

The `tc` CLI is self-documenting and provides built-in usage instructions:

- **Discover commands and syntax:** Run `tc --help` or `tc <subcommand> --help` (e.g. `tc apps --help`, `tc apps create --help`) to inspect available subcommands, options, and arguments.
- **Always use `--json`:** Append `--json` to commands (e.g. `tc whoami --json`, `tc apps list --json`, `tc apps create my-app --json`) to receive structured, machine-readable JSON output.
- **Actionable Remediation:** If a command fails or arguments are invalid, `tc` outputs a structured error envelope to `stderr` with a `remediation` field detailing how to fix the issue.

---

## 4. Core User Journeys (CUJ)

### Journey 1: Create an App and Push Initial Code to GitHub

When starting or onboarding a new project:

1. **Create the App:**
   ```bash
   tc apps create my-web-app --name "My Web App" --json
   ```
   *(Note: This automatically provisions a dedicated **private GitHub repository** under the platform organization. The code remains private and secure by default).*
   
   The backend records the app before submitting a Cloud Run provisioning job.
   The CLI polls every ten seconds for up to thirty minutes and succeeds when
   `status` is `"ready"`; provisioning failure returns a nonzero exit code.
   The response identifies the app with `app_id` and includes `repository.status`,
   `repository.full_name`, and `repository.repository_id`. Wait for the app to be
   ready before retrieving credentials or deploying.

   Inspect progress or diagnose failure with:
   ```bash
   tc apps get my-web-app --json
   ```
   Check `provisioning_error`, individual `provisioning.steps` entries (status,
   error, and resource identifiers), and `provisioning.dispatch` (latest submission
   status and error). Dispatch status `dispatched` means the job was accepted,
   not completed. These checkpoints are not a heartbeat or run history and cannot
   reliably distinguish a running job from one that died.

   Choose the retry based on the problem:

   - **Initial creation:** provisions all required resources.
   - **Resume:** repeat `tc apps create my-web-app --json` to retry failed or
     unfinished steps while skipping checkpoints already marked `succeeded`.
   - **Hard repair:** use `tc apps create my-web-app --fix --json` to recheck
     every step, including previously succeeded operations. This repairs the
     existing project and repository without changing their identities.

   A CLI timeout does not stop the worker. Inspect the app before retrying;
   avoid blindly looping creation or `--fix` while a job may still be running.
   Do not delete and recreate an app to recover interrupted provisioning.

2. **Retrieve Scoped GitHub Credentials:**
   ```bash
   tc apps repository-credentials my-web-app --json
   ```
   *Response schema:*
   ```json
   {
     "clone_url": "https://github.com/tech-cofounder/my-client--my-web-app.git",
     "git_username": "tech-cofounder-x-access-token",
     "access_token": "ghs_xxxxxxxxxxxxxxxxxxxx",
     "expires_at": "<RFC 3339 timestamp>"
   }
   ```

3. **Initialize Git and Push Code:**
   Inside the project directory:
   ```bash
   # Ensure .gitignore exists and ignores dependencies, env files, and .tech-cofounder/
   git init -b main
   git add .
   git commit -m "feat: initial project scaffolding"

   # Use the unmodified clone_url returned by tc.
   git remote add origin "<clone_url>"
   git -c credential.helper= push -u origin main
   ```
   When Git prompts, supply `git_username` as the username and `access_token` as the
   password. An agent without an interactive terminal may use a temporary `GIT_ASKPASS`
   helper that reads the token from memory. Never put the token in the remote URL,
   command arguments, Git config, logs, or a persistent credential helper.

---

### Deploy a Pushed Commit

#### Architecture and Repository Layout

Use one Git repository for the app, with its deployment manifest at the Git root.
The deployment requirements are one `tech_cofounder_configs.json`, one Dockerfile
building the bundled web backend/frontend, and one Terraform root module defining
exactly one Cloud Run service. The directory names below are recommended; the
manifest specifies the paths actually used by the platform.

Example recommended directory structure (include mobile directories only when
building the corresponding apps; web files below illustrate a Next.js app):

```text
my-app/
├── AGENTS.md                    # shared repository instructions
├── CLAUDE.md -> AGENTS.md
├── GEMINI.md -> AGENTS.md
├── tech_cofounder_configs.json
├── .gitignore
├── README.md
├── ios_app/                     # optional iOS app project and source
├── android_app/                 # optional Android app project and source
├── web_app/                     # bundled web backend and frontend
│   ├── Dockerfile
│   ├── .dockerignore
│   ├── package.json
│   ├── public/
│   └── src/
└── infra/
    └── terraform/
        ├── main.tf
        └── variables.tf
```

Bundle the web backend and frontend into one container deployed as exactly one
Cloud Run service. Do not configure separate backend/frontend images. Mobile
directories are optional source organization; the platform does not build or
release mobile apps. Create only the source directories the app needs. A mobile-only
repository can omit `web_app/`, but cannot use the current deployment command
without a web container and Terraform configuration.

#### Shared Agent Instructions

Recommend a top-level `AGENTS.md` as the shared source of repository instructions,
with relative symlinks `CLAUDE.md -> AGENTS.md` and `GEMINI.md -> AGENTS.md`.
Record the app's architecture, directory layout, development/build commands, and
the root-level `tc validate` / `tc deploy` workflow there. Keep credentials out of
these files. Framework-generated instructions can remain in a nested `AGENTS.md`
(for example, `web_app/AGENTS.md`) alongside the framework's source and dependencies.

Recommend including this notice in the root `AGENTS.md` so future agents know
where to find the platform guidance:

```markdown
This project is deployed and co-managed by tech-cofounder. Refer to the
`tech-cofounder` skill for the recommended directory structure, deployment
requirements, and best practices before changing the architecture or deploying.
```

After writing the root `AGENTS.md`, create and commit the symlinks from the Git root:

```bash
ln -s AGENTS.md CLAUDE.md
ln -s AGENTS.md GEMINI.md
```

For an existing repository, consolidate relevant instructions from existing
`CLAUDE.md` and `GEMINI.md` into `AGENTS.md` before replacing them with symlinks.
Maintain shared instructions in `AGENTS.md` rather than separate copies.

#### Deployment Manifest

Commit this manifest alongside the source:

```json
{
  "schema_version": 1,
  "terraform": { "directory": "infra/terraform" },
  "web_app": {
    "dockerfile": "web_app/Dockerfile",
    "build_context": "web_app"
  }
}
```

All shown manifest fields are required for schema version 1; unknown fields and
unsupported versions fail validation. Agent instruction files and symlinks are
repository recommendations, not deployment prerequisites checked by the platform.
All paths are canonical POSIX paths relative to the repository root; absolute
paths, `..`, and symlinks in local Terraform paths/files are unsupported. Use `"."`
as `build_context` when the Dockerfile needs shared files outside `web_app/`, and
place `.dockerignore` in that context. Dockerfile `COPY` paths are relative to the
build context. Keep credentials and local environment files out of Git and Docker.
Missing/invalid manifests fail; there is no fallback to conventional paths.
Validation reads the local manifest; deployment reads the manifest and Terraform
from the exact pushed commit and builds that same commit. Run repository commands
such as `git` and `tc` from the repository root, and package-manager commands from
`web_app/` (or the configured application's directory).

#### Recommended Application Frameworks
Recommend either:
- **Next.js** (unified full-stack React and TypeScript application)
- **Python FastAPI backend** with a **React + Vite + TailwindCSS** frontend (containerized together to serve API and bundled frontend assets)

#### Container Contract
- Listen on HTTP port `8080`.
- Include a startup probe endpoint at `/healthz` (returns HTTP 200).
- Expose a public route for HTTP checks (e.g. `/health`).

#### Terraform Contract (configured directory; recommended `infra/terraform`)
The platform worker injects these standard variables when evaluating and applying the plan:
- `tc_project_id`: The app's dedicated GCP project ID.
- `tc_region`: The deployment GCP region.
- `tc_app_id`: The immutable application ID.
- `tc_runtime_service_account`: The runtime service account (`app-runner@<app-project>.iam.gserviceaccount.com`).
- `tc_image_digest`: The published container image digest from Artifact Registry.

Supported resources:
- `google_cloud_run_v2_service` (required, exactly 1):
  - Limits: up to 1 CPU, up to 4GB memory, up to 10 instances (`max_instance_count`).
  - Runtime service account: `var.tc_runtime_service_account`.
  - Ingress: `INGRESS_TRAFFIC_ALL`, `invoker_iam_disabled = true`.
- `google_storage_bucket` and `google_storage_bucket_iam_member` (optional):
  - Allowed roles: `roles/storage.objectUser`, `roles/storage.objectViewer`, `roles/storage.objectAdmin`.
  - Member: `serviceAccount:${var.tc_runtime_service_account}`.
- `google_secret_manager_secret` and `google_secret_manager_secret_iam_member` (optional):
  - Allowed roles: `roles/secretmanager.secretAccessor`, `roles/secretmanager.viewer`.
  - Member: `serviceAccount:${var.tc_runtime_service_account}`.
  - Secret values are seeded out-of-band by the platform (do not define `google_secret_manager_secret_version` in Terraform).

Validate and deploy:
```bash
# Validate Terraform policy
tc validate my-web-app --json

# Deploy the exact pushed commit
tc deploy my-web-app "$(git rev-parse HEAD)" --json
tc apps get my-web-app --json
```

Deployment polls for up to twenty minutes. If the CLI times out, inspect the run
status before retrying; the worker may still be active. A successful deployment
populates the app's `url`. Use a public `/health` route for HTTP checks; Cloud Run's
internal `/healthz` startup probe can behave differently through Google Frontend.
Ensure you are running the latest CLI version as described in §1.

### Journey 2: Handling Token Expiration (1-Hour Lifespan)

GitHub installation tokens issued by the platform are short-lived and expire after **1 hour** (`expires_at`).

When an agent pushes code and receives a Git authentication error (e.g. `HTTP 401 Unauthorized` or `Authentication failed`):
1. Call `tc apps repository-credentials <APP_ID> --json` to obtain a fresh token.
2. Keep the remote at the plain `clone_url`. Retry the push with the new
   `git_username` and `access_token` as temporary Git credentials.

---

### Journey 3: Deleting an Application (Safety Guardrail)

> ⚠️ **CRITICAL WARNING:** Deleting an application retires its GCP project, unlinks billing, and deletes the app registration **and the private GitHub repository and all commit history**. Local files are preserved.

#### Deletion Policy for Agents:
1. **Never delete an app autonomously.**
2. **Double Confirmation Required:** When a user asks to delete an app, the agent MUST explicitly ask the user for confirmation:
   > *"Are you sure you want to delete application '**<APP_NAME>**' (`<APP_ID>`)? This will permanently delete the app and destroy its GitHub repository and code history."*
3. Only after the user confirms explicitly (e.g., "Yes, delete it"), execute:
   ```bash
   tc apps delete <APP_ID> --json
   ```

---

### Journey 4: GCP Debugging & Secret Management

When debugging Cloud Run services, viewing Cloud Build logs, inspecting Firestore/GCS data, or managing application secrets:

1. **Retrieve Scoped GCP Credentials:**
   ```bash
   tc apps gcp-credentials <APP_ID> --json
   ```
   *Response schema:*
   ```json
   {
     "access_token": "ya29.xxxxxxxxxxxxxxxxxxxx",
     "expires_at": "<RFC 3339 timestamp>",
     "gcp_project": "tc-my-web-app-123456",
     "service_account_email": "client-safe-operator@tc-my-web-app-123456.iam.gserviceaccount.com"
   }
   ```

2. **Configure Environment for Google Cloud SDK (`gcloud`):**
   ```bash
   GCP_CREDS=$(tc apps gcp-credentials <APP_ID> --json)
   export CLOUDSDK_AUTH_ACCESS_TOKEN=$(echo "$GCP_CREDS" | jq -r '.access_token')
   export CLOUDSDK_CORE_PROJECT=$(echo "$GCP_CREDS" | jq -r '.gcp_project')
   ```

3. **Available Permissions & Operations:**
   The `client-safe-operator` service account provides:
   - **Observability & Inspection:** Inspect Cloud Run services, revisions, metrics, Cloud Build logs, Cloud Logging log entries, and Firestore documents (`roles/viewer`, `roles/datastore.viewer`).
     ```bash
     # View Cloud Run service status
     gcloud run services describe <SERVICE_NAME> --region <REGION>

     # Read application or build logs
     gcloud logging read 'resource.type="cloud_run_revision"' --limit 50

     # Inspect Cloud Build logs
     gcloud builds list --limit 5
     gcloud builds log <BUILD_ID>
     ```
   - **Cloud Storage Object Management:** Full CRUD permissions (`roles/storage.objectUser`) to list, upload, read, update, and delete objects in GCS buckets for data backfills and assets:
     ```bash
     # Upload or backfill data to a bucket
     gcloud storage cp ./data.json gs://<BUCKET_NAME>/data.json
     gcloud storage cp -r ./backfill/ gs://<BUCKET_NAME>/backfill/

     # List and inspect objects
     gcloud storage ls gs://<BUCKET_NAME>/
     ```
   - **Secret Manager Administration:** Full CRUD permissions (`roles/secretmanager.admin`) to create, update, read, and delete application secrets and secret versions.
     ```bash
     # Create a new secret
     gcloud secrets create API_KEY --data-file=- <<< "my-secret-value"

     # Add a new version to an existing secret
     gcloud secrets versions add API_KEY --data-file=- <<< "new-secret-value"

     # Read secret payload
     gcloud secrets versions access latest --secret API_KEY
     ```
   *(Note: The token expires in 1 hour; call `tc apps gcp-credentials` again if you receive an authentication error).*

