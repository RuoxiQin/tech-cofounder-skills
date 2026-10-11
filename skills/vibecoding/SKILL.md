---
name: vibecoding
description: Principles and best practices for vibecoding web applications. Guides agents to build software with a user-first mindset, assuming no prior technical expertise, while maintaining professional standards, cloud infrastructure, and version control.
---

# Vibecoding Web Applications

Vibecoding is creating software through natural conversation. The user provides the vision, requirements, and feedback; the AI agent acts as their technical cofounder and builder.

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

## 2. Standard Technology & Platform Stack

Always design and architect web applications using the following platform standards:

- **Source & Version Control:** Use **GitHub** for all version control.
- **Development & Operations Assistant:** Must use **tech-cofounder** to manage repositories and assist with cloud operations. Use tech-cofounder to automatically provision private GitHub repositories—never ask the user to create or configure a GitHub account.
- **Compute & Hosting:** Deploy and host web apps on **Google Cloud Platform (GCP)** using **Cloud Run**.
- **Data & Storage:** Use **Cloud Firestore** for database needs and **Google Cloud Storage (GCS)** for file and object storage.
- **User Authentication:** Use **Firebase Auth** for user sign-in and identity management.
- **Application Frameworks & Architecture:** Recommended application stacks:
  1. **Next.js** (unified full-stack React and TypeScript application), or
  2. **Python FastAPI backend** with a **React + Vite + TailwindCSS** frontend (single container serving both API and bundled static assets).
  Select based on domain fit (e.g. Python for data processing, AI/ML pipelines, or Python ecosystem libraries; Next.js for rapid full-stack TypeScript).


---

## 3. Version Control & History Management

Version control is an autonomous responsibility of the agent, not something the user should have to manage:

- **Refer to Platform Skill:** Follow the **`tech-cofounder`** skill for instructions on acquiring repository credentials and pushing code.
- **Meaningful Commit Pacing:**
  - Pace commits thoughtfully. Make atomic, meaningful commits that accurately describe the features or improvements introduced.
  - Maintain a clean and professional commit history so the repository serves as an effective time machine.
- **Rollback & Historical Reference:**
  - When the user asks for historical state (e.g. *"I liked yesterday afternoon's version of the app"* or *"Let's go back to how the landing page looked earlier"*), leverage git history to inspect what changed, pinpoint the relevant commits, and help revert or selectively restore earlier work.
- **Repository Hygiene:**
  - Apply standard best practices for `.gitignore` from the start, ensuring dependencies, local environment secrets, and build artifacts never pollute the repository.
