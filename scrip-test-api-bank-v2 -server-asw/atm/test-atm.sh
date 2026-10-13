#!/bin/bash
# =============================================================================
# atm/test-atm.sh — Test ATM Cardless Withdrawal APIs
#
# Endpoints covered:
#   POST   /api/v1/atm/generate
#   POST   /api/v1/atm/redeem
#   DELETE /api/v1/atm/cancel/{code}
#   GET    /api/v1/atm/status/{code}
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/config.sh"
load_token
load_credentials
load_account

print_header "🏧 ATM CARDLESS API TESTS"

if [ -z "$JWT_TOKEN" ]; then
  echo -e "${RED}❌ No JWT token. Run auth/test-auth.sh first.${NC}"
  exit 1
fi

if [ -z "$TEST_ACCOUNT" ]; then
  echo -e "${RED}❌ No account. Run accounts/test-accounts.sh first.${NC}"
  exit 1
fi

ATM_CODE_FILE="/tmp/titan_test_atm_code.txt"
ATM_CODE_CANCEL_FILE="/tmp/titan_test_atm_cancel_code.txt"

# ── 1. GENERATE ATM CODE ──────────────────────────────────────────────────────
echo -e "\n${CYAN}[1/6] POST /api/v1/atm/generate — Generate 12-digit ATM code${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/atm/generate" \
  -H "Content-Type: application/json" \
  -H "$(auth_header)" \
  -d "{
    \"accountNumber\": \"$TEST_ACCOUNT\",
    \"amount\": 100.00,
    \"pin\": \"1234\"
  }")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_status "Generate ATM withdrawal code" 200 "$HTTP_CODE" "$BODY"

ATM_CODE=$(echo "$BODY" | jq -r '.atmCode // .code // empty' 2>/dev/null)
if [ -n "$ATM_CODE" ] && [ "$ATM_CODE" != "null" ]; then
  echo "$ATM_CODE" > "$ATM_CODE_FILE"
  echo -e "  ${CYAN}   ATM Code: $ATM_CODE${NC}"
  echo -e "  ${CYAN}   Expires: $(echo "$BODY" | jq -r '.expiresAt // "N/A"' 2>/dev/null)${NC}"
fi

# ── 2. CHECK STATUS ───────────────────────────────────────────────────────────
if [ -f "$ATM_CODE_FILE" ]; then
  ATM_CODE=$(cat "$ATM_CODE_FILE")
  echo -e "\n${CYAN}[2/6] GET /api/v1/atm/status/$ATM_CODE — Check ATM code status${NC}"
  RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$BASE_URL/api/v1/atm/status/$ATM_CODE" \
    -H "$(auth_header)")

  HTTP_CODE=$(echo "$RESPONSE" | tail -1)
  BODY=$(echo "$RESPONSE" | head -1)
  assert_status "Get ATM code status" 200 "$HTTP_CODE" "$BODY"
  echo -e "  ${CYAN}   Status: $(echo "$BODY" | jq -r '.status // "N/A"' 2>/dev/null)${NC}"
else
  echo -e "\n${YELLOW}[2/6] Skipping status check — no ATM code saved${NC}"
fi

# ── 3. REDEEM ATM CODE ────────────────────────────────────────────────────────
if [ -f "$ATM_CODE_FILE" ]; then
  ATM_CODE=$(cat "$ATM_CODE_FILE")
  echo -e "\n${CYAN}[3/6] POST /api/v1/atm/redeem — Redeem ATM code at terminal${NC}"
  RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/atm/redeem" \
    -H "Content-Type: application/json" \
    -H "$(auth_header)" \
    -d "{
      \"code\": \"$ATM_CODE\",
      \"terminalId\": \"ATM-QA-TERMINAL-001\"
    }")

  HTTP_CODE=$(echo "$RESPONSE" | tail -1)
  BODY=$(echo "$RESPONSE" | head -1)
  assert_status "Redeem ATM code" 200 "$HTTP_CODE" "$BODY"
  echo -e "  ${CYAN}   Status: $(echo "$BODY" | jq -r '.status // "N/A"' 2>/dev/null)${NC}"
else
  echo -e "\n${YELLOW}[3/6] Skipping redeem — no ATM code saved${NC}"
fi

# ── 4. REDEEM ALREADY USED CODE (expect 400) ──────────────────────────────────
if [ -f "$ATM_CODE_FILE" ]; then
  ATM_CODE=$(cat "$ATM_CODE_FILE")
  echo -e "\n${CYAN}[4/6] POST /api/v1/atm/redeem — Redeem already used code (expect 400)${NC}"
  RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/atm/redeem" \
    -H "Content-Type: application/json" \
    -H "$(auth_header)" \
    -d "{
      \"code\": \"$ATM_CODE\",
      \"terminalId\": \"ATM-QA-TERMINAL-001\"
    }")

  HTTP_CODE=$(echo "$RESPONSE" | tail -1)
  BODY=$(echo "$RESPONSE" | head -1)
  if [ "$HTTP_CODE" -ge 400 ]; then
    echo -e "  ${GREEN}✅ PASS${NC} — Double-redeem rejected (HTTP $HTTP_CODE)"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}❌ FAIL${NC} — Double-redeem should be rejected, got HTTP $HTTP_CODE"
    FAIL=$((FAIL + 1))
  fi
fi

# ── 5. GENERATE CODE TO CANCEL ────────────────────────────────────────────────
echo -e "\n${CYAN}[5/6] Generate new ATM code for cancel test...${NC}"
RESPONSE=$(curl -s -X POST "$BASE_URL/api/v1/atm/generate" \
  -H "Content-Type: application/json" \
  -H "$(auth_header)" \
  -d "{
    \"accountNumber\": \"$TEST_ACCOUNT\",
    \"amount\": 50.00,
    \"pin\": \"1234\"
  }")

CANCEL_CODE=$(echo "$RESPONSE" | jq -r '.atmCode // .code // empty' 2>/dev/null)
if [ -n "$CANCEL_CODE" ] && [ "$CANCEL_CODE" != "null" ]; then
  echo "$CANCEL_CODE" > "$ATM_CODE_CANCEL_FILE"

  # ── 6. CANCEL ATM CODE ────────────────────────────────────────────────────
  echo -e "\n${CYAN}[6/6] DELETE /api/v1/atm/cancel/$CANCEL_CODE — Cancel ATM code${NC}"
  RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE "$BASE_URL/api/v1/atm/cancel/$CANCEL_CODE" \
    -H "$(auth_header)")

  HTTP_CODE=$(echo "$RESPONSE" | tail -1)
  BODY=$(echo "$RESPONSE" | head -1)
  assert_status "Cancel ATM code" 200 "$HTTP_CODE" "$BODY"
  echo -e "  ${CYAN}   Status: $(echo "$BODY" | jq -r '.status // "N/A"' 2>/dev/null)${NC}"
else
  echo -e "\n${YELLOW}[5-6/6] Could not generate code for cancel test${NC}"
fi

print_summary "ATM Cardless"

# Save counters for run-all.sh
echo "$PASS" > /tmp/titan_module_pass.txt
echo "$FAIL" > /tmp/titan_module_fail.txt
