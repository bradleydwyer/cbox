#!/usr/bin/env bash
# Security test for cbox path validation

echo "=== Testing cbox Security Improvements ==="
echo ""

# Test dangerous paths (should all fail)
echo "Testing dangerous paths (should be blocked):"
echo "-------------------------------------------"

test_path() {
  local path="$1"
  local expected="$2"
  echo -n "Testing: $path ... "
  
  # Run cbox with the path (will fail on Docker but we check the error message)
  output=$(bash cbox "$path" 2>&1 || true)
  
  if [[ "$output" == *"Security error"* ]]; then
    result="BLOCKED"
  elif [[ "$output" == *"Docker is required"* ]]; then
    result="ALLOWED"
  elif [[ "$output" == *"Directory does not exist"* ]]; then
    result="NOTEXIST"
  else
    result="UNKNOWN"
  fi
  
  if [[ "$result" == "$expected" ]]; then
    echo "✓ PASS (got: $expected)"
    return 0
  else
    echo "✗ FAIL (expected: $expected, got: $result)"
    return 1
  fi
}

passed=0
failed=0

# Test dangerous characters
test_path "/tmp; rm -rf /" "BLOCKED" && ((passed++)) || ((failed++))
test_path "/tmp | cat /etc/passwd" "BLOCKED" && ((passed++)) || ((failed++))
test_path "/tmp && echo bad" "BLOCKED" && ((passed++)) || ((failed++))
test_path '/tmp$(whoami)' "BLOCKED" && ((passed++)) || ((failed++))
test_path '/tmp`id`' "BLOCKED" && ((passed++)) || ((failed++))
test_path "/tmp > /dev/null" "BLOCKED" && ((passed++)) || ((failed++))
test_path "/tmp < input" "BLOCKED" && ((passed++)) || ((failed++))

echo ""
echo "Testing system directories (should be blocked):"
echo "-----------------------------------------------"

# Test system directories
test_path "/etc" "BLOCKED" && ((passed++)) || ((failed++))
test_path "/sys" "BLOCKED" && ((passed++)) || ((failed++))
test_path "/proc" "BLOCKED" && ((passed++)) || ((failed++))
test_path "/dev" "BLOCKED" && ((passed++)) || ((failed++))
test_path "/root" "BLOCKED" && ((passed++)) || ((failed++))
test_path "/var/log" "BLOCKED" && ((passed++)) || ((failed++))
test_path "/usr/bin" "BLOCKED" && ((passed++)) || ((failed++))

echo ""
echo "Testing valid paths (should be allowed):"
echo "----------------------------------------"

# Test valid paths
test_path "/tmp" "ALLOWED" && ((passed++)) || ((failed++))
test_path "/work" "ALLOWED" && ((passed++)) || ((failed++))
test_path "$HOME" "ALLOWED" && ((passed++)) || ((failed++))

# Test non-existent paths (should fail with "does not exist")
echo ""
echo "Testing non-existent paths:"
echo "---------------------------"
test_path "/nonexistent/path" "NOTEXIST" && ((passed++)) || ((failed++))

echo ""
echo "==================================="
echo "Test Results:"
echo "  Passed: $passed"
echo "  Failed: $failed"
echo ""

if [[ $failed -eq 0 ]]; then
  echo "✓ All security tests passed!"
  exit 0
else
  echo "✗ Some tests failed"
  exit 1
fi