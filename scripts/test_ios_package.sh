#!/usr/bin/env bash
set -euo pipefail

SCHEME="${SCHEME:-XHSMarkdownKit-Package}"
SIM_ID="${IOS_SIMULATOR_ID:-}"

if [[ -z "$SIM_ID" ]]; then
  SIM_ID="$(xcodebuild -scheme "$SCHEME" -showdestinations 2>/dev/null | awk -F'id:|, OS:' '/platform:iOS Simulator, arch:arm64/{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2; exit}')"
fi

if [[ -z "$SIM_ID" ]]; then
  echo "No arm64 iOS Simulator destination found for scheme '$SCHEME'." >&2
  exit 1
fi

xcodebuild \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,id=$SIM_ID" \
  test \
  CODE_SIGNING_ALLOWED=NO
