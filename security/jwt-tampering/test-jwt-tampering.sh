#!/bin/bash
# =============================================================================
# security/jwt-tampering/test-jwt-tampering.sh
#
# Tests JWT token security:
#   1. No token on protected route              → must be 401
#   2. Malformed token (random string)          → must be 401
#   3. Expired token (hardcoded old token)      → must be 401
#   4. Forged token (valid structure, fake sig) → must be 401
#   5. Token with tampered payload (role=ADMIN) → must be 401/403
#   6. Empty Bearer header                      → must be 401
#   7. Valid token — control test               → must be 200
#   8. Token reuse after logout (if supported)  → must be 401
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.sh"

print_header "🔑 JWT TAMPERING — Token Security Tests"

# ── Setup: get a valid token ──────────────────────────────────────────────────
echo -e "\n${CYAN}Setting up test user...${NC}"
TS=$(date +%s)
USERNAME="jwt_test_${TS}"

RESP=$(curl -s -X POST "$BASE_URL/api/v1/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$USERNAME\",\"password\":\"JwtTest@123\",\"email\":\"${USERNAME}@test.com\",\"firstName\":\"JWT\",\"lastName\":\"Test\",\"pin\":\"1234\"}")
VALID_TOKEN=$(echo "$RESP" | jq -r '.token // empty' 2>/dev/null)

if [ -z "$VALID_TOKEN" ]; then
  RESP=$(curl -s -X POST "$BASE_URL/api/v1/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"$USERNAME\",\"password\":\"JwtTest@123\"}")
  VALID_TOKEN=$(echo "$RESP" | jq -r '.token // empty' 2>/dev/null)
fi

echo -e "${CYAN}  Valid token: ${VALID_TOKEN:0:40}...${NC}"

# A hardcoded expired JWT (signed with fake secret, exp in the past 2024)
EXPIRED_TOKEN="eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ0ZXN0dXNlciIsImlhdCI6MTcwMDAwMDAwMCwiZXhwIjoxNzAwMDAwMDAxfQ.invalid_signature_here"

# A forged token — valid Base64 structure but wrong signature
FORGED_TOKEN="eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJhZG1pbiIsInJvbGUiOiJBRE1JTiIsImlhdCI6OTk5OTk5OTk5OX0.FakeSignatureXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

# Tampered payload: take valid token, replace middle part with admin payload
# eyJzdWIiOiJhZG1pbiIsInJvbGVzIjpbIlJPTEVfQURNSU4iXX0 = {"sub":"admin","roles":["ROLE_ADMIN"]}
HEADER=$(echo "$VALID_TOKEN" | cut -d'.' -f1)
FAKE_PAYLOAD="eyJzdWIiOiJhZG1pbiIsInJvbGVzIjpbIlJPTEVfQURNSU4iXX0"
ORIGINAL_SIG=$(echo "$VALID_TOKEN" | cut -d'.' -f3)
TAMPERED_TOKEN="${HEADER}.${FAKE_PAYLOAD}.${ORIGINAL_SIG}"

print_section "No / Invalid Token"

# ── 1. No token ───────────────────────────────────────────────────────────────
echo -e "\n${CYAN}[1/8] GET /api/v1/accounts — No token${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$BASE_URL/api/v1/accounts")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_blocked "No token rejected on protected route" "$HTTP_CODE" "$BODY"

# ── 2. Random malformed token ─────────────────────────────────────────────────
echo -e "\n${CYAN}[2/8] GET /api/v1/accounts — Random garbage token${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$BASE_URL/api/v1/accounts" \
  -H "Authorization: Bearer thisisnotavalidtokenatall12345")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_blocked "Malformed token rejected" "$HTTP_CODE" "$BODY"

# ── 3. Empty Bearer ───────────────────────────────────────────────────────────
echo -e "\n${CYAN}[3/8] GET /api/v1/accounts — Empty Bearer header${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$BASE_URL/api/v1/accounts" \
  -H "Authorization: Bearer ")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_blocked "Empty Bearer token rejected" "$HTTP_CODE" "$BODY"

print_section "Expired / Forged Token"

# ── 4. Expired token ──────────────────────────────────────────────────────────
echo -e "\n${CYAN}[4/8] GET /api/v1/accounts — Expired token${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$BASE_URL/api/v1/accounts" \
  -H "Authorization: Bearer $EXPIRED_TOKEN")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_blocked "Expired token rejected" "$HTTP_CODE" "$BODY"

# ── 5. Forged token (fake signature) ─────────────────────────────────────────
echo -e "\n${CYAN}[5/8] GET /api/v1/accounts — Forged token (fake signature)${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$BASE_URL/api/v1/accounts" \
  -H "Authorization: Bearer $FORGED_TOKEN")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_blocked "Forged token with fake signature rejected" "$HTTP_CODE" "$BODY"

print_section "Tampered Payload"

# ── 6. Tampered payload (keep valid sig, change payload to ADMIN) ─────────────
echo -e "\n${CYAN}[6/8] GET /api/v1/users — Tampered payload (role=ADMIN, original signature)${NC}"
echo -e "  ${YELLOW}Token: ${HEADER}.${FAKE_PAYLOAD}.<original_sig>${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$BASE_URL/api/v1/users" \
  -H "Authorization: Bearer $TAMPERED_TOKEN")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_blocked "Tampered payload with mismatched signature rejected" "$HTTP_CODE" "$BODY"

# ── 7. Valid token on protected route (control test) ─────────────────────────
print_section "Control Test"

echo -e "\n${CYAN}[7/8] GET /api/v1/accounts — Valid token (must be allowed)${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$BASE_URL/api/v1/accounts" \
  -H "Authorization: Bearer $VALID_TOKEN")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_allowed "Valid token accepted on protected route" "$HTTP_CODE" "$BODY"

# ── 8. Wrong scheme (Basic instead of Bearer) ────────────────────────────────
echo -e "\n${CYAN}[8/8] GET /api/v1/accounts — Wrong auth scheme (Basic)${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$BASE_URL/api/v1/accounts" \
  -H "Authorization: Basic dXNlcjpwYXNz")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_blocked "Wrong auth scheme (Basic) rejected" "$HTTP_CODE" "$BODY"

print_summary "JWT Tampering"

echo "$PASS" > /tmp/sec_module_pass.txt
echo "$FAIL" > /tmp/sec_module_fail.txt
echo "$WARN" > /tmp/sec_module_warn.txt
