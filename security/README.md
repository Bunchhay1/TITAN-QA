# Security Test Suite

Tests that validate the banking API's resilience against common attack vectors.

| Test | Description |
|------|-------------|
| sql-injection | Verifies parameterized queries prevent injection |
| brute-force | Verifies rate limiting on login endpoints |
| jwt-tampering | Verifies JWT signature validation |
| idor | Verifies object-level authorization |
| privilege-escalation | Verifies role-based access control |
