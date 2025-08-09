#!/usr/bin/env bash
# verify-install.sh - Verify integrity of install.sh before running
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
info() { echo -e "${GREEN}[INFO]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# Known good checksum for install.sh
# Update this when install.sh is legitimately modified
INSTALL_SH_CHECKSUM="56f89f6a0a536a6028beb02929d52a3df4f37c3299999f2ce7e3897ecfcaaeda"

info "Verifying install.sh integrity..."

# Check if install.sh exists
if [[ ! -f "install.sh" ]]; then
  error "install.sh not found"
  exit 1
fi

# Calculate actual checksum
if command -v sha256sum &> /dev/null; then
  actual_checksum=$(sha256sum install.sh | awk '{print $1}')
elif command -v shasum &> /dev/null; then
  actual_checksum=$(shasum -a 256 install.sh | awk '{print $1}')
else
  error "Neither sha256sum nor shasum available"
  exit 1
fi

# Compare checksums
if [[ "$INSTALL_SH_CHECKSUM" == "PLACEHOLDER_CHECKSUM" ]]; then
  info "Current install.sh checksum: $actual_checksum"
  info "Update INSTALL_SH_CHECKSUM in this script with the above value"
elif [[ "$INSTALL_SH_CHECKSUM" != "$actual_checksum" ]]; then
  error "install.sh integrity check failed!"
  error "  Expected: $INSTALL_SH_CHECKSUM"
  error "  Got:      $actual_checksum"
  error "DO NOT run install.sh - it may have been tampered with"
  exit 1
else
  info "✓ install.sh integrity verified"
  info "It is safe to run: bash install.sh"
fi