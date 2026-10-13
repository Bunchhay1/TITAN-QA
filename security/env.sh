#!/bin/bash
# env.sh - Security test environment config
export BASE_URL="${BASE_URL:-http://localhost:8080}"
export ATTACK_DELAY=0.5  # seconds between attack attempts
export MAX_BRUTE_FORCE=10
export SQL_INJECTION_TIMEOUT=10
