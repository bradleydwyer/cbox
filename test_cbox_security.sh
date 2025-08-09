#!/usr/bin/env bash
# Test script for cbox security validations

echo "Testing cbox security validations..."
echo "====================================="

# Source the validation function from cbox
source <(sed -n '/^validate_path_security()/,/^}/p' cbox)

# Test cases
test_paths=(
  # Valid paths
  "/home/user/project:VALID"
  "/tmp/workspace:VALID"
  "$HOME/test:VALID"
  
  # Dangerous characters
  "/home/user; rm -rf /:INVALID:dangerous characters"
  "/home/user | cat /etc/passwd:INVALID:dangerous characters"
  "/home/user && echo bad:INVALID:dangerous characters"
  "/home/user\$(whoami):INVALID:command substitution"
  "/home/user\`id\`:INVALID:dangerous characters"
  "/home/user > /dev/null:INVALID:dangerous characters"
  "/home/user < input:INVALID:dangerous characters"
  
  # System directories
  "/etc/passwd:INVALID:system directory"
  "/sys/kernel:INVALID:system directory"
  "/proc/1/mem:INVALID:system directory"
  "/dev/sda:INVALID:system directory"
  "/root/.ssh:INVALID:system directory"
  "/var/log/secure:INVALID:system directory"
  
  # Directory traversal
  "../../../etc/passwd:INVALID:traversal"
  "/home/user/../../etc:INVALID:system directory"
  
  # Null bytes
  $'/home/user\x00/bad:INVALID:null bytes'
)

echo ""
echo "Running security validation tests..."
echo ""

passed=0
failed=0

for test_case in "${test_paths[@]}"; do
  IFS=: read -r path expected reason <<< "$test_case"
  
  echo -n "Testing: $path ... "
  
  # Temporarily override WORKDIR
  WORKDIR=""
  
  if validate_path_security "$path" 2>/dev/null; then
    result="VALID"
  else
    result="INVALID"
  fi
  
  if [[ "$result" == "$expected" ]]; then
    echo "✓ PASSED (expected: $expected)"
    ((passed++))
  else
    echo "✗ FAILED (expected: $expected, got: $result)"
    ((failed++))
  fi
done

echo ""
echo "====================================="
echo "Test Results:"
echo "  Passed: $passed"
echo "  Failed: $failed"
echo ""

if [[ $failed -eq 0 ]]; then
  echo "✓ All security validation tests passed!"
  exit 0
else
  echo "✗ Some tests failed. Please review the security validation logic."
  exit 1
fi