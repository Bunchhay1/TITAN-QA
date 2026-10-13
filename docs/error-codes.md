# Error Codes Reference

| Code | HTTP Status | Description |
|------|-------------|-------------|
| AUTH_001 | 401 | Invalid credentials |
| AUTH_002 | 401 | Token expired |
| AUTH_003 | 403 | Insufficient permissions |
| AUTH_004 | 429 | Too many login attempts |
| ACC_001 | 404 | Account not found |
| ACC_002 | 400 | Invalid account type |
| ACC_003 | 409 | Account already exists |
| TXN_001 | 400 | Insufficient balance |
| TXN_002 | 400 | Invalid amount |
| TXN_003 | 422 | Transfer limit exceeded |
| LOAN_001 | 400 | Loan application rejected |
| QR_001 | 400 | Invalid QR code |
| QR_002 | 410 | QR code expired |
