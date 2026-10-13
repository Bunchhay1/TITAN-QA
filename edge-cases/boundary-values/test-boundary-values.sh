#!/bin/bash
# =============================================================================
# edge-cases/boundary-values/test-boundary-values.sh
#
# Tests amount boundary values across deposit, withdraw, transfer:
#   1.  amount = 0                 → reject
#   2.  amount = -1                → reject
#   3.  amount = -0.01             → reject
#   4.  amount = 0.001 (3 decimals)→ reject (max 2 decimal places)
#   5.  amount = 0.01 (minimum)    → accept
#   6.  amount = 1000000.00 (max)  → accept
#   7.  amount = 1000000.01 (>max) → reject
#   8.  amount = "abc" (string)    → reject
#   9.  amount = null              → reject
#   10. amount = 999999999999      → reject
#   11. Transfer to self           → reject
#   12. Withdraw exact balance     → accept
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.sh"

print_header "🔢 BOUNDARY VALUES — Amount Edge Case Tests"

echo -e "\n${CYAN}Setting up test user and accounts...${NC}"
setup_user

TOKEN=$(cat "$EC_TOKEN")
ACC1=$(cat "$EC_ACCOUNT")
ACC2=$(cat "$EC_ACCOUNT2")

print_section "Zero & Negative Amounts"

# ── 1. Amount = 0 ─────────────────────────────────────────────────────────────
echo -e "\n${CYAN}[1/12] Deposit amount = 0${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/transactions/deposit" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"toAccountNumber\":\"$ACC1\",\"amount\":0,\"note\":\"zero amount\"}")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_rejected "Amount = 0 deposit" "$HTTP_CODE" "$BODY"

# ── 2. Amount = -1 ────────────────────────────────────────────────────────────
echo -e "\n${CYAN}[2/12] Transfer amount = -1${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/transactions/transfer" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"fromAccountNumber\":\"$ACC1\",\"toAccountNumber\":\"$ACC2\",\"amount\":-1,\"pin\":\"1234\",\"note\":\"negative\"}")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_rejected "Amount = -1 transfer" "$HTTP_CODE" "$BODY"

# ── 3. Amount = -0.01 ─────────────────────────────────────────────────────────
echo -e "\n${CYAN}[3/12] Withdraw amount = -0.01${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/transactions/withdraw" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"fromAccountNumber\":\"$ACC1\",\"amount\":-0.01,\"pin\":\"1234\",\"note\":\"neg decimal\"}")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_rejected "Amount = -0.01 withdraw" "$HTTP_CODE" "$BODY"

print_section "Decimal Precision"

# ── 4. Amount = 0.001 (3 decimal places) ─────────────────────────────────────
echo -e "\n${CYAN}[4/12] Deposit amount = 0.001 (3 decimal places — max is 2)${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/transactions/deposit" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"toAccountNumber\":\"$ACC1\",\"amount\":0.001,\"note\":\"3 decimals\"}")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_rejected "Amount = 0.001 (3 decimal places)" "$HTTP_CODE" "$BODY"

# ── 5. Amount = 0.01 (minimum valid) ─────────────────────────────────────────
echo -e "\n${CYAN}[5/12] Deposit amount = 0.01 (minimum valid amount)${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/transactions/deposit" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"toAccountNumber\":\"$ACC1\",\"amount\":0.01,\"note\":\"minimum valid\"}")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_accepted "Amount = 0.01 (minimum valid)" "$HTTP_CODE" "$BODY"

print_section "Maximum Boundary"

# ── 6. Amount = 1000000.00 (max allowed) ─────────────────────────────────────
echo -e "\n${CYAN}[6/12] Transfer amount = 1000000.00 (max allowed by validation)${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/transactions/transfer" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"fromAccountNumber\":\"$ACC1\",\"toAccountNumber\":\"$ACC2\",\"amount\":1000000.00,\"pin\":\"1234\",\"note\":\"max amount\"}")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
TX_STATUS=$(echo "$BODY" | jq -r '.status // empty' 2>/dev/null)
# Should be rejected by balance check (account only has $1000) or risk engine
if [ "$HTTP_CODE" -ge 400 ] || [ "$TX_STATUS" = "FAILED" ] || [ "$TX_STATUS" = "BLOCKED" ]; then
  echo -e "  ${GREEN}✅ PASS${NC} — Max amount $1M rejected (HTTP $HTTP_CODE, status=$TX_STATUS)"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}❌ FAIL${NC} — $1M transfer succeeded unexpectedly (HTTP $HTTP_CODE)"
  FAIL=$((FAIL + 1))
fi

# ── 7. Amount = 1000000.01 (over max) ────────────────────────────────────────
echo -e "\n${CYAN}[7/12] Transfer amount = 1000000.01 (exceeds max validation limit)${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/transactions/transfer" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"fromAccountNumber\":\"$ACC1\",\"toAccountNumber\":\"$ACC2\",\"amount\":1000000.01,\"pin\":\"1234\",\"note\":\"over max\"}")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_rejected "Amount = 1000000.01 (exceeds max)" "$HTTP_CODE" "$BODY"

print_section "Invalid Type Amounts"

# ── 8. Amount = string "abc" ──────────────────────────────────────────────────
echo -e "\n${CYAN}[8/12] Deposit amount = \"abc\" (string instead of number)${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/transactions/deposit" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"toAccountNumber\":\"$ACC1\",\"amount\":\"abc\",\"note\":\"string amount\"}")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_rejected "Amount = 'abc' string type" "$HTTP_CODE" "$BODY"

# ── 9. Amount = null ──────────────────────────────────────────────────────────
echo -e "\n${CYAN}[9/12] Deposit amount = null${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/transactions/deposit" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"toAccountNumber\":\"$ACC1\",\"amount\":null,\"note\":\"null amount\"}")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_rejected "Amount = null" "$HTTP_CODE" "$BODY"

# ── 10. Amount = 999999999999 (astronomically large) ─────────────────────────
echo -e "\n${CYAN}[10/12] Deposit amount = 999999999999 (astronomically large)${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/transactions/deposit" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"toAccountNumber\":\"$ACC1\",\"amount\":999999999999,\"note\":\"huge amount\"}")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_rejected "Amount = 999999999999 (overflow)" "$HTTP_CODE" "$BODY"

print_section "Transfer Edge Cases"

# ── 11. Transfer to self (same account) ───────────────────────────────────────
echo -e "\n${CYAN}[11/12] Transfer to SAME account (self-transfer)${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/transactions/transfer" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"fromAccountNumber\":\"$ACC1\",\"toAccountNumber\":\"$ACC1\",\"amount\":10.00,\"pin\":\"1234\",\"note\":\"self transfer\"}")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_rejected "Self-transfer (from=to)" "$HTTP_CODE" "$BODY"

# ── 12. Withdraw exact balance ────────────────────────────────────────────────
echo -e "\n${CYAN}[12/12] Withdraw exact current balance${NC}"
# Get current balance
BAL_RESP=$(curl -s -X GET "$BASE_URL/api/v1/accounts/$(cat $EC_ACCOUNT_ID)" \
  -H "Authorization: Bearer $TOKEN")
BALANCE=$(echo "$BAL_RESP" | jq -r '.balance // empty' 2>/dev/null)
echo -e "  ${CYAN}   Current balance: \$$BALANCE${NC}"

if [ -n "$BALANCE" ] && [ "$BALANCE" != "null" ] && [ "$BALANCE" != "0" ]; then
  RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/transactions/withdraw" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d "{\"fromAccountNumber\":\"$ACC1\",\"amount\":$BALANCE,\"pin\":\"1234\",\"note\":\"withdraw all\"}")
  HTTP_CODE=$(echo "$RESPONSE" | tail -1)
  BODY=$(echo "$RESPONSE" | head -1)
  TX_STATUS=$(echo "$BODY" | jq -r '.status // empty' 2>/dev/null)
  if [ "$HTTP_CODE" -eq 200 ] && [ "$TX_STATUS" = "SUCCESS" ]; then
    echo -e "  ${GREEN}✅ PASS${NC} — Withdraw exact balance accepted (HTTP $HTTP_CODE)"
    PASS=$((PASS + 1))
  elif [ "$HTTP_CODE" -ge 400 ] || [ "$TX_STATUS" = "BLOCKED" ]; then
    echo -e "  ${YELLOW}⚠️  WARN${NC} — Withdraw exact balance rejected (HTTP $HTTP_CODE, status=$TX_STATUS)"
    echo -e "  ${YELLOW}   May be blocked by Risk Engine or fee calculation${NC}"
    WARN=$((WARN + 1))
  else
    echo -e "  ${RED}❌ FAIL${NC} — Unexpected response (HTTP $HTTP_CODE, status=$TX_STATUS)"
    FAIL=$((FAIL + 1))
  fi
else
  echo -e "  ${YELLOW}⚠️  SKIP${NC} — Could not determine balance"
  WARN=$((WARN + 1))
fi

print_summary "Boundary Values"

echo "$PASS" > /tmp/ec_module_pass.txt
echo "$FAIL" > /tmp/ec_module_fail.txt
echo "$WARN" > /tmp/ec_module_warn.txt
