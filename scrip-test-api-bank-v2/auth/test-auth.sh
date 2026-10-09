#!/bin/bash
# =============================================================================
# auth/test-auth.sh — Test Authentication APIs
#
# Endpoints covered:
#   POST /api/v1/auth/register
#   POST /api/v1/auth/login
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/config.sh"

# Use a unique username per run to avoid "Username already exists" on re-runs
RUN_ID=$(date +%s)
TEST_USERNAME="titan_qa_${RUN_ID}"
TEST_EMAIL="titan_qa_${RUN_ID}@titanbank.com"

print_header "🔐 AUTH API TESTS"

# ── 1. REGISTER ───────────────────────────────────────────────────────────────
echo -e "\n${CYAN}[1/4] POST /api/v1/auth/register — Valid registration${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/auth/register" \
  -H "Content-Type: application/json" \
  -d "{
    \"username\": \"$TEST_USERNAME\",
    \"password\": \"$TEST_PASSWORD\",
    \"email\": \"$TEST_EMAIL\",
    \"firstName\": \"Titan\",
    \"lastName\": \"QA\",
    \"pin\": \"1234\"
  }")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_status "Register new user" 200 "$HTTP_CODE" "$BODY"

# Extract token from register response if returned
TOKEN=$(echo "$BODY" | jq -r '.token // empty' 2>/dev/null)
if [ -n "$TOKEN" ] && [ "$TOKEN" != "null" ]; then
  save_token "$TOKEN"
  echo -e "  ${CYAN}   Token captured from register response${NC}"
fi

# Save username for downstream scripts
echo "$TEST_USERNAME" > /tmp/titan_test_username.txt
echo "$TEST_PASSWORD" > /tmp/titan_test_password.txt

# ── 2. REGISTER DUPLICATE ────────────────────────────────────────────────────
echo -e "\n${CYAN}[2/4] POST /api/v1/auth/register — Duplicate username (expect 4xx)${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/auth/register" \
  -H "Content-Type: application/json" \
  -d "{
    \"username\": \"$TEST_USERNAME\",
    \"password\": \"$TEST_PASSWORD\",
    \"email\": \"$TEST_EMAIL\",
    \"firstName\": \"Titan\",
    \"lastName\": \"QA\",
    \"pin\": \"1234\"
  }")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
# Expect 400 or 409 conflict
if [ "$HTTP_CODE" -ge 400 ] && [ "$HTTP_CODE" -lt 500 ]; then
  echo -e "  ${GREEN}✅ PASS${NC} — Duplicate register rejected (HTTP $HTTP_CODE)"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}❌ FAIL${NC} — Duplicate register should return 4xx, got HTTP $HTTP_CODE"
  FAIL=$((FAIL + 1))
fi

# ── 3. LOGIN — Valid credentials ─────────────────────────────────────────────
echo -e "\n${CYAN}[3/4] POST /api/v1/auth/login — Valid credentials${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d "{
    \"username\": \"$TEST_USERNAME\",
    \"password\": \"$TEST_PASSWORD\"
  }")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_status "Login with valid credentials" 200 "$HTTP_CODE" "$BODY"

# Extract & save JWT token
TOKEN=$(echo "$BODY" | jq -r '.token // empty' 2>/dev/null)
if [ -n "$TOKEN" ] && [ "$TOKEN" != "null" ]; then
  save_token "$TOKEN"
  echo -e "  ${CYAN}   ✅ JWT Token saved to $TOKEN_FILE${NC}"
  echo -e "  ${CYAN}   Token preview: ${TOKEN:0:40}...${NC}"
else
  echo -e "  ${YELLOW}   ⚠️  No token found in response. Check response field name.${NC}"
  echo -e "  ${YELLOW}   Response: $BODY${NC}"
fi

# ── 4. LOGIN — Wrong password ────────────────────────────────────────────────
echo -e "\n${CYAN}[4/4] POST /api/v1/auth/login — Wrong password (expect 4xx)${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d "{
    \"username\": \"$TEST_USERNAME\",
    \"password\": \"WrongPassword999\"
  }")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
if [ "$HTTP_CODE" -ge 400 ] && [ "$HTTP_CODE" -lt 500 ]; then
  echo -e "  ${GREEN}✅ PASS${NC} — Invalid login rejected (HTTP $HTTP_CODE)"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}❌ FAIL${NC} — Invalid login should return 4xx, got HTTP $HTTP_CODE"
  FAIL=$((FAIL + 1))
fi

print_summary "Auth"

# Save counters for run-all.sh
echo "$PASS" > /tmp/titan_module_pass.txt
echo "$FAIL" > /tmp/titan_module_fail.txt
