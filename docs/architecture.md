# TITAN-QA Architecture

## Test Architecture

```
┌──────────────────────┐
│   Test Runner        │
│   (run-all.sh)       │
└──────────┬───────────┘
           │
    ┌──────▼──────┐
    │  Test Suite │
    │  - auth     │
    │  - accounts │
    │  - atm      │
    │  - loans    │
    │  - txn      │
    │  - qr       │
    │  - otp      │
    └──────┬──────┘
           │
    ┌──────▼──────┐
    │  Banking API │
    │  (local/AWS) │
    └─────────────┘
```
