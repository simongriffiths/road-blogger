#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: bin/pipeline.sh --env <dev|test|prod> --app <app_name>
EOF
}

usage
echo "bin/pipeline.sh is intentionally scaffolded. Stabilize the manual deploy path before implementing orchestration." >&2
exit 1
