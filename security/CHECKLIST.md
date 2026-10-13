# Security Test Checklist

## Authentication
- [ ] SQL injection on login
- [ ] Brute force protection
- [ ] Account lockout after failed attempts
- [ ] Weak password rejection

## Authorization
- [ ] IDOR on account endpoints
- [ ] IDOR on transaction endpoints
- [ ] Privilege escalation via role change
- [ ] Admin endpoint access by non-admin

## Token Security
- [ ] JWT signature validation
- [ ] JWT algorithm confusion (RS256 → HS256)
- [ ] JWT none algorithm
- [ ] Expired token rejection
- [ ] Token replay prevention

## Input Validation
- [ ] XSS in input fields
- [ ] Command injection
- [ ] Path traversal
