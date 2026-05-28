#!/usr/bin/env bash
set -euo pipefail

source bin/assert-http.sh

RESPONSE_FILE="$(mktemp)"
STATUS="$(curl -s -w "%{http_code}" -o "${RESPONSE_FILE}" "${UI_ROOT_URL}/")"
BODY="$(cat "${RESPONSE_FILE}")"
rm "${RESPONSE_FILE}"

assert_http "GET admin UI root returns 200" 200 "${STATUS}" "${BODY}"
assert_body_contains "Admin UI root returns shell" "${BODY}" "<div id=\"root\"></div>"
