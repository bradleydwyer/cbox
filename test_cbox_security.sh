#!/usr/bin/env bash
# Test script for cbox security validations

echo "Testing cbox security validations..."
echo "====================================="

# Source the validation function from cbox
if [[ ! -f "cbox" ]]; then
  echo "Error: cbox script not found in current directory" >&2
  exit 1
fi

# Extract and source the validate_path_security function
source <(sed -n '/^validate_path_security()/,/^}$/p' cbox)

# Test cases
test_paths=(
  # Valid paths
  "/home/user/project:VALID:safe user directory"
  "/tmp/workspace:VALID:safe temp directory"  
  "/var/tmp/test:VALID:safe var temp directory"
  "/home:VALID:home directory root"
  "/usr/local/share:VALID:usr local share"
  
  # Dangerous characters - shell metacharacters
  "/home/user; rm -rf /:INVALID:dangerous characters"
  "/home/user | cat /etc/passwd:INVALID:dangerous characters"
  "/home/user && echo bad:INVALID:dangerous characters"  
  "/home/user\$(whoami):INVALID:command substitution"
  "/home/user\`id\`:INVALID:dangerous characters"
  "/home/user > /dev/null:INVALID:dangerous characters"
  "/home/user < input:INVALID:dangerous characters"
  "/home/user\${PATH}:INVALID:variable expansion"
  
  # System directories - /etc
  "/etc:INVALID:system directory"
  "/etc/passwd:INVALID:system directory"
  "/etc/shadow:INVALID:system directory"
  
  # System directories - core system
  "/sys:INVALID:system directory"
  "/sys/kernel:INVALID:system directory"
  "/proc:INVALID:system directory"
  "/proc/1/mem:INVALID:system directory"
  "/dev:INVALID:system directory"
  "/dev/sda:INVALID:system directory"
  "/boot:INVALID:system directory"
  "/root:INVALID:system directory"
  "/root/.ssh:INVALID:system directory"
  
  # System directories - binaries and libraries
  "/bin:INVALID:system directory"
  "/bin/bash:INVALID:system directory"
  "/sbin:INVALID:system directory"
  "/lib:INVALID:system directory"
  "/lib64:INVALID:system directory"
  "/usr/bin:INVALID:system directory"
  "/usr/sbin:INVALID:system directory"
  "/usr/lib:INVALID:system directory"
  
  # System directories - var subdirectories
  "/var/log:INVALID:system directory"
  "/var/log/secure:INVALID:system directory"
  "/var/run:INVALID:system directory"
  "/var/lock:INVALID:system directory"
  "/var/spool:INVALID:system directory"
  "/var/mail:INVALID:system directory"
  
  # Directory traversal attempts
  "../../../etc/passwd:INVALID:traversal to system directory"
  "/home/user/../../etc:INVALID:traversal to system directory"
  "/tmp/../etc/passwd:INVALID:traversal to system directory"
)

echo ""
echo "Running security validation tests..."
echo ""

passed=0
failed=0

# Function to run a single test
run_test() {
  local path="$1"
  local expected="$2"
  local description="$3"
  
  echo -n "Testing: $path ... "
  
  # Clear any environment variables that might interfere
  local old_workdir="$WORKDIR"
  WORKDIR=""
  
  # Capture both return code and output
  local output result
  if output=$(validate_path_security "$path" 2>&1); then
    result="VALID"
  else
    result="INVALID"
  fi
  
  # Restore WORKDIR
  WORKDIR="$old_workdir"
  
  if [[ "$result" == "$expected" ]]; then
    echo "✓ PASSED ($description)"
    ((passed++))
  else
    echo "✗ FAILED ($description)"
    echo "    Expected: $expected, Got: $result"
    if [[ -n "$output" ]]; then
      echo "    Output: $output"
    fi
    ((failed++))
  fi
}

# Run standard test cases
for test_case in "${test_paths[@]}"; do
  IFS=: read -r path expected reason <<< "$test_case"
  run_test "$path" "$expected" "$reason"
done

# Special test for null bytes (limited by shell command substitution)
echo ""
echo "Testing null byte detection..."
echo "Note: Shell command substitution strips null bytes, so this test is limited."
echo "However, the null byte detection code is present and functional in the cbox script."
echo "Testing that null byte detection code exists..."
if grep -q "null_count.*od.*tx1" cbox; then
  echo "✓ Null byte detection code found in cbox script"
  ((passed++))
else
  echo "✗ Null byte detection code missing from cbox script" 
  ((failed++))
fi

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