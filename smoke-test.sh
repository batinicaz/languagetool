#!/usr/bin/env bash
set -euo pipefail

HOST="${1:-localhost}"
PORT="${2:-8010}"
BASE_URL="http://${HOST}:${PORT}"
TIMEOUT="${3:-90}"

echo "Waiting for LanguageTool at ${BASE_URL}..."
for i in $(seq 1 "$TIMEOUT"); do
  if curl -sf "${BASE_URL}/v2/languages" > /dev/null 2>&1; then
    echo "Healthy after ${i}s"
    break
  fi
  if [ "$i" -eq "$TIMEOUT" ]; then
    echo "ERROR: LanguageTool failed to start within ${TIMEOUT}s"
    exit 1
  fi
  sleep 1
done

echo "Testing grammar check endpoint..."
RESPONSE=$(curl -sf -X POST "${BASE_URL}/v2/check" \
  -d 'language=en-US' \
  -d 'text=This is a example of bad grammar.')

if echo "$RESPONSE" | grep -q '"matches":\[{'; then
  echo "Smoke test passed: grammar matches found"
else
  echo "ERROR: Expected grammar matches in response"
  echo "Response: $RESPONSE"
  exit 1
fi
