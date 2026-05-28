#!/usr/bin/env bash
set -euo pipefail

source bin/assert-http.sh

echo "[INFO] Starting endpoint tests"
bash test/endpoint/subscriber.endpoint.sh
bash test/endpoint/tracker.endpoint.sh
bash test/endpoint/ui-root.endpoint.sh
echo "[INFO] Endpoint tests complete"
