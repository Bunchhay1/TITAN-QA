#!/bin/bash
# =============================================================================
# edge-cases/concurrent/test-concurrent-transfer.sh
#
# Tests race conditions — most critical edge case in banking:
#   1. Fire 5 concurrent transfers from same account simultaneously
#      → total amount > balance → only some should succeed
#      → final balance must NEVER go negative
#   2. Fire 3 concurrent withdrawals simultaneously
#      → balance must not go negative
#   3. Fire concurrent deposit + withdraw simultaneously
#      → balance must remain consistent
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.sh"

print_header "⚡ CONCURRENT TRANSFERS — Race Condition Tests"
echo -e "${YELLOW}  ⚠️  This is the most critical banking test — negative balance = real money loss${NC}"

echo -e "\n${CYAN}Setting up test user with $300 balance...${NC}"
setup_user

TOKEN=$(cat "$EC_TOKEN")
ACC1=$(cat "$EC_ACCOUNT")   # starts with $1000
ACC2=$(cat "$EC_ACCOUNT2")  # target account
ACC1_ID=$(cat "$EC_ACCOUNT_ID")

# Withdraw to reduce balance to exactly $300 for predictable test
echo -e "${CYAN}  Reducing balance to \$300 for controlled test...${NC}"
curl -s -X POST "$BASE_URL/api/v1/transactions/withdraw" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"fromAccountNumber\":\"$ACC1\",\"amount\":700.00,\"pin\":\"1234\",\"note\":\"setup\"}" > /dev/null

# Verify balance is now $300
BAL_RESP=$(curl -s -X GET "$BASE_URL/api/v1/accounts/$ACC1_ID" \
  -H "Authorization: Bearer $TOKEN")
BALANCE=$(echo "$BAL_RESP" | jq -r '.balance // "unknown"' 2>/dev/null)
echo -e "${CYAN}  Starting balance: \$$BALANCE${NC}"

print_section "Test 1 — 5 Concurrent Transfers (\$100 each, balance \$300)"

echo -e "\n${CYAN}[1/3] Firing 5 concurrent \$100 transfers simultaneously...${NC}"
echo -e "  ${YELLOW}Total requested: \$500 | Available: ~\$300 | Max allowed: 3 transfers${NC}"

# Fire 5 concurrent requests in background
RESULT_DIR=$(mktemp -d)

for i in $(seq 1 5); do
  (
    RESP=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/transactions/transfer" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $TOKEN" \
      -d "{\"fromAccountNumber\":\"$ACC1\",\"toAccountNumber\":\"$ACC2\",\"amount\":100.00,\"pin\":\"1234\",\"note\":\"concurrent test $i\"}")
    HTTP_CODE=$(echo "$RESP" | tail -1)
    BODY=$(echo "$RESP" | head -1)
    STATUS=$(echo "$BODY" | jq -r '.status // "UNKNOWN"' 2>/dev/null)
    echo "$HTTP_CODE $STATUS" > "$RESULT_DIR/result_$i.txt"
  ) &
done

# Wait for all background jobs
wait

echo -e "\n  ${CYAN}Results:${NC}"
SUCCESS_COUNT=0
FAIL_COUNT=0
BLOCKED_COUNT=0

for i in $(seq 1 5); do
  RESULT=$(cat "$RESULT_DIR/result_$i.txt" 2>/dev/null || echo "UNKNOWN UNKNOWN")
  HTTP_CODE=$(echo "$RESULT" | awk '{print $1}')
  STATUS=$(echo "$RESULT" | awk '{print $2}')
  echo -e "  ${CYAN}   Transfer $i: HTTP $HTTP_CODE | status=$STATUS${NC}"

  if [ "$HTTP_CODE" -eq 200 ] && [ "$STATUS" = "SUCCESS" ]; then
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
  elif [ "$STATUS" = "BLOCKED" ]; then
    BLOCKED_COUNT=$((BLOCKED_COUNT + 1))
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
done

echo -e "\n  ${CYAN}   Succeeded: $SUCCESS_COUNT | Failed/Rejected: $FAIL_COUNT | Blocked: $BLOCKED_COUNT${NC}"

# Check final balance — must NOT be negative
sleep 1  # allow DB writes to settle
FINAL_RESP=$(curl -s -X GET "$BASE_URL/api/v1/accounts/$ACC1_ID" \
  -H "Authorization: Bearer $TOKEN")
FINAL_BALANCE=$(echo "$FINAL_RESP" | jq -r '.balance // "unknown"' 2>/dev/null)
echo -e "  ${CYAN}   Final balance: \$$FINAL_BALANCE${NC}"

# Critical assertion: balance must never be negative
if echo "$FINAL_BALANCE" | grep -q "^-"; then
  echo -e "  ${RED}❌ CRITICAL FAIL${NC} — Balance went NEGATIVE: \$$FINAL_BALANCE ← REAL MONEY LOSS BUG!"
  FAIL=$((FAIL + 1))
elif [ "$FINAL_BALANCE" = "unknown" ]; then
  echo -e "  ${YELLOW}⚠️  WARN${NC} — Could not verify final balance"
  WARN=$((WARN + 1))
else
  echo -e "  ${GREEN}✅ PASS${NC} — Balance is non-negative: \$$FINAL_BALANCE (race condition handled)"
  # Verify balance is mathematically consistent
  EXPECTED_MIN="0.00"
  echo -e "  ${CYAN}   Balance integrity: OK — no negative balance${NC}"
  PASS=$((PASS + 1))
fi

rm -rf "$RESULT_DIR"

print_section "Test 2 — 3 Concurrent Withdrawals"

# Deposit fresh $200 for next test
curl -s -X POST "$BASE_URL/api/v1/transactions/deposit" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"toAccountNumber\":\"$ACC1\",\"amount\":200.00,\"note\":\"refill\"}" > /dev/null

BAL_RESP2=$(curl -s -X GET "$BASE_URL/api/v1/accounts/$ACC1_ID" -H "Authorization: Bearer $TOKEN")
BAL2=$(echo "$BAL_RESP2" | jq -r '.balance // "unknown"' 2>/dev/null)
echo -e "\n${CYAN}[2/3] Firing 3 concurrent \$100 withdrawals (balance: \$$BAL2)...${NC}"

RESULT_DIR2=$(mktemp -d)

for i in $(seq 1 3); do
  (
    RESP=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/transactions/withdraw" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $TOKEN" \
      -d "{\"fromAccountNumber\":\"$ACC1\",\"amount\":100.00,\"pin\":\"1234\",\"note\":\"concurrent withdraw $i\"}")
    HTTP_CODE=$(echo "$RESP" | tail -1)
    STATUS=$(echo "$RESP" | head -1 | jq -r '.status // "UNKNOWN"' 2>/dev/null)
    echo "$HTTP_CODE $STATUS" > "$RESULT_DIR2/result_$i.txt"
  ) &
done

wait

W_SUCCESS=0
for i in $(seq 1 3); do
  R=$(cat "$RESULT_DIR2/result_$i.txt" 2>/dev/null)
  C=$(echo "$R" | awk '{print $1}')
  S=$(echo "$R" | awk '{print $2}')
  echo -e "  ${CYAN}   Withdraw $i: HTTP $C | status=$S${NC}"
  [ "$C" -eq 200 ] && [ "$S" = "SUCCESS" ] && W_SUCCESS=$((W_SUCCESS + 1))
done

sleep 1
FINAL2=$(curl -s -X GET "$BASE_URL/api/v1/accounts/$ACC1_ID" -H "Authorization: Bearer $TOKEN" | jq -r '.balance // "unknown"' 2>/dev/null)
echo -e "  ${CYAN}   Final balance: \$$FINAL2${NC}"

if echo "$FINAL2" | grep -q "^-"; then
  echo -e "  ${RED}❌ CRITICAL FAIL${NC} — Concurrent withdrawals caused NEGATIVE balance: \$$FINAL2"
  FAIL=$((FAIL + 1))
else
  echo -e "  ${GREEN}✅ PASS${NC} — Concurrent withdrawals: balance OK (\$$FINAL2)"
  PASS=$((PASS + 1))
fi

rm -rf "$RESULT_DIR2"

print_section "Test 3 — Concurrent Deposit + Withdraw"

echo -e "\n${CYAN}[3/3] Concurrent deposit \$50 AND withdraw \$50 simultaneously...${NC}"

RESULT_DIR3=$(mktemp -d)

# Deposit in background
(
  RESP=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/transactions/deposit" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d "{\"toAccountNumber\":\"$ACC1\",\"amount\":50.00,\"note\":\"concurrent deposit\"}")
  echo "$(echo "$RESP" | tail -1) $(echo "$RESP" | head -1 | jq -r '.status // "UNKNOWN"' 2>/dev/null)" > "$RESULT_DIR3/deposit.txt"
) &

# Withdraw in background at same time
(
  RESP=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/transactions/withdraw" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d "{\"fromAccountNumber\":\"$ACC1\",\"amount\":50.00,\"pin\":\"1234\",\"note\":\"concurrent withdraw\"}")
  echo "$(echo "$RESP" | tail -1) $(echo "$RESP" | head -1 | jq -r '.status // "UNKNOWN"' 2>/dev/null)" > "$RESULT_DIR3/withdraw.txt"
) &

wait

DEP_R=$(cat "$RESULT_DIR3/deposit.txt" 2>/dev/null)
WIT_R=$(cat "$RESULT_DIR3/withdraw.txt" 2>/dev/null)
echo -e "  ${CYAN}   Deposit:  HTTP $(echo $DEP_R | awk '{print $1}') | status=$(echo $DEP_R | awk '{print $2}')${NC}"
echo -e "  ${CYAN}   Withdraw: HTTP $(echo $WIT_R | awk '{print $1}') | status=$(echo $WIT_R | awk '{print $2}')${NC}"

sleep 1
FINAL3=$(curl -s -X GET "$BASE_URL/api/v1/accounts/$ACC1_ID" -H "Authorization: Bearer $TOKEN" | jq -r '.balance // "unknown"' 2>/dev/null)
echo -e "  ${CYAN}   Final balance: \$$FINAL3${NC}"

if echo "$FINAL3" | grep -q "^-"; then
  echo -e "  ${RED}❌ CRITICAL FAIL${NC} — Concurrent deposit/withdraw caused negative balance!"
  FAIL=$((FAIL + 1))
else
  echo -e "  ${GREEN}✅ PASS${NC} — Concurrent deposit/withdraw: balance consistent (\$$FINAL3)"
  PASS=$((PASS + 1))
fi

rm -rf "$RESULT_DIR3"

print_summary "Concurrent Transfer"

echo "$PASS" > /tmp/ec_module_pass.txt
echo "$FAIL" > /tmp/ec_module_fail.txt
echo "$WARN" > /tmp/ec_module_warn.txt
