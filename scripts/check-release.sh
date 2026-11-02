#!/usr/bin/env bash
# Before a release, check that versions agree and that Claude Code, Antigravity,
# and Codex all accept the plugin. Override CLI paths with CLAUDE_BIN, AGY_BIN,
# and CODEX_BIN.

set -euo pipefail

CLAUDE_BIN="${CLAUDE_BIN:-claude}"
AGY_BIN="${AGY_BIN:-agy}"
CODEX_BIN="${CODEX_BIN:-codex}"

for cli in "$CLAUDE_BIN" "$AGY_BIN" "$CODEX_BIN"; do
    if ! command -v "$cli" >/dev/null; then
        echo "missing CLI: $cli (set CLAUDE_BIN, AGY_BIN, or CODEX_BIN)" >&2
        exit 1
    fi
done

cd "$(dirname "$0")/.."

echo "==> Versions"
version="$(python3 -I scripts/check-versions.py)"
echo "All versions are $version"

echo "==> Claude Code"
"$CLAUDE_BIN" plugin validate --strict .

echo "==> Antigravity"
"$AGY_BIN" plugin validate --strict .

echo "==> Codex"
# Codex has no validator, so install into a throwaway CODEX_HOME.
codex_home="$(mktemp -d)"
trap 'rm -rf "$codex_home"' EXIT
CODEX_HOME="$codex_home" "$CODEX_BIN" plugin marketplace add "$PWD"
CODEX_HOME="$codex_home" "$CODEX_BIN" plugin add tech-cofounder@tech-cofounder
CODEX_HOME="$codex_home" "$CODEX_BIN" plugin list --json -m tech-cofounder |
    python3 -I -c '
import json, sys
installed = json.load(sys.stdin)["installed"]
versions = [plugin["version"] for plugin in installed if plugin["name"] == "tech-cofounder"]
if versions != [sys.argv[1]]:
    sys.exit(f"Codex installed {versions}, expected {sys.argv[1]}")
' "$version"

echo "Release checks passed for $version"
