#!/bin/bash
# =============================================================================
# run-all.sh — Master test runner for Titan Bank API
#
# Runs all test modules in order:
#   1. Auth
#   2. Accounts
#   3. Transactions
#   4. QR Payment
#   5. ATM Cardless
#   6. Loans
#   7. OTP + Fixed Deposit + Scheduled Transactions
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils/config.sh"

TOTAL_PASS=0
TOTAL_FAIL=0
FAILED_MODULES=()

# ── Helper: run a module and collect results ──────────────────────────────────
run_module() {
  local name="$1"
  local script="$2"

  echo ""
  echo -e "${BOLD}${YELLOW}▶ Running: $name${NC}"

  if [ ! -f "$script" ]; then
    echo -e "${RED}  ❌ Script not found: $script${NC}"
    FAILED_MODULES+=("$name (script missing)")
    return
  fi

  chmod +x "$script"
  bash "$script"
  EXIT_CODE=$?

  # Read pass/fail from temp counters written by each script
  MODULE_PASS=$(cat /tmp/titan_module_pass.txt 2>/dev/null || echo 0)
  MODULE_FAIL=$(cat /tmp/titan_module_fail.txt 2>/dev/null || echo 0)

  TOTAL_PASS=$((TOTAL_PASS + MODULE_PASS))
  TOTAL_FAIL=$((TOTAL_FAIL + MODULE_FAIL))

  if [ "$MODULE_FAIL" -gt 0 ]; then
    FAILED_MODULES+=("$name ($MODULE_FAIL failures)")
  fi

  rm -f /tmp/titan_module_pass.txt /tmp/titan_module_fail.txt
}

# ── Banner ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${BLUE}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${BLUE}║     🏦 TITAN BANK API — FULL TEST SUITE          ║${NC}"
echo -e "${BOLD}${BLUE}║     $(date '+%Y-%m-%d %H:%M:%S')                         ║${NC}"
echo -e "${BOLD}${BLUE}╚══════════════════════════════════════════════════╝${NC}"

# ── Health check before running tests ────────────────────────────────────────
echo -e "\n${CYAN}🔍 Checking if Titan Bank is running at $BASE_URL...${NC}"
HEALTH=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$BASE_URL/actuator/health" 2>/dev/null)
if [ "$HEALTH" = "200" ]; then
  echo -e "${GREEN}  ✅ Server is UP (HTTP 200)${NC}"
else
  # Also try /test-connection as fallback
  HEALTH2=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$BASE_URL/test-connection" 2>/dev/null)
  if [ "$HEALTH2" = "200" ]; then
    echo -e "${GREEN}  ✅ Server is UP (HTTP 200)${NC}"
  else
    echo -e "${RED}  ❌ Server does not appear to be running at $BASE_URL${NC}"
    echo -e "${YELLOW}  ➡  Start your Spring Boot app in IntelliJ first, then re-run.${NC}"
    exit 1
  fi
fi

# ── Make all scripts executable ───────────────────────────────────────────────
find "$SCRIPT_DIR" -name "*.sh" -exec chmod +x {} \;

# ── Run all modules ───────────────────────────────────────────────────────────
run_module "Auth"                    "$SCRIPT_DIR/auth/test-auth.sh"
run_module "Accounts"                "$SCRIPT_DIR/accounts/test-accounts.sh"
run_module "Transactions"            "$SCRIPT_DIR/transactions/test-transactions.sh"
run_module "QR Payment"              "$SCRIPT_DIR/qr-payment/test-qr-payment.sh"
run_module "ATM Cardless"            "$SCRIPT_DIR/atm/test-atm.sh"
run_module "Loans"                   "$SCRIPT_DIR/loans/test-loans.sh"
run_module "OTP+FixedDeposit+Scheduled" "$SCRIPT_DIR/otp-fixed-scheduled/test-otp-fixed-scheduled.sh"

# ── Final Summary ─────────────────────────────────────────────────────────────
TOTAL=$((TOTAL_PASS + TOTAL_FAIL))
echo ""
echo -e "${BOLD}${BLUE}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${BLUE}║           📊 FINAL TEST RESULTS                  ║${NC}"
echo -e "${BOLD}${BLUE}╠══════════════════════════════════════════════════╣${NC}"
echo -e "${BOLD}${BLUE}║  Total Tests : $TOTAL${NC}"
echo -e "${BOLD}${GREEN}║  ✅ Passed   : $TOTAL_PASS${NC}"
echo -e "${BOLD}${RED}║  ❌ Failed   : $TOTAL_FAIL${NC}"

if [ ${#FAILED_MODULES[@]} -gt 0 ]; then
  echo -e "${BOLD}${BLUE}╠══════════════════════════════════════════════════╣${NC}"
  echo -e "${BOLD}${RED}║  Failed Modules:${NC}"
  for m in "${FAILED_MODULES[@]}"; do
    echo -e "${RED}║    • $m${NC}"
  done
fi

echo -e "${BOLD}${BLUE}╚══════════════════════════════════════════════════╝${NC}"

# ── Clean up temp files ───────────────────────────────────────────────────────
rm -f /tmp/titan_test_token.txt \
      /tmp/titan_test_account.txt \
      /tmp/titan_test_account2.txt \
      /tmp/titan_test_account_id.txt \
      /tmp/titan_test_username.txt \
      /tmp/titan_test_password.txt \
      /tmp/titan_test_qr_code.txt \
      /tmp/titan_test_payer_qr.txt \
      /tmp/titan_test_atm_code.txt \
      /tmp/titan_test_atm_cancel_code.txt \
      /tmp/titan_test_loan_id.txt

echo -e "\n${CYAN}🧹 Temp files cleaned up.${NC}"

if [ "$TOTAL_FAIL" -eq 0 ]; then
  echo -e "\n${GREEN}${BOLD}🎉 All tests passed!${NC}\n"
  exit 0
else
  echo -e "\n${RED}${BOLD}⚠️  $TOTAL_FAIL test(s) failed. Review output above.${NC}\n"
  exit 1
fi
