#!/bin/bash
# =============================================================================
# transactions/test-transactions.sh — Test Transaction APIs
#
# Endpoints covered:
#   POST /api/v1/transactions/transfer
#   POST /api/v1/transactions/withdraw
#   POST /api/v1/transactions/deposit
#   POST /api/v1/transactions/international
#   GET  /api/v1/transactions
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/config.sh"
load_token
load_credentials
load_account
load_account2

print_header "💸 TRANSACTION API TESTS"

if [ -z "$JWT_TOKEN" ]; then
  echo -e "${RED}❌ No JWT token. Run auth/test-auth.sh first.${NC}"
  exit 1
fi

if [ -z "$TEST_ACCOUNT" ]; then
  echo -e "${RED}❌ No account number. Run accounts/test-accounts.sh first.${NC}"
  exit 1
fi

echo -e "  ${CYAN}From Account: $TEST_ACCOUNT${NC}"
echo -e "  ${CYAN}To Account:   $TEST_ACCOUNT2${NC}"

# ── 1. DEPOSIT ────────────────────────────────────────────────────────────────
echo -e "\n${CYAN}[1/7] POST /api/v1/transactions/deposit — Deposit \$500${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/transactions/deposit" \
  -H "Content-Type: application/json" \
  -H "$(auth_header)" \
  -d "{
    \"toAccountNumber\": \"$TEST_ACCOUNT\",
    \"amount\": 500.00,
    \"note\": \"QA Test Deposit\"
  }")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_status "Deposit \$500 to account" 200 "$HTTP_CODE" "$BODY"
echo -e "  ${CYAN}   Status: $(echo "$BODY" | jq -r '.status // "N/A"' 2>/dev/null)${NC}"

# ── 2. WITHDRAW ───────────────────────────────────────────────────────────────
echo -e "\n${CYAN}[2/7] POST /api/v1/transactions/withdraw — Withdraw \$100${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/transactions/withdraw" \
  -H "Content-Type: application/json" \
  -H "$(auth_header)" \
  -d "{
    \"fromAccountNumber\": \"$TEST_ACCOUNT\",
    \"amount\": 100.00,
    \"pin\": \"1234\",
    \"note\": \"QA Test Withdrawal\"
  }")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_status "Withdraw \$100 from account" 200 "$HTTP_CODE" "$BODY"
echo -e "  ${CYAN}   Status: $(echo "$BODY" | jq -r '.status // "N/A"' 2>/dev/null)${NC}"

# ── 3. TRANSFER ───────────────────────────────────────────────────────────────
if [ -n "$TEST_ACCOUNT2" ] && [ "$TEST_ACCOUNT2" != "$TEST_ACCOUNT" ]; then
  echo -e "\n${CYAN}[3/7] POST /api/v1/transactions/transfer — Transfer \$50 between accounts${NC}"
  RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/transactions/transfer" \
    -H "Content-Type: application/json" \
    -H "$(auth_header)" \
    -d "{
      \"fromAccountNumber\": \"$TEST_ACCOUNT\",
      \"toAccountNumber\": \"$TEST_ACCOUNT2\",
      \"amount\": 50.00,
      \"pin\": \"1234\",
      \"note\": \"QA Test Transfer\"
    }")

  HTTP_CODE=$(echo "$RESPONSE" | tail -1)
  BODY=$(echo "$RESPONSE" | head -1)
  assert_status "Transfer \$50 between accounts" 200 "$HTTP_CODE" "$BODY"
  echo -e "  ${CYAN}   Ref: $(echo "$BODY" | jq -r '.transactionReference // .idempotencyKey // "N/A"' 2>/dev/null)${NC}"
else
  echo -e "\n${YELLOW}[3/7] Skipping transfer — need 2 different accounts${NC}"
fi

# ── 4. TRANSFER — Insufficient balance ───────────────────────────────────────
# Risk Engine calls Python service at localhost:8082.
# If Python service is OFFLINE → fail-safe returns BLOCK (HTTP 200, status=BLOCKED)
# If Python service is ONLINE  → ALLOW → balance check runs → HTTP 400 (bug fixed)
# Test accepts: HTTP 4xx OR status=FAILED OR status=BLOCKED — all mean rejected.
echo -e "\n${CYAN}[4/7] POST /api/v1/transactions/transfer — Insufficient balance \$5,000 on ~\$1,350 balance${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/transactions/transfer" \
  -H "Content-Type: application/json" \
  -H "$(auth_header)" \
  -d "{
    \"fromAccountNumber\": \"$TEST_ACCOUNT\",
    \"toAccountNumber\": \"$TEST_ACCOUNT2\",
    \"amount\": 5000.00,
    \"pin\": \"1234\",
    \"note\": \"Overdraft attempt — should be rejected\"
  }")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
TX_STATUS=$(echo "$BODY" | jq -r '.status // empty' 2>/dev/null)

if [ "$HTTP_CODE" -ge 400 ]; then
  echo -e "  ${GREEN}✅ PASS${NC} — Overdraft rejected with HTTP $HTTP_CODE (InsufficientBalance)"
  PASS=$((PASS + 1))
elif [ "$TX_STATUS" = "FAILED" ]; then
  echo -e "  ${GREEN}✅ PASS${NC} — Overdraft rejected (status=FAILED — balance check hit)"
  PASS=$((PASS + 1))
elif [ "$TX_STATUS" = "BLOCKED" ]; then
  echo -e "  ${GREEN}✅ PASS${NC} — Overdraft rejected (status=BLOCKED — Risk Engine offline → fail-safe BLOCK)"
  echo -e "  ${CYAN}   ℹ️  Python Risk Engine (localhost:8082) is not running — fail-safe blocked the transfer${NC}"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}❌ FAIL${NC} — Transfer succeeded when it should have been rejected"
  echo -e "  ${YELLOW}   HTTP: $HTTP_CODE | status: $TX_STATUS${NC}"
  echo -e "  ${YELLOW}   Response: $BODY${NC}"
  FAIL=$((FAIL + 1))
fi

# ── 5. INTERNATIONAL TRANSFER — Valid SWIFT/IBAN ─────────────────────────────
echo -e "\n${CYAN}[5/7] POST /api/v1/transactions/international — Valid SWIFT/IBAN${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/transactions/international" \
  -H "Content-Type: application/json" \
  -H "$(auth_header)" \
  -d "{
    \"fromAccountNumber\": \"$TEST_ACCOUNT\",
    \"amount\": 200.00,
    \"swiftCode\": \"BKCHKHHHXXX\",
    \"iban\": \"GB82WEST12345698765432\",
    \"note\": \"QA International Transfer\"
  }")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_status "International transfer with valid SWIFT/IBAN" 200 "$HTTP_CODE" "$BODY"

# ── 6. INTERNATIONAL TRANSFER — Invalid SWIFT ────────────────────────────────
echo -e "\n${CYAN}[6/7] POST /api/v1/transactions/international — Invalid SWIFT (expect 400)${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/transactions/international" \
  -H "Content-Type: application/json" \
  -H "$(auth_header)" \
  -d "{
    \"fromAccountNumber\": \"$TEST_ACCOUNT\",
    \"amount\": 100.00,
    \"swiftCode\": \"INVALID\",
    \"iban\": \"GB82WEST12345698765432\",
    \"note\": \"Bad SWIFT test\"
  }")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_status "International transfer with invalid SWIFT rejected" 400 "$HTTP_CODE" "$BODY"

# ── 7. GET TRANSACTION HISTORY ────────────────────────────────────────────────
echo -e "\n${CYAN}[7/7] GET /api/v1/transactions — Get transaction history${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$BASE_URL/api/v1/transactions" \
  -H "$(auth_header)")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_status "Get transaction history" 200 "$HTTP_CODE" "$BODY"
COUNT=$(echo "$BODY" | jq 'length' 2>/dev/null)
echo -e "  ${CYAN}   Transactions returned: $COUNT${NC}"

print_summary "Transactions"

# Save counters for run-all.sh
echo "$PASS" > /tmp/titan_module_pass.txt
echo "$FAIL" > /tmp/titan_module_fail.txt
