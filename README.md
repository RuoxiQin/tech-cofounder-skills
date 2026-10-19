# tech-cofounder-skills

Portable skills and plugins for AI coding agents (Claude Code, Codex, Antigravity) developing with the [tech-cofounder](https://github.com/RuoxiQin/tech-cofounder-cli) platform.

---

## Included Skills

### 1. [`vibecoding`](skills/vibecoding/SKILL.md)
Core principles and best practices for AI-assisted vibecoding. Guides rapid prototyping, clean architecture, and automatic version control via platform-managed GitHub repositories.

### 2. [`tech-cofounder`](skills/tech-cofounder/SKILL.md)
Comprehensive technical guide for agents to interact with the platform via the `tc` CLI:
- CLI installation and verification
- Token authentication (`tc login`, `tc whoami`)
- Creating apps and provisioning private GitHub repositories
- Minting scoped 1-hour GitHub tokens (`tc apps repository-credentials`)
- Refreshing expired tokens
- Safe deletion procedures with explicit confirmation
- Repository manifest, recommended `web_app/` layout, Terraform validation, and
  deployment of a bundled backend/frontend to one Cloud Run service
- CLI v0.1.13 Terraform supporting files, Firebase registration/Auth, Firestore
  rules and TTL, App Check configuration, and live verification
- [Firebase iOS workflow](skills/tech-cofounder/references/firebase-ios.md): Apple
  registration, debug-token management with scoped credentials, and App Attest

---

## Quick Install

To install these skills into your current workspace:

```bash
curl -fsSL https://raw.githubusercontent.com/RuoxiQin/tech-cofounder-skills/main/install.sh | bash
```

Or ask your AI coding agent:
> *"Install the skills from https://github.com/RuoxiQin/tech-cofounder-skills into this project."*
