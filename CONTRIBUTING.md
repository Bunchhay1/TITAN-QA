# Contributing to TITAN-QA

## How to Add Tests

1. Navigate to the relevant directory
2. Create your test script following the naming convention `test-<feature>.sh`
3. Make the script executable: `chmod +x test-<feature>.sh`
4. Add it to the relevant `run-*.sh` runner

## Test Script Template

```bash
#!/bin/bash
source ../utils/config.sh

echo "=== Testing Feature ==="

# Test 1: Description
response=$(curl -s -X POST "$BASE_URL/endpoint" ...)
# validate response
```
