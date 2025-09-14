#!/usr/bin/env bash
set -euo pipefail

log() { echo "[$(date +'%H:%M:%S')] $*"; }
fail() { echo "ERROR: $*" >&2; exit 1; }

# Inputs mapped from the original GitHub Action
WORKING_DIRECTORY="${WORKING_DIRECTORY:-$BITRISE_SOURCE_DIR}"
DESTINATION="${DESTINATION:-simulator}"
SCHEME="${SCHEME:-}"
CONFIGURATION="${CONFIGURATION:-}"
RE_SIGN="${RE_SIGN:-}"
AD_HOC="${AD_HOC:-false}"

CERTIFICATE_BASE64="${CERTIFICATE_BASE64:-}"
CERTIFICATE_PASSWORD="${CERTIFICATE_PASSWORD:-}"
PROVISIONING_PROFILE_BASE64="${PROVISIONING_PROFILE_BASE64:-}"
PROVISIONING_PROFILE_NAME="${PROVISIONING_PROFILE_NAME:-}"
KEYCHAIN_PASSWORD="${KEYCHAIN_PASSWORD:-}"

ROCK_BUILD_EXTRA_PARAMS="${ROCK_BUILD_EXTRA_PARAMS:-}"

RUNNER_TEMP="${RUNNER_TEMP:-${TMPDIR:-/tmp}}"

# Validate inputs (mirror composite action behavior)
if [ "$DESTINATION" != "simulator" ] && [ "$DESTINATION" != "device" ]; then
  fail "Invalid input 'destination': '$DESTINATION'. Allowed values: 'simulator' or 'device'."
fi

if [ "$DESTINATION" = "device" ]; then
  [ -z "$CERTIFICATE_BASE64" ] && fail "Input 'certificate-base64' is required for device builds."
  [ -z "$CERTIFICATE_PASSWORD" ] && fail "Input 'certificate-password' is required for device builds."
  [ -z "$PROVISIONING_PROFILE_BASE64" ] && fail "Input 'provisioning-profile-base64' is required for device builds."
  [ -z "$PROVISIONING_PROFILE_NAME" ] && fail "Input 'provisioning-profile-name' is required for device builds."
  [ -z "$KEYCHAIN_PASSWORD" ] && fail "Input 'keychain-password' is required for device builds."
fi

# Provisioning profile dir
PROFILE_DIR="$HOME/Library/MobileDevice/Provisioning Profiles"
envman add --key PROFILE_DIR --value "$PROFILE_DIR"

# Fingerprint
pushd "$WORKING_DIRECTORY" >/dev/null
log "Generating fingerprint"
if ! FINGERPRINT_OUTPUT="$(npx rock fingerprint -p ios --raw)"; then
  echo "$FINGERPRINT_OUTPUT"
  fail "Fingerprint failed"
fi
FINGERPRINT="$FINGERPRINT_OUTPUT"
envman add --key FINGERPRINT --value "$FINGERPRINT"
popd >/dev/null

# Detect provider and fail early if GitHub (not supported from this Bitrise step)
pushd "$WORKING_DIRECTORY" >/dev/null
log "Detecting provider name"
if ! PROVIDER_NAME="$(npx rock remote-cache get-provider-name)"; then
  echo "$PROVIDER_NAME"
  fail "remote-cache get-provider-name failed"
fi
popd >/dev/null

if [ "$PROVIDER_NAME" = "GitHub" ]; then
  fail "Provider 'GitHub' is not supported from this Bitrise step. Please configure Rock remote cache with a non-GitHub provider."
fi

# Artifact discovery
ARTIFACT_NAME="${ARTIFACT_NAME:-}"
ARTIFACT_URL="${ARTIFACT_URL:-}"
ARTIFACT_ID="${ARTIFACT_ID:-}"

# PR-specific artifact (avoid overwriting the main artifact with new JS bundle)
if [ "${BITRISE_GIT_EVENT_TYPE:-}" = "pull_request" ] && [ "$RE_SIGN" = "true" ]; then
  ARTIFACT_TRAITS="${DESTINATION},${CONFIGURATION},${BITRISE_PULL_REQUEST:-}"
  envman add --key ARTIFACT_TRAITS --value "$ARTIFACT_TRAITS"

  OUTPUT=$(npx rock remote-cache list -p ios --traits "${ARTIFACT_TRAITS}" --json || (echo "$OUTPUT" && exit 1))
  if [ -n "$OUTPUT" ]; then
    ARTIFACT_URL="$(echo "$OUTPUT" | jq -r '.url')"
    ARTIFACT_ID="$(echo "$OUTPUT" | jq -r '.id')"
    ARTIFACT_NAME="$(echo "$OUTPUT" | jq -r '.name')"
    envman add --key ARTIFACT_URL --value "$ARTIFACT_URL"
    envman add --key ARTIFACT_ID --value "$ARTIFACT_ID"
    envman add --key ARTIFACT_NAME --value "$ARTIFACT_NAME"
  fi
fi

# Regular artifact
if [ -z "$ARTIFACT_NAME" ]; then
  ARTIFACT_TRAITS="${DESTINATION},${CONFIGURATION}"
  envman add --key ARTIFACT_TRAITS --value "$ARTIFACT_TRAITS"

  OUTPUT=$(npx rock remote-cache list -p ios --traits "${ARTIFACT_TRAITS}" --json || (echo "$OUTPUT" && exit 1))
  if [ -n "$OUTPUT" ]; then
    ARTIFACT_URL="$(echo "$OUTPUT" | jq -r '.url')"
    ARTIFACT_ID="$(echo "$OUTPUT" | jq -r '.id')"
    ARTIFACT_NAME="$(echo "$OUTPUT" | jq -r '.name')"
    envman add --key ARTIFACT_URL --value "$ARTIFACT_URL"
    envman add --key ARTIFACT_ID --value "$ARTIFACT_ID"
    envman add --key ARTIFACT_NAME --value "$ARTIFACT_NAME"
  fi
fi

# Set Artifact Name (if not set)
if [ -z "$ARTIFACT_NAME" ]; then
  ARTIFACT_TRAITS_HYPHENATED="$(echo "$ARTIFACT_TRAITS" | tr ',' '-')"
  ARTIFACT_TRAITS_HYPHENATED_FINGERPRINT="${ARTIFACT_TRAITS_HYPHENATED}-${FINGERPRINT}"
  ARTIFACT_NAME="rock-ios-${ARTIFACT_TRAITS_HYPHENATED_FINGERPRINT}"
  envman add --key ARTIFACT_NAME --value "$ARTIFACT_NAME"
fi

# Setup Code Signing (device builds only)
if { [ "$RE_SIGN" = "true" ] && [ "$DESTINATION" = "device" ]; } || { [ -z "$ARTIFACT_URL" ] && [ "$DESTINATION" = "device" ]; }; then
  KEYCHAIN_PATH="$RUNNER_TEMP/app-signing.keychain-db"

  security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
  security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
  security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"

  CERTIFICATE_PATH="$RUNNER_TEMP/certificate.p12"
  echo -n "$CERTIFICATE_BASE64" | base64 --decode -o "$CERTIFICATE_PATH"
  security import "$CERTIFICATE_PATH" -P "$CERTIFICATE_PASSWORD" -A -t cert -f pkcs12 -k "$KEYCHAIN_PATH"
  security set-key-partition-list -S apple-tool:,apple: -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
  security list-keychain -d user -s "$KEYCHAIN_PATH"

  IDENTITY=$(security find-identity -v -p codesigning "$KEYCHAIN_PATH" | grep -oE '([0-9A-F]{40})' | head -n 1 || (echo "$IDENTITY" && exit 1))
  echo "Certificate identity: $IDENTITY"
  envman add --key IDENTITY --value "$IDENTITY"

  mkdir -p "$PROFILE_DIR"
  PROFILE_PATH="$PROFILE_DIR/$PROVISIONING_PROFILE_NAME.mobileprovision"
  echo -n "$PROVISIONING_PROFILE_BASE64" | base64 --decode -o "$PROFILE_PATH"
fi

# Build if no artifact was found
if [ -z "$ARTIFACT_URL" ]; then
  pushd "$WORKING_DIRECTORY" >/dev/null
  JSON_OUTPUT=$(npx rock config -p ios || (echo "$JSON_OUTPUT" && exit 1))
  IOS_SOURCE_DIR="$(echo "$JSON_OUTPUT" | jq -r '.project.ios.sourceDir')"
  log "Resolved ios.sourceDir: ${IOS_SOURCE_DIR:-<empty>}"
  envman add --key IOS_SOURCE_DIR --value "$IOS_SOURCE_DIR"

  # Build iOS with safe extra params handling (no eval)
  BUILD_ARGS=(--scheme "$SCHEME" --configuration "$CONFIGURATION" --build-folder build --destination "$DESTINATION" --verbose)
  if [ "$DESTINATION" = "device" ]; then
    BUILD_ARGS+=("--archive")
  fi

  if [ -n "$ROCK_BUILD_EXTRA_PARAMS" ]; then
    IFS=' ' read -r -a EXTRA_ARR <<< "$ROCK_BUILD_EXTRA_PARAMS"
    BUILD_ARGS+=("${EXTRA_ARR[@]}")
  fi

  npx rock build:ios "${BUILD_ARGS[@]}"
  popd >/dev/null

  # Find Build Artifact
  if [ "$DESTINATION" = "device" ]; then
    IPA_PATH="$(find .rock/cache/ios/export -maxdepth 1 -name '*.ipa' -type f | head -1)"
    echo "IPA_PATH $IPA_PATH"
    envman add --key ARTIFACT_PATH --value "$IPA_PATH"
  else
    APP_PATH="$(find "$IOS_SOURCE_DIR"/build -name '*.app' -type d | head -1 )"
    APP_DIR="$(dirname "$APP_PATH")"
    APP_BASENAME="$(basename "$APP_PATH")"

    ARTIFACT_PATH="$APP_DIR/app.tar.gz"
    tar -C "$APP_DIR" -czvf "$ARTIFACT_PATH" "$APP_BASENAME"
    envman add --key ARTIFACT_PATH --value "$ARTIFACT_PATH"
  fi
fi

# PR re-sign: download and (re)sign/rebundle
if [ -n "$ARTIFACT_URL" ] && [ "$RE_SIGN" = "true" ] && [ "${BITRISE_GIT_EVENT_TYPE:-}" = "pull_request" ]; then
  log "Downloading cached artifact from remote cache: name=$ARTIFACT_NAME"
  DOWNLOAD_OUTPUT=$(npx rock remote-cache download --name "$ARTIFACT_NAME" --json || (echo "$DOWNLOAD_OUTPUT" && exit 1))
  DL_PATH="$(echo "$DOWNLOAD_OUTPUT" | jq -r '.path')"

  if [ "$DESTINATION" = "device" ]; then
    envman add --key ARTIFACT_PATH --value "$DL_PATH"
    log "Re-signing IPA with new JS bundle: path=$DL_PATH identity=${IDENTITY:-unset}"
    pushd "$WORKING_DIRECTORY" >/dev/null
    npx rock sign:ios "$DL_PATH" --build-jsbundle --identity "$IDENTITY"
    popd >/dev/null
  else
    APP_DIR="$(dirname "$DL_PATH")"
    log "Unpacking APP tarball: $DL_PATH"
    tar -C "$APP_DIR" -xzf "$DL_PATH"
    EXTRACTED_APP="$(find "$APP_DIR" -name '*.app' -type d | head -1)"
    envman add --key ARTIFACT_PATH --value "$DL_PATH"
    envman add --key ARTIFACT_TAR_PATH --value "$EXTRACTED_APP"

    log "Re-bundling APP with new JS: app=$EXTRACTED_APP"
    pushd "$WORKING_DIRECTORY" >/dev/null
    npx rock sign:ios "$EXTRACTED_APP" --build-jsbundle --app
    popd >/dev/null
  fi

  # Update Artifact Name for re-signed builds
  ARTIFACT_TRAITS="${DESTINATION},${CONFIGURATION},${BITRISE_PULL_REQUEST:-}"
  ARTIFACT_TRAITS_HYPHENATED="$(echo "$ARTIFACT_TRAITS" | tr ',' '-')"
  ARTIFACT_TRAITS_HYPHENATED_FINGERPRINT="${ARTIFACT_TRAITS_HYPHENATED}-${FINGERPRINT}"
  ARTIFACT_NAME="rock-ios-${ARTIFACT_TRAITS_HYPHENATED_FINGERPRINT}"
  envman add --key ARTIFACT_NAME --value "$ARTIFACT_NAME"
  envman add --key ARTIFACT_TRAITS --value "$ARTIFACT_TRAITS"
fi

# Find artifact URL again before uploading
OUTPUT=$(npx rock remote-cache list --name "$ARTIFACT_NAME" --json || (echo "$OUTPUT" && exit 1))
if [ -n "$OUTPUT" ]; then
  ARTIFACT_URL="$(echo "$OUTPUT" | jq -r '.url')"
  ARTIFACT_ID="$(echo "$OUTPUT" | jq -r '.id')"
  envman add --key ARTIFACT_URL --value "$ARTIFACT_URL"
  envman add --key ARTIFACT_ID --value "$ARTIFACT_ID"
fi

# Copy artifact to Bitrise Deploy dir (parity with "Upload Artifact to GitHub" intent)
if { [ -z "${ARTIFACT_URL:-}" ] || { [ "$RE_SIGN" = "true" ] && [ "${BITRISE_GIT_EVENT_TYPE:-}" = "pull_request" ]; }; } && [ -n "${ARTIFACT_PATH:-}" ]; then
  if [ -n "${BITRISE_DEPLOY_DIR:-}" ]; then
    TARGET_PATH="$BITRISE_DEPLOY_DIR/$ARTIFACT_NAME"
    log "Copying artifact to Bitrise Deploy dir: $TARGET_PATH"
    cp "$ARTIFACT_PATH" "$TARGET_PATH"
    envman add --key UPLOAD_ARTIFACT_URL --value "${BITRISE_BUILD_URL:-}/artifacts"
    envman add --key UPLOAD_ARTIFACT_ID --value "bitrise-$ARTIFACT_NAME"
  fi
fi

# Upload to Remote Cache for re-signed builds (PR)
if [ "$RE_SIGN" = "true" ] && [ "${BITRISE_GIT_EVENT_TYPE:-}" = "pull_request" ] && [ -n "${ARTIFACT_PATH:-}" ]; then
  OUTPUT=$(npx rock remote-cache upload --name "$ARTIFACT_NAME" --binary-path "$ARTIFACT_PATH" --json || (echo "$OUTPUT" && exit 1))
  if [ -n "$OUTPUT" ]; then
    ARTIFACT_URL="$(echo "$OUTPUT" | jq -r '.url')"
    envman add --key ARTIFACT_URL --value "$ARTIFACT_URL"
  fi
fi

# Upload to Remote Cache for regular builds
if [ -z "${ARTIFACT_URL:-}" ]; then
  OUTPUT=$(npx rock remote-cache upload --name "$ARTIFACT_NAME" --json || (echo "$OUTPUT" && exit 1))
  if [ -n "$OUTPUT" ]; then
    ARTIFACT_URL="$(echo "$OUTPUT" | jq -r '.url')"
    envman add --key ARTIFACT_URL --value "$ARTIFACT_URL"
  fi
fi

# Upload for Ad-hoc distribution
if [ "$AD_HOC" = "true" ] && [ -n "${ARTIFACT_PATH:-}" ]; then
  OUTPUT=$(npx rock remote-cache upload --name "$ARTIFACT_NAME" --binary-path "$ARTIFACT_PATH" --json --ad-hoc || (echo "$OUTPUT" && exit 1))
  if [ -n "$OUTPUT" ]; then
    ARTIFACT_URL="$(echo "$OUTPUT" | jq -r '.url')"
    envman add --key ARTIFACT_URL --value "$ARTIFACT_URL"
  fi
fi

# Delete Old Re-Signed Artifacts
if [ -n "${ARTIFACT_URL:-}" ] && [ "$RE_SIGN" = "true" ] && [ "${BITRISE_GIT_EVENT_TYPE:-}" = "pull_request" ]; then
  npx rock remote-cache delete --name "$ARTIFACT_NAME" --all-but-latest --json
fi

# Clean Up Code Signing (device builds only, when we built locally)
if [ -z "${ARTIFACT_URL:-}" ] && [ "$DESTINATION" = "device" ]; then
  KEYCHAIN_PATH="$RUNNER_TEMP/app-signing.keychain-db"
  security delete-keychain "$KEYCHAIN_PATH"

  PROFILE_PATH="$PROFILE_DIR/$PROVISIONING_PROFILE_NAME.mobileprovision"
  rm -f "$PROFILE_PATH"
fi

# Cleanup Cache glue
rm -rf .rock/cache/project.json

# Outputs
[ -n "${ARTIFACT_URL:-}" ] && envman add --key ARTIFACT_URL --value "$ARTIFACT_URL"
[ -n "${ARTIFACT_ID:-}" ] && envman add --key ARTIFACT_ID --value "$ARTIFACT_ID"

log "Done."
