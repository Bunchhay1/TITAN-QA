# Changelog

## [Unreleased]

## [1.0.0] - 2026-10-09
### Added
- Initial test suite for banking API
- Auth, accounts, ATM, loans, transactions, QR payment tests
- Security test suite: SQL injection, brute force, JWT tampering, IDOR, privilege escalation
- Edge case tests: boundary values, missing fields, invalid formats, concurrent, expired
- AWS server test suite mirror

### Added in dev
- Shared helper utilities for all test suites
- Environment config files for local and AWS
- Test data fixtures (users, accounts, transactions)
- Security test payloads (SQL injection, JWT, brute force, IDOR)
- Edge case test data (boundary values, invalid formats)
- CI/CD GitHub Actions workflow
- Makefile for test orchestration
