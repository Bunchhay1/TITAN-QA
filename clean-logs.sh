#!/bin/bash
# clean-logs.sh - Remove all test logs

echo "Cleaning test logs..."
find . -name "*.log" -not -path "./.git/*" -delete
echo "Done."
