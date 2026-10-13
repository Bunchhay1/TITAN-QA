#!/bin/bash
# =============================================================================
# qr-payment/test-qr-payment.sh — Test QR Payment APIs
#
# Endpoints covered:
#   POST /api/v1/qr/generate
#   POST /api/v1/qr/pay
#   POST /api/v1/qr/generate-payer
#   POST /api/v1/qr/collect
#   POST /api/v1/qr/cancel/{qrCode}
#   GET  /api/v1/qr/history/{accountNumber}
#   GET  /api/v1/qr/account/{accountNumber}
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/config.sh"
load_token
load_credentials
load_account
load_account2

print_header "📱 QR PAYMENT API TESTS"

if [ -z "$JWT_TOKEN" ]; then
  echo -e "${RED}❌ No JWT token. Run auth/test-auth.sh first.${NC}"
  exit 1
fi

if [ -z "$TEST_ACCOUNT" ]; then
  echo -e "${RED}❌ No account. Run accounts/test-accounts.sh first.${NC}"
  exit 1
fi

QR_CODE_FILE="/tmp/titan_test_qr_code.txt"
PAYER_QR_FILE="/tmp/titan_test_payer_qr.txt"

# ── 1. GENERATE QR (Receive money) ───────────────────────────────────────────
echo -e "\n${CYAN}[1/7] POST /api/v1/qr/generate — Generate receive QR code${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/qr/generate" \
  -H "Content-Type: application/json" \
  -H "$(auth_header)" \
  -d "{
    \"payeeAccountNumber\": \"$TEST_ACCOUNT\",
    \"amount\": 50.00,
    \"note\": \"QA Test QR Payment\",
    \"ttlMinutes\": 15
  }")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_status "Generate QR code for receiving" 200 "$HTTP_CODE" "$BODY"

QR_CODE=$(echo "$BODY" | jq -r '.qrCode // empty' 2>/dev/null)
if [ -n "$QR_CODE" ] && [ "$QR_CODE" != "null" ]; then
  echo "$QR_CODE" > "$QR_CODE_FILE"
  echo -e "  ${CYAN}   QR Code: ${QR_CODE:0:30}...${NC}"
fi

# ── 2. PAY BY QR ─────────────────────────────────────────────────────────────
if [ -n "$TEST_ACCOUNT2" ] && [ -f "$QR_CODE_FILE" ]; then
  QR_CODE=$(cat "$QR_CODE_FILE")
  echo -e "\n${CYAN}[2/7] POST /api/v1/qr/pay — Pay using QR code${NC}"
  RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/qr/pay" \
    -H "Content-Type: application/json" \
    -H "$(auth_header)" \
    -d "{
      \"qrCode\": \"$QR_CODE\",
      \"payerAccountNumber\": \"$TEST_ACCOUNT2\",
      \"amount\": 50.00,
      \"pin\": \"1234\"
    }")

  HTTP_CODE=$(echo "$RESPONSE" | tail -1)
  BODY=$(echo "$RESPONSE" | head -1)
  assert_status "Pay using QR code" 200 "$HTTP_CODE" "$BODY"
  echo -e "  ${CYAN}   Status: $(echo "$BODY" | jq -r '.status // "N/A"' 2>/dev/null)${NC}"
else
  echo -e "\n${YELLOW}[2/7] Skipping Pay by QR — need 2 accounts or QR code${NC}"
fi

# ── 3. GENERATE PAYER QR (Send money) ────────────────────────────────────────
echo -e "\n${CYAN}[3/7] POST /api/v1/qr/generate-payer — Generate send-by-QR code${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/qr/generate-payer" \
  -H "Content-Type: application/json" \
  -H "$(auth_header)" \
  -d "{
    \"payerAccountNumber\": \"$TEST_ACCOUNT\",
    \"amount\": 30.00,
    \"pin\": \"1234\",
    \"note\": \"QA Payer QR Test\",
    \"ttlMinutes\": 15
  }")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_status "Generate payer QR code" 200 "$HTTP_CODE" "$BODY"

PAYER_QR=$(echo "$BODY" | jq -r '.qrCode // empty' 2>/dev/null)
if [ -n "$PAYER_QR" ] && [ "$PAYER_QR" != "null" ]; then
  echo "$PAYER_QR" > "$PAYER_QR_FILE"
  echo -e "  ${CYAN}   Payer QR: ${PAYER_QR:0:30}...${NC}"
fi

# ── 4. COLLECT BY QR ─────────────────────────────────────────────────────────
if [ -n "$TEST_ACCOUNT2" ] && [ -f "$PAYER_QR_FILE" ]; then
  PAYER_QR=$(cat "$PAYER_QR_FILE")
  echo -e "\n${CYAN}[4/7] POST /api/v1/qr/collect — Collect money from payer QR${NC}"
  RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/qr/collect" \
    -H "Content-Type: application/json" \
    -H "$(auth_header)" \
    -d "{
      \"qrCode\": \"$PAYER_QR\",
      \"collectorAccountNumber\": \"$TEST_ACCOUNT2\"
    }")

  HTTP_CODE=$(echo "$RESPONSE" | tail -1)
  BODY=$(echo "$RESPONSE" | head -1)
  assert_status "Collect money from payer QR" 200 "$HTTP_CODE" "$BODY"
else
  echo -e "\n${YELLOW}[4/7] Skipping Collect QR — need payer QR code${NC}"
fi

# ── 5. CANCEL QR ─────────────────────────────────────────────────────────────
# Generate a fresh QR to cancel
echo -e "\n${CYAN}[5/7] POST /api/v1/qr/cancel/{qrCode} — Cancel a QR code${NC}"
NEW_QR_RESP=$(curl -s -X POST "$BASE_URL/api/v1/qr/generate" \
  -H "Content-Type: application/json" \
  -H "$(auth_header)" \
  -d "{
    \"payeeAccountNumber\": \"$TEST_ACCOUNT\",
    \"amount\": 25.00,
    \"note\": \"To be cancelled\",
    \"ttlMinutes\": 15
  }")

CANCEL_QR=$(echo "$NEW_QR_RESP" | jq -r '.qrCode // empty' 2>/dev/null)
if [ -n "$CANCEL_QR" ] && [ "$CANCEL_QR" != "null" ]; then
  RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/qr/cancel/$CANCEL_QR" \
    -H "$(auth_header)")

  HTTP_CODE=$(echo "$RESPONSE" | tail -1)
  BODY=$(echo "$RESPONSE" | head -1)
  assert_status "Cancel QR code" 200 "$HTTP_CODE" "$BODY"
  echo -e "  ${CYAN}   Status: $(echo "$BODY" | jq -r '.status // "N/A"' 2>/dev/null)${NC}"
else
  echo -e "  ${YELLOW}   ⚠️  Could not generate a QR to cancel${NC}"
fi

# ── 6. QR HISTORY ─────────────────────────────────────────────────────────────
echo -e "\n${CYAN}[6/7] GET /api/v1/qr/history/$TEST_ACCOUNT — QR payment history${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$BASE_URL/api/v1/qr/history/$TEST_ACCOUNT" \
  -H "$(auth_header)")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_status "Get QR payment history" 200 "$HTTP_CODE" "$BODY"
COUNT=$(echo "$BODY" | jq 'length' 2>/dev/null)
echo -e "  ${CYAN}   QR records: $COUNT${NC}"

# ── 7. GET OR CREATE ACCOUNT QR ──────────────────────────────────────────────
echo -e "\n${CYAN}[7/7] GET /api/v1/qr/account/$TEST_ACCOUNT — Get permanent account QR${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$BASE_URL/api/v1/qr/account/$TEST_ACCOUNT" \
  -H "$(auth_header)")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_status "Get or create permanent account QR" 200 "$HTTP_CODE" "$BODY"

print_summary "QR Payment"

# Save counters for run-all.sh
echo "$PASS" > /tmp/titan_module_pass.txt
echo "$FAIL" > /tmp/titan_module_fail.txt
