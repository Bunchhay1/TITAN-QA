#!/bin/bash
# env.sh - Edge case test environment config
export BASE_URL="${BASE_URL:-http://localhost:8080}"
export CONCURRENT_WORKERS=5
export REQUEST_DELAY=0.1
export TOKEN_EXPIRY_BUFFER=10
