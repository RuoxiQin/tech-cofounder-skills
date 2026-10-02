#!/usr/bin/env bash
# tech-cofounder-skills Installer
# Installs tech-cofounder skills into the current workspace (.agents/skills/) or global config.

set -euo pipefail

GITHUB_REPO="RuoxiQin/tech-cofounder-skills"
GITHUB_RAW_BASE="https://raw.githubusercontent.com/${GITHUB_REPO}/main"

log_info() {
    printf "\033[1;34m==>\033[0m %s\n" "$1"
}

# Determine destination directory
# Default to current workspace .agents/skills/
TARGET_DIR="${TARGET_DIR:-.agents/skills}"

log_info "Installing tech-cofounder skills into ${TARGET_DIR}..."
mkdir -p "${TARGET_DIR}/vibecoding"
mkdir -p "${TARGET_DIR}/tech-cofounder"

# Download skills
curl -fsSL "${GITHUB_RAW_BASE}/skills/vibecoding/SKILL.md" -o "${TARGET_DIR}/vibecoding/SKILL.md"
curl -fsSL "${GITHUB_RAW_BASE}/skills/tech-cofounder/SKILL.md" -o "${TARGET_DIR}/tech-cofounder/SKILL.md"

log_info "Successfully installed skills:"
echo " - ${TARGET_DIR}/vibecoding/SKILL.md"
echo " - ${TARGET_DIR}/tech-cofounder/SKILL.md"
echo ""
log_info "Installation complete! Your AI coding agent can now use the tech-cofounder skills."
