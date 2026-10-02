---
name: tech-cofounder
description: Guide for LLM coding agents to interact with the tech-cofounder platform via the `tc` CLI. Use this skill to install the CLI, authenticate users, create applications, retrieve scoped GitHub repository tokens, push commits, refresh tokens, and manage application lifecycle safely.
---

# Tech-Cofounder Platform Skill

The `tc` CLI provides command-line access to the **tech-cofounder** hosting platform. It allows agents to register applications, provision private GitHub repositories, obtain short-lived scoped credentials, and deploy applications without requiring personal GitHub or cloud accounts.

---

## 1. CLI Installation

Before running `tc` commands, verify if the CLI is installed. If `tc` is not found, install it via the official installer:

```bash
# Verify if tc is installed
which tc || {
    echo "Installing tech-cofounder CLI..."
    curl -fsSL https://raw.githubusercontent.com/RuoxiQin/tech-cofounder-cli/main/install.sh | bash
    export PATH="$HOME/.local/bin:$PATH"
}
```

---

## 2. Authentication & Login

The CLI requires a platform token to authenticate API calls.

### Check Current Authentication Status
```bash
tc whoami --json
```

- **If authenticated:** Returns JSON containing `{ "client_id": "...", "auth_mechanism": "..." }`.
- **If unauthenticated / token expired:** The command exits with error code `2` (`UNAUTHENTICATED`).

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
   
   *Response schema:*
   ```json
   {
     "id": "my-web-app",
     "name": "My Web App",
     "status": "PROVISIONING",
     "repository": {
       "status": "ready",
       "owner": "tech-cofounder",
       "name": "my-client--my-web-app",
       "id": 123456789
     }
   }
   ```

2. **Retrieve Scoped GitHub Credentials:**
   ```bash
   tc apps repository-credentials my-web-app --json
   ```
   *Response schema:*
   ```json
   {
     "clone_url": "https://github.com/tech-cofounder/my-client--my-web-app.git",
     "username": "x-access-token",
     "token": "ghs_xxxxxxxxxxxxxxxxxxxx",
     "expires_at": "2026-10-02T16:06:14Z"
   }
   ```

3. **Initialize Git and Push Code:**
   Inside the project directory:
   ```bash
   # Ensure .gitignore exists and is populated
   git init -b main
   git add .
   git commit -m "feat: initial project scaffolding"

   # Configure authenticated remote URL using the scoped token
   # Format: https://x-access-token:<TOKEN>@github.com/<OWNER>/<REPO>.git
   AUTH_REMOTE_URL="https://x-access-token:${TOKEN}@github.com/${REPO_OWNER}/${REPO_NAME}.git"
   
   git remote add origin "${AUTH_REMOTE_URL}" || git remote set-url origin "${AUTH_REMOTE_URL}"
   git push -u origin main
   ```

---

### Journey 2: Handling Token Expiration (1-Hour Lifespan)

GitHub installation tokens issued by the platform are short-lived and expire after **1 hour** (`expires_at`).

When an agent pushes code and receives a Git authentication error (e.g. `HTTP 401 Unauthorized` or `Authentication failed`):
1. Call `tc apps repository-credentials <APP_ID> --json` to obtain a fresh token.
2. Update the Git remote URL with the new token:
   ```bash
   git remote set-url origin "https://x-access-token:${NEW_TOKEN}@github.com/${REPO_OWNER}/${REPO_NAME}.git"
   ```
3. Retry the `git push`.

---

### Journey 3: Deleting an Application (Safety Guardrail)

> ⚠️ **CRITICAL WARNING:** Deleting an application permanently deletes the app registration **and destroys the private GitHub repository and all commit history**.

#### Deletion Policy for Agents:
1. **Never delete an app autonomously.**
2. **Double Confirmation Required:** When a user asks to delete an app, the agent MUST explicitly ask the user for confirmation:
   > *"Are you sure you want to delete application '**<APP_NAME>**' (`<APP_ID>`)? This will permanently delete the app and destroy its GitHub repository and code history."*
3. Only after the user confirms explicitly (e.g., "Yes, delete it"), execute:
   ```bash
   tc apps delete <APP_ID> --json
   ```
