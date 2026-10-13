#!/bin/bash
# =============================================================================
# edge-cases/invalid-formats/test-invalid-formats.sh
#
# Tests invalid format rejection:
#   1.  IBAN too short
#   2.  IBAN wrong country prefix (numbers instead of letters)
#   3.  SWIFT too short (< 8 chars)
#   4.  SWIFT too long (> 11 chars)
#   5.  SWIFT lowercase (must be uppercase)
#   6.  Account number too short (< 10 digits)
#   7.  Account number too long (> 16 digits)
#   8.  Account number with letters
#   9.  Email without @ sign
#   10. Email without domain
#   11. PIN too short (< 4 digits)
#   12. PIN with letters
#   13. PIN too long (> 6 digits)
#   14. Non-existent account number (valid format, doesn't exist)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.sh"

print_header "📋 INVALID FORMATS — Input Format Validation Tests"

echo -e "\n${CYAN}Setting up test user...${NC}"
setup_user

TOKEN=$(cat "$EC_TOKEN")
ACC1=$(cat "$EC_ACCOUNT")
ACC2=$(cat "$EC_ACCOUNT2")

print_section "SWIFT & IBAN Format"

# ── 1. IBAN too short ─────────────────────────────────────────────────────────
echo -e "\n${CYAN}[1/14] International transfer — IBAN too short${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/transactions/international" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"fromAccountNumber\":\"$ACC1\",\"amount\":10.00,\"swiftCode\":\"BKCHKHHHXXX\",\"iban\":\"GB82\",\"note\":\"short iban\"}")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_rejected "IBAN too short (GB82 only)" "$HTTP_CODE" "$BODY"

# ── 2. IBAN wrong format (all numbers) ───────────────────────────────────────
echo -e "\n${CYAN}[2/14] International transfer — IBAN starts with numbers${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/transactions/international" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"fromAccountNumber\":\"$ACC1\",\"amount\":10.00,\"swiftCode\":\"BKCHKHHHXXX\",\"iban\":\"1234567890123456\",\"note\":\"numeric iban\"}")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_rejected "IBAN with no country prefix" "$HTTP_CODE" "$BODY"

# ── 3. SWIFT too short ────────────────────────────────────────────────────────
echo -e "\n${CYAN}[3/14] International transfer — SWIFT too short (< 8 chars)${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/transactions/international" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"fromAccountNumber\":\"$ACC1\",\"amount\":10.00,\"swiftCode\":\"BKCH\",\"iban\":\"GB82WEST12345698765432\",\"note\":\"short swift\"}")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_rejected "SWIFT too short (4 chars)" "$HTTP_CODE" "$BODY"

# ── 4. SWIFT too long ─────────────────────────────────────────────────────────
echo -e "\n${CYAN}[4/14] International transfer — SWIFT too long (> 11 chars)${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/transactions/international" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"fromAccountNumber\":\"$ACC1\",\"amount\":10.00,\"swiftCode\":\"BKCHKHHHXXXABC\",\"iban\":\"GB82WEST12345698765432\",\"note\":\"long swift\"}")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_rejected "SWIFT too long (14 chars)" "$HTTP_CODE" "$BODY"

# ── 5. SWIFT lowercase ────────────────────────────────────────────────────────
echo -e "\n${CYAN}[5/14] International transfer — SWIFT lowercase${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/transactions/international" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"fromAccountNumber\":\"$ACC1\",\"amount\":10.00,\"swiftCode\":\"bkchkhhhxxx\",\"iban\":\"GB82WEST12345698765432\",\"note\":\"lowercase swift\"}")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_rejected "SWIFT lowercase (must be uppercase)" "$HTTP_CODE" "$BODY"

print_section "Account Number Format"

# ── 6. Account number too short (< 10 digits) ────────────────────────────────
echo -e "\n${CYAN}[6/14] Transfer — account number too short (< 10 digits)${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/transactions/transfer" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"fromAccountNumber\":\"123\",\"toAccountNumber\":\"$ACC2\",\"amount\":10.00,\"pin\":\"1234\",\"note\":\"short account\"}")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_rejected "Account number too short (3 digits)" "$HTTP_CODE" "$BODY"

# ── 7. Account number too long (> 16 digits) ──────────────────────────────────
echo -e "\n${CYAN}[7/14] Transfer — account number too long (> 16 digits)${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/transactions/transfer" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"fromAccountNumber\":\"12345678901234567\",\"toAccountNumber\":\"$ACC2\",\"amount\":10.00,\"pin\":\"1234\",\"note\":\"long account\"}")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_rejected "Account number too long (17 digits)" "$HTTP_CODE" "$BODY"

# ── 8. Account number with letters ───────────────────────────────────────────
echo -e "\n${CYAN}[8/14] Transfer — account number with letters${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/transactions/transfer" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"fromAccountNumber\":\"ABCD1234567\",\"toAccountNumber\":\"$ACC2\",\"amount\":10.00,\"pin\":\"1234\",\"note\":\"letters in account\"}")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_rejected "Account number with letters" "$HTTP_CODE" "$BODY"

print_section "Email & PIN Format"

# ── 9. Email without @ ────────────────────────────────────────────────────────
echo -e "\n${CYAN}[9/14] Register — email without @${NC}"
TS=$(date +%s)
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"emailtest_${TS}\",\"password\":\"Test@123\",\"email\":\"notanemail\",\"firstName\":\"Bad\",\"lastName\":\"Email\",\"pin\":\"1234\"}")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_rejected "Email without @ symbol" "$HTTP_CODE" "$BODY"

# ── 10. Email without domain ──────────────────────────────────────────────────
echo -e "\n${CYAN}[10/14] Register — email without domain${NC}"
TS2=$((TS + 1))
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"emailtest2_${TS2}\",\"password\":\"Test@123\",\"email\":\"user@\",\"firstName\":\"Bad\",\"lastName\":\"Email2\",\"pin\":\"1234\"}")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_rejected "Email without domain (user@)" "$HTTP_CODE" "$BODY"

# ── 11. PIN too short (< 4 digits) ───────────────────────────────────────────
echo -e "\n${CYAN}[11/14] ATM generate — PIN too short (< 4 digits)${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/atm/generate" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"accountNumber\":\"$ACC1\",\"amount\":50.00,\"pin\":\"12\"}")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_rejected "PIN too short (2 digits)" "$HTTP_CODE" "$BODY"

# ── 12. PIN with letters ──────────────────────────────────────────────────────
echo -e "\n${CYAN}[12/14] Transfer — PIN with letters${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/transactions/transfer" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"fromAccountNumber\":\"$ACC1\",\"toAccountNumber\":\"$ACC2\",\"amount\":10.00,\"pin\":\"abcd\",\"note\":\"alpha pin\"}")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_rejected "PIN with letters (abcd)" "$HTTP_CODE" "$BODY"

# ── 13. PIN too long (> 6 digits) ────────────────────────────────────────────
echo -e "\n${CYAN}[13/14] ATM generate — PIN too long (> 6 digits)${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/atm/generate" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"accountNumber\":\"$ACC1\",\"amount\":50.00,\"pin\":\"1234567\"}")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_rejected "PIN too long (7 digits)" "$HTTP_CODE" "$BODY"

print_section "Non-existent Resources"

# ── 14. Transfer to valid-format but non-existent account ────────────────────
echo -e "\n${CYAN}[14/14] Transfer — valid format account number that doesn't exist${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/transactions/transfer" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"fromAccountNumber\":\"$ACC1\",\"toAccountNumber\":\"9999999999\",\"amount\":10.00,\"pin\":\"1234\",\"note\":\"ghost account\"}")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
TX_STATUS=$(echo "$BODY" | jq -r '.status // empty' 2>/dev/null)
if [ "$HTTP_CODE" -ge 400 ] || [ "$TX_STATUS" = "FAILED" ]; then
  echo -e "  ${GREEN}✅ PASS${NC} — Non-existent account rejected (HTTP $HTTP_CODE, status=$TX_STATUS)"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}❌ FAIL${NC} — Transfer to non-existent account succeeded!"
  FAIL=$((FAIL + 1))
fi

print_summary "Invalid Formats"

echo "$PASS" > /tmp/ec_module_pass.txt
echo "$FAIL" > /tmp/ec_module_fail.txt
echo "$WARN" > /tmp/ec_module_warn.txt
