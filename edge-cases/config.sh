#!/bin/bash
# =============================================================================
# edge-cases/config.sh — Shared config for all edge case test scripts
# =============================================================================

export BASE_URL="http://localhost:8080"

# ── Colors ────────────────────────────────────────────────────────────────────
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export ORANGE='\033[0;33m'
export BOLD='\033[1m'
export NC='\033[0m'

# ── Counters ──────────────────────────────────────────────────────────────────
export PASS=0
export FAIL=0
export WARN=0

# ── Temp files ────────────────────────────────────────────────────────────────
export EC_TOKEN="/tmp/ec_token.txt"
export EC_TOKEN2="/tmp/ec_token2.txt"
export EC_ACCOUNT="/tmp/ec_account.txt"
export EC_ACCOUNT2="/tmp/ec_account2.txt"
export EC_ACCOUNT_ID="/tmp/ec_account_id.txt"

# ── Helpers ───────────────────────────────────────────────────────────────────
print_header() {
  echo ""
  echo -e "${ORANGE}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
  echo -e "${ORANGE}${BOLD}║  $1${NC}"
  echo -e "${ORANGE}${BOLD}╚══════════════════════════════════════════════════╝${NC}"
}

print_section() {
  echo -e "\n${BLUE}${BOLD}── $1 ──────────────────────────────────────${NC}"
}

# Server should REJECT this input
assert_rejected() {
  local name="$1"
  local http_code="$2"
  local body="$3"

  if [ "$http_code" -ge 400 ] && [ "$http_code" -lt 600 ]; then
    echo -e "  ${GREEN}✅ PASS${NC} — $name correctly rejected (HTTP $http_code)"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}❌ FAIL${NC} — $name should be rejected, got HTTP $http_code"
    echo -e "  ${YELLOW}   Response: $body${NC}"
    FAIL=$((FAIL + 1))
  fi
}

# Server should ACCEPT this input
assert_accepted() {
  local name="$1"
  local http_code="$2"
  local body="$3"

  if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
    echo -e "  ${GREEN}✅ PASS${NC} — $name accepted (HTTP $http_code)"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}❌ FAIL${NC} — $name should be accepted, got HTTP $http_code"
    echo -e "  ${YELLOW}   Response: $body${NC}"
    FAIL=$((FAIL + 1))
  fi
}

print_summary() {
  local module="$1"
  echo ""
  echo -e "${BOLD}${ORANGE}── $module Edge Case Summary ──────────────────${NC}"
  echo -e "  ${GREEN}✅ Pass : $PASS${NC}"
  echo -e "  ${RED}❌ Fail : $FAIL${NC}"
  echo -e "  ${YELLOW}⚠️  Warn : $WARN${NC}"
  echo ""
}

# ── Setup: register one user and create accounts ──────────────────────────────
setup_user() {
  local TS=$(date +%s)
  local USERNAME="ec_user_${TS}"

  RESP=$(curl -s -X POST "$BASE_URL/api/v1/auth/register" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"$USERNAME\",\"password\":\"EdgeTest@123\",\"email\":\"${USERNAME}@test.com\",\"firstName\":\"Edge\",\"lastName\":\"Case\",\"pin\":\"1234\"}")
  TOKEN=$(echo "$RESP" | jq -r '.token // empty' 2>/dev/null)

  if [ -z "$TOKEN" ]; then
    RESP=$(curl -s -X POST "$BASE_URL/api/v1/auth/login" \
      -H "Content-Type: application/json" \
      -d "{\"username\":\"$USERNAME\",\"password\":\"EdgeTest@123\"}")
    TOKEN=$(echo "$RESP" | jq -r '.token // empty' 2>/dev/null)
  fi
  echo "$TOKEN" > "$EC_TOKEN"

  # Account 1
  ACC1=$(curl -s -X POST "$BASE_URL/api/v1/accounts" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d '{"accountType":"SAVINGS","currency":"USD","initialDeposit":1000.00}')
  ACC1_NUM=$(echo "$ACC1" | jq -r '.accountNumber // empty' 2>/dev/null)
  ACC1_ID=$(echo "$ACC1" | jq -r '.id // empty' 2>/dev/null)
  echo "$ACC1_NUM" > "$EC_ACCOUNT"
  echo "$ACC1_ID" > "$EC_ACCOUNT_ID"

  # Account 2
  ACC2=$(curl -s -X POST "$BASE_URL/api/v1/accounts" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d '{"accountType":"CHECKING","currency":"USD","initialDeposit":500.00}')
  ACC2_NUM=$(echo "$ACC2" | jq -r '.accountNumber // empty' 2>/dev/null)
  echo "$ACC2_NUM" > "$EC_ACCOUNT2"

  echo -e "${CYAN}  User: $USERNAME | Acc1: $ACC1_NUM | Acc2: $ACC2_NUM${NC}"
}
