#!/bin/bash
# setup.sh - Initial project setup

echo "Setting up TITAN-QA..."

# Check deps
./check-deps.sh || exit 1

# Make all scripts executable
find . -name "*.sh" -not -path "./.git/*" -exec chmod +x {} \;
echo "[OK] All scripts made executable"

echo "Setup complete. Run 'make test' to start testing."
