#!/bin/bash
# helpers.sh - Shared utility functions for TITAN-QA tests

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Pass/Fail counters
PASS=0
FAIL=0

pass() {
  echo -e "${GREEN}[PASS]${NC} $1"
  ((PASS++))
}

fail() {
  echo -e "${RED}[FAIL]${NC} $1"
  ((FAIL++))
}

warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

summary() {
  echo ""
  echo "============================="
  echo "Total: $((PASS + FAIL)) | Pass: $PASS | Fail: $FAIL"
  echo "============================="
}
