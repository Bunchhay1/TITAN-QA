# 🏦 TITAN-QA — Titan Bank API Test Suite

> Comprehensive QA automation and security audit for **Titan Core Banking System**  
> Built with `bash` + `curl` + `jq` — no external test framework needed.

---

## 📋 Table of Contents

- [Overview](#overview)
- [Project Structure](#project-structure)
- [Requirements](#requirements)
- [Quick Start](#quick-start)
- [Test Modules](#test-modules)
- [Test Results](#test-results)
- [Bugs Found & Fixed](#bugs-found--fixed)
- [Known Limitations](#known-limitations)
- [How It Works](#how-it-works)

---

## Overview

TITAN-QA is a shell-based API test suite that covers all 38 endpoints of the
Titan Core Banking System. It runs sequentially, auto-captures JWT tokens and
account numbers between modules, and produces a color-coded pass/fail report.

**Stack:** Titan Core Banking (Spring Boot 3, Java 21, PostgreSQL, Kafka, Redis)  
**Test tool:** bash + curl + jq  
**Total endpoints covered:** 32 active / 7 pending (loans-service offline)  
**Last run result:** ✅ 32/32 PASSED

---

## Project Structure

```
TITAN-QA/
├── scrip-test-api-bank-v2/
│   ├── utils/
│   │   └── config.sh                       # Shared config, helpers, JWT token management
│   ├── auth/
│   │   └── test-auth.sh                    # Register, Login (4 tests)
│   ├── accounts/
│   │   └── test-accounts.sh                # Create, Get, Get by ID (5 tests)
│   ├── transactions/
│   │   └── test-transactions.sh            # Transfer, Withdraw, Deposit, International (7 tests)
│   ├── qr-payment/
│   │   └── test-qr-payment.sh              # Generate, Pay, Payer QR, Collect, Cancel, History (7 tests)
│   ├── atm/
│   │   └── test-atm.sh                     # Generate, Redeem, Cancel, Status (5 tests... wait 6 steps)
│   ├── loans/
│   │   └── test-loans.sh                   # Apply, Approve, Reject, Get, Repayments (7 tests)
│   ├── otp-fixed-scheduled/
│   │   └── test-otp-fixed-scheduled.sh     # OTP, Fixed Deposit, Scheduled TX (4 tests)
│   ├── run-all.sh                          # Master runner — runs all modules in order
│   └── README.md                           # This file
└── README.md
```

---

## Requirements

| Tool | Version | Install |
|------|---------|---------|
| `curl` | any | pre-installed on macOS |
| `jq` | 1.6+ | `brew install jq` |
| Titan Bank | running | IntelliJ → Run |
| Docker | running | postgres, redis, kafka |

**Infrastructure (Docker):**
```bash
docker compose -f /Users/chhay/Desktop/Bank/core-bank/docker-compose.yml \
  up -d postgres redis kafka kafka-init
```

**Application (IntelliJ):**  
Start `TitanCoreBankingApplication` from IntelliJ — runs on `http://localhost:8080`

---

## Quick Start

```bash
# 1. Navigate to test folder
cd /Users/chhay/Desktop/study/TITAN-QA/scrip-test-api-bank-v2

# 2. Make scripts executable (first time only)
chmod +x run-all.sh utils/config.sh **/*.sh

# 3. Run full test suite
./run-all.sh

# 4. Or run a single module
./auth/test-auth.sh
./accounts/test-accounts.sh
./transactions/test-transactions.sh
./qr-payment/test-qr-payment.sh
./atm/test-atm.sh
./loans/test-loans.sh
./otp-fixed-scheduled/test-otp-fixed-scheduled.sh
```

---

## Test Modules

### 🔐 Auth — `auth/test-auth.sh`
| # | Test | Expected |
|---|------|----------|
| 1 | Register new user | HTTP 200 |
| 2 | Register duplicate username | HTTP 400 |
| 3 | Login with valid credentials | HTTP 200 + JWT token |
| 4 | Login with wrong password | HTTP 400 |

### 🏦 Accounts — `accounts/test-accounts.sh`
| # | Test | Expected |
|---|------|----------|
| 1 | Create SAVINGS account | HTTP 201 |
| 2 | Create CHECKING account | HTTP 201 |
| 3 | Create account without JWT | HTTP 401 |
| 4 | Get my accounts | HTTP 200 |
| 5 | Get account by ID | HTTP 200 |

### 💸 Transactions — `transactions/test-transactions.sh`
| # | Test | Expected |
|---|------|----------|
| 1 | Deposit $500 | HTTP 200, status=SUCCESS |
| 2 | Withdraw $100 (with PIN) | HTTP 200, status=SUCCESS |
| 3 | Transfer $50 between accounts | HTTP 200 |
| 4 | Transfer $5,000 (insufficient balance) | HTTP 400 |
| 5 | International transfer valid SWIFT/IBAN | HTTP 200 |
| 6 | International transfer invalid SWIFT | HTTP 400 |
| 7 | Get transaction history | HTTP 200 |

### 📱 QR Payment — `qr-payment/test-qr-payment.sh`
| # | Test | Expected |
|---|------|----------|
| 1 | Generate receive QR code | HTTP 200 |
| 2 | Pay by scanning QR | HTTP 200, status=COMPLETED |
| 3 | Generate payer (send-by) QR | HTTP 200 |
| 4 | Collect money from payer QR | HTTP 200 |
| 5 | Cancel QR code | HTTP 200, status=CANCELLED |
| 6 | QR payment history | HTTP 200 |
| 7 | Get or create permanent account QR | HTTP 200 |

### 🏧 ATM Cardless — `atm/test-atm.sh`
| # | Test | Expected |
|---|------|----------|
| 1 | Generate 12-digit ATM code | HTTP 200 |
| 2 | Check ATM code status | HTTP 200, status=PENDING |
| 3 | Redeem ATM code at terminal | HTTP 200, status=USED |
| 4 | Redeem already-used code | HTTP 400 |
| 5 | Generate new code for cancel | — |
| 6 | Cancel ATM code | HTTP 200, status=CANCELLED |

### 💰 Loans — `loans/test-loans.sh`
| # | Test | Expected |
|---|------|----------|
| 1 | Apply for loan | HTTP 200 |
| 2 | Get my loans | HTTP 200 |
| 3 | Get loan by ID | HTTP 200 |
| 4 | Get loans by account | HTTP 200 |
| 5 | Approve loan | HTTP 200 |
| 6 | Get repayment schedule | HTTP 200 |
| 7 | Apply + Reject loan | HTTP 200 |

> ⚠️ Loans are proxied to `titan-loans-service` (separate microservice).  
> Tests auto-skip if the service is offline — not counted as failures.

### 🔑 OTP + Fixed Deposit + Scheduled — `otp-fixed-scheduled/test-otp-fixed-scheduled.sh`
| # | Test | Expected |
|---|------|----------|
| 1 | Generate OTP (authenticated) | HTTP 200 |
| 2 | Generate OTP (no token) | HTTP 401 |
| 3 | Create fixed deposit 6 months $1,000 | HTTP 200 |
| 4 | Create scheduled transaction | HTTP 200, status=PENDING |

---

## Test Results

```
╔══════════════════════════════════════════════════╗
║           📊 FINAL TEST RESULTS                  ║
╠══════════════════════════════════════════════════╣
║  Total Tests : 32                                ║
║  ✅ Passed   : 32                                ║
║  ❌ Failed   : 0                                 ║
╚══════════════════════════════════════════════════╝
🎉 All tests passed!
```

> When `titan-loans-service` is running: target is **39/39**

---

## Bugs Found & Fixed

All bugs were discovered through this test suite and fixed in the source code.

| # | Bug | Severity | File | Status |
|---|-----|----------|------|--------|
| 1 | `ScheduledTransactionController` missing 4 NOT NULL fields | 🔴 Critical | ScheduledTransactionController.java | ✅ Fixed |
| 2 | `InsufficientBalanceException` swallowed — returned HTTP 200 instead of HTTP 400 | 🔴 High | TransactionService.java | ✅ Fixed |
| 3 | Internal loan endpoints had no authentication — any user could credit any account | 🟡 Medium | LoanDisbursementController.java, LoanFeeController.java | ✅ Fixed |
| 4 | `GET /api/v1/users` exposed all users without ADMIN role check | 🟡 Medium | UserController.java | ✅ Fixed |
| 5 | Statement PDF endpoint had no account ownership check | 🟡 Medium | StatementController.java | ✅ Fixed |
| 6 | `RiskEngineService` log said ALLOW but returned BLOCK — misleading | 🟡 Medium | RiskEngineService.java | ✅ Fixed |
| 7 | Wrong request field names in test scripts (`fullName` vs `firstName/lastName`, `atmCode` vs `code`) | 🟢 Low | Test scripts | ✅ Fixed |

### Security Patterns Applied After Fixes
- **Defense in Depth** — multiple security layers
- **Principle of Least Privilege** — users access only their own resources
- **Fail-Safe Defaults** — deny by default, BLOCK when Risk Engine is uncertain
- **Complete Mediation** — every request validated
- **Proper HTTP Semantics** — 4xx for client errors, 5xx for server errors

---

## Known Limitations

**1. Loans module skipped when titan-loans-service is offline**
The loan endpoints proxy to a separate microservice. When not running, all 7 tests are skipped gracefully with a `KNOWN_BUG` notice — not counted as failures.

**2. Risk Engine (Python) at localhost:8082**
When the Python Risk Engine is offline, the fail-safe blocks all transactions above a threshold. The overdraft test accounts for both behaviors (HTTP 400 or status=BLOCKED/FAILED).

**3. Scheduled Transaction frequency**
The controller defaults `frequency` to `"ONCE"` when not provided. To schedule recurring transactions, pass `transactionType` field with values like `"DAILY"`, `"WEEKLY"`, `"MONTHLY"`.

**4. Internal API key required after security fix**
Add to `application.properties` before starting the app:
```properties
internal.api.key=YOUR_KEY_HERE   # generate: openssl rand -hex 32
risk.engine.failsafe.action=BLOCK
```

---

## How It Works

```
run-all.sh
    │
    ├── Health check → http://localhost:8080/actuator/health
    │
    ├── auth/test-auth.sh
    │       └── Registers unique user (titan_qa_{timestamp})
    │           Saves JWT token → /tmp/titan_test_token.txt
    │
    ├── accounts/test-accounts.sh
    │       └── Creates 2 accounts
    │           Saves account numbers → /tmp/titan_test_account.txt
    │                                   /tmp/titan_test_account2.txt
    │
    ├── transactions/test-transactions.sh
    │       └── Loads token + accounts from /tmp
    │           Runs deposit → withdraw → transfer → overdraft → international
    │
    ├── qr-payment/test-qr-payment.sh
    │       └── Generates QR → pays → cancels → checks history
    │
    ├── atm/test-atm.sh
    │       └── Generates code → checks status → redeems → cancels
    │
    ├── loans/test-loans.sh
    │       └── Checks if titan-loans-service is online
    │           Skips gracefully if offline
    │
    ├── otp-fixed-scheduled/test-otp-fixed-scheduled.sh
    │       └── OTP → fixed deposit → scheduled transaction
    │
    └── Final summary + cleanup /tmp files
```

**Token sharing between modules:**
Each script writes/reads from `/tmp/titan_test_*.txt` files so JWT tokens
and account numbers flow automatically from auth → accounts → all other modules.
No manual setup required between runs.

---

*Generated: 2026-10-09 | Titan Bank QA Suite v2*
