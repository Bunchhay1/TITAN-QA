#!/bin/bash
# =============================================================================
# security/run-security.sh — Master security test runner
#
# Runs all 5 security test modules:
#   1. IDOR
#   2. JWT Tampering
#   3. SQL Injection
#   4. Brute Force
#   5. Privilege Escalation
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_WARN=0
FAILED_MODULES=()
WARNED_MODULES=()

# ── Helper: run a module ──────────────────────────────────────────────────────
run_module() {
  local name="$1"
  local script="$2"

  echo ""
  echo -e "${BOLD}${YELLOW}▶ Running Security Module: $name${NC}"

  if [ ! -f "$script" ]; then
    echo -e "${RED}  ❌ Script not found: $script${NC}"
    return
  fi

  chmod +x "$script"
  bash "$script"

  M_PASS=$(cat /tmp/sec_module_pass.txt 2>/dev/null || echo 0)
  M_FAIL=$(cat /tmp/sec_module_fail.txt 2>/dev/null || echo 0)
  M_WARN=$(cat /tmp/sec_module_warn.txt 2>/dev/null || echo 0)

  TOTAL_PASS=$((TOTAL_PASS + M_PASS))
  TOTAL_FAIL=$((TOTAL_FAIL + M_FAIL))
  TOTAL_WARN=$((TOTAL_WARN + M_WARN))

  [ "$M_FAIL" -gt 0 ] && FAILED_MODULES+=("$name ($M_FAIL vulnerabilities)")
  [ "$M_WARN" -gt 0 ] && WARNED_MODULES+=("$name ($M_WARN warnings)")

  rm -f /tmp/sec_module_pass.txt /tmp/sec_module_fail.txt /tmp/sec_module_warn.txt
}

# ── Banner ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${MAGENTA}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}${BOLD}║   🛡️  TITAN BANK — SECURITY TEST SUITE          ║${NC}"
echo -e "${MAGENTA}${BOLD}║   $(date '+%Y-%m-%d %H:%M:%S')                         ║${NC}"
echo -e "${MAGENTA}${BOLD}╚══════════════════════════════════════════════════╝${NC}"

# ── Health check ─────────────────────────────────────────────────────────────
echo -e "\n${CYAN}🔍 Checking if Titan Bank is running at $BASE_URL...${NC}"
HEALTH=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$BASE_URL/actuator/health" 2>/dev/null)
HEALTH2=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$BASE_URL/test-connection" 2>/dev/null)

if [ "$HEALTH" = "200" ] || [ "$HEALTH2" = "200" ]; then
  echo -e "${GREEN}  ✅ Server is UP${NC}"
else
  echo -e "${RED}  ❌ Server is not running at $BASE_URL. Start IntelliJ first.${NC}"
  exit 1
fi

chmod +x "$SCRIPT_DIR"/**/*.sh 2>/dev/null

# ── Run all modules ───────────────────────────────────────────────────────────
run_module "IDOR"                    "$SCRIPT_DIR/idor/test-idor.sh"
run_module "JWT Tampering"           "$SCRIPT_DIR/jwt-tampering/test-jwt-tampering.sh"
run_module "SQL Injection"           "$SCRIPT_DIR/sql-injection/test-sql-injection.sh"
run_module "Brute Force"             "$SCRIPT_DIR/brute-force/test-brute-force.sh"
run_module "Privilege Escalation"    "$SCRIPT_DIR/privilege-escalation/test-privilege-escalation.sh"

# ── Final Report ─────────────────────────────────────────────────────────────
TOTAL=$((TOTAL_PASS + TOTAL_FAIL + TOTAL_WARN))

echo ""
echo -e "${MAGENTA}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}${BOLD}║        🛡️  SECURITY TEST RESULTS                 ║${NC}"
echo -e "${MAGENTA}${BOLD}╠══════════════════════════════════════════════════╣${NC}"
echo -e "${BOLD}║  Total Checks  : $TOTAL${NC}"
echo -e "${GREEN}${BOLD}║  ✅ Secure     : $TOTAL_PASS${NC}"
echo -e "${RED}${BOLD}║  ❌ Vulnerable : $TOTAL_FAIL${NC}"
echo -e "${YELLOW}${BOLD}║  ⚠️  Warnings  : $TOTAL_WARN${NC}"

if [ ${#FAILED_MODULES[@]} -gt 0 ]; then
  echo -e "${MAGENTA}${BOLD}╠══════════════════════════════════════════════════╣${NC}"
  echo -e "${RED}${BOLD}║  🚨 VULNERABILITIES FOUND:${NC}"
  for m in "${FAILED_MODULES[@]}"; do
    echo -e "${RED}║    • $m${NC}"
  done
fi

if [ ${#WARNED_MODULES[@]} -gt 0 ]; then
  echo -e "${MAGENTA}${BOLD}╠══════════════════════════════════════════════════╣${NC}"
  echo -e "${YELLOW}${BOLD}║  ⚠️  WARNINGS (improve security):${NC}"
  for m in "${WARNED_MODULES[@]}"; do
    echo -e "${YELLOW}║    • $m${NC}"
  done
fi

echo -e "${MAGENTA}${BOLD}╚══════════════════════════════════════════════════╝${NC}"

# ── Cleanup temp files ────────────────────────────────────────────────────────
rm -f "$SEC_TOKEN_A" "$SEC_TOKEN_B" \
      "$SEC_ACCOUNT_A" "$SEC_ACCOUNT_B" "$SEC_ACCOUNT_A_ID"

echo -e "\n${CYAN}🧹 Temp files cleaned up.${NC}"

if [ "$TOTAL_FAIL" -eq 0 ]; then
  echo -e "\n${GREEN}${BOLD}🎉 No vulnerabilities found!${NC}\n"
  exit 0
else
  echo -e "\n${RED}${BOLD}🚨 $TOTAL_FAIL vulnerability/vulnerabilities found — fix immediately!${NC}\n"
  exit 1
fi
