#!/usr/bin/env bash
#
# Build a signed Release PeekBar.app (arm64-only, thinned, re-signed).
#
# Prerequisites:
#   - xcodegen
#   - .env.local with PEEKBAR_SIGNING_IDENTITY or APPLE_SIGNING_IDENTITY
#     (optional PEEKBAR_DEVELOPMENT_TEAM, DEVELOPMENT_TEAM, or APPLE_TEAM_ID)
#
# Usage:
#   ./scripts/build-release.sh
#
# Prints the absolute path to PeekBar.app on stdout. Progress logs go to stderr.
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="PeekBar"
SCHEME="PeekBar"
PROJECT="PeekBar.xcodeproj"
DERIVED_DATA="build"
RELEASE_ARCH="arm64"

log() {
  echo "==> $*" >&2
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

require_signing_env() {
  if [[ -z "${PEEKBAR_SIGNING_IDENTITY:-}" ]]; then
    echo "ERROR: missing signing identity (set PEEKBAR_SIGNING_IDENTITY or APPLE_SIGNING_IDENTITY in .env.local)" >&2
    exit 1
  fi
}

verify_release_architecture() {
  local app_path="$1"
  local binary archs relative
  local unexpected=()

  while IFS= read -r -d '' binary; do
    if /usr/bin/file "$binary" | grep -q 'Mach-O'; then
      archs="$(/usr/bin/lipo -archs "$binary" 2>/dev/null || true)"
      if [[ "$archs" != "$RELEASE_ARCH" ]]; then
        relative="${binary#$app_path/}"
        unexpected+=("$relative [$archs]")
      fi
    fi
  done < <(/usr/bin/find "$app_path" -type f -print0)

  if [[ ${#unexpected[@]} -gt 0 ]]; then
    echo "ERROR: release app contains non-${RELEASE_ARCH} Mach-O binaries:" >&2
    printf '  - %s\n' "${unexpected[@]}" >&2
    exit 1
  fi

  log "Verified release app contains ${RELEASE_ARCH}-only Mach-O binaries"
}

thin_release_architecture() {
  local app_path="$1"
  local binary archs mode relative tmp
  local thinned=()

  while IFS= read -r -d '' binary; do
    if ! /usr/bin/file "$binary" | grep -q 'Mach-O'; then
      continue
    fi

    archs="$(/usr/bin/lipo -archs "$binary" 2>/dev/null || true)"
    relative="${binary#$app_path/}"
    if [[ " $archs " != *" $RELEASE_ARCH "* ]]; then
      fail "$relative does not contain required architecture $RELEASE_ARCH (found: ${archs:-unknown})"
    fi

    if [[ "$archs" == "$RELEASE_ARCH" ]]; then
      continue
    fi

    mode="$(/usr/bin/stat -f '%Lp' "$binary")"
    tmp="$(/usr/bin/mktemp "$binary.XXXXXX")"
    if ! /usr/bin/lipo "$binary" -thin "$RELEASE_ARCH" -output "$tmp"; then
      rm -f "$tmp"
      fail "failed to thin $relative to $RELEASE_ARCH"
    fi
    chmod "$mode" "$tmp"
    mv "$tmp" "$binary"
    thinned+=("$relative")
  done < <(/usr/bin/find "$app_path" -type f -print0)

  if [[ ${#thinned[@]} -gt 0 ]]; then
    log "Thinned ${#thinned[@]} Mach-O binaries to ${RELEASE_ARCH}"
  fi
}

resign_release_app() {
  local app_path="$1"

  log "Re-signing thinned ${APP_NAME}.app"
  /usr/bin/codesign \
    --force \
    --deep \
    --sign "$PEEKBAR_SIGNING_IDENTITY" \
    --preserve-metadata=identifier,entitlements,requirements,flags,runtime \
    "$app_path" \
    || fail "failed to re-sign thinned ${APP_NAME}.app"

  /usr/bin/codesign --verify --deep --strict "$app_path" \
    || fail "failed to verify signature for thinned ${APP_NAME}.app"
}

main() {
  local products_dir="$ROOT_DIR/$DERIVED_DATA/Build/Products/Release"
  local app_path="$products_dir/${APP_NAME}.app"
  local xcodebuild_args

  load_env
  normalize_env
  require_signing_env

  log "Building signed ${APP_NAME}.app (Release, ${RELEASE_ARCH} only)"
  command -v xcodegen >/dev/null || fail "xcodegen is required to generate $PROJECT"
  xcodegen generate >&2

  xcodebuild_args=(
    -project "$PROJECT"
    -scheme "$SCHEME"
    -configuration Release
    -derivedDataPath "$DERIVED_DATA"
    CODE_SIGN_STYLE=Manual
    CODE_SIGN_IDENTITY="$PEEKBAR_SIGNING_IDENTITY"
    CODE_SIGNING_ALLOWED=YES
    ARCHS="$RELEASE_ARCH"
    EXCLUDED_ARCHS="x86_64"
    ONLY_ACTIVE_ARCH=NO
  )
  if [[ -n "$PEEKBAR_DEVELOPMENT_TEAM" ]]; then
    xcodebuild_args+=(DEVELOPMENT_TEAM="$PEEKBAR_DEVELOPMENT_TEAM")
  fi
  xcodebuild_args+=(build)

  xcodebuild "${xcodebuild_args[@]}" >&2

  [[ -d "$app_path" ]] || fail "expected app bundle missing at $app_path"
  thin_release_architecture "$app_path"
  resign_release_app "$app_path"
  verify_release_architecture "$app_path"

  printf '%s\n' "$app_path"
}

main "$@"
