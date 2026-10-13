#!/bin/bash
# check-deps.sh - Check required tools are installed

MISSING=0

check_cmd() {
  if command -v "$1" &>/dev/null; then
    echo "[OK] $1 found"
  else
    echo "[MISSING] $1 not found"
    MISSING=1
  fi
}

echo "Checking required dependencies..."
check_cmd curl
check_cmd jq
check_cmd bash

if [ $MISSING -eq 1 ]; then
  echo "Please install missing dependencies."
  exit 1
else
  echo "All dependencies satisfied."
fi
