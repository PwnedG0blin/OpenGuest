#!/bin/bash
# Render real production windows and dialogs without starting guests or downloads.
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$project_dir"
preview_dir="${1:-$project_dir/dist/paste-preview}"
mkdir -p "$preview_dir"
preview_dir="$(cd -- "$preview_dir" && pwd)"
STRATOVO_PREVIEW_DIRECTORY="$preview_dir" xcrun swift test --filter WorkspacePreviewTests
