# Security Test Report

## Summary
This directory contains security tests for the TITAN-QA banking API.

## Test Suites
- **sql-injection**: SQL injection attack prevention
- **brute-force**: Brute force attack protection
- **jwt-tampering**: JWT token manipulation prevention
- **idor**: Insecure Direct Object Reference tests
- **privilege-escalation**: Privilege escalation prevention

## Running Tests
```bash
chmod +x run-security.sh
./run-security.sh
```
