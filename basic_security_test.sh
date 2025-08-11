#!/bin/bash
# Basic validation test for security modes implementation

echo "=== Testing Security Modes Implementation ==="

# Test 1: Help text includes security options
echo "Test 1: Help text includes security options"
if ./cbox --help | grep -q -- "--security-mode"; then
  echo "✓ Help text includes --security-mode"
else
  echo "✗ Help text missing --security-mode"
fi

# Test 2: Valid security mode accepted
echo "Test 2: Valid security mode parsing"
if ./cbox --security-mode standard --help >/dev/null 2>&1; then
  echo "✓ Standard mode accepted"
else
  echo "✗ Standard mode rejected"
fi

# Test 3: Invalid security mode rejected
echo "Test 3: Invalid security mode rejected"
if ./cbox --security-mode invalid 2>&1 | grep -q "Invalid security mode"; then
  echo "✓ Invalid mode properly rejected"
else
  echo "✗ Invalid mode not rejected properly"
fi

# Test 4: Network type validation
echo "Test 4: Network type validation"
if ./cbox --network invalid 2>&1 | grep -q "Invalid network type"; then
  echo "✓ Invalid network type rejected"
else
  echo "✗ Invalid network type not rejected"
fi

# Test 5: SSH agent validation
echo "Test 5: SSH agent validation"
if ./cbox --ssh-agent invalid 2>&1 | grep -q "Invalid boolean value"; then
  echo "✓ Invalid SSH agent value rejected"
else
  echo "✗ Invalid SSH agent value not rejected"
fi

# Test 6: Combined arguments
echo "Test 6: Combined arguments parsing"
if ./cbox --security-mode paranoid --network none --ssh-agent false --read-only --help >/dev/null 2>&1; then
  echo "✓ Combined security arguments accepted"
else
  echo "✗ Combined security arguments failed"
fi

echo "=== Basic Security Test Complete ==="