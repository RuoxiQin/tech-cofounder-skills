# tech-cofounder-skills

Portable skills and plugins for AI coding agents (Claude Code, Codex, Antigravity) developing with the [tech-cofounder](https://github.com/RuoxiQin/tech-cofounder-cli) platform.

---

## Included Skills

### 1. [`vibecoding`](skills/vibecoding/SKILL.md)
Guidance for vibecoding web and mobile apps: a recommended tech stack, security practices, App Store and Google Play requirements, and known failure patterns. Examples use tech-cofounder as the hosting backend, but the practices apply to any backend.

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
- [Firebase workflow](skills/tech-cofounder/references/firebase.md): CLI v0.1.13
  Terraform supporting files, Firebase registration/Auth, Firestore rules and TTL,
  App Check configuration, and live verification
- [Firebase iOS workflow](skills/tech-cofounder/references/firebase-ios.md): Apple
  registration, debug-token management with scoped credentials, and App Attest
- [Custom domains](skills/tech-cofounder/references/custom-domain.md): Search Console
  owner setup for the app's deployer, Cloud Run domain mapping, and DNS records
- [Static site](skills/tech-cofounder/references/static-site.md): privacy, support,
  and account-deletion pages hosted on the app's Firebase Hosting site

---

## Quick Install

### Claude Code

Install the `tech-cofounder` plugin from this repository's marketplace. Inside a
Claude Code session (v2.1.275 or later):

```
/plugin install tech-cofounder --marketplace RuoxiQin/tech-cofounder-skills
```

Or from your shell:

```bash
claude plugin marketplace add RuoxiQin/tech-cofounder-skills
claude plugin install tech-cofounder@tech-cofounder
```

Get a newer release with `claude plugin update tech-cofounder@tech-cofounder`.

### Codex

Add this repository's marketplace, then install the `tech-cofounder` plugin:

```bash
codex plugin marketplace add RuoxiQin/tech-cofounder-skills
codex plugin add tech-cofounder@tech-cofounder
```

Get a newer release with `codex plugin marketplace upgrade tech-cofounder`.

### Antigravity

Install the `tech-cofounder` plugin from this repository:

```bash
agy plugin install https://github.com/RuoxiQin/tech-cofounder-skills
```

### Other agents

To install these skills into your current workspace:

```bash
curl -fsSL https://raw.githubusercontent.com/RuoxiQin/tech-cofounder-skills/main/install.sh | bash
```

Or ask your AI coding agent:
> *"Install the skills from https://github.com/RuoxiQin/tech-cofounder-skills into this project."*

---

## License

The skills and plugin files are licensed under the [Mozilla Public License 2.0](LICENSE).

The tech-cofounder name and logo are not licensed under MPL-2.0; all rights reserved.
