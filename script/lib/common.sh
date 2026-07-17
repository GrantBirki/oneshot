#!/usr/bin/env bash

set -euo pipefail

readonly XCODEGEN_VERSION="2.46.0"
readonly XCODEGEN_SHA256="4d9e34b62172d645eed6457cac13fc222569974098ef4ee9c3368bedf0196806"
readonly XCODEGEN_URL="https://github.com/yonaskolb/XcodeGen/releases/download/${XCODEGEN_VERSION}/xcodegen.zip"
readonly SWIFTLINT_VERSION="0.65.0"
readonly SWIFTLINT_SHA256="d6cb0aa7a2f5f1ef306fc9e37bcb54dc9a26facc8f7784ac0c3dd3eccf5c6ba6"
readonly SWIFTLINT_URL="https://github.com/realm/SwiftLint/releases/download/${SWIFTLINT_VERSION}/portable_swiftlint.zip"
readonly SWIFTFORMAT_VERSION="0.62.1"
readonly SWIFTFORMAT_SHA256="7cb1cb1fae04932047c7015441c543848e8e60e1572d808d080e0a1f1661114a"
readonly SWIFTFORMAT_URL="https://github.com/nicklockwood/SwiftFormat/releases/download/${SWIFTFORMAT_VERSION}/swiftformat.zip"

require_macos() {
  local mode="${1:-error}"
  local message="${2:-}"

  if [[ "$(uname -s)" != "Darwin" ]]; then
    if [[ "$mode" == "skip" ]]; then
      if [[ -n "$message" ]]; then
        echo -e "${YELLOW}${message}${OFF}"
      else
        echo -e "${YELLOW}Skipping on non-macOS host.${OFF}"
      fi
      exit 0
    fi

    if [[ -n "$message" ]]; then
      echo -e "${RED}${message}${OFF}"
    else
      echo -e "${RED}This script requires macOS.${OFF}"
    fi
    exit 1
  fi
}

require_tool() {
  local tool="$1"
  local message="${2:-${tool} not found.}"

  if ! command -v "$tool" >/dev/null 2>&1; then
    echo -e "${RED}${message}${OFF}"
    exit 1
  fi
}

require_pinned_tool() {
  local tool="$1"
  if [[ ! -x "$TOOLS_BIN/$tool" ]]; then
    echo -e "${RED}Pinned ${tool} not found. Run script/bootstrap.${OFF}"
    exit 1
  fi
}

require_full_xcode() {
  require_macos error "This command requires macOS."
  require_tool xcode-select "xcode-select not found. Install Xcode 26."
  require_tool xcodebuild "xcodebuild not found. Install Xcode 26."
  require_tool xcrun "xcrun not found. Install Xcode 26."

  local developer_dir
  developer_dir="$(xcode-select -p 2>/dev/null || true)"
  if [[ -z "$developer_dir" || "$developer_dir" == *"CommandLineTools"* ]]; then
    echo -e "${RED}Full Xcode 26 is required; Command Line Tools alone are not sufficient.${OFF}"
    echo "Select it with: sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer"
    exit 1
  fi

  local xcode_output
  if ! xcode_output="$(xcodebuild -version 2>&1)"; then
    echo -e "${RED}Unable to read the selected Xcode version.${OFF}"
    echo "$xcode_output"
    exit 1
  fi

  local xcode_version
  xcode_version="$(awk '/^Xcode / {print $2; exit}' <<< "$xcode_output")"
  if [[ "$xcode_version" != 26.* ]]; then
    echo -e "${RED}Xcode 26.x is required; selected version is ${xcode_version:-unknown}.${OFF}"
    exit 1
  fi

  local sdk_version sdk_output
  if ! sdk_output="$(xcrun --sdk macosx --show-sdk-version 2>&1)"; then
    echo -e "${RED}Unable to read the selected macOS SDK version.${OFF}"
    if [[ "$sdk_output" == *"license"* ]]; then
      echo "Accept the Xcode license with: sudo xcodebuild -license"
    else
      echo "$sdk_output"
    fi
    exit 1
  fi
  sdk_version="$sdk_output"
  if [[ "$sdk_version" != 26.* ]]; then
    echo -e "${RED}The macOS 26 SDK is required; selected SDK is ${sdk_version:-unknown}.${OFF}"
    exit 1
  fi
}

find_xcrun_tool() {
  local tool="$1"
  local tool_path
  if ! tool_path="$(xcrun --find "$tool" 2>/dev/null)"; then
    echo -e "${RED}${tool} was not found in the selected Xcode installation.${OFF}" >&2
    exit 1
  fi
  echo "$tool_path"
}

archive_sha256() {
  shasum -a 256 "$1" | awk '{print $1}'
}

download_verified_archive() {
  local name="$1"
  local version="$2"
  local url="$3"
  local expected_sha="$4"
  local archive="$TOOLS_ROOT/downloads/${name}-${version}.zip"
  local actual_sha=""

  mkdir -p "$TOOLS_ROOT/downloads"
  if [[ -f "$archive" ]]; then
    actual_sha="$(archive_sha256 "$archive")"
  fi

  if [[ "$actual_sha" != "$expected_sha" ]]; then
    local download="$archive.download.$$"
    rm -f "$download"
    echo -e "${BLUE}Downloading${OFF} - ${name} ${version}" >&2
    if ! curl --fail --location --retry 3 --retry-all-errors --silent --show-error --output "$download" "$url"; then
      rm -f "$download"
      echo -e "${RED}Failed to download ${name} ${version}.${OFF}" >&2
      exit 1
    fi

    actual_sha="$(archive_sha256 "$download")"
    if [[ "$actual_sha" != "$expected_sha" ]]; then
      rm -f "$download"
      echo -e "${RED}Checksum mismatch for ${name} ${version}.${OFF}" >&2
      echo "Expected: $expected_sha" >&2
      echo "Actual:   $actual_sha" >&2
      exit 1
    fi
    mv "$download" "$archive"
  fi

  echo "$archive"
}

install_pinned_tool() {
  local name="$1"
  local version="$2"
  local url="$3"
  local expected_sha="$4"
  local relative_binary="$5"
  local entrypoint_type="${6:-symlink}"
  local archive
  archive="$(download_verified_archive "$name" "$version" "$url" "$expected_sha")"

  local install_dir="$TOOLS_ROOT/${name}-${version}"
  local binary="$install_dir/$relative_binary"
  local marker="$install_dir/.archive-sha256"
  local valid_install=0

  if [[ -x "$binary" && -f "$marker" && "$(cat "$marker")" == "$expected_sha" ]]; then
    local version_output
    version_output="$("$binary" --version 2>&1 || true)"
    if [[ "$version_output" == *"$version"* ]]; then
      valid_install=1
    fi
  fi

  if (( valid_install == 0 )); then
    local extract_dir="$TOOLS_ROOT/.extract-${name}-${version}.$$"
    rm -rf "$extract_dir" "$install_dir"
    mkdir -p "$extract_dir"
    ditto -x -k "$archive" "$extract_dir"
    chmod +x "$extract_dir/$relative_binary"
    printf '%s\n' "$expected_sha" > "$extract_dir/.archive-sha256"
    mv "$extract_dir" "$install_dir"
  fi

  local version_output
  version_output="$("$binary" --version 2>&1 || true)"
  if [[ "$version_output" != *"$version"* ]]; then
    echo -e "${RED}${name} version check failed.${OFF}"
    echo "Expected: $version"
    echo "Reported: ${version_output:-nothing}"
    exit 1
  fi

  mkdir -p "$TOOLS_BIN"
  if [[ "$entrypoint_type" == "wrapper" ]]; then
    rm -f "$TOOLS_BIN/$name"
    printf '%s\n' '#!/usr/bin/env bash' > "$TOOLS_BIN/$name"
    printf 'exec %q "$@"\n' "$binary" >> "$TOOLS_BIN/$name"
    chmod +x "$TOOLS_BIN/$name"
  else
    ln -sfn "../${name}-${version}/${relative_binary}" "$TOOLS_BIN/$name"
  fi
  echo -e "${GREEN}OK${OFF} - ${name} ${version}"
}

install_pinned_tools() {
  require_tool curl "curl not found."
  require_tool ditto "ditto not found."
  require_tool shasum "shasum not found."

  # XcodeGen locates its bundled setting presets relative to its real executable
  # path, so invoke it through a wrapper instead of a symlink.
  install_pinned_tool "xcodegen" "$XCODEGEN_VERSION" "$XCODEGEN_URL" "$XCODEGEN_SHA256" "xcodegen/bin/xcodegen" "wrapper"
  install_pinned_tool "swiftlint" "$SWIFTLINT_VERSION" "$SWIFTLINT_URL" "$SWIFTLINT_SHA256" "swiftlint"
  install_pinned_tool "swiftformat" "$SWIFTFORMAT_VERSION" "$SWIFTFORMAT_URL" "$SWIFTFORMAT_SHA256" "swiftformat"
}

XCODEGEN_LOCK_DIR=""

release_xcodegen_lock() {
  if [[ -n "$XCODEGEN_LOCK_DIR" && -d "$XCODEGEN_LOCK_DIR" ]]; then
    local owner=""
    owner="$(cat "$XCODEGEN_LOCK_DIR/pid" 2>/dev/null || true)"
    if [[ "$owner" == "$$" ]]; then
      rm -rf "$XCODEGEN_LOCK_DIR"
    fi
  fi
  XCODEGEN_LOCK_DIR=""
}

acquire_xcodegen_lock() {
  local lock_dir="$1"
  local started_at=$SECONDS
  local announced=0

  while ! mkdir "$lock_dir" 2>/dev/null; do
    local owner=""
    owner="$(cat "$lock_dir/pid" 2>/dev/null || true)"
    if [[ "$owner" =~ ^[0-9]+$ ]] && ! kill -0 "$owner" 2>/dev/null; then
      echo -e "${YELLOW}Removing stale XcodeGen lock owned by PID ${owner}.${OFF}"
      rm -rf "$lock_dir"
      continue
    fi

    if [[ ! "$owner" =~ ^[0-9]+$ ]]; then
      local modified_at now
      modified_at="$(stat -f %m "$lock_dir" 2>/dev/null || echo 0)"
      now="$(date +%s)"
      if (( modified_at > 0 && now - modified_at >= 5 )); then
        echo -e "${YELLOW}Removing stale XcodeGen lock without a valid owner.${OFF}"
        rm -rf "$lock_dir"
        continue
      fi
    fi

    if (( announced == 0 )); then
      echo -e "${YELLOW}Waiting for existing XcodeGen run...${OFF}"
      announced=1
    fi
    if (( SECONDS - started_at >= 60 )); then
      echo -e "${RED}Timed out after 60 seconds waiting for XcodeGen lock (owner: ${owner:-unknown}).${OFF}"
      exit 1
    fi
    sleep 0.2
  done

  printf '%s\n' "$$" > "$lock_dir/pid"
  XCODEGEN_LOCK_DIR="$lock_dir"
}

generate_xcodeproj() {
  if [[ ! -f "$DIR/project.yml" ]]; then
    echo -e "${YELLOW}project.yml not found; nothing to update.${OFF}"
    return 0
  fi

  require_pinned_tool xcodegen
  mkdir -p "$DIR/.tmp"
  local lock_dir="$DIR/.tmp/xcodegen.lock"
  acquire_xcodegen_lock "$lock_dir"
  trap 'release_xcodegen_lock' EXIT
  trap 'release_xcodegen_lock; exit 130' INT TERM HUP
  echo -e "${BLUE}Generating Xcode project...${OFF}"
  local status=0
  (cd "$DIR" && "$TOOLS_BIN/xcodegen" generate) || status=$?
  release_xcodegen_lock
  trap - EXIT INT TERM HUP
  if (( status != 0 )); then
    return "$status"
  fi
  echo -e "${GREEN}✅ Update complete!${OFF}"
}

find_project() {
  local project_path="${PROJECT_PATH:-}"

  if [[ -z "$project_path" ]]; then
    project_path=$(find "$DIR" -maxdepth 1 -name "*.xcodeproj" -print -quit)
  fi

  if [[ -z "$project_path" ]]; then
    echo -e "${RED}No .xcodeproj found. Run script/update.${OFF}"
    exit 1
  fi

  echo "$project_path"
}

set_xcodebuild_vars() {
  APP_NAME="${APP_NAME:-OneShot}"
  SCHEME="${SCHEME:-$APP_NAME}"
  CONFIGURATION="${CONFIGURATION:-Debug}"
  DERIVED_DATA="${DERIVED_DATA:-$DIR/build/DerivedData}"
}

has_swift_files() {
  find "$DIR" -name "*.swift" -print -quit | grep -q .
}
