#!/usr/bin/env bash
set -euo pipefail

source bin/assert-http.sh

RESPONSE_FILE="$(mktemp)"
STATUS="$(curl -s -w "%{http_code}" \
  -H "Content-Type: application/json" \
  -o "${RESPONSE_FILE}" \
  -d '{"email":"not-an-email","first_name":"Test","website":""}' \
  "${ORDS_ROOT_URL}/subscriber/subscribe")"
BODY="$(cat "${RESPONSE_FILE}")"
rm "${RESPONSE_FILE}"

assert_http "POST /subscriber/subscribe rejects invalid email" 400 "${STATUS}" "${BODY}"
assert_body_contains "Invalid email response is classified" "${BODY}" "invalid_email"
