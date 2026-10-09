#!/bin/bash
# =============================================================================
# security/privilege-escalation/test-privilege-escalation.sh
#
# Tests privilege escalation resistance:
#   1. Normal user promotes own role to ADMIN via PUT /users/{id}/tier
#   2. Normal user accesses GET /api/v1/users (ADMIN only endpoint)
#   3. Normal user accesses GET /api/admin/outbox/status (ADMIN only)
#   4. Normal user calls internal disburse-loan endpoint
#   5. Normal user calls internal deduct-fee endpoint
#   6. Normal user updates ANOTHER user's tier
#   7. Unauthenticated user accesses admin endpoints
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.sh"

print_header "👑 PRIVILEGE ESCALATION — Authorization Tests"

# ── Setup two users ───────────────────────────────────────────────────────────
echo -e "\n${CYAN}Setting up two users...${NC}"
TS=$(date +%s)

# User A — normal user
USER_A="priv_user_a_${TS}"
RESP_A=$(curl -s -X POST "$BASE_URL/api/v1/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$USER_A\",\"password\":\"PrivTest@123\",\"email\":\"${USER_A}@test.com\",\"firstName\":\"Priv\",\"lastName\":\"UserA\",\"pin\":\"1234\"}")
TOKEN_A=$(echo "$RESP_A" | jq -r '.token // empty' 2>/dev/null)
USER_A_ID=$(echo "$RESP_A" | jq -r '.id // empty' 2>/dev/null)

if [ -z "$TOKEN_A" ]; then
  RESP_A=$(curl -s -X POST "$BASE_URL/api/v1/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"$USER_A\",\"password\":\"PrivTest@123\"}")
  TOKEN_A=$(echo "$RESP_A" | jq -r '.token // empty' 2>/dev/null)
fi

# User B — another normal user
USER_B="priv_user_b_${TS}"
RESP_B=$(curl -s -X POST "$BASE_URL/api/v1/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$USER_B\",\"password\":\"PrivTest@456\",\"email\":\"${USER_B}@test.com\",\"firstName\":\"Priv\",\"lastName\":\"UserB\",\"pin\":\"5678\"}")
TOKEN_B=$(echo "$RESP_B" | jq -r '.token // empty' 2>/dev/null)
USER_B_ID=$(echo "$RESP_B" | jq -r '.id // empty' 2>/dev/null)

if [ -z "$TOKEN_B" ]; then
  RESP_B=$(curl -s -X POST "$BASE_URL/api/v1/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"$USER_B\",\"password\":\"PrivTest@456\"}")
  TOKEN_B=$(echo "$RESP_B" | jq -r '.token // empty' 2>/dev/null)
  USER_B_ID=$(echo "$RESP_B" | jq -r '.id // empty' 2>/dev/null)
fi

# Get User A's ID from profile if not in register response
if [ -z "$USER_A_ID" ] || [ "$USER_A_ID" = "null" ]; then
  # Try getting from users list as a fallback (using User A's own token)
  USERS=$(curl -s -X GET "$BASE_URL/api/v1/users" -H "Authorization: Bearer $TOKEN_A")
  USER_A_ID=$(echo "$USERS" | jq -r ".[] | select(.username==\"$USER_A\") | .id" 2>/dev/null | head -1)
fi

echo -e "${CYAN}  User A: $USER_A (ID: $USER_A_ID)${NC}"
echo -e "${CYAN}  User B: $USER_B (ID: $USER_B_ID)${NC}"

# Create account for User A (for internal endpoint tests)
ACC_RESP=$(curl -s -X POST "$BASE_URL/api/v1/accounts" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN_A" \
  -d '{"accountType":"SAVINGS","currency":"USD","initialDeposit":500.00}')
ACC_A_ID=$(echo "$ACC_RESP" | jq -r '.id // empty' 2>/dev/null)
echo -e "${CYAN}  User A Account ID: $ACC_A_ID${NC}"

print_section "Role Escalation"

# ── 1. Normal user promotes own role to ADMIN ─────────────────────────────────
echo -e "\n${CYAN}[1/7] PUT /api/v1/users/{id}/tier — Normal user promotes self to VIP${NC}"
if [ -n "$USER_A_ID" ] && [ "$USER_A_ID" != "null" ]; then
  RESPONSE=$(curl -s -w "\n%{http_code}" -X PUT "$BASE_URL/api/v1/users/$USER_A_ID/tier" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN_A" \
    -d '{"tier": "PLATINUM"}')
  HTTP_CODE=$(echo "$RESPONSE" | tail -1)
  BODY=$(echo "$RESPONSE" | head -1)
  # This endpoint should require ADMIN role
  if [ "$HTTP_CODE" -eq 200 ]; then
    NEW_TIER=$(echo "$BODY" | jq -r '.tier // empty' 2>/dev/null)
    echo -e "  ${RED}❌ VULNERABLE${NC} — Normal user self-promoted to $NEW_TIER (HTTP $HTTP_CODE)"
    FAIL=$((FAIL + 1))
  else
    echo -e "  ${GREEN}✅ SECURE${NC} — Self-promotion to PLATINUM rejected (HTTP $HTTP_CODE)"
    PASS=$((PASS + 1))
  fi
else
  echo -e "  ${YELLOW}⚠️  SKIP${NC} — Could not determine User A ID"
  WARN=$((WARN + 1))
fi

# ── 2. Normal user updates ANOTHER user's tier ───────────────────────────────
echo -e "\n${CYAN}[2/7] PUT /api/v1/users/{id}/tier — User A promotes User B${NC}"
if [ -n "$USER_B_ID" ] && [ "$USER_B_ID" != "null" ]; then
  RESPONSE=$(curl -s -w "\n%{http_code}" -X PUT "$BASE_URL/api/v1/users/$USER_B_ID/tier" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN_A" \
    -d '{"tier": "PLATINUM"}')
  HTTP_CODE=$(echo "$RESPONSE" | tail -1)
  BODY=$(echo "$RESPONSE" | head -1)
  if [ "$HTTP_CODE" -eq 200 ]; then
    echo -e "  ${RED}❌ VULNERABLE${NC} — User A promoted User B (HTTP $HTTP_CODE)"
    FAIL=$((FAIL + 1))
  else
    echo -e "  ${GREEN}✅ SECURE${NC} — Cross-user tier promotion rejected (HTTP $HTTP_CODE)"
    PASS=$((PASS + 1))
  fi
else
  echo -e "  ${YELLOW}⚠️  SKIP${NC} — Could not determine User B ID"
  WARN=$((WARN + 1))
fi

print_section "Admin Endpoint Access"

# ── 3. Normal user accesses GET /api/v1/users (ADMIN only) ───────────────────
echo -e "\n${CYAN}[3/7] GET /api/v1/users — Normal user accesses all-users list${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$BASE_URL/api/v1/users" \
  -H "Authorization: Bearer $TOKEN_A")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_blocked "Normal user cannot list all users (ADMIN only)" "$HTTP_CODE" "$BODY"

# ── 4. Normal user accesses outbox monitoring (ADMIN only) ───────────────────
echo -e "\n${CYAN}[4/7] GET /api/admin/outbox/status — Normal user accesses admin endpoint${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$BASE_URL/api/admin/outbox/status" \
  -H "Authorization: Bearer $TOKEN_A")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_blocked "Normal user cannot access admin outbox status" "$HTTP_CODE" "$BODY"

print_section "Internal Endpoint Access"

# ── 5. Normal user calls internal disburse-loan (no API key) ─────────────────
echo -e "\n${CYAN}[5/7] POST /api/v1/transactions/internal/disburse-loan — No API key${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/transactions/internal/disburse-loan" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN_A" \
  -d "{\"accountId\": $ACC_A_ID, \"amount\": 99999.00, \"reason\": \"hacked disbursement\"}")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_blocked "Internal disburse-loan without API key rejected" "$HTTP_CODE" "$BODY"

# ── 6. Normal user calls internal deduct-fee (no API key) ────────────────────
echo -e "\n${CYAN}[6/7] POST /api/v1/transactions/internal/deduct-fee — No API key${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/transactions/internal/deduct-fee" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN_A" \
  -d "{\"accountId\": $ACC_A_ID, \"amount\": 1.00, \"reason\": \"hacked fee\"}")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_blocked "Internal deduct-fee without API key rejected" "$HTTP_CODE" "$BODY"

# ── 7. Unauthenticated access to admin endpoints ─────────────────────────────
echo -e "\n${CYAN}[7/7] GET /api/admin/outbox/status — No token at all${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$BASE_URL/api/admin/outbox/status")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_blocked "Unauthenticated access to admin endpoint rejected" "$HTTP_CODE" "$BODY"

print_summary "Privilege Escalation"

echo "$PASS" > /tmp/sec_module_pass.txt
echo "$FAIL" > /tmp/sec_module_fail.txt
echo "$WARN" > /tmp/sec_module_warn.txt
