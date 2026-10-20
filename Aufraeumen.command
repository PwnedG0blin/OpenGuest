#!/bin/bash
set -euo pipefail
source_dir="$(cd -- "$(dirname -- "$0")" && pwd -P)"
python3 "$source_dir/scripts/storage-cleanup.py"
