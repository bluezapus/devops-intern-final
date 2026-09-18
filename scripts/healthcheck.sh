#!/usr/bin/env bash
set -euo pipefail

TARGET_URL="${1:-http://localhost:8080}"

echo "Checking application health: ${TARGET_URL}"

HTTP_STATUS="$(curl \
    --silent \
    --output /dev/null \
    --write-out "%{http_code}" \
    --max-time 10 \
    "${TARGET_URL}" || true)"

if [ "${HTTP_STATUS}" = "200" ]; then
    echo "Health check passed: HTTP ${HTTP_STATUS}"
    exit 0
fi

echo "Health check failed: ${TARGET_URL} returned HTTP ${HTTP_STATUS}" >&2
exit 1