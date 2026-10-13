# TITAN-QA

## Project Structure

```
TITAN-QA/
├── scrip-test-api-bank-v2/          # Local server test suite
├── scrip-test-api-bank-v2 -server-asw/  # AWS server test suite
├── edge-cases/                       # Edge case test scenarios
└── security/                         # Security test suite
```

## CI Status

![Tests](https://github.com/Bunchhay1/TITAN-QA/actions/workflows/test.yml/badge.svg)

## Test Coverage

| Suite | Tests |
|-------|-------|
| Local API | auth, accounts, atm, loans, transactions, qr-payment, otp |
| AWS API | auth, accounts, atm, loans, transactions, qr-payment, otp |
| Security | sql-injection, brute-force, jwt-tampering, idor, privilege-escalation |
| Edge Cases | boundary-values, missing-fields, invalid-formats, concurrent, expired |
