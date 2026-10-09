#!/bin/bash
# =============================================================================
# utils/config.sh — Shared configuration for all Titan Bank API test scripts
# =============================================================================

# ── Base URL ──────────────────────────────────────────────────────────────────
export BASE_URL="http://localhost:8080"

# ── Test user credentials ─────────────────────────────────────────────────────
export TEST_USERNAME="titan_test_qa"
export TEST_PASSWORD="Test@1234"
export TEST_EMAIL="titan_test_qa@titanbank.com"
export TEST_FULL_NAME="Titan QA Tester"

# ── Token storage file (shared across scripts) ────────────────────────────────
export TOKEN_FILE="/tmp/titan_test_token.txt"
export ACCOUNT_FILE="/tmp/titan_test_account.txt"
export ACCOUNT2_FILE="/tmp/titan_test_account2.txt"
export USERNAME_FILE="/tmp/titan_test_username.txt"
export PASSWORD_FILE="/tmp/titan_test_password.txt"

# ── Load dynamic credentials set by auth script ───────────────────────────────
load_credentials() {
  if [ -f "$USERNAME_FILE" ]; then
    export TEST_USERNAME=$(cat "$USERNAME_FILE")
  fi
  if [ -f "$PASSWORD_FILE" ]; then
    export TEST_PASSWORD=$(cat "$PASSWORD_FILE")
  fi
}

# ── Load JWT token if already saved ──────────────────────────────────────────
load_token() {
  if [ -f "$TOKEN_FILE" ]; then
    export JWT_TOKEN=$(cat "$TOKEN_FILE")
  fi
}

# ── Save JWT token ────────────────────────────────────────────────────────────
save_token() {
  echo "$1" > "$TOKEN_FILE"
  export JWT_TOKEN="$1"
}

# ── Load account number ───────────────────────────────────────────────────────
load_account() {
  if [ -f "$ACCOUNT_FILE" ]; then
    export TEST_ACCOUNT=$(cat "$ACCOUNT_FILE")
  fi
}

save_account() {
  echo "$1" > "$ACCOUNT_FILE"
  export TEST_ACCOUNT="$1"
}

load_account2() {
  if [ -f "$ACCOUNT2_FILE" ]; then
    export TEST_ACCOUNT2=$(cat "$ACCOUNT2_FILE")
  fi
}

save_account2() {
  echo "$1" > "$ACCOUNT2_FILE"
  export TEST_ACCOUNT2="$1"
}

# ── Terminal colors ───────────────────────────────────────────────────────────
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export BOLD='\033[1m'
export NC='\033[0m' # No Color

# ── Test result counters ──────────────────────────────────────────────────────
export PASS=0
export FAIL=0

# ── Helper: print section header ──────────────────────────────────────────────
print_header() {
  echo ""
  echo -e "${BLUE}${BOLD}════════════════════════════════════════════${NC}"
  echo -e "${BLUE}${BOLD}  $1${NC}"
  echo -e "${BLUE}${BOLD}════════════════════════════════════════════${NC}"
}

# ── Helper: print test result ─────────────────────────────────────────────────
assert_status() {
  local test_name="$1"
  local expected="$2"
  local actual="$3"
  local response_body="$4"

  if [ "$actual" -eq "$expected" ]; then
    echo -e "  ${GREEN}✅ PASS${NC} — $test_name (HTTP $actual)"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}❌ FAIL${NC} — $test_name (expected HTTP $expected, got HTTP $actual)"
    echo -e "  ${YELLOW}   Response: $response_body${NC}"
    FAIL=$((FAIL + 1))
  fi
}

# ── Helper: print summary ─────────────────────────────────────────────────────
print_summary() {
  local module="$1"
  echo ""
  echo -e "${BOLD}── $module Summary ──────────────────────────${NC}"
  echo -e "  ${GREEN}Passed: $PASS${NC}"
  echo -e "  ${RED}Failed: $FAIL${NC}"
  TOTAL=$((PASS + FAIL))
  echo -e "  Total:  $TOTAL"
  echo ""
}

# ── Helper: make authenticated request ───────────────────────────────────────
auth_header() {
  echo "Authorization: Bearer $JWT_TOKEN"
}
