#!/bin/zsh
set -euo pipefail

PROJECT_ROOT=${0:A:h:h}
"$PROJECT_ROOT/scripts/build-macos.sh"
"$PROJECT_ROOT/scripts/build-android.sh"
