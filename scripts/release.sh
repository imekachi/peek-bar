#!/usr/bin/env bash
#
# Local release: build a signed PeekBar.app, create a Sparkle update archive,
# sign it, generate appcast.xml, and publish GitHub Release assets.
#
# Prerequisites (one-time, local-only — never commit):
#   - .env.release with PEEKBAR_SIGNING_IDENTITY, SPARKLE_PRIVATE_KEY_PATH,
#     and GITHUB_REPOSITORY (see .env.release.example).
#   - Sparkle EdDSA private key at SPARKLE_PRIVATE_KEY_PATH.
#   - `gh` CLI authenticated for publishing (not required for --dry-run).
#
# Usage:
#   ./scripts/release.sh --dry-run    # stage assets locally; no tag/gh/git mutation
#   ./scripts/release.sh              # build, tag, and publish a GitHub Release
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

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    -h|--help)
      sed -n '2,16p' "$0"
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument '$arg' (supported: --dry-run)" >&2
      exit 1
      ;;
  esac
done

log() {
  echo "==> $*"
}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

load_env() {
  local env_file="$ROOT_DIR/.env.release"
  if [[ -f "$env_file" ]]; then
    log "Loading $env_file"
    set -a
    # shellcheck disable=SC1090
    source "$env_file"
    set +a
  fi
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
    echo "Set them in .env.release (gitignored) or export them in your shell." >&2
    exit 1
  fi
}

read_version() {
  local from_project from_plist

  from_project="$(awk -F': ' '/^[[:space:]]*MARKETING_VERSION:/ {print $2; exit}' project.yml | tr -d ' "')"
  from_plist="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' PeekBar/Resources/Info.plist 2>/dev/null || true)"

  VERSION="${from_project:-$from_plist}"
  [[ -n "$VERSION" ]] || fail "could not determine marketing version from project.yml or Info.plist"

  BUILD_NUMBER="$(awk -F': ' '/^[[:space:]]*CURRENT_PROJECT_VERSION:/ {print $2; exit}' project.yml | tr -d ' "')"
  if [[ -z "$BUILD_NUMBER" ]]; then
    BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' PeekBar/Resources/Info.plist 2>/dev/null || true)"
  fi
  [[ -n "$BUILD_NUMBER" ]] || fail "could not determine build number from project.yml or Info.plist"

  TAG="v$VERSION"
  ARCHIVE_NAME="${APP_NAME}-${VERSION}.zip"
  DOWNLOAD_PREFIX="https://github.com/${GITHUB_REPOSITORY}/releases/download/${TAG}/"
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
  local products_dir="$ROOT_DIR/$DERIVED_DATA/Build/Products/Release"
  local app_path="$products_dir/${APP_NAME}.app"

  log "Building signed ${APP_NAME}.app (Release)"
  xcodegen generate

  xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGN_IDENTITY="$PEEKBAR_SIGNING_IDENTITY" \
    CODE_SIGNING_ALLOWED=YES \
  build

  [[ -d "$app_path" ]] || fail "expected app bundle missing at $app_path"
  RELEASE_APP_PATH="$app_path"
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
  <string>${BUILD_NUMBER}</string>
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
  local signature_output
  log "Signing update archive with Sparkle EdDSA key"
  signature_output="$("$SPARKLE_BIN_DIR/sign_update" --ed-key-file "$SPARKLE_KEY_FILE" "$UPDATE_ARCHIVE_PATH")"
  echo "$signature_output" | sed 's/sparkle:edSignature="[^"]*"/sparkle:edSignature="[REDACTED]"/'
}

generate_appcast() {
  log "Generating appcast.xml"
  "$SPARKLE_BIN_DIR/generate_appcast" \
    --ed-key-file "$SPARKLE_KEY_FILE" \
    --download-url-prefix "$DOWNLOAD_PREFIX" \
    "$STAGE_DIR"
  [[ -f "$STAGE_DIR/appcast.xml" ]] || fail "appcast.xml was not generated in $STAGE_DIR"
}

verify_staged_assets() {
  local asset
  for asset in "$ARCHIVE_NAME" "appcast.xml"; do
    [[ -f "$STAGE_DIR/$asset" ]] || fail "expected staged asset missing: $STAGE_DIR/$asset"
  done
}

publish_release() {
  local commit branch release_body commit_log prev_tag compare_url

  commit="$(git rev-parse HEAD)"
  branch="$(git rev-parse --abbrev-ref HEAD)"
  [[ "$branch" == "main" ]] || echo "WARNING: releasing from '$branch', not 'main'"

  log "Pushing branch $branch"
  git push origin "$branch"

  if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
    log "Tag $TAG exists locally; moving to $commit"
    git tag -f -a "$TAG" -m "$TAG" "$commit"
    git push -f origin "$TAG"
  else
    log "Tagging $commit as $TAG"
    git tag -a "$TAG" -m "$TAG" "$commit"
    git push origin "$TAG"
  fi

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
    log "Release $TAG exists; uploading assets"
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

main() {
  load_env
  require_env
  read_version

  if [[ "$DRY_RUN" == "1" ]]; then
    log "[dry-run] Releasing $TAG (local staging only; no tag, push, or GitHub mutation)"
  else
    log "Releasing $TAG"
    preflight_publish
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
