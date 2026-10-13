#!/bin/bash
# utils.sh - Edge case test utilities

assert_equals() {
  local expected=$1
  local actual=$2
  local label=$3
  if [ "$actual" == "$expected" ]; then
    echo "[PASS] $label"
  else
    echo "[FAIL] $label: expected='$expected' actual='$actual'"
  fi
}

assert_http_status() {
  local url=$1
  local method=$2
  local data=$3
  local expected_code=$4
  local label=$5
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" -X "$method" -H "Content-Type: application/json" -d "$data" "$url")
  assert_equals "$expected_code" "$code" "$label"
}
