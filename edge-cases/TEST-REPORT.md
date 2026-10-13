# Edge Cases Test Report

## Summary
This directory contains edge case tests for the TITAN-QA banking API.

## Test Suites
- **boundary-values**: Tests for min/max value limits
- **missing-fields**: Tests for required field validation
- **invalid-formats**: Tests for input format validation
- **concurrent**: Tests for race conditions
- **expired**: Tests for token/session expiry

## Running Tests
```bash
chmod +x run-edge-cases.sh
./run-edge-cases.sh
```
