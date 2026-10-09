#!/bin/bash
# =============================================================================
# security/config.sh — Shared config for all security test scripts
# =============================================================================

export BASE_URL="http://localhost:8080"

# ── Colors ────────────────────────────────────────────────────────────────────
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export MAGENTA='\033[0;35m'
export BOLD='\033[1m'
export NC='\033[0m'

# ── Counters ──────────────────────────────────────────────────────────────────
export PASS=0
export FAIL=0
export WARN=0

# ── Temp files ────────────────────────────────────────────────────────────────
export SEC_TOKEN_A="/tmp/sec_token_a.txt"
export SEC_TOKEN_B="/tmp/sec_token_b.txt"
export SEC_ACCOUNT_A="/tmp/sec_account_a.txt"
export SEC_ACCOUNT_B="/tmp/sec_account_b.txt"
export SEC_ACCOUNT_A_ID="/tmp/sec_account_a_id.txt"

# ── Helpers ───────────────────────────────────────────────────────────────────
print_header() {
  echo ""
  echo -e "${MAGENTA}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
  echo -e "${MAGENTA}${BOLD}║  $1${NC}"
  echo -e "${MAGENTA}${BOLD}╚══════════════════════════════════════════════════╝${NC}"
}

print_section() {
  echo -e "\n${BLUE}${BOLD}── $1 ──────────────────────────────────────${NC}"
}

# PASS = server correctly blocked the attack
assert_blocked() {
  local test_name="$1"
  local http_code="$2"
  local body="$3"

  if [ "$http_code" -ge 400 ] && [ "$http_code" -lt 600 ]; then
    echo -e "  ${GREEN}✅ SECURE${NC} — $test_name (HTTP $http_code — correctly blocked)"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}❌ VULNERABLE${NC} — $test_name (HTTP $http_code — should have been blocked!)"
    echo -e "  ${YELLOW}   Response: $body${NC}"
    FAIL=$((FAIL + 1))
  fi
}

# PASS = server correctly allowed the request
assert_allowed() {
  local test_name="$1"
  local http_code="$2"
  local body="$3"

  if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
    echo -e "  ${GREEN}✅ PASS${NC} — $test_name (HTTP $http_code)"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}❌ FAIL${NC} — $test_name (HTTP $http_code)"
    echo -e "  ${YELLOW}   Response: $body${NC}"
    FAIL=$((FAIL + 1))
  fi
}

# WARN = server returned 200 but we need to inspect the body
assert_no_data_leak() {
  local test_name="$1"
  local http_code="$2"
  local body="$3"
  local forbidden_field="$4"

  if [ "$http_code" -ge 400 ]; then
    echo -e "  ${GREEN}✅ SECURE${NC} — $test_name (HTTP $http_code — access denied)"
    PASS=$((PASS + 1))
  elif echo "$body" | grep -q "$forbidden_field" 2>/dev/null; then
    echo -e "  ${RED}❌ DATA LEAK${NC} — $test_name — response contains '$forbidden_field'"
    echo -e "  ${YELLOW}   Response: $body${NC}"
    FAIL=$((FAIL + 1))
  else
    echo -e "  ${YELLOW}⚠️  WARN${NC} — $test_name — HTTP $http_code but no sensitive data found"
    WARN=$((WARN + 1))
  fi
}

print_summary() {
  local module="$1"
  echo ""
  echo -e "${BOLD}${MAGENTA}── $module Security Summary ──────────────────${NC}"
  echo -e "  ${GREEN}✅ Secure (Pass): $PASS${NC}"
  echo -e "  ${RED}❌ Vulnerable:    $FAIL${NC}"
  echo -e "  ${YELLOW}⚠️  Warning:      $WARN${NC}"
  echo ""
}

# ── Setup: register two users and get their tokens ────────────────────────────
setup_two_users() {
  local TS=$(date +%s)
  local USER_A="sec_user_a_${TS}"
  local USER_B="sec_user_b_${TS}"

  echo -e "${CYAN}  Setting up User A: $USER_A${NC}"
  RESP_A=$(curl -s -X POST "$BASE_URL/api/v1/auth/register" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"$USER_A\",\"password\":\"SecTest@123\",\"email\":\"${USER_A}@test.com\",\"firstName\":\"Sec\",\"lastName\":\"UserA\",\"pin\":\"1234\"}")
  TOKEN_A=$(echo "$RESP_A" | jq -r '.token // empty' 2>/dev/null)

  if [ -z "$TOKEN_A" ]; then
    RESP_A=$(curl -s -X POST "$BASE_URL/api/v1/auth/login" \
      -H "Content-Type: application/json" \
      -d "{\"username\":\"$USER_A\",\"password\":\"SecTest@123\"}")
    TOKEN_A=$(echo "$RESP_A" | jq -r '.token // empty' 2>/dev/null)
  fi
  echo "$TOKEN_A" > "$SEC_TOKEN_A"

  echo -e "${CYAN}  Setting up User B: $USER_B${NC}"
  RESP_B=$(curl -s -X POST "$BASE_URL/api/v1/auth/register" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"$USER_B\",\"password\":\"SecTest@456\",\"email\":\"${USER_B}@test.com\",\"firstName\":\"Sec\",\"lastName\":\"UserB\",\"pin\":\"5678\"}")
  TOKEN_B=$(echo "$RESP_B" | jq -r '.token // empty' 2>/dev/null)

  if [ -z "$TOKEN_B" ]; then
    RESP_B=$(curl -s -X POST "$BASE_URL/api/v1/auth/login" \
      -H "Content-Type: application/json" \
      -d "{\"username\":\"$USER_B\",\"password\":\"SecTest@456\"}")
    TOKEN_B=$(echo "$RESP_B" | jq -r '.token // empty' 2>/dev/null)
  fi
  echo "$TOKEN_B" > "$SEC_TOKEN_B"

  # Create account for User A
  RESP_ACC_A=$(curl -s -X POST "$BASE_URL/api/v1/accounts" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN_A" \
    -d '{"accountType":"SAVINGS","currency":"USD","initialDeposit":500.00}')
  ACC_A=$(echo "$RESP_ACC_A" | jq -r '.accountNumber // empty' 2>/dev/null)
  ACC_A_ID=$(echo "$RESP_ACC_A" | jq -r '.id // empty' 2>/dev/null)
  echo "$ACC_A" > "$SEC_ACCOUNT_A"
  echo "$ACC_A_ID" > "$SEC_ACCOUNT_A_ID"

  # Create account for User B
  RESP_ACC_B=$(curl -s -X POST "$BASE_URL/api/v1/accounts" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN_B" \
    -d '{"accountType":"SAVINGS","currency":"USD","initialDeposit":500.00}')
  ACC_B=$(echo "$RESP_ACC_B" | jq -r '.accountNumber // empty' 2>/dev/null)
  echo "$ACC_B" > "$SEC_ACCOUNT_B"

  echo -e "${CYAN}  User A token: ${TOKEN_A:0:30}...${NC}"
  echo -e "${CYAN}  User A account: $ACC_A (ID: $ACC_A_ID)${NC}"
  echo -e "${CYAN}  User B token: ${TOKEN_B:0:30}...${NC}"
  echo -e "${CYAN}  User B account: $ACC_B${NC}"
}
