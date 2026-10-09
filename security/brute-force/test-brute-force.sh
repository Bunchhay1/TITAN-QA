#!/bin/bash
# =============================================================================
# security/brute-force/test-brute-force.sh
#
# Tests brute force protection:
#   1. Hit /auth/login 20x with wrong password → check if rate limiting kicks in
#   2. Hit /auth/login 20x different usernames → check lockout behavior
#   3. Hit /api/v1/atm/generate with wrong PIN → check account lockout
#   4. Hit /api/v1/transactions/withdraw wrong PIN → check lockout
#   5. Rapid OTP requests → check rate limiting
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.sh"

print_header "🔨 BRUTE FORCE — Rate Limiting & Lockout Tests"

# ── Setup ─────────────────────────────────────────────────────────────────────
echo -e "\n${CYAN}Setting up test user...${NC}"
TS=$(date +%s)
USERNAME="bruteforce_test_${TS}"

RESP=$(curl -s -X POST "$BASE_URL/api/v1/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$USERNAME\",\"password\":\"BruteTest@123\",\"email\":\"${USERNAME}@test.com\",\"firstName\":\"Brute\",\"lastName\":\"Test\",\"pin\":\"1234\"}")
TOKEN=$(echo "$RESP" | jq -r '.token // empty' 2>/dev/null)

if [ -z "$TOKEN" ]; then
  RESP=$(curl -s -X POST "$BASE_URL/api/v1/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"$USERNAME\",\"password\":\"BruteTest@123\"}")
  TOKEN=$(echo "$RESP" | jq -r '.token // empty' 2>/dev/null)
fi

ACC_RESP=$(curl -s -X POST "$BASE_URL/api/v1/accounts" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"accountType":"SAVINGS","currency":"USD","initialDeposit":500.00}')
MY_ACCOUNT=$(echo "$ACC_RESP" | jq -r '.accountNumber // empty' 2>/dev/null)
echo -e "${CYAN}  User: $USERNAME | Account: $MY_ACCOUNT${NC}"

print_section "Login Brute Force (Same User)"

# ── 1. 20 wrong password attempts on same user ────────────────────────────────
echo -e "\n${CYAN}[1/5] POST /api/v1/auth/login — 20 wrong password attempts${NC}"
echo -e "  ${YELLOW}Sending 20 requests with wrong password...${NC}"

RATE_LIMITED=false
BLOCKED_AT=0
ALL_CODES=()

for i in $(seq 1 20); do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/api/v1/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"$USERNAME\",\"password\":\"WrongPass${i}\"}")
  ALL_CODES+=("$CODE")

  if [ "$CODE" -eq 429 ] || [ "$CODE" -eq 423 ] || [ "$CODE" -eq 503 ]; then
    RATE_LIMITED=true
    BLOCKED_AT=$i
    break
  fi
done

echo -e "  ${CYAN}   HTTP codes received: ${ALL_CODES[*]}${NC}"

if $RATE_LIMITED; then
  echo -e "  ${GREEN}✅ SECURE${NC} — Rate limiting triggered at attempt #$BLOCKED_AT (HTTP ${ALL_CODES[$((BLOCKED_AT-1))]})"
  PASS=$((PASS + 1))
else
  # Check if last few attempts returned something different
  LAST_CODE="${ALL_CODES[-1]}"
  if [ "$LAST_CODE" -eq 400 ] || [ "$LAST_CODE" -eq 401 ]; then
    echo -e "  ${YELLOW}⚠️  WARN${NC} — No rate limiting detected after 20 attempts (all HTTP $LAST_CODE)"
    echo -e "  ${YELLOW}   Consider adding Spring Security rate limiting or IP-based throttling${NC}"
    WARN=$((WARN + 1))
  else
    echo -e "  ${RED}❌ VULNERABLE${NC} — No rate limiting, unexpected response: HTTP $LAST_CODE"
    FAIL=$((FAIL + 1))
  fi
fi

print_section "Login Brute Force (Random Usernames)"

# ── 2. 20 attempts with random usernames ─────────────────────────────────────
echo -e "\n${CYAN}[2/5] POST /api/v1/auth/login — 20 attempts with random usernames${NC}"
echo -e "  ${YELLOW}Sending 20 requests with non-existent usernames...${NC}"

RATE_LIMITED2=false
ENUM_VULNERABLE=false
CODES2=()

for i in $(seq 1 20); do
  RESP=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"nonexistent_${i}_${TS}\",\"password\":\"WrongPass\"}")
  CODE=$(echo "$RESP" | tail -1)
  BODY=$(echo "$RESP" | head -1)
  CODES2+=("$CODE")

  # Check if error message reveals whether user exists (enumeration vulnerability)
  MSG=$(echo "$BODY" | jq -r '.message // empty' 2>/dev/null)
  if echo "$MSG" | grep -qi "user not found\|no such user\|username.*not.*exist"; then
    ENUM_VULNERABLE=true
  fi

  if [ "$CODE" -eq 429 ] || [ "$CODE" -eq 423 ]; then
    RATE_LIMITED2=true
    break
  fi
done

if $RATE_LIMITED2; then
  echo -e "  ${GREEN}✅ SECURE${NC} — Rate limiting triggered on random username attempts"
  PASS=$((PASS + 1))
else
  echo -e "  ${YELLOW}⚠️  WARN${NC} — No rate limiting on random username attempts"
  WARN=$((WARN + 1))
fi

if $ENUM_VULNERABLE; then
  echo -e "  ${RED}❌ VULNERABLE${NC} — User enumeration: error message reveals if username exists!"
  FAIL=$((FAIL + 1))
else
  echo -e "  ${GREEN}✅ SECURE${NC} — No user enumeration: generic error messages returned"
  PASS=$((PASS + 1))
fi

print_section "PIN Brute Force"

# ── 3. Wrong PIN on ATM generate (5 attempts) ────────────────────────────────
echo -e "\n${CYAN}[3/5] POST /api/v1/atm/generate — 5 wrong PIN attempts${NC}"
echo -e "  ${YELLOW}Sending 5 requests with wrong PIN...${NC}"

PIN_BLOCKED=false
PIN_CODES=()

for i in $(seq 1 5); do
  WRONG_PIN=$(printf "%04d" $((RANDOM % 10000)))
  # avoid accidentally sending correct pin 1234
  [ "$WRONG_PIN" = "1234" ] && WRONG_PIN="9999"

  CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/api/v1/atm/generate" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d "{\"accountNumber\":\"$MY_ACCOUNT\",\"amount\":50.00,\"pin\":\"$WRONG_PIN\"}")
  PIN_CODES+=("$CODE")

  if [ "$CODE" -eq 429 ] || [ "$CODE" -eq 423 ] || [ "$CODE" -eq 403 ]; then
    PIN_BLOCKED=true
    break
  fi
done

echo -e "  ${CYAN}   HTTP codes: ${PIN_CODES[*]}${NC}"

if $PIN_BLOCKED; then
  echo -e "  ${GREEN}✅ SECURE${NC} — Account locked after repeated wrong PIN attempts"
  PASS=$((PASS + 1))
else
  echo -e "  ${YELLOW}⚠️  WARN${NC} — No PIN lockout detected after 5 wrong attempts"
  echo -e "  ${YELLOW}   Consider adding account lockout after N failed PIN attempts${NC}"
  WARN=$((WARN + 1))
fi

print_section "OTP Rate Limiting"

# ── 4. Rapid OTP requests ─────────────────────────────────────────────────────
echo -e "\n${CYAN}[4/5] POST /api/auth/otp/generate — 10 rapid OTP requests${NC}"
echo -e "  ${YELLOW}Sending 10 rapid OTP generation requests...${NC}"

OTP_RATE_LIMITED=false
OTP_CODES=()

for i in $(seq 1 10); do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/api/auth/otp/generate" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN")
  OTP_CODES+=("$CODE")

  if [ "$CODE" -eq 429 ] || [ "$CODE" -eq 423 ]; then
    OTP_RATE_LIMITED=true
    break
  fi
done

echo -e "  ${CYAN}   HTTP codes: ${OTP_CODES[*]}${NC}"

if $OTP_RATE_LIMITED; then
  echo -e "  ${GREEN}✅ SECURE${NC} — OTP rate limiting triggered"
  PASS=$((PASS + 1))
else
  echo -e "  ${YELLOW}⚠️  WARN${NC} — No OTP rate limiting detected (OTP spam possible)"
  echo -e "  ${YELLOW}   Consider: max 1 OTP per minute per user${NC}"
  WARN=$((WARN + 1))
fi

# ── 5. Wrong PIN on withdraw (5 attempts) ────────────────────────────────────
echo -e "\n${CYAN}[5/5] POST /api/v1/transactions/withdraw — 5 wrong PIN attempts${NC}"
echo -e "  ${YELLOW}Sending 5 withdraw requests with wrong PIN...${NC}"

WITHDRAW_BLOCKED=false
W_CODES=()

for i in $(seq 1 5); do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/api/v1/transactions/withdraw" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d "{\"fromAccountNumber\":\"$MY_ACCOUNT\",\"amount\":10.00,\"pin\":\"0000\",\"note\":\"brute test\"}")
  W_CODES+=("$CODE")

  if [ "$CODE" -eq 429 ] || [ "$CODE" -eq 423 ] || [ "$CODE" -eq 403 ]; then
    WITHDRAW_BLOCKED=true
    break
  fi
done

echo -e "  ${CYAN}   HTTP codes: ${W_CODES[*]}${NC}"

if $WITHDRAW_BLOCKED; then
  echo -e "  ${GREEN}✅ SECURE${NC} — Withdraw locked after repeated wrong PIN"
  PASS=$((PASS + 1))
else
  echo -e "  ${YELLOW}⚠️  WARN${NC} — No lockout after 5 wrong PIN on withdraw"
  echo -e "  ${YELLOW}   Recommend: lock account after 3-5 failed PIN attempts${NC}"
  WARN=$((WARN + 1))
fi

print_summary "Brute Force"

echo "$PASS" > /tmp/sec_module_pass.txt
echo "$FAIL" > /tmp/sec_module_fail.txt
echo "$WARN" > /tmp/sec_module_warn.txt
