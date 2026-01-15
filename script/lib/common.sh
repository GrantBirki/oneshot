#!/usr/bin/env bash

set -euo pipefail

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

generate_xcodeproj() {
  if [[ ! -f "$DIR/project.yml" ]]; then
    echo -e "${YELLOW}project.yml not found; nothing to update.${OFF}"
    return 0
  fi

  require_tool xcodegen "xcodegen not found. Run script/bootstrap."
  echo -e "${BLUE}Generating Xcode project...${OFF}"
  (cd "$DIR" && xcodegen generate)
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
