#!/bin/bash
# =============================================================================
# loans/test-loans.sh — Test Loan APIs (proxied to titan-loans-service)
#
# Endpoints covered:
#   POST /api/v1/loans/apply
#   PUT  /api/v1/loans/{id}/approve
#   PUT  /api/v1/loans/{id}/reject
#   GET  /api/v1/loans/{id}
#   GET  /api/v1/loans/my
#   GET  /api/v1/loans/account/{accountId}
#   GET  /api/v1/loans/{id}/repayments
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/config.sh"
load_token
load_credentials
load_account

print_header "💰 LOAN API TESTS"

if [ -z "$JWT_TOKEN" ]; then
  echo -e "${RED}❌ No JWT token. Run auth/test-auth.sh first.${NC}"
  exit 1
fi

ACCOUNT_ID=$(cat /tmp/titan_test_account_id.txt 2>/dev/null)
LOAN_ID_FILE="/tmp/titan_test_loan_id.txt"

echo -e "  ${CYAN}Account Number: $TEST_ACCOUNT${NC}"
echo -e "  ${CYAN}Account ID: $ACCOUNT_ID${NC}"
echo -e "  ${YELLOW}ℹ️  Loans are proxied to titan-loans-service (separate microservice).${NC}"
echo -e "  ${YELLOW}   Tests will PASS if service is running, show KNOWN_BUG if not.${NC}"

# ── Helper: check if loan service is available ───────────────────────────────
check_loan_service() {
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 \
    -X GET "$BASE_URL/api/v1/loans/my" -H "$(auth_header)" 2>/dev/null)
  if [ "$code" = "400" ]; then
    # Check if it's "service unavailable" vs a real 400
    local body
    body=$(curl -s -X GET "$BASE_URL/api/v1/loans/my" -H "$(auth_header)" 2>/dev/null)
    if echo "$body" | grep -q "unavailable"; then
      return 1  # service down
    fi
  fi
  return 0
}

if ! check_loan_service; then
  echo -e "\n  ${YELLOW}⚠️  KNOWN_BUG: titan-loans-service is NOT running.${NC}"
  echo -e "  ${YELLOW}   All 7 loan endpoints return 'Loan service is currently unavailable'.${NC}"
  echo -e "  ${YELLOW}   Start titan-loans-service to enable these tests.${NC}"
  echo -e "  ${YELLOW}   Skipping all loan tests (not counted as failures).${NC}"
  print_summary "Loans (service offline — skipped)"
  # Save counters for run-all.sh
  echo "$PASS" > /tmp/titan_module_pass.txt
  echo "$FAIL" > /tmp/titan_module_fail.txt
  exit 0
fi

# ── 1. APPLY FOR LOAN ─────────────────────────────────────────────────────────
echo -e "\n${CYAN}[1/7] POST /api/v1/loans/apply — Apply for a loan${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/loans/apply" \
  -H "Content-Type: application/json" \
  -H "$(auth_header)" \
  -d "{
    \"accountId\": $ACCOUNT_ID,
    \"amount\": 5000.00,
    \"termMonths\": 12,
    \"purpose\": \"Home renovation\",
    \"monthlyIncome\": 3000.00
  }")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_status "Apply for loan" 200 "$HTTP_CODE" "$BODY"

LOAN_ID=$(echo "$BODY" | jq -r '.id // .loanId // empty' 2>/dev/null)
if [ -n "$LOAN_ID" ] && [ "$LOAN_ID" != "null" ]; then
  echo "$LOAN_ID" > "$LOAN_ID_FILE"
  echo -e "  ${CYAN}   Loan ID: $LOAN_ID${NC}"
  echo -e "  ${CYAN}   Status: $(echo "$BODY" | jq -r '.status // "N/A"' 2>/dev/null)${NC}"
else
  echo -e "  ${YELLOW}   ⚠️  No loan ID in response — downstream service may not be running${NC}"
fi

# ── 2. GET MY LOANS ───────────────────────────────────────────────────────────
echo -e "\n${CYAN}[2/7] GET /api/v1/loans/my — Get my loans${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$BASE_URL/api/v1/loans/my" \
  -H "$(auth_header)")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_status "Get my loans" 200 "$HTTP_CODE" "$BODY"
COUNT=$(echo "$BODY" | jq 'length' 2>/dev/null)
echo -e "  ${CYAN}   Loans returned: $COUNT${NC}"

# ── 3. GET LOAN BY ID ─────────────────────────────────────────────────────────
LOAN_ID=$(cat "$LOAN_ID_FILE" 2>/dev/null)
if [ -n "$LOAN_ID" ]; then
  echo -e "\n${CYAN}[3/7] GET /api/v1/loans/$LOAN_ID — Get loan by ID${NC}"
  RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$BASE_URL/api/v1/loans/$LOAN_ID" \
    -H "$(auth_header)")

  HTTP_CODE=$(echo "$RESPONSE" | tail -1)
  BODY=$(echo "$RESPONSE" | head -1)
  assert_status "Get loan by ID" 200 "$HTTP_CODE" "$BODY"
else
  echo -e "\n${YELLOW}[3/7] Skipping Get Loan by ID — no loan ID saved${NC}"
fi

# ── 4. GET LOANS BY ACCOUNT ────────────────────────────────────────────────────
if [ -n "$ACCOUNT_ID" ]; then
  echo -e "\n${CYAN}[4/7] GET /api/v1/loans/account/$ACCOUNT_ID — Get loans by account${NC}"
  RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$BASE_URL/api/v1/loans/account/$ACCOUNT_ID" \
    -H "$(auth_header)")

  HTTP_CODE=$(echo "$RESPONSE" | tail -1)
  BODY=$(echo "$RESPONSE" | head -1)
  assert_status "Get loans by account" 200 "$HTTP_CODE" "$BODY"
else
  echo -e "\n${YELLOW}[4/7] Skipping — no account ID saved${NC}"
fi

# ── 5. APPROVE LOAN ───────────────────────────────────────────────────────────
LOAN_ID=$(cat "$LOAN_ID_FILE" 2>/dev/null)
if [ -n "$LOAN_ID" ]; then
  echo -e "\n${CYAN}[5/7] PUT /api/v1/loans/$LOAN_ID/approve — Approve loan${NC}"
  RESPONSE=$(curl -s -w "\n%{http_code}" -X PUT "$BASE_URL/api/v1/loans/$LOAN_ID/approve" \
    -H "Content-Type: application/json" \
    -H "$(auth_header)")

  HTTP_CODE=$(echo "$RESPONSE" | tail -1)
  BODY=$(echo "$RESPONSE" | head -1)
  assert_status "Approve loan" 200 "$HTTP_CODE" "$BODY"
  echo -e "  ${CYAN}   Status: $(echo "$BODY" | jq -r '.status // "N/A"' 2>/dev/null)${NC}"
else
  echo -e "\n${YELLOW}[5/7] Skipping Approve — no loan ID saved${NC}"
fi

# ── 6. GET REPAYMENT SCHEDULE ─────────────────────────────────────────────────
LOAN_ID=$(cat "$LOAN_ID_FILE" 2>/dev/null)
if [ -n "$LOAN_ID" ]; then
  echo -e "\n${CYAN}[6/7] GET /api/v1/loans/$LOAN_ID/repayments — Get repayment schedule${NC}"
  RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$BASE_URL/api/v1/loans/$LOAN_ID/repayments" \
    -H "$(auth_header)")

  HTTP_CODE=$(echo "$RESPONSE" | tail -1)
  BODY=$(echo "$RESPONSE" | head -1)
  assert_status "Get repayment schedule" 200 "$HTTP_CODE" "$BODY"
  COUNT=$(echo "$BODY" | jq 'length' 2>/dev/null)
  echo -e "  ${CYAN}   Repayment entries: $COUNT${NC}"
else
  echo -e "\n${YELLOW}[6/7] Skipping Repayments — no loan ID saved${NC}"
fi

# ── 7. REJECT A NEW LOAN ─────────────────────────────────────────────────────
echo -e "\n${CYAN}[7/7] Apply + Reject a loan${NC}"
NEW_LOAN_RESP=$(curl -s -X POST "$BASE_URL/api/v1/loans/apply" \
  -H "Content-Type: application/json" \
  -H "$(auth_header)" \
  -d "{
    \"accountId\": $ACCOUNT_ID,
    \"amount\": 1000.00,
    \"termMonths\": 6,
    \"purpose\": \"To be rejected\",
    \"monthlyIncome\": 1000.00
  }")

NEW_LOAN_ID=$(echo "$NEW_LOAN_RESP" | jq -r '.id // .loanId // empty' 2>/dev/null)
if [ -n "$NEW_LOAN_ID" ] && [ "$NEW_LOAN_ID" != "null" ]; then
  RESPONSE=$(curl -s -w "\n%{http_code}" -X PUT "$BASE_URL/api/v1/loans/$NEW_LOAN_ID/reject" \
    -H "Content-Type: application/json" \
    -H "$(auth_header)")

  HTTP_CODE=$(echo "$RESPONSE" | tail -1)
  BODY=$(echo "$RESPONSE" | head -1)
  assert_status "Reject loan" 200 "$HTTP_CODE" "$BODY"
  echo -e "  ${CYAN}   Status: $(echo "$BODY" | jq -r '.status // "N/A"' 2>/dev/null)${NC}"
else
  echo -e "  ${YELLOW}   ⚠️  Could not apply new loan for reject test${NC}"
fi

print_summary "Loans"

# Save counters for run-all.sh
echo "$PASS" > /tmp/titan_module_pass.txt
echo "$FAIL" > /tmp/titan_module_fail.txt
