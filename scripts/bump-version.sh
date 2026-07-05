#!/usr/bin/env bash
#
# Bump PeekBar version numbers across declared files, with drift detection and
# repo-wide audit for missed version references.
#
# Declared files + their version locations live in .version-bump.json.
#
# Usage:
#   scripts/bump-version.sh <new-version>   Bump all declared files
#   scripts/bump-version.sh --check         Report current versions
#   scripts/bump-version.sh --audit         Check + scan repo for references
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG="$REPO_ROOT/.version-bump.json"

[[ -f "$CONFIG" ]] || { echo "error: .version-bump.json not found at $CONFIG" >&2; exit 1; }

python3 - "$CONFIG" "$REPO_ROOT" "${1:-}" <<'PY'
import json
import plistlib
import re
import sys
from pathlib import Path

config_path = Path(sys.argv[1])
repo_root = Path(sys.argv[2])
command = sys.argv[3]

config = json.loads(config_path.read_text())
files = config["files"]
exclude_names = set(config.get("audit", {}).get("exclude", []))


def fail(message):
    print(f"error: {message}", file=sys.stderr)
    sys.exit(1)


def declared_path(entry):
    return repo_root / entry["path"]


def label_for(entry):
    return f"{entry['path']} ({entry['field']})"


def read_version(entry):
    path = declared_path(entry)
    if entry["type"] == "xcodegen-yaml":
        pattern = re.compile(rf"^[ \t]*{re.escape(entry['field'])}:[ \t]*(.+?)[ \t]*(?:#.*)?$", re.MULTILINE)
        match = pattern.search(path.read_text())
        if not match:
            fail(f"could not read {entry['field']} from {entry['path']}")
        return match.group(1).strip().strip("\"'")

    if entry["type"] == "plist":
        with path.open("rb") as handle:
            plist = plistlib.load(handle)
        value = plist.get(entry["field"])
        if not value:
            fail(f"could not read {entry['field']} from {entry['path']}")
        return str(value)

    fail(f"unknown type '{entry['type']}'")


def write_version(entry, version):
    path = declared_path(entry)
    if entry["type"] == "xcodegen-yaml":
        pattern = re.compile(rf"(^[ \t]*{re.escape(entry['field'])}:[ \t]*)[^\n#]+", re.MULTILINE)
        text, count = pattern.subn(rf"\g<1>{version}", path.read_text(), count=1)
        if count != 1:
            fail(f"could not update {entry['field']} in {entry['path']}")
        path.write_text(text)
        return

    if entry["type"] == "plist":
        pattern = re.compile(
            rf"(<key>{re.escape(entry['field'])}</key>\s*<string>)([^<]*)(</string>)",
            re.MULTILINE,
        )
        text, count = pattern.subn(rf"\g<1>{version}\g<3>", path.read_text(), count=1)
        if count != 1:
            fail(f"could not update {entry['field']} in {entry['path']}")
        path.write_text(text)
        return

    fail(f"unknown type '{entry['type']}'")


def check_versions():
    versions = []
    has_drift = False

    print("Version check:\n")
    for entry in files:
        path = declared_path(entry)
        label = label_for(entry)
        if not path.exists():
            print(f"  {label:<60}  MISSING")
            has_drift = True
            continue

        version = read_version(entry)
        versions.append(version)
        print(f"  {label:<60}  {version}")

    print("")
    unique = sorted(set(versions))
    if not unique:
        fail("no declared versions found")
    if len(unique) > 1:
        print("DRIFT DETECTED - versions are not in sync:")
        for version in unique:
            print(f"  {version} ({versions.count(version)} files)")
        has_drift = True
    else:
        print(f"All declared files are in sync at {unique[0]}")

    return has_drift


def is_excluded(path):
    rel_parts = path.relative_to(repo_root).parts
    return any(part in exclude_names for part in rel_parts)


def audit_versions():
    check_versions()
    current_version = read_version(files[0])
    declared_paths = {declared_path(entry).resolve() for entry in files}
    found = []

    for path in repo_root.rglob("*"):
        if path.is_dir() or is_excluded(path):
            continue
        if path.resolve() in declared_paths:
            continue
        try:
            text = path.read_text(errors="ignore")
        except OSError:
            continue
        if current_version in text:
            found.append(path.relative_to(repo_root))

    print(f"\nAudit: scanning repo for version string '{current_version}'...\n")
    if not found:
        print("No undeclared files contain the version string. All clear.")
        return False

    print(f"UNDECLARED files containing '{current_version}':")
    for path in found:
        print(f"  {path}")
    print("\nReview these files. Add real version sources to .version-bump.json; add generated or irrelevant paths to audit.exclude.")
    return True


def bump_version(version):
    if not re.match(r"^[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z]+)?$", version):
        fail(f"'{version}' doesn't look like a version (expected X.Y.Z)")

    print(f"Bumping all declared files to {version}...\n")
    for entry in files:
        path = declared_path(entry)
        if not path.exists():
            print(f"  SKIP (missing): {entry['path']}")
            continue
        old_version = read_version(entry)
        write_version(entry, version)
        print(f"  {label_for(entry):<60}  {old_version} -> {version}")

    print("\nDone. Running audit to check for missed files...\n")
    audit_versions()


if command == "--check":
    sys.exit(1 if check_versions() else 0)
if command == "--audit":
    sys.exit(1 if audit_versions() else 0)
if command in ("", "--help", "-h"):
    print("Usage: scripts/bump-version.sh <new-version> | --check | --audit")
    print("")
    print("  <new-version>      Bump all declared version files")
    print("  --check            Show current versions, detect drift")
    print("  --audit            Check + scan repo for undeclared version references")
    sys.exit(0)
if command.startswith("--"):
    fail(f"unknown flag '{command}'")

bump_version(command)
PY
