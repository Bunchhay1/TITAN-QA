#!/bin/bash
# health-check.sh - Check API server health before running tests

BASE_URL="${1:-http://localhost:8080}"

echo "Checking server health at $BASE_URL..."
response=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/health" 2>/dev/null)

if [ "$response" == "200" ]; then
  echo "[OK] Server is healthy"
  exit 0
else
  echo "[ERROR] Server returned HTTP $response"
  echo "Please ensure the server is running before running tests."
  exit 1
fi
