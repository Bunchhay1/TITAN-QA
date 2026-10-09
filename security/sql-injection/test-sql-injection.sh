#!/bin/bash
# =============================================================================
# security/sql-injection/test-sql-injection.sh
#
# Tests SQL injection resistance across all input fields:
#   1. Login username field                    → must not return token
#   2. Login password field                    → must not return token
#   3. Account number in transfer              → must be 400/403
#   4. Account number in path param            → must be 400/404
#   5. Note field in transaction               → must sanitize safely
#   6. UNION injection in account number       → must be 400
#   7. Blind boolean injection in path         → must be 400
#   8. SQL in register username                → must not cause 500
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.sh"

print_header "💉 SQL INJECTION — Input Validation Tests"

# ── Setup ─────────────────────────────────────────────────────────────────────
echo -e "\n${CYAN}Setting up test user...${NC}"
TS=$(date +%s)
USERNAME="sqli_test_${TS}"

RESP=$(curl -s -X POST "$BASE_URL/api/v1/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$USERNAME\",\"password\":\"SqliTest@123\",\"email\":\"${USERNAME}@test.com\",\"firstName\":\"SQL\",\"lastName\":\"Test\",\"pin\":\"1234\"}")
TOKEN=$(echo "$RESP" | jq -r '.token // empty' 2>/dev/null)

if [ -z "$TOKEN" ]; then
  RESP=$(curl -s -X POST "$BASE_URL/api/v1/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"$USERNAME\",\"password\":\"SqliTest@123\"}")
  TOKEN=$(echo "$RESP" | jq -r '.token // empty' 2>/dev/null)
fi

ACC_RESP=$(curl -s -X POST "$BASE_URL/api/v1/accounts" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"accountType":"SAVINGS","currency":"USD","initialDeposit":1000.00}')
MY_ACCOUNT=$(echo "$ACC_RESP" | jq -r '.accountNumber // empty' 2>/dev/null)
echo -e "${CYAN}  Token ready | Account: $MY_ACCOUNT${NC}"

print_section "Auth Endpoint Injection"

# ── 1. SQL in login username ──────────────────────────────────────────────────
echo -e "\n${CYAN}[1/8] POST /api/v1/auth/login — SQL in username${NC}"
echo -e "  ${YELLOW}Payload: ' OR '1'='1${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"' OR '1'='1\",\"password\":\"anything\"}")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
HAS_TOKEN=$(echo "$BODY" | jq -r '.token // empty' 2>/dev/null)
if [ -n "$HAS_TOKEN" ] && [ "$HAS_TOKEN" != "null" ]; then
  echo -e "  ${RED}❌ VULNERABLE${NC} — SQL injection returned a valid token!"
  FAIL=$((FAIL + 1))
else
  assert_blocked "SQL injection in login username rejected" "$HTTP_CODE" "$BODY"
fi

# ── 2. SQL in login password ──────────────────────────────────────────────────
echo -e "\n${CYAN}[2/8] POST /api/v1/auth/login — SQL in password${NC}"
echo -e "  ${YELLOW}Payload: ' OR 1=1 --${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"admin\",\"password\":\"' OR 1=1 --\"}")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
HAS_TOKEN=$(echo "$BODY" | jq -r '.token // empty' 2>/dev/null)
if [ -n "$HAS_TOKEN" ] && [ "$HAS_TOKEN" != "null" ]; then
  echo -e "  ${RED}❌ VULNERABLE${NC} — SQL injection in password returned a token!"
  FAIL=$((FAIL + 1))
else
  assert_blocked "SQL injection in login password rejected" "$HTTP_CODE" "$BODY"
fi

print_section "Transaction Field Injection"

# ── 3. SQL in account number (transfer) ──────────────────────────────────────
echo -e "\n${CYAN}[3/8] POST /api/v1/transactions/transfer — SQL in account number${NC}"
echo -e "  ${YELLOW}Payload: 1'; DROP TABLE accounts; --${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/transactions/transfer" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{
    \"fromAccountNumber\": \"1'; DROP TABLE accounts; --\",
    \"toAccountNumber\": \"$MY_ACCOUNT\",
    \"amount\": 1.00,
    \"pin\": \"1234\",
    \"note\": \"sqli test\"
  }")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_blocked "DROP TABLE injection in account number rejected" "$HTTP_CODE" "$BODY"

# ── 4. SQL in path param ──────────────────────────────────────────────────────
echo -e "\n${CYAN}[4/8] GET /api/v1/accounts/{id} — SQL in path parameter${NC}"
echo -e "  ${YELLOW}Payload: 1 OR 1=1${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$BASE_URL/api/v1/accounts/1%20OR%201%3D1" \
  -H "Authorization: Bearer $TOKEN")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_blocked "SQL injection in path param rejected" "$HTTP_CODE" "$BODY"

# ── 5. SQL in note field (free text — should store safely) ────────────────────
echo -e "\n${CYAN}[5/8] POST /api/v1/transactions/deposit — SQL in note field${NC}"
echo -e "  ${YELLOW}Payload: '); INSERT INTO users VALUES('hacked','hacked'); --${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/transactions/deposit" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{
    \"toAccountNumber\": \"$MY_ACCOUNT\",
    \"amount\": 1.00,
    \"note\": \"'); INSERT INTO users VALUES('hacked','hacked'); --\"
  }")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
if [ "$HTTP_CODE" -eq 500 ]; then
  echo -e "  ${RED}❌ VULNERABLE${NC} — SQL in note caused HTTP 500 (possible injection!)"
  FAIL=$((FAIL + 1))
else
  echo -e "  ${GREEN}✅ SECURE${NC} — SQL in note handled safely (HTTP $HTTP_CODE — parameterized query)"
  PASS=$((PASS + 1))
fi

print_section "Advanced Injection"

# ── 6. UNION injection ────────────────────────────────────────────────────────
echo -e "\n${CYAN}[6/8] POST /api/v1/transactions/transfer — UNION injection${NC}"
echo -e "  ${YELLOW}Payload: 1 UNION SELECT username,password FROM users --${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/transactions/transfer" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{
    \"fromAccountNumber\": \"1 UNION SELECT username,password FROM users --\",
    \"toAccountNumber\": \"$MY_ACCOUNT\",
    \"amount\": 1.00,
    \"pin\": \"1234\",
    \"note\": \"union test\"
  }")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_blocked "UNION injection rejected" "$HTTP_CODE" "$BODY"

# ── 7. Blind boolean injection ────────────────────────────────────────────────
echo -e "\n${CYAN}[7/8] GET /api/v1/accounts/{id} — Blind boolean injection${NC}"
echo -e "  ${YELLOW}Payload: 1 AND 1=1${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$BASE_URL/api/v1/accounts/1%20AND%201%3D1" \
  -H "Authorization: Bearer $TOKEN")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
assert_blocked "Blind boolean injection rejected" "$HTTP_CODE" "$BODY"

# ── 8. SQL in register username ───────────────────────────────────────────────
echo -e "\n${CYAN}[8/8] POST /api/v1/auth/register — SQL injection in username${NC}"
echo -e "  ${YELLOW}Payload: admin'--${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/auth/register" \
  -H "Content-Type: application/json" \
  -d "{
    \"username\": \"admin'--\",
    \"password\": \"Test@123\",
    \"email\": \"sqli2@test.com\",
    \"firstName\": \"SQL\",
    \"lastName\": \"Inject\",
    \"pin\": \"1234\"
  }")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
if [ "$HTTP_CODE" -eq 500 ]; then
  echo -e "  ${RED}❌ VULNERABLE${NC} — SQL in register username caused HTTP 500!"
  FAIL=$((FAIL + 1))
else
  echo -e "  ${GREEN}✅ SECURE${NC} — SQL in register username handled safely (HTTP $HTTP_CODE)"
  PASS=$((PASS + 1))
fi

print_summary "SQL Injection"

echo "$PASS" > /tmp/sec_module_pass.txt
echo "$FAIL" > /tmp/sec_module_fail.txt
echo "$WARN" > /tmp/sec_module_warn.txt
