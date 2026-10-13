# Test Plan - TITAN-QA Banking API

## Objectives
Validate the banking API's correctness, security, and resilience.

## Scope
- Functional API tests (local + AWS)
- Security vulnerability tests
- Edge case and boundary tests

## Test Types
1. **Functional** - Verify API returns correct responses
2. **Security** - Verify API resists attacks
3. **Edge Case** - Verify API handles unusual inputs
4. **Load** - (Future) Verify API handles concurrent requests

## Test Environments
- Local: http://localhost:8080
- AWS: https://api.titan-bank.aws.example.com

## Pass Criteria
- All functional tests pass (HTTP 200/201)
- All security tests return expected rejections (HTTP 400/401/403)
- All edge case tests return correct validation errors
