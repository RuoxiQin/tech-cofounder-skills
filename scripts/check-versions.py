#!/usr/bin/env python3
"""Check that the plugin manifests and skills all declare the same version."""

import json
import sys
from pathlib import Path

REPOSITORY_ROOT = Path(__file__).resolve().parent.parent
MANIFEST_PATHS = ["plugin.json", ".claude-plugin/plugin.json"]
SKILL_PATHS = ["skills/tech-cofounder/SKILL.md", "skills/vibecoding/SKILL.md"]


def read_manifest_version(path):
    return json.loads((REPOSITORY_ROOT / path).read_text())["version"]


def read_skill_metadata_version(path):
    """Read `metadata.version` from a SKILL.md frontmatter block."""
    text = (REPOSITORY_ROOT / path).read_text()
    if not text.startswith("---\n"):
        sys.exit(f"{path}: missing frontmatter")
    frontmatter = text[len("---\n"):].split("\n---\n", 1)[0].splitlines()
    if "metadata:" not in frontmatter:
        sys.exit(f"{path}: missing metadata in frontmatter")
    for line in frontmatter[frontmatter.index("metadata:") + 1:]:
        if not line.startswith("  "):
            break
        key, _, value = line.strip().partition(":")
        if key == "version":
            return value.strip().strip('"')
    sys.exit(f"{path}: missing metadata.version in frontmatter")


def main():
    versions = {path: read_manifest_version(path) for path in MANIFEST_PATHS}
    versions.update({path: read_skill_metadata_version(path) for path in SKILL_PATHS})
    if len(set(versions.values())) != 1:
        for path, version in versions.items():
            print(f"{path}: {version}", file=sys.stderr)
        sys.exit("Versions differ; set them all to the same release version.")
    print(next(iter(versions.values())))


if __name__ == "__main__":
    main()
