#!/usr/bin/env bash
set -euo pipefail

source bin/assert-http.sh

RESPONSE_FILE="$(mktemp)"
STATUS="$(curl -s -w "%{http_code}" -o "${RESPONSE_FILE}" "${ORDS_ROOT_URL}/tracker/pixel")"
BODY="$(cat "${RESPONSE_FILE}")"
rm "${RESPONSE_FILE}"

assert_http "GET /tracker/pixel without token returns 200" 200 "${STATUS}" "${BODY}"
