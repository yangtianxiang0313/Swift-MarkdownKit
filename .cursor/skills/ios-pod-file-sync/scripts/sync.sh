#!/bin/bash
# Sync Swift files to iOS Xcode project via pod install.
# Run from workspace root. Finds Example/Podfile or ./Podfile.

set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$ROOT"

if [ -f "Example/Podfile" ]; then
  echo "Running pod install in Example/"
  cd Example && pod install
elif [ -f "Podfile" ]; then
  echo "Running pod install in root"
  pod install
else
  echo "Podfile not found in Example/ or root. Skipping."
  exit 1
fi
