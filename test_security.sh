#!/usr/bin/env bash
# Test script to verify security fixes in cbox

set -euo pipefail

echo "=== Testing cbox Security Fixes ==="
echo

# Test 1: Command injection prevention
echo "Test 1: Command injection prevention"
echo "--------------------------------------"
# This should fail with security error
if ./cbox '$(echo pwned)' 2>&1 | grep -q "Security error: Path contains dangerous shell characters"; then
  echo "✓ Command injection blocked correctly"
else
  echo "✗ FAIL: Command injection not blocked"
fi

# Test 2: Path with semicolon
echo
echo "Test 2: Path with semicolon"
echo "----------------------------"
if ./cbox '/tmp;ls' 2>&1 | grep -q "Security error: Path contains dangerous shell characters"; then
  echo "✓ Semicolon in path blocked correctly"
else
  echo "✗ FAIL: Semicolon in path not blocked"
fi

# Test 3: Backtick injection
echo
echo "Test 3: Backtick injection"
echo "--------------------------"
if ./cbox '/tmp`whoami`' 2>&1 | grep -q "Security error: Path contains dangerous shell characters"; then
  echo "✓ Backtick injection blocked correctly"
else
  echo "✗ FAIL: Backtick injection not blocked"
fi

# Test 4: System directory access
echo
echo "Test 4: System directory access"
echo "--------------------------------"
if ./cbox '/etc' 2>&1 | grep -q "Security error: Access to system directory denied"; then
  echo "✓ System directory access blocked correctly"
else
  echo "✗ FAIL: System directory access not blocked"
fi

# Test 5: Valid directory should work (dry run with --verify)
echo
echo "Test 5: Valid directory access"
echo "-------------------------------"
if ./cbox --verify 2>&1 | grep -q "installed successfully"; then
  echo "✓ Valid operations work correctly"
else
  echo "✗ FAIL: Valid operations broken"
fi

echo
echo "=== Security Test Complete ==="