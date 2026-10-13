#!/bin/bash
# =============================================================================
# edge-cases/run-edge-cases.sh — Master edge case test runner
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_WARN=0
FAILED_MODULES=()
WARNED_MODULES=()

run_module() {
  local name="$1"
  local script="$2"

  echo ""
  echo -e "${BOLD}${YELLOW}▶ Running: $name${NC}"

  chmod +x "$script"
  bash "$script"

  M_PASS=$(cat /tmp/ec_module_pass.txt 2>/dev/null || echo 0)
  M_FAIL=$(cat /tmp/ec_module_fail.txt 2>/dev/null || echo 0)
  M_WARN=$(cat /tmp/ec_module_warn.txt 2>/dev/null || echo 0)

  TOTAL_PASS=$((TOTAL_PASS + M_PASS))
  TOTAL_FAIL=$((TOTAL_FAIL + M_FAIL))
  TOTAL_WARN=$((TOTAL_WARN + M_WARN))

  [ "$M_FAIL" -gt 0 ] && FAILED_MODULES+=("$name ($M_FAIL failures)")
  [ "$M_WARN" -gt 0 ] && WARNED_MODULES+=("$name ($M_WARN warnings)")

  rm -f /tmp/ec_module_pass.txt /tmp/ec_module_fail.txt /tmp/ec_module_warn.txt
}

# ── Banner ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${ORANGE}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${ORANGE}${BOLD}║   🧪 TITAN BANK — EDGE CASE TEST SUITE           ║${NC}"
echo -e "${ORANGE}${BOLD}║   $(date '+%Y-%m-%d %H:%M:%S')                         ║${NC}"
echo -e "${ORANGE}${BOLD}╚══════════════════════════════════════════════════╝${NC}"

# ── Health check ──────────────────────────────────────────────────────────────
echo -e "\n${CYAN}🔍 Checking server at $BASE_URL...${NC}"
HEALTH=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$BASE_URL/actuator/health" 2>/dev/null)
HEALTH2=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$BASE_URL/test-connection" 2>/dev/null)

if [ "$HEALTH" = "200" ] || [ "$HEALTH2" = "200" ]; then
  echo -e "${GREEN}  ✅ Server is UP${NC}"
else
  echo -e "${RED}  ❌ Server not running. Start IntelliJ first.${NC}"
  exit 1
fi

chmod +x "$SCRIPT_DIR"/**/*.sh 2>/dev/null

# ── Run all modules ───────────────────────────────────────────────────────────
run_module "Boundary Values"       "$SCRIPT_DIR/boundary-values/test-boundary-values.sh"
run_module "Missing Fields"        "$SCRIPT_DIR/missing-fields/test-missing-fields.sh"
run_module "Invalid Formats"       "$SCRIPT_DIR/invalid-formats/test-invalid-formats.sh"
run_module "Concurrent Transfer"   "$SCRIPT_DIR/concurrent/test-concurrent-transfer.sh"
run_module "Expired & Reuse"       "$SCRIPT_DIR/expired/test-expired.sh"

# ── Final Report ──────────────────────────────────────────────────────────────
TOTAL=$((TOTAL_PASS + TOTAL_FAIL + TOTAL_WARN))

echo ""
echo -e "${ORANGE}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${ORANGE}${BOLD}║        🧪 EDGE CASE TEST RESULTS                 ║${NC}"
echo -e "${ORANGE}${BOLD}╠══════════════════════════════════════════════════╣${NC}"
echo -e "${BOLD}║  Total Checks : $TOTAL${NC}"
echo -e "${GREEN}${BOLD}║  ✅ Passed    : $TOTAL_PASS${NC}"
echo -e "${RED}${BOLD}║  ❌ Failed    : $TOTAL_FAIL${NC}"
echo -e "${YELLOW}${BOLD}║  ⚠️  Warnings : $TOTAL_WARN${NC}"

if [ ${#FAILED_MODULES[@]} -gt 0 ]; then
  echo -e "${ORANGE}${BOLD}╠══════════════════════════════════════════════════╣${NC}"
  echo -e "${RED}${BOLD}║  Failed Modules:${NC}"
  for m in "${FAILED_MODULES[@]}"; do
    echo -e "${RED}║    • $m${NC}"
  done
fi

if [ ${#WARNED_MODULES[@]} -gt 0 ]; then
  echo -e "${ORANGE}${BOLD}╠══════════════════════════════════════════════════╣${NC}"
  echo -e "${YELLOW}${BOLD}║  Warnings (review behavior):${NC}"
  for m in "${WARNED_MODULES[@]}"; do
    echo -e "${YELLOW}║    • $m${NC}"
  done
fi

echo -e "${ORANGE}${BOLD}╚══════════════════════════════════════════════════╝${NC}"

# ── Cleanup ───────────────────────────────────────────────────────────────────
rm -f "$EC_TOKEN" "$EC_TOKEN2" "$EC_ACCOUNT" "$EC_ACCOUNT2" "$EC_ACCOUNT_ID"
echo -e "\n${CYAN}🧹 Temp files cleaned up.${NC}"

if [ "$TOTAL_FAIL" -eq 0 ]; then
  echo -e "\n${GREEN}${BOLD}🎉 All edge case tests passed!${NC}\n"
  exit 0
else
  echo -e "\n${RED}${BOLD}⚠️  $TOTAL_FAIL test(s) failed — review above.${NC}\n"
  exit 1
fi

# End summary
echo ""
echo "Edge case test run complete."
echo "Timestamp: $(date)"
