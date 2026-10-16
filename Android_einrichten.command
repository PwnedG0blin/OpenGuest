#!/bin/bash
set -euo pipefail
script_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
exec /bin/bash "$script_dir/Android_System_verwalten.command" 16 install 0
