.PHONY: test test-local test-aws test-edge test-security

test: test-local test-edge test-security

test-local:
	@echo "Running local API tests..."
	@chmod +x scrip-test-api-bank-v2/run-all.sh
	@cd scrip-test-api-bank-v2 && ./run-all.sh

test-aws:
	@echo "Running AWS API tests..."
	@chmod +x "scrip-test-api-bank-v2 -server-asw/run-all.sh"
	@cd "scrip-test-api-bank-v2 -server-asw" && ./run-all.sh

test-edge:
	@echo "Running edge case tests..."
	@chmod +x edge-cases/run-edge-cases.sh
	@cd edge-cases && ./run-edge-cases.sh

test-security:
	@echo "Running security tests..."
	@chmod +x security/run-security.sh
	@cd security && ./run-security.sh
