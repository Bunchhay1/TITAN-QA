#!/bin/bash
# =============================================================================
# accounts/test-accounts.sh — Test Account APIs
#
# Endpoints covered:
#   POST /api/v1/accounts           — Create account
#   GET  /api/v1/accounts           — Get my accounts
#   GET  /api/v1/accounts/{id}      — Get account by ID
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/config.sh"
load_token
load_credentials

print_header "🏦 ACCOUNT API TESTS"

# Guard: need a token
if [ -z "$JWT_TOKEN" ]; then
  echo -e "${RED}❌ No JWT token found. Run auth/test-auth.sh first.${NC}"
  exit 1
fi

# ── 1. CREATE ACCOUNT (SAVINGS) ───────────────────────────────────────────────
echo -e "\n${CYAN}[1/5] POST /api/v1/accounts — Create SAVINGS account${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/accounts" \
  -H "Content-Type: application/json" \
  -H "$(auth_header)" \
  -d '{
    "accountType": "SAVINGS",
    "currency": "USD",
    "initialDeposit": 1000.00
  }')

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_status "Create SAVINGS account" 201 "$HTTP_CODE" "$BODY"

# Save account number and id
ACCOUNT_NUMBER=$(echo "$BODY" | jq -r '.accountNumber // empty' 2>/dev/null)
ACCOUNT_ID=$(echo "$BODY" | jq -r '.id // empty' 2>/dev/null)

if [ -n "$ACCOUNT_NUMBER" ] && [ "$ACCOUNT_NUMBER" != "null" ]; then
  save_account "$ACCOUNT_NUMBER"
  echo -e "  ${CYAN}   Account Number: $ACCOUNT_NUMBER${NC}"
  echo -e "  ${CYAN}   Account ID: $ACCOUNT_ID${NC}"
  echo "$ACCOUNT_ID" > /tmp/titan_test_account_id.txt
fi

# ── 2. CREATE SECOND ACCOUNT (CHECKING) ──────────────────────────────────────
echo -e "\n${CYAN}[2/5] POST /api/v1/accounts — Create CHECKING account (for transfer target)${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/accounts" \
  -H "Content-Type: application/json" \
  -H "$(auth_header)" \
  -d '{
    "accountType": "CHECKING",
    "currency": "USD",
    "initialDeposit": 500.00
  }')

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_status "Create CHECKING account" 201 "$HTTP_CODE" "$BODY"

ACCOUNT2_NUMBER=$(echo "$BODY" | jq -r '.accountNumber // empty' 2>/dev/null)
if [ -n "$ACCOUNT2_NUMBER" ] && [ "$ACCOUNT2_NUMBER" != "null" ]; then
  save_account2 "$ACCOUNT2_NUMBER"
  echo -e "  ${CYAN}   Account2 Number: $ACCOUNT2_NUMBER${NC}"
fi

# ── 3. CREATE ACCOUNT — No auth (expect 401) ─────────────────────────────────
echo -e "\n${CYAN}[3/5] POST /api/v1/accounts — No JWT token (expect 401)${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/accounts" \
  -H "Content-Type: application/json" \
  -d '{"accountType": "SAVINGS", "currency": "USD"}')

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
if [ "$HTTP_CODE" -eq 401 ] || [ "$HTTP_CODE" -eq 403 ]; then
  echo -e "  ${GREEN}✅ PASS${NC} — Unauthenticated request rejected (HTTP $HTTP_CODE)"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}❌ FAIL${NC} — Expected 401/403, got HTTP $HTTP_CODE"
  FAIL=$((FAIL + 1))
fi

# ── 4. GET MY ACCOUNTS ────────────────────────────────────────────────────────
echo -e "\n${CYAN}[4/5] GET /api/v1/accounts — Get my accounts${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$BASE_URL/api/v1/accounts" \
  -H "$(auth_header)")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_status "Get my accounts" 200 "$HTTP_CODE" "$BODY"

COUNT=$(echo "$BODY" | jq 'length' 2>/dev/null)
echo -e "  ${CYAN}   Accounts returned: $COUNT${NC}"

# ── 5. GET ACCOUNT BY ID ──────────────────────────────────────────────────────
ACCOUNT_ID_SAVED=$(cat /tmp/titan_test_account_id.txt 2>/dev/null)
if [ -n "$ACCOUNT_ID_SAVED" ]; then
  echo -e "\n${CYAN}[5/5] GET /api/v1/accounts/$ACCOUNT_ID_SAVED — Get account by ID${NC}"
  RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$BASE_URL/api/v1/accounts/$ACCOUNT_ID_SAVED" \
    -H "$(auth_header)")

  HTTP_CODE=$(echo "$RESPONSE" | tail -1)
  BODY=$(echo "$RESPONSE" | head -1)
  assert_status "Get account by ID" 200 "$HTTP_CODE" "$BODY"
  echo -e "  ${CYAN}   Account: $(echo "$BODY" | jq -r '.accountNumber // "N/A"' 2>/dev/null)${NC}"
else
  echo -e "\n${YELLOW}[5/5] Skipping Get Account By ID — no account ID saved${NC}"
fi

print_summary "Accounts"

# Save counters for run-all.sh
echo "$PASS" > /tmp/titan_module_pass.txt
echo "$FAIL" > /tmp/titan_module_fail.txt
