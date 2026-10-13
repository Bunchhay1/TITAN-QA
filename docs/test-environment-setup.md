# Test Environment Setup

## Prerequisites
- bash 4.0+
- curl
- jq

## Local Setup
1. Clone the repository
2. Run `chmod +x check-deps.sh && ./check-deps.sh`
3. Configure `scrip-test-api-bank-v2/utils/env.local.sh`
4. Start local server
5. Run `make test-local`

## AWS Setup
1. Configure `scrip-test-api-bank-v2 -server-asw/utils/env.aws.sh`
2. Ensure AWS server is reachable
3. Run `make test-aws`
