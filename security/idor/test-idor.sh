#!/bin/bash
# =============================================================================
# security/idor/test-idor.sh
#
# IDOR = Insecure Direct Object Reference
# Tests whether User A can access or modify User B's resources
# by guessing/knowing User B's account ID, statement, or ATM code.
#
# Tests:
#   1. User B reads User A's account by ID              → must be 403
#   2. User B reads User A's statement PDF              → must be 403
#   3. User B reads User A's QR history                 → must be 403
#   4. User B reads User A's ATM code status            → must be 403
#   5. User B cancels User A's ATM code                 → must be 403
#   6. User B accesses User A's permanent account QR    → must be 403
#   7. User A reads own account (control test)          → must be 200
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.sh"

print_header "🔍 IDOR — Insecure Direct Object Reference Tests"

# ── Setup two users ───────────────────────────────────────────────────────────
echo -e "\n${CYAN}Setting up two independent users...${NC}"
setup_two_users

TOKEN_A=$(cat "$SEC_TOKEN_A")
TOKEN_B=$(cat "$SEC_TOKEN_B")
ACC_A=$(cat "$SEC_ACCOUNT_A")
ACC_A_ID=$(cat "$SEC_ACCOUNT_A_ID")
ACC_B=$(cat "$SEC_ACCOUNT_B")

if [ -z "$TOKEN_A" ] || [ -z "$TOKEN_B" ]; then
  echo -e "${RED}❌ Setup failed — could not create test users${NC}"
  exit 1
fi

# ── Generate ATM code for User A (for ATM IDOR tests) ────────────────────────
ATM_RESP=$(curl -s -X POST "$BASE_URL/api/v1/atm/generate" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN_A" \
  -d "{\"accountNumber\":\"$ACC_A\",\"amount\":50.00,\"pin\":\"1234\"}")
ATM_CODE=$(echo "$ATM_RESP" | jq -r '.atmCode // .code // empty' 2>/dev/null)
echo -e "${CYAN}  User A ATM code: $ATM_CODE${NC}"

print_section "Account IDOR"

# ── 1. User B reads User A's account by ID ───────────────────────────────────
echo -e "\n${CYAN}[1/7] User B tries to read User A's account (ID: $ACC_A_ID)${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$BASE_URL/api/v1/accounts/$ACC_A_ID" \
  -H "Authorization: Bearer $TOKEN_B")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_blocked "User B cannot read User A's account by ID" "$HTTP_CODE" "$BODY"

# ── 2. User A reads own account (control — must pass) ────────────────────────
echo -e "\n${CYAN}[2/7] User A reads own account (control test — must be allowed)${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$BASE_URL/api/v1/accounts/$ACC_A_ID" \
  -H "Authorization: Bearer $TOKEN_A")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_allowed "User A can read own account" "$HTTP_CODE" "$BODY"

print_section "Statement IDOR"

# ── 3. User B downloads User A's statement PDF ───────────────────────────────
echo -e "\n${CYAN}[3/7] User B tries to download User A's statement (accountId: $ACC_A_ID)${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$BASE_URL/api/v1/statements/$ACC_A_ID/pdf" \
  -H "Authorization: Bearer $TOKEN_B")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_blocked "User B cannot download User A's statement" "$HTTP_CODE" "$BODY"

print_section "QR Payment IDOR"

# ── 4. User B reads User A's QR payment history ──────────────────────────────
echo -e "\n${CYAN}[4/7] User B tries to read User A's QR history (account: $ACC_A)${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$BASE_URL/api/v1/qr/history/$ACC_A" \
  -H "Authorization: Bearer $TOKEN_B")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_blocked "User B cannot read User A's QR history" "$HTTP_CODE" "$BODY"

# ── 5. User B reads User A's permanent account QR ────────────────────────────
echo -e "\n${CYAN}[5/7] User B tries to get User A's permanent account QR (account: $ACC_A)${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$BASE_URL/api/v1/qr/account/$ACC_A" \
  -H "Authorization: Bearer $TOKEN_B")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_blocked "User B cannot access User A's permanent QR" "$HTTP_CODE" "$BODY"

print_section "ATM Code IDOR"

# ── 6. User B checks status of User A's ATM code ─────────────────────────────
if [ -n "$ATM_CODE" ]; then
  echo -e "\n${CYAN}[6/7] User B tries to check status of User A's ATM code ($ATM_CODE)${NC}"
  RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$BASE_URL/api/v1/atm/status/$ATM_CODE" \
    -H "Authorization: Bearer $TOKEN_B")
  HTTP_CODE=$(echo "$RESPONSE" | tail -1)
  BODY=$(echo "$RESPONSE" | head -1)
  assert_blocked "User B cannot check status of User A's ATM code" "$HTTP_CODE" "$BODY"

  # ── 7. User B cancels User A's ATM code ──────────────────────────────────────
  echo -e "\n${CYAN}[7/7] User B tries to cancel User A's ATM code ($ATM_CODE)${NC}"
  RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE "$BASE_URL/api/v1/atm/cancel/$ATM_CODE" \
    -H "Authorization: Bearer $TOKEN_B")
  HTTP_CODE=$(echo "$RESPONSE" | tail -1)
  BODY=$(echo "$RESPONSE" | head -1)
  assert_blocked "User B cannot cancel User A's ATM code" "$HTTP_CODE" "$BODY"
else
  echo -e "\n${YELLOW}[6-7/7] Skipping ATM IDOR — ATM code generation failed${NC}"
fi

print_summary "IDOR"

# Save counters for run-security.sh
echo "$PASS" > /tmp/sec_module_pass.txt
echo "$FAIL" > /tmp/sec_module_fail.txt
echo "$WARN" > /tmp/sec_module_warn.txt
