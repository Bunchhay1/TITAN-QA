#!/bin/bash
# utils.sh - Security test utilities

check_response_code() {
  local expected=$1
  local actual=$2
  local test_name=$3
  if [ "$actual" == "$expected" ]; then
    echo "[PASS] $test_name - Got $actual"
  else
    echo "[FAIL] $test_name - Expected $expected, got $actual"
  fi
}

check_not_contains() {
  local pattern=$1
  local body=$2
  local test_name=$3
  if echo "$body" | grep -q "$pattern"; then
    echo "[FAIL] $test_name - Response contains forbidden pattern: $pattern"
  else
    echo "[PASS] $test_name - Response does not contain: $pattern"
  fi
}
