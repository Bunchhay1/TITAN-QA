#!/bin/bash
# =============================================================================
# edge-cases/missing-fields/test-missing-fields.sh
#
# Tests that required fields are properly validated:
#   1.  Register — no username
#   2.  Register — no password
#   3.  Register — no email
#   4.  Register — empty body {}
#   5.  Login — no username
#   6.  Login — no password
#   7.  Transfer — no fromAccountNumber
#   8.  Transfer — no toAccountNumber
#   9.  Transfer — no amount
#   10. Transfer — no pin
#   11. Deposit — no toAccountNumber
#   12. QR generate — no payeeAccountNumber
#   13. ATM generate — no accountNumber
#   14. ATM generate — no amount
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.sh"

print_header "🚫 MISSING FIELDS — Required Field Validation Tests"

echo -e "\n${CYAN}Setting up test user...${NC}"
setup_user

TOKEN=$(cat "$EC_TOKEN")
ACC1=$(cat "$EC_ACCOUNT")
ACC2=$(cat "$EC_ACCOUNT2")

print_section "Register Missing Fields"

# ── 1. Register — no username ─────────────────────────────────────────────────
echo -e "\n${CYAN}[1/14] Register — no username${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"password\":\"Test@123\",\"email\":\"test@test.com\",\"firstName\":\"No\",\"lastName\":\"Username\",\"pin\":\"1234\"}")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_rejected "Register without username" "$HTTP_CODE" "$BODY"

# ── 2. Register — no password ─────────────────────────────────────────────────
echo -e "\n${CYAN}[2/14] Register — no password${NC}"
TS=$(date +%s)
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"nopass_${TS}\",\"email\":\"nopass@test.com\",\"firstName\":\"No\",\"lastName\":\"Pass\",\"pin\":\"1234\"}")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_rejected "Register without password" "$HTTP_CODE" "$BODY"

# ── 3. Register — empty body ──────────────────────────────────────────────────
echo -e "\n${CYAN}[3/14] Register — empty body {}${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/auth/register" \
  -H "Content-Type: application/json" \
  -d "{}")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_rejected "Register with empty body" "$HTTP_CODE" "$BODY"

print_section "Login Missing Fields"

# ── 4. Login — no username ────────────────────────────────────────────────────
echo -e "\n${CYAN}[4/14] Login — no username${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"password\":\"Test@123\"}")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_rejected "Login without username" "$HTTP_CODE" "$BODY"

# ── 5. Login — no password ────────────────────────────────────────────────────
echo -e "\n${CYAN}[5/14] Login — no password${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"someuser\"}")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_rejected "Login without password" "$HTTP_CODE" "$BODY"

print_section "Transaction Missing Fields"

# ── 6. Transfer — no fromAccountNumber ───────────────────────────────────────
echo -e "\n${CYAN}[6/14] Transfer — no fromAccountNumber${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/transactions/transfer" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"toAccountNumber\":\"$ACC2\",\"amount\":10.00,\"pin\":\"1234\",\"note\":\"missing from\"}")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_rejected "Transfer without fromAccountNumber" "$HTTP_CODE" "$BODY"

# ── 7. Transfer — no toAccountNumber ─────────────────────────────────────────
echo -e "\n${CYAN}[7/14] Transfer — no toAccountNumber${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/transactions/transfer" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"fromAccountNumber\":\"$ACC1\",\"amount\":10.00,\"pin\":\"1234\",\"note\":\"missing to\"}")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_rejected "Transfer without toAccountNumber" "$HTTP_CODE" "$BODY"

# ── 8. Transfer — no amount ───────────────────────────────────────────────────
echo -e "\n${CYAN}[8/14] Transfer — no amount${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/transactions/transfer" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"fromAccountNumber\":\"$ACC1\",\"toAccountNumber\":\"$ACC2\",\"pin\":\"1234\",\"note\":\"missing amount\"}")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_rejected "Transfer without amount" "$HTTP_CODE" "$BODY"

# ── 9. Transfer — no pin ──────────────────────────────────────────────────────
echo -e "\n${CYAN}[9/14] Transfer — no pin${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/transactions/transfer" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"fromAccountNumber\":\"$ACC1\",\"toAccountNumber\":\"$ACC2\",\"amount\":10.00,\"note\":\"missing pin\"}")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_rejected "Transfer without PIN" "$HTTP_CODE" "$BODY"

# ── 10. Deposit — no toAccountNumber ─────────────────────────────────────────
echo -e "\n${CYAN}[10/14] Deposit — no toAccountNumber${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/transactions/deposit" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"amount\":100.00,\"note\":\"missing account\"}")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_rejected "Deposit without toAccountNumber" "$HTTP_CODE" "$BODY"

print_section "QR & ATM Missing Fields"

# ── 11. QR generate — no payeeAccountNumber ───────────────────────────────────
echo -e "\n${CYAN}[11/14] QR generate — no payeeAccountNumber${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/qr/generate" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"amount\":50.00,\"note\":\"missing account\",\"ttlMinutes\":15}")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_rejected "QR generate without payeeAccountNumber" "$HTTP_CODE" "$BODY"

# ── 12. ATM generate — no accountNumber ───────────────────────────────────────
echo -e "\n${CYAN}[12/14] ATM generate — no accountNumber${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/atm/generate" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"amount\":50.00,\"pin\":\"1234\"}")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_rejected "ATM generate without accountNumber" "$HTTP_CODE" "$BODY"

# ── 13. ATM generate — no amount ─────────────────────────────────────────────
echo -e "\n${CYAN}[13/14] ATM generate — no amount${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/atm/generate" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"accountNumber\":\"$ACC1\",\"pin\":\"1234\"}")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_rejected "ATM generate without amount" "$HTTP_CODE" "$BODY"

# ── 14. ATM generate — no pin ────────────────────────────────────────────────
echo -e "\n${CYAN}[14/14] ATM generate — no pin${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/atm/generate" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"accountNumber\":\"$ACC1\",\"amount\":50.00}")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_rejected "ATM generate without PIN" "$HTTP_CODE" "$BODY"

print_summary "Missing Fields"

echo "$PASS" > /tmp/ec_module_pass.txt
echo "$FAIL" > /tmp/ec_module_fail.txt
echo "$WARN" > /tmp/ec_module_warn.txt
