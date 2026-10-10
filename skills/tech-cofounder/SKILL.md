---
name: tech-cofounder
description: Guide for LLM coding agents to interact with the tech-cofounder platform via the `tc` CLI. Use this skill to install the CLI, authenticate users, create applications, retrieve scoped GitHub repository tokens, push commits, refresh tokens, and manage application lifecycle safely.
---

# Tech-Cofounder Platform Skill

The `tc` CLI provides command-line access to the **tech-cofounder** hosting platform. It currently allows agents to register applications, provision private GitHub repositories, and obtain short-lived scoped credentials without requiring personal GitHub or cloud accounts. It can validate app Terraform and deploy a pushed commit to Cloud Run.

---

## 1. CLI Installation

Use CLI **v0.1.5 or newer** for the app creation workflow below. Check the active
executable with `command -v tc`; for installer-managed binaries, the symlink target
contains the release version (`readlink "$(command -v tc)"`). The presence of
`--fix` alone does not establish that the CLI supports waiting for provisioning.
If the CLI is missing, older, or its version is unknown, install or upgrade it via
the official installer:

```bash
curl -fsSL https://raw.githubusercontent.com/RuoxiQin/tech-cofounder-cli/main/install.sh | bash
export PATH="$HOME/.local/bin:$PATH"
```

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

---

## 3. Discovering Commands & Tooling

The `tc` CLI is self-documenting and provides built-in usage instructions:

- **Discover commands and syntax:** Run `tc --help` or `tc <subcommand> --help` (e.g. `tc apps --help`, `tc apps create --help`) to inspect available subcommands, options, and arguments.
- **Always use `--json`:** Append `--json` to commands (e.g. `tc whoami --json`, `tc apps list --json`, `tc apps create "Name" --json`) to receive structured, machine-readable JSON output.
- **Actionable Remediation:** If a command fails or arguments are invalid, `tc` outputs a structured error envelope to `stderr` with a `remediation` field detailing how to fix the issue.

---

## 4. Core User Journeys (CUJ)

### Journey 1: Create an App and Push Initial Code to GitHub

When starting or onboarding a new project:

1. **Create the App:**
   ```bash
   tc apps create "My Web App" --json
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
   - **Resume:** repeat `tc apps create "My Web App" --json` to retry failed or
     unfinished steps while skipping checkpoints already marked `succeeded`.
   - **Hard repair:** use `tc apps create "My Web App" --fix --json` to recheck
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
   # Ensure .gitignore exists and is populated
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

The app must include a Dockerfile and policy-compliant Terraform under
`infra/terraform`. Run `tc validate --help` for the local configuration arguments.
Deploy the exact pushed commit:

```bash
tc deploy my-web-app "$(git rev-parse HEAD)" --json
tc apps get my-web-app --json
```

Deployment polls for up to twenty minutes. If the CLI times out, inspect the run
status before retrying; the worker may still be active. A successful deployment
populates the app's `url`. Use a public `/health` route for HTTP checks; Cloud Run's
internal `/healthz` startup probe can behave differently through Google Frontend.
Use the minimum CLI version specified in the installation section above.

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
