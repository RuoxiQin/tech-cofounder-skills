---
name: vibecoding
description: Battle-tested guidance for vibecoding web and mobile apps with a coding agent. Covers a recommended tech stack, engineering and security practices, App Store and Google Play requirements, and known failure patterns, so apps come out fast, polished, secure, store-compliant, and easy to maintain. Examples use tech-cofounder as the hosting backend, but the practices apply to any backend.
metadata:
  version: "0.1.8"
---

# Vibecoding Web and Mobile Apps

Vibecoding is creating software through natural conversation. The user provides the vision, requirements, and feedback; the AI agent acts as their technical cofounder and builder.

The practices in this skill are general. Examples use **tech-cofounder** as the hosting backend. When the project uses tech-cofounder (it has a `tech_cofounder_configs.json`, or the user asks to host with tech-cofounder or `tc`), follow the `tech-cofounder` skill for platform commands and requirements. On another backend, use its equivalent of each recommended service.

---

## 1. The Non-Technical User Mindset

- **No Assumed Technical Expertise:**
  - Assume the user has zero technical or cloud knowledge. Never expect them to read stack traces, configure cloud consoles, or understand infrastructure terminology.
  - Avoid technical jargon in conversation. Focus on user-facing behaviors, designs, and product outcomes.
  - When technical decisions require user input, explain trade-offs simply and in plain language.
  - If the user shows curiosity and asks how something works under the hood, adjust your explanation to provide richer detail at whatever depth they want to explore.

- **Solve with Best Engineering Practices:**
  - The absence of technical requirements from the user is not an excuse for sloppy code. Silently apply modern, robust engineering and security best practices behind the scenes.
  - Build polished, responsive, and aesthetic interfaces with clean typography, harmonious palettes, and smooth interactive elements.

---

## 2. Recommended Stack

Use these defaults unless the project already uses something else or the user asks otherwise:

- **Version Control:** Git, hosted on **GitHub**. The agent manages the repository; never ask the user to create or configure a GitHub account.
  *On tech-cofounder:* the platform provisions a private repository and short-lived push credentials.
- **Hosting:** One container serving the web app and its API on a managed serverless service.
  *On tech-cofounder:* Google Cloud Run.
- **Data & Storage:** A managed database for app data and object storage for files, rather than self-managed servers.
  *On tech-cofounder:* Cloud Firestore and Google Cloud Storage.
- **User Authentication:** A managed sign-in service. Never implement password storage yourself.
  *On tech-cofounder:* Firebase Auth.
- **Secrets:** A managed secret store. Never put secret values in source code or in conversation.
  *On tech-cofounder:* Secret Manager, with values seeded by the platform.
- **Application Frameworks:**
  1. **Next.js** (unified full-stack React and TypeScript application), or
  2. **Python FastAPI backend** with a **React + Vite + TailwindCSS** frontend (single container serving both API and bundled static assets).
  Select based on domain fit (e.g. Python for data processing, AI/ML pipelines, or Python ecosystem libraries; Next.js for rapid full-stack TypeScript).
- **Mobile Apps:** Build native iOS and Android clients rather than cross-platform frameworks such as Flutter or React Native, so the apps start fast and feel responsive. They share the web app's backend, authentication, and data. Build mobile binaries with each platform's own tools (Xcode, Android Studio).
  *On tech-cofounder:* the platform deploys the backend; mobile builds and store releases are outside its current scope.

---

## 3. Repository Layout & Agent Instructions

- **Repository Layout:** Keep the bundled web backend/frontend and its Dockerfile under
  `web_app/`, with Terraform under `infra/terraform/`. Optional `ios_app/` and
  `android_app/` directories hold mobile source.
  *On tech-cofounder:* commit a root `tech_cofounder_configs.json` declaring the
  Terraform directory, Dockerfile, and build context as described in the
  `tech-cofounder` skill, and deploy one web container to one Cloud Run service.
- **Shared Agent Instructions:** Recommend a root `AGENTS.md` with relative symlinks
  `CLAUDE.md -> AGENTS.md` and `GEMINI.md -> AGENTS.md`. Keep shared architecture,
  directory layout, and development/deployment commands in `AGENTS.md`; preserve
  relevant existing instructions when consolidating files. Framework-specific
  instructions may remain in nested `AGENTS.md` files.
  *On tech-cofounder:* include a notice that the project is deployed and co-managed
  by tech-cofounder, referring future agents to the `tech-cofounder` skill for
  directory structure, deployment requirements, and best practices.

---

## 4. Security

- **Keep Secrets Out of the Repository:** Ignore environment files, local tool
  configuration, and credentials from the first commit (see §7).
- **Never Expose Credentials in Output:** Read tokens and credentials without echoing
  them, keep them out of shell history, and keep shell tracing disabled while handling
  them.
- **Least Privilege:** Grant the running app only the permissions it needs.
- **Protect the Backend From Unofficial Clients:** Use app attestation, such as Firebase
  App Check with App Attest on iOS, so only your real apps can call the backend. Keep
  debug tokens confined to development builds.

---

## 5. App Store & Google Play Requirements

- **App Store Connect:** every app needs a Privacy Policy URL and a Support URL.
- **Google Play Console:** every app needs a privacy policy URL. Apps where users
  create accounts also need a web page where users can request account and data
  deletion.
- **In-App Account Deletion (iOS):** if users can create an account in the app, they
  must also be able to start deleting it from inside the app (App Store Review
  Guideline 5.1.1(v)).
- **Write the Privacy Policy From What the App Actually Collects** and which services
  receive the data (for example the authentication provider and database). Ask the
  user to review it before submitting the app; it is not legal advice.

*On tech-cofounder:* host the privacy, support, and account-deletion pages as the
app's static site; see the `tech-cofounder` skill's static site reference.

---

## 6. Known Failure Patterns

- **Long builds or deploys exceed the agent's command time limit.** Start the
  operation, then poll its status. A client timeout does not stop server-side work,
  so inspect the current state before retrying.
- **Newly registered cloud resources are not ready yet.** Inspect the error and retry
  after propagation instead of changing working configuration.
- **Enforcing app attestation locks out the real app.** Before enabling enforcement,
  verify that the app works with its production attestation provider and that
  requests without attestation are rejected. Never disable existing enforcement to
  make a debug build work.
- **Store submission is blocked by missing pages.** Publish the privacy policy,
  support, and account-deletion pages (§5) before submitting.
- **Credentials leak through command output, logs, or commits.** Follow §4.

---

## 7. Version Control & History Management

Version control is an autonomous responsibility of the agent, not something the user should have to manage:

- **Pushing Code:** *On tech-cofounder:* follow the **`tech-cofounder`** skill for acquiring repository credentials and pushing code.
- **Meaningful Commit Pacing:**
  - Pace commits thoughtfully. Make atomic, meaningful commits that accurately describe the features or improvements introduced.
  - Maintain a clean and professional commit history so the repository serves as an effective time machine.
- **Rollback & Historical Reference:**
  - When the user asks for historical state (e.g. *"I liked yesterday afternoon's version of the app"* or *"Let's go back to how the landing page looked earlier"*), leverage git history to inspect what changed, pinpoint the relevant commits, and help revert or selectively restore earlier work.
- **Repository Hygiene:**
  - Apply standard best practices for `.gitignore` from the start, ensuring dependencies, local environment secrets, workspace configuration (such as `.tech-cofounder/`), and build artifacts never pollute the repository.
