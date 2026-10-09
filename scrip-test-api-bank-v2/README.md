# 🏦 Titan Bank API Test Scripts

Comprehensive API test suite for Titan Core Banking System.

## 📁 Project Structure

```
scrip-test-api-bank-v2/
├── utils/
│   └── config.sh               # Shared config (BASE_URL, tokens, colors)
├── auth/
│   └── test-auth.sh            # Register & Login
├── accounts/
│   └── test-accounts.sh        # Create, Get My Accounts, Get By ID
├── transactions/
│   └── test-transactions.sh    # Transfer, Withdraw, Deposit, International, History
├── qr-payment/
│   └── test-qr-payment.sh      # Generate QR, Pay, Generate Payer QR, Collect, Cancel, History
├── atm/
│   └── test-atm.sh             # Generate Code, Redeem, Cancel, Status
├── loans/
│   └── test-loans.sh           # Apply, Approve, Reject, Get, My Loans, Repayments
├── otp-fixed-scheduled/
│   └── test-otp-fixed-scheduled.sh  # OTP, Fixed Deposit, Scheduled Transaction
├── run-all.sh                  # Master script — runs all tests
└── README.md
```

## ⚙️ Requirements

- `curl` (pre-installed on macOS)
- `jq` — install with: `brew install jq`
- Titan Bank running on `http://localhost:8080`

## 🚀 Quick Start

```bash
# 1. Make all scripts executable
chmod +x run-all.sh utils/config.sh **/*.sh

# 2. Run all tests
./run-all.sh

# 3. Or run individual modules
./auth/test-auth.sh
./accounts/test-accounts.sh
./transactions/test-transactions.sh
./qr-payment/test-qr-payment.sh
./atm/test-atm.sh
./loans/test-loans.sh
./otp-fixed-scheduled/test-otp-fixed-scheduled.sh
```

## 📊 Total Endpoints Covered

| Module | Endpoints |
|---|---|
| Auth | 2 |
| Accounts | 3 |
| Transactions | 5 |
| QR Payment | 7 |
| ATM Cardless | 4 |
| Loans | 7 |
| OTP + Fixed Deposit + Scheduled | 3 |
| **Total** | **31** |

## 🔑 Test Credentials

Default test user created automatically during auth tests:
- **Username:** `titan_test_qa`
- **Password:** `Test@1234`

JWT token is auto-captured and shared across all test modules via `utils/config.sh`.
