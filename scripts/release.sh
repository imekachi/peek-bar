#!/usr/bin/env bash
#
# Local release: build a signed PeekBar.app, create a Sparkle update archive,
# sign it, generate appcast.xml, and publish GitHub Release assets.
#
# Prerequisites (one-time, local-only — never commit):
#   - .env.local with PEEKBAR_SIGNING_IDENTITY or APPLE_SIGNING_IDENTITY,
#     SPARKLE_PRIVATE_KEY_PATH, and GITHUB_REPOSITORY
#     (see .env.local.example).
#   - Sparkle EdDSA private key at SPARKLE_PRIVATE_KEY_PATH.
#   - `gh` CLI authenticated for publishing (not required for --dry-run).
#
# Usage:
#   ./scripts/release.sh                 # version read from project.yml/Info.plist
#   ./scripts/release.sh 0.2.0           # bump + commit version, then release
#   ./scripts/release.sh -f              # overwrite an existing tag/release
#   ./scripts/release.sh 0.2.0 -f        # bump + overwrite
#   ./scripts/release.sh --dry-run       # stage assets locally; no tag/gh/git mutation
#   ./scripts/release.sh 0.2.0 --dry-run # stage assets with that version; no mutation
#
# By default the script refuses to release a version whose tag already exists
# (local or on origin). Re-run with -f / --force to move the tag and overwrite
# the release assets.
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="PeekBar"
SCHEME="PeekBar"
PROJECT="PeekBar.xcodeproj"
DERIVED_DATA="build"
STAGE_DIR="$ROOT_DIR/release"
DRY_RUN=0
FORCE=0
VERSION_ARG=""

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    -f|--force) FORCE=1 ;;
    -h|--help)
      sed -n '2,23p' "$0"
      exit 0
      ;;
    -*)
      echo "ERROR: unknown flag '$arg' (supported: --dry-run, -f, --force)" >&2
      exit 1
      ;;
    *)
      if [[ -n "$VERSION_ARG" ]]; then
        echo "ERROR: multiple version arguments provided: '$VERSION_ARG' and '$arg'" >&2
        exit 1
      fi
      VERSION_ARG="$arg"
      ;;
  esac
done

# `npm run release -f` is consumed by npm itself and exposed as
# npm_config_force=true. Honor it so npm-style forwarding still works.
[[ "${npm_config_force:-}" == "true" ]] && FORCE=1

log() {
  echo "==> $*"
}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

load_env() {
  local env_file
  env_file="$ROOT_DIR/.env.local"
  if [[ -f "$env_file" ]]; then
    log "Loading $env_file"
    set -a
    # shellcheck disable=SC1090
    source "$env_file"
    set +a
  fi
}

normalize_env() {
  if [[ -z "${PEEKBAR_SIGNING_IDENTITY:-}" && -n "${APPLE_SIGNING_IDENTITY:-}" ]]; then
    PEEKBAR_SIGNING_IDENTITY="$APPLE_SIGNING_IDENTITY"
  fi
  PEEKBAR_DEVELOPMENT_TEAM="${PEEKBAR_DEVELOPMENT_TEAM:-${DEVELOPMENT_TEAM:-${APPLE_TEAM_ID:-}}}"
}

require_env() {
  local missing=()
  local var
  for var in PEEKBAR_SIGNING_IDENTITY SPARKLE_PRIVATE_KEY_PATH GITHUB_REPOSITORY; do
    if [[ -z "${!var:-}" ]]; then
      missing+=("$var")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "ERROR: missing required release environment variables:" >&2
    printf '  - %s\n' "${missing[@]}" >&2
    echo "Set them in .env.local (gitignored) or export them in your shell." >&2
    exit 1
  fi
}

read_version() {
  local from_project from_plist

  from_project="$(awk -F': ' '/^[[:space:]]*MARKETING_VERSION:/ {print $2; exit}' project.yml | tr -d ' "')"
  from_plist="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' PeekBar/Resources/Info.plist 2>/dev/null || true)"

  VERSION="${from_project:-$from_plist}"
  [[ -n "$VERSION" ]] || fail "could not determine marketing version from project.yml or Info.plist"

  set_release_version "$VERSION"
}

set_release_version() {
  VERSION="$1"
  TAG="v$VERSION"
  ARCHIVE_NAME="${APP_NAME}-${VERSION}.zip"
  DOWNLOAD_PREFIX="https://github.com/${GITHUB_REPOSITORY}/releases/download/${TAG}/"
}

bump_version() {
  local version="$1"

  log "Bumping version to $version"
  "$ROOT_DIR/scripts/bump-version.sh" "$version"
  git add project.yml PeekBar/Resources/Info.plist
  git diff --cached --quiet -- project.yml PeekBar/Resources/Info.plist \
    || git commit -m "chore(release): v$version" -- project.yml PeekBar/Resources/Info.plist
}

preflight_sparkle_version() {
  local feed_url feed_xml compare_status

  feed_url="https://github.com/${GITHUB_REPOSITORY}/releases/latest/download/appcast.xml"
  feed_xml="$(curl -fsSL "$feed_url" 2>/dev/null || true)"

  if [[ -z "$feed_xml" ]]; then
    log "No published appcast found at $feed_url; skipping feed comparison"
    return 0
  fi

  set +e
  python3 - "$feed_xml" "$VERSION" <<'PY'
import re
import sys

feed_xml = sys.argv[1]
release_version = sys.argv[2]

def parse_version_parts(marketing: str) -> list[int]:
    parts: list[int] = []
    for piece in marketing.split("."):
        digits = "".join(ch for ch in piece if ch.isdigit())
        parts.append(int(digits or "0"))
    while len(parts) < 3:
        parts.append(0)
    return parts[:3]

def compare(lhs: str, rhs: str) -> int:
    lhs_parts = parse_version_parts(lhs)
    rhs_parts = parse_version_parts(rhs)
    return (lhs_parts > rhs_parts) - (lhs_parts < rhs_parts)

published_version = re.search(r"<sparkle:version>([^<]+)</sparkle:version>", feed_xml)
published_short = re.search(
    r"<sparkle:shortVersionString>([^<]+)</sparkle:shortVersionString>", feed_xml
)
published = published_short or published_version
if not published:
    sys.exit(0)

published_version_text = published.group(1).strip()
result = compare(release_version, published_version_text)
if result < 0:
    print(
        f"release version {release_version} must be newer than published {published_version_text}",
        file=sys.stderr,
    )
    sys.exit(1)
if result == 0:
    sys.exit(2)
PY
  compare_status=$?
  set -e

  if [[ "$compare_status" == "2" ]]; then
    if [[ "$FORCE" == "1" ]]; then
      log "Release version $VERSION matches the published appcast; continuing because -f/--force is set"
      return 0
    fi
    fail "release version $VERSION already matches the published appcast; re-run with -f / --force to republish"
  elif [[ "$compare_status" != "0" ]]; then
    fail "release version $VERSION is not newer than the published appcast"
  fi

  log "Release version $VERSION is newer than the published appcast"
}

resolve_sparkle_tools() {
  local bin_dir="$ROOT_DIR/$DERIVED_DATA/SourcePackages/artifacts/sparkle/Sparkle/bin"
  if [[ -x "$bin_dir/sign_update" && -x "$bin_dir/generate_appcast" ]]; then
    SPARKLE_BIN_DIR="$bin_dir"
    return 0
  fi

  log "Resolving Sparkle command-line tools"
  command -v xcodegen >/dev/null || fail "xcodegen is required to generate $PROJECT"
  xcodegen generate

  xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$DERIVED_DATA" \
    -resolvePackageDependencies \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGN_IDENTITY="" \
    >/dev/null

  bin_dir="$ROOT_DIR/$DERIVED_DATA/SourcePackages/artifacts/sparkle/Sparkle/bin"
  [[ -x "$bin_dir/sign_update" && -x "$bin_dir/generate_appcast" ]] \
    || fail "Sparkle tools not found after package resolve (expected sign_update and generate_appcast under $bin_dir)"
  SPARKLE_BIN_DIR="$bin_dir"
}

preflight_publish() {
  command -v gh >/dev/null || fail "gh CLI is required to publish releases"
  gh auth status >/dev/null 2>&1 || fail "gh is not authenticated (run: gh auth login)"

  if ! git diff --quiet || ! git diff --cached --quiet; then
    fail "working tree has uncommitted changes; commit or stash before publishing"
  fi
}

preflight_release_tag() {
  if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null \
    || [[ -n "$(git ls-remote --tags origin "refs/tags/$TAG" 2>/dev/null)" ]]; then
    if [[ "$FORCE" != "1" ]]; then
      fail "tag $TAG already exists (local or origin). Re-run with -f / --force to overwrite it"
    fi
  fi
}

ensure_sparkle_key() {
  if [[ -f "$SPARKLE_PRIVATE_KEY_PATH" ]]; then
    SPARKLE_KEY_FILE="$SPARKLE_PRIVATE_KEY_PATH"
    return 0
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    SPARKLE_KEY_FILE="$STAGE_DIR/.dry-run-sparkle-ed25519-key"
    openssl rand -base64 32 | tr -d '\n' > "$SPARKLE_KEY_FILE"
    log "[dry-run] Sparkle private key not found at $SPARKLE_PRIVATE_KEY_PATH; using temporary key"
    return 0
  fi

  fail "Sparkle private key not found at $SPARKLE_PRIVATE_KEY_PATH"
}

prepare_stage() {
  rm -rf "$STAGE_DIR"
  mkdir -p "$STAGE_DIR"
}

build_release_app() {
  RELEASE_APP_PATH="$("$ROOT_DIR/scripts/build-release.sh")"
  [[ -d "$RELEASE_APP_PATH" ]] || fail "expected app bundle missing at $RELEASE_APP_PATH"
}

build_dry_run_app() {
  local app_path="$STAGE_DIR/${APP_NAME}.app"
  local minimum_version

  minimum_version="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' PeekBar/Resources/Info.plist 2>/dev/null || echo "26.0")"

  log "[dry-run] Staging synthetic ${APP_NAME}.app (skipping signed xcodebuild)"
  mkdir -p "$app_path/Contents/MacOS"

  cat > "$app_path/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>com.imekachi.PeekBar</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${VERSION}</string>
  <key>LSMinimumSystemVersion</key>
  <string>${minimum_version}</string>
</dict>
</plist>
PLIST

  : > "$app_path/Contents/MacOS/${APP_NAME}"
  RELEASE_APP_PATH="$app_path"
}

create_update_archive() {
  local archive_path="$STAGE_DIR/$ARCHIVE_NAME"
  log "Creating update archive $ARCHIVE_NAME"
  ditto -c -k --sequesterRsrc --keepParent "$RELEASE_APP_PATH" "$archive_path"
  [[ -f "$archive_path" ]] || fail "failed to create update archive at $archive_path"
  UPDATE_ARCHIVE_PATH="$archive_path"
}

sign_update_archive() {
  local signature_output redacted_output

  log "Signing update archive with Sparkle EdDSA key"
  signature_output="$("$SPARKLE_BIN_DIR/sign_update" --ed-key-file "$SPARKLE_KEY_FILE" "$UPDATE_ARCHIVE_PATH")"

  UPDATE_ED_SIGNATURE="$(printf '%s\n' "$signature_output" | sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p')"
  UPDATE_DSA_SIGNATURE="$(printf '%s\n' "$signature_output" | sed -n 's/.*sparkle:dsaSignature="\([^"]*\)".*/\1/p')"
  UPDATE_ARCHIVE_LENGTH="$(printf '%s\n' "$signature_output" | sed -n 's/.*length="\([^"]*\)".*/\1/p')"

  if [[ -z "$UPDATE_ED_SIGNATURE" && -z "$UPDATE_DSA_SIGNATURE" ]]; then
    fail "sign_update did not produce sparkle:edSignature or sparkle:dsaSignature for $UPDATE_ARCHIVE_PATH"
  fi
  [[ -n "$UPDATE_ARCHIVE_LENGTH" ]] || fail "sign_update did not return archive length for $UPDATE_ARCHIVE_PATH"

  redacted_output="$(printf '%s\n' "$signature_output" | sed -E 's/sparkle:(ed|dsa)Signature="[^"]*"/sparkle:\1Signature="[REDACTED]"/g')"
  echo "$redacted_output"
}

generate_appcast() {
  log "Generating appcast.xml"
  "$SPARKLE_BIN_DIR/generate_appcast" \
    --ed-key-file "$SPARKLE_KEY_FILE" \
    --download-url-prefix "$DOWNLOAD_PREFIX" \
    "$STAGE_DIR"
  [[ -f "$STAGE_DIR/appcast.xml" ]] || fail "appcast.xml was not generated in $STAGE_DIR"
  set_appcast_sparkle_version
}

set_appcast_sparkle_version() {
  local appcast="$STAGE_DIR/appcast.xml"
  local sparkle_version="$VERSION"

  log "Setting sparkle:version to ${sparkle_version} in appcast.xml"
  if ! python3 - "$appcast" "$sparkle_version" <<'PY'
import re
import sys
from pathlib import Path

appcast_path = Path(sys.argv[1])
sparkle_version = sys.argv[2]
text = appcast_path.read_text()
updated, count = re.subn(
    r"(<sparkle:version>)[^<]*(</sparkle:version>)",
    rf"\g<1>{sparkle_version}\g<2>",
    text,
    count=1,
)
if count != 1:
    print("ERROR: could not update sparkle:version in appcast.xml", file=sys.stderr)
    sys.exit(1)
appcast_path.write_text(updated)
PY
  then
    fail "failed to set sparkle:version in appcast.xml"
  fi
}

appcast_has_signature_metadata() {
  local appcast="$STAGE_DIR/appcast.xml"
  grep -qE 'sparkle:(edSignature|dsaSignature)=' "$appcast"
}

embed_update_signature_in_appcast() {
  local appcast="$STAGE_DIR/appcast.xml"

  if appcast_has_signature_metadata; then
    return 0
  fi

  log "Embedding Sparkle signature metadata into appcast.xml"
  if ! python3 - "$appcast" "$ARCHIVE_NAME" "$UPDATE_ED_SIGNATURE" "$UPDATE_DSA_SIGNATURE" "$UPDATE_ARCHIVE_LENGTH" <<'PY'
import re
import sys
from pathlib import Path

appcast_path = Path(sys.argv[1])
archive_name = sys.argv[2]
ed_signature = sys.argv[3]
dsa_signature = sys.argv[4]
length = sys.argv[5]

text = appcast_path.read_text()
if re.search(r"sparkle:(edSignature|dsaSignature)=", text):
    sys.exit(0)

pattern = re.compile(
    r'(<enclosure\b[^>]*\burl="[^"]*' + re.escape(archive_name) + r'"[^>]*?)\s*/>'
)
match = pattern.search(text)
if not match:
    print(f"ERROR: no enclosure found for {archive_name}", file=sys.stderr)
    sys.exit(1)

prefix = match.group(1).rstrip()
attrs = []
if ed_signature:
    attrs.append(f'sparkle:edSignature="{ed_signature}"')
if dsa_signature:
    attrs.append(f'sparkle:dsaSignature="{dsa_signature}"')
if not attrs:
    print("ERROR: no Sparkle signature attributes available to embed", file=sys.stderr)
    sys.exit(1)

if re.search(r'\blength="', prefix):
    prefix = re.sub(r'\blength="[^"]*"', f'length="{length}"', prefix, count=1)
else:
    attrs.append(f'length="{length}"')

replacement = f"{prefix} {' '.join(attrs)} />"
text = text[: match.start()] + replacement + text[match.end() :]
appcast_path.write_text(text)
PY
  then
    fail "failed to embed Sparkle signature metadata into appcast.xml"
  fi
}

verify_appcast_signatures() {
  local appcast="$STAGE_DIR/appcast.xml"

  if ! appcast_has_signature_metadata; then
    fail "appcast.xml is missing Sparkle signature metadata (sparkle:edSignature or sparkle:dsaSignature)"
  fi

  if ! grep -q "$ARCHIVE_NAME" "$appcast"; then
    fail "appcast.xml does not reference update archive $ARCHIVE_NAME"
  fi
}

verify_staged_assets() {
  local asset
  for asset in "$ARCHIVE_NAME" "appcast.xml"; do
    [[ -f "$STAGE_DIR/$asset" ]] || fail "expected staged asset missing: $STAGE_DIR/$asset"
  done
  verify_appcast_signatures
}

remote_tag_commit() {
  local peeled_sha direct_sha

  peeled_sha="$(git ls-remote --tags origin "refs/tags/$TAG^{}" 2>/dev/null | awk '{print $1}')"
  if [[ -n "$peeled_sha" ]]; then
    printf '%s' "$peeled_sha"
    return 0
  fi

  direct_sha="$(git ls-remote --tags origin "refs/tags/$TAG" 2>/dev/null | awk '{print $1}')"
  printf '%s' "$direct_sha"
}

ensure_release_tag() {
  local commit local_sha remote_sha
  local has_local=0 has_remote=0

  commit="$(git rev-parse HEAD)"

  if [[ "$FORCE" == "1" ]]; then
    log "Overwriting tag $TAG at $commit (-f)"
    git tag -f -a "$TAG" -m "$TAG" "$commit"
    git push -f origin "$TAG"
    return 0
  fi

  if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
    has_local=1
    local_sha="$(git rev-parse "refs/tags/$TAG^{commit}")"
    [[ "$local_sha" == "$commit" ]] \
      || fail "local tag $TAG points to $local_sha, not release commit $commit; delete or move the tag manually before publishing"
  fi

  remote_sha="$(remote_tag_commit)"
  if [[ -n "$remote_sha" ]]; then
    has_remote=1
    [[ "$remote_sha" == "$commit" ]] \
      || fail "remote tag $TAG points to $remote_sha, not release commit $commit; public release tags cannot be rewritten"
  fi

  if [[ "$has_local" == "1" && "$has_remote" == "1" ]]; then
    log "Local and remote tag $TAG already point to $commit"
  elif [[ "$has_local" == "1" ]]; then
    log "Pushing local tag $TAG to origin"
    git push origin "$TAG"
  elif [[ "$has_remote" == "1" ]]; then
    log "Fetching existing remote tag $TAG at $commit"
    git fetch origin "refs/tags/$TAG:refs/tags/$TAG"
  else
    log "Creating tag $TAG at $commit"
    git tag -a "$TAG" -m "$TAG" "$commit"
    log "Pushing tag $TAG"
    git push origin "$TAG"
  fi

  git rev-parse -q --verify "refs/tags/$TAG" >/dev/null \
    || fail "release tag $TAG is missing after tag preparation"
}

publish_release() {
  local commit branch release_body commit_log prev_tag compare_url

  commit="$(git rev-parse HEAD)"
  branch="$(git rev-parse --abbrev-ref HEAD)"
  [[ "$branch" == "main" ]] || echo "WARNING: releasing from '$branch', not 'main'"

  log "Pushing branch $branch"
  git push origin "$branch"

  ensure_release_tag

  prev_tag="$(git tag --list 'v*' --sort=-v:refname | grep -vx "$TAG" | head -n1 || true)"
  if [[ -n "$prev_tag" ]]; then
    commit_log="$(git log "$prev_tag..$commit" --no-merges --pretty=format:'* %s')"
    compare_url="https://github.com/${GITHUB_REPOSITORY}/compare/${prev_tag}...${TAG}"
  else
    commit_log="$(git log "$commit" --no-merges --pretty=format:'* %s')"
    compare_url=""
  fi

  release_body="## What's Changed"$'\n'"${commit_log:-* PeekBar ${VERSION}}"
  [[ -n "$compare_url" ]] && release_body+=$'\n\n**Full Changelog**: '"$compare_url"

  if gh release view "$TAG" --repo "$GITHUB_REPOSITORY" >/dev/null 2>&1; then
    log "Release $TAG exists; uploading/overwriting assets + notes"
    gh release upload "$TAG" --repo "$GITHUB_REPOSITORY" --clobber \
      "$STAGE_DIR/$ARCHIVE_NAME" \
      "$STAGE_DIR/appcast.xml"
    gh release edit "$TAG" --repo "$GITHUB_REPOSITORY" --notes "$release_body"
  else
    log "Creating GitHub Release $TAG"
    gh release create "$TAG" \
      --repo "$GITHUB_REPOSITORY" \
      --title "$TAG" \
      --notes "$release_body" \
      --target "$commit" \
      "$STAGE_DIR/$ARCHIVE_NAME" \
      "$STAGE_DIR/appcast.xml"
  fi

  log "Done. Appcast: https://github.com/${GITHUB_REPOSITORY}/releases/latest/download/appcast.xml"
}

resolve_release_version() {
  if [[ "$DRY_RUN" == "1" ]]; then
    read_version
    if [[ -n "$VERSION_ARG" ]]; then
      log "[dry-run] Using requested version $VERSION_ARG without editing version files"
      set_release_version "$VERSION_ARG"
    fi
    return 0
  fi

  if [[ -n "$VERSION_ARG" ]]; then
    set_release_version "$VERSION_ARG"
    preflight_release_tag
    bump_version "$VERSION_ARG"
  fi

  read_version

  if [[ -n "$VERSION_ARG" && "$VERSION" != "$VERSION_ARG" ]]; then
    fail "version files resolved to $VERSION after bump, expected $VERSION_ARG"
  fi

  preflight_release_tag
  preflight_sparkle_version
}

main() {
  load_env
  normalize_env
  require_env

  if [[ "$DRY_RUN" == "1" ]]; then
    resolve_release_version
    log "[dry-run] Releasing $TAG (local staging only; no tag, push, or GitHub mutation)"
  else
    preflight_publish
    resolve_release_version
    log "Releasing $TAG"
  fi

  resolve_sparkle_tools
  prepare_stage

  if [[ "$DRY_RUN" == "1" ]]; then
    build_dry_run_app
  else
    build_release_app
  fi

  ensure_sparkle_key
  create_update_archive
  sign_update_archive
  generate_appcast
  embed_update_signature_in_appcast
  verify_staged_assets

  log "Staged assets in $STAGE_DIR:"
  ls -1 "$STAGE_DIR"

  if [[ "$DRY_RUN" == "1" ]]; then
    log "[dry-run] Complete. Would upload to GitHub Release $TAG:"
    echo "  - $ARCHIVE_NAME"
    echo "  - appcast.xml"
    echo "  Download prefix: $DOWNLOAD_PREFIX"
    exit 0
  fi

  publish_release
}

main "$@"
