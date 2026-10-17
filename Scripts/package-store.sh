#!/bin/zsh
set -euo pipefail
readonly root_directory="$(cd "$(dirname "$0")/.." && pwd)"
DISTRIBUTION=app-store "$root_directory/Scripts/package-app.sh"
