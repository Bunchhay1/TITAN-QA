#!/bin/bash
# =============================================================================
# edge-cases/expired/test-expired.sh
#
# Tests expiry and reuse edge cases:
#   1.  Pay with already CANCELLED QR code          → reject
#   2.  Pay with already COMPLETED QR code          → reject (no double pay)
#   3.  Collect with already USED payer QR          → reject
#   4.  Redeem already USED ATM code                → reject
#   5.  Cancel already CANCELLED ATM code           → reject
#   6.  Cancel already USED ATM code                → reject
#   7.  QR with TTL=1min then pay immediately       → accept (within window)
#   8.  Pay QR with wrong amount (fixed-amount QR)  → reject
#   9.  Generate QR with ttlMinutes=0               → reject or use default
#   10. Generate QR with negative ttlMinutes        → reject
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.sh"

print_header "⏰ EXPIRED & REUSE — QR and ATM Code Edge Cases"

echo -e "\n${CYAN}Setting up test user...${NC}"
setup_user

TOKEN=$(cat "$EC_TOKEN")
ACC1=$(cat "$EC_ACCOUNT")
ACC2=$(cat "$EC_ACCOUNT2")

print_section "QR Code Reuse & State"

# ── Setup: generate a QR and cancel it ───────────────────────────────────────
echo -e "\n${CYAN}Setup: generating and cancelling a QR for test [1]...${NC}"
QR_RESP=$(curl -s -X POST "$BASE_URL/api/v1/qr/generate" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"payeeAccountNumber\":\"$ACC1\",\"amount\":25.00,\"note\":\"to cancel\",\"ttlMinutes\":15}")
CANCELLED_QR=$(echo "$QR_RESP" | jq -r '.qrCode // empty' 2>/dev/null)

# Cancel it
curl -s -X POST "$BASE_URL/api/v1/qr/cancel/$CANCELLED_QR" \
  -H "Authorization: Bearer $TOKEN" > /dev/null
echo -e "${CYAN}  Cancelled QR: ${CANCELLED_QR:0:20}...${NC}"

# ── 1. Pay with CANCELLED QR ──────────────────────────────────────────────────
echo -e "\n${CYAN}[1/10] POST /api/v1/qr/pay — Use CANCELLED QR code${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/qr/pay" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"qrCode\":\"$CANCELLED_QR\",\"payerAccountNumber\":\"$ACC2\",\"amount\":25.00,\"pin\":\"1234\"}")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_rejected "Pay with CANCELLED QR" "$HTTP_CODE" "$BODY"

# ── Setup: generate and complete a QR ────────────────────────────────────────
echo -e "\n${CYAN}Setup: generating and paying a QR for test [2]...${NC}"
QR_RESP2=$(curl -s -X POST "$BASE_URL/api/v1/qr/generate" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"payeeAccountNumber\":\"$ACC1\",\"amount\":10.00,\"note\":\"to complete\",\"ttlMinutes\":15}")
COMPLETED_QR=$(echo "$QR_RESP2" | jq -r '.qrCode // empty' 2>/dev/null)

# Pay it (complete it)
curl -s -X POST "$BASE_URL/api/v1/qr/pay" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"qrCode\":\"$COMPLETED_QR\",\"payerAccountNumber\":\"$ACC2\",\"amount\":10.00,\"pin\":\"1234\"}" > /dev/null
echo -e "${CYAN}  Completed QR: ${COMPLETED_QR:0:20}...${NC}"

# ── 2. Pay with COMPLETED QR (double pay) ────────────────────────────────────
echo -e "\n${CYAN}[2/10] POST /api/v1/qr/pay — Double pay COMPLETED QR${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/qr/pay" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"qrCode\":\"$COMPLETED_QR\",\"payerAccountNumber\":\"$ACC2\",\"amount\":10.00,\"pin\":\"1234\"}")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_rejected "Double pay with COMPLETED QR" "$HTTP_CODE" "$BODY"

# ── Setup: generate payer QR and collect it ───────────────────────────────────
echo -e "\n${CYAN}Setup: generating payer QR and collecting for test [3]...${NC}"
PAYER_QR_RESP=$(curl -s -X POST "$BASE_URL/api/v1/qr/generate-payer" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"payerAccountNumber\":\"$ACC1\",\"amount\":5.00,\"pin\":\"1234\",\"note\":\"to collect\",\"ttlMinutes\":15}")
USED_PAYER_QR=$(echo "$PAYER_QR_RESP" | jq -r '.qrCode // empty' 2>/dev/null)

# Collect it
curl -s -X POST "$BASE_URL/api/v1/qr/collect" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"qrCode\":\"$USED_PAYER_QR\",\"collectorAccountNumber\":\"$ACC2\"}" > /dev/null
echo -e "${CYAN}  Used payer QR: ${USED_PAYER_QR:0:20}...${NC}"

# ── 3. Collect with already USED payer QR ─────────────────────────────────────
echo -e "\n${CYAN}[3/10] POST /api/v1/qr/collect — Collect already USED payer QR${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/qr/collect" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"qrCode\":\"$USED_PAYER_QR\",\"collectorAccountNumber\":\"$ACC2\"}")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_rejected "Double collect with USED payer QR" "$HTTP_CODE" "$BODY"

print_section "ATM Code Reuse & State"

# ── Setup: generate and redeem ATM code ──────────────────────────────────────
echo -e "\n${CYAN}Setup: generating and redeeming ATM code for tests [4]...${NC}"
ATM_RESP=$(curl -s -X POST "$BASE_URL/api/v1/atm/generate" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"accountNumber\":\"$ACC1\",\"amount\":10.00,\"pin\":\"1234\"}")
USED_ATM=$(echo "$ATM_RESP" | jq -r '.atmCode // .code // empty' 2>/dev/null)

curl -s -X POST "$BASE_URL/api/v1/atm/redeem" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"code\":\"$USED_ATM\",\"terminalId\":\"TEST-TERMINAL\"}" > /dev/null
echo -e "${CYAN}  Used ATM code: $USED_ATM${NC}"

# ── 4. Redeem already USED ATM code ──────────────────────────────────────────
echo -e "\n${CYAN}[4/10] POST /api/v1/atm/redeem — Redeem already USED code${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/atm/redeem" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"code\":\"$USED_ATM\",\"terminalId\":\"TEST-TERMINAL\"}")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_rejected "Redeem already USED ATM code" "$HTTP_CODE" "$BODY"

# ── Setup: generate and cancel ATM code ──────────────────────────────────────
echo -e "\n${CYAN}Setup: generating and cancelling ATM code for tests [5,6]...${NC}"
ATM_RESP2=$(curl -s -X POST "$BASE_URL/api/v1/atm/generate" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"accountNumber\":\"$ACC1\",\"amount\":10.00,\"pin\":\"1234\"}")
CANCELLED_ATM=$(echo "$ATM_RESP2" | jq -r '.atmCode // .code // empty' 2>/dev/null)

curl -s -X DELETE "$BASE_URL/api/v1/atm/cancel/$CANCELLED_ATM" \
  -H "Authorization: Bearer $TOKEN" > /dev/null
echo -e "${CYAN}  Cancelled ATM code: $CANCELLED_ATM${NC}"

# ── 5. Cancel already CANCELLED ATM code ─────────────────────────────────────
echo -e "\n${CYAN}[5/10] DELETE /api/v1/atm/cancel — Cancel already CANCELLED code${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE "$BASE_URL/api/v1/atm/cancel/$CANCELLED_ATM" \
  -H "Authorization: Bearer $TOKEN")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_rejected "Cancel already CANCELLED ATM code" "$HTTP_CODE" "$BODY"

# ── 6. Redeem CANCELLED ATM code ─────────────────────────────────────────────
echo -e "\n${CYAN}[6/10] POST /api/v1/atm/redeem — Redeem CANCELLED code${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/atm/redeem" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"code\":\"$CANCELLED_ATM\",\"terminalId\":\"TEST-TERMINAL\"}")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_rejected "Redeem CANCELLED ATM code" "$HTTP_CODE" "$BODY"

print_section "QR Generation Edge Cases"

# ── 7. QR within valid window (ttlMinutes=1 then pay immediately) ─────────────
echo -e "\n${CYAN}[7/10] Generate QR with ttlMinutes=1 then pay immediately${NC}"
QR_RESP3=$(curl -s -X POST "$BASE_URL/api/v1/qr/generate" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"payeeAccountNumber\":\"$ACC1\",\"amount\":5.00,\"note\":\"1 min ttl\",\"ttlMinutes\":1}")
FRESH_QR=$(echo "$QR_RESP3" | jq -r '.qrCode // empty' 2>/dev/null)

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/qr/pay" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"qrCode\":\"$FRESH_QR\",\"payerAccountNumber\":\"$ACC2\",\"amount\":5.00,\"pin\":\"1234\"}")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_accepted "Pay QR with ttl=1min immediately" "$HTTP_CODE" "$BODY"

# ── 8. Pay fixed-amount QR with wrong amount ──────────────────────────────────
echo -e "\n${CYAN}[8/10] Pay fixed-amount QR (\$20) with wrong amount (\$99)${NC}"
QR_FIXED=$(curl -s -X POST "$BASE_URL/api/v1/qr/generate" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"payeeAccountNumber\":\"$ACC1\",\"amount\":20.00,\"note\":\"fixed amount\",\"ttlMinutes\":15}")
FIXED_QR_CODE=$(echo "$QR_FIXED" | jq -r '.qrCode // empty' 2>/dev/null)

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/qr/pay" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"qrCode\":\"$FIXED_QR_CODE\",\"payerAccountNumber\":\"$ACC2\",\"amount\":99.00,\"pin\":\"1234\"}")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_rejected "Pay fixed-amount QR with wrong amount" "$HTTP_CODE" "$BODY"

# ── 9. Generate QR with ttlMinutes=0 ─────────────────────────────────────────
echo -e "\n${CYAN}[9/10] Generate QR with ttlMinutes=0${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/qr/generate" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"payeeAccountNumber\":\"$ACC1\",\"amount\":10.00,\"note\":\"zero ttl\",\"ttlMinutes\":0}")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
if [ "$HTTP_CODE" -ge 400 ]; then
  echo -e "  ${GREEN}✅ PASS${NC} — ttlMinutes=0 rejected (HTTP $HTTP_CODE)"
  PASS=$((PASS + 1))
elif [ "$HTTP_CODE" -eq 200 ]; then
  echo -e "  ${YELLOW}⚠️  WARN${NC} — ttlMinutes=0 accepted (HTTP 200) — using default TTL"
  echo -e "  ${YELLOW}   Consider rejecting 0 or enforcing minimum 1 minute${NC}"
  WARN=$((WARN + 1))
fi

# ── 10. Generate QR with negative ttlMinutes ──────────────────────────────────
echo -e "\n${CYAN}[10/10] Generate QR with ttlMinutes=-5${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/qr/generate" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"payeeAccountNumber\":\"$ACC1\",\"amount\":10.00,\"note\":\"neg ttl\",\"ttlMinutes\":-5}")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_rejected "QR with negative ttlMinutes" "$HTTP_CODE" "$BODY"

print_summary "Expired & Reuse"

echo "$PASS" > /tmp/ec_module_pass.txt
echo "$FAIL" > /tmp/ec_module_fail.txt
echo "$WARN" > /tmp/ec_module_warn.txt
