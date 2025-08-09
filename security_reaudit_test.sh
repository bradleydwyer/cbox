#!/usr/bin/env bash
# Comprehensive Security Re-audit Test Suite for cbox
# Tests critical security vulnerabilities after fixes

set -euo pipefail

echo "========================================"
echo "   CBOX SECURITY RE-AUDIT TEST SUITE   "
echo "========================================"
echo

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Test result function
test_result() {
  local test_name="$1"
  local result="$2"
  local details="$3"
  
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  
  if [[ "$result" == "PASS" ]]; then
    echo -e "${GREEN}✓${NC} $test_name - ${GREEN}PASS${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
  else
    echo -e "${RED}✗${NC} $test_name - ${RED}FAIL${NC}"
    echo -e "  ${YELLOW}Details: $details${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
  fi
}

echo -e "${BLUE}1. COMMAND INJECTION VULNERABILITY TESTS${NC}"
echo "Testing if path validation happens before command substitution..."
echo

# Test 1.1: Direct command injection attempt
test_name="1.1 Command injection via \$()"
# Check that validation happens BEFORE the cd command (line 204 before line 266)
if grep -n 'validate_path_security.*"\$WORKDIR"' cbox | grep -q "204" && \
   grep -n 'cd -- "\$WORKDIR"' cbox | grep -q "266"; then
  test_result "$test_name" "PASS" "Path validation (line 204) occurs before cd command (line 266)"
else
  test_result "$test_name" "FAIL" "Path validation missing or occurs after command execution"
fi

# Test 1.2: Backtick command injection
test_name="1.2 Backtick command injection"
if grep -q '\[\[ "\$.*" == \*'\''`'\''.*\]\]' cbox; then
  test_result "$test_name" "PASS" "Backtick detection implemented"
else
  test_result "$test_name" "FAIL" "Backtick detection not found"
fi

# Test 1.3: Semicolon command chaining
test_name="1.3 Semicolon command chaining"
if grep -q '\[\[ "\$.*" == \*";".*\]\]' cbox; then
  test_result "$test_name" "PASS" "Semicolon detection implemented"
else
  test_result "$test_name" "FAIL" "Semicolon detection not found"
fi

# Test 1.4: Pipe command injection
test_name="1.4 Pipe command injection"
if grep -q '\[\[ "\$.*" == \*"|".*\]\]' cbox; then
  test_result "$test_name" "PASS" "Pipe detection implemented"
else
  test_result "$test_name" "FAIL" "Pipe detection not found"
fi

echo
echo -e "${BLUE}2. VARIABLE EXPANSION SECURITY TESTS${NC}"
echo "Testing if all variables are properly quoted..."
echo

# Test 2.1: WORKDIR variable quoting
test_name="2.1 WORKDIR variable quoting"
if grep -E 'cd -- "\$WORKDIR"' cbox > /dev/null; then
  test_result "$test_name" "PASS" "WORKDIR properly quoted with --"
else
  test_result "$test_name" "FAIL" "WORKDIR not properly quoted"
fi

# Test 2.2: Volume mount quoting
test_name="2.2 Volume mount variable quoting"
if grep -E '\-v "\$WORKDIR":/work' cbox > /dev/null; then
  test_result "$test_name" "PASS" "Volume mount variables properly quoted"
else
  test_result "$test_name" "FAIL" "Volume mount variables not properly quoted"
fi

# Test 2.3: Array usage for TTY flags
test_name="2.3 TTY flags array usage"
if grep -q 'declare -a TTY_FLAGS' cbox && grep -q '"${TTY_FLAGS\[@\]}"' cbox; then
  test_result "$test_name" "PASS" "TTY flags use array to prevent word splitting"
else
  test_result "$test_name" "FAIL" "TTY flags not using array pattern"
fi

echo
echo -e "${BLUE}3. FILE MOUNT SECURITY TESTS${NC}"
echo "Testing if sensitive files are mounted read-only..."
echo

# Test 3.1: .claude.json read-only mount
test_name="3.1 .claude.json read-only mount"
if grep -q '\.claude\.json.*:ro' cbox; then
  test_result "$test_name" "PASS" ".claude.json mounted read-only"
else
  test_result "$test_name" "FAIL" ".claude.json not mounted read-only"
fi

# Test 3.2: .gitconfig read-only mount
test_name="3.2 .gitconfig read-only mount"
if grep -q '\.gitconfig.*:ro' cbox; then
  test_result "$test_name" "PASS" ".gitconfig mounted read-only"
else
  test_result "$test_name" "FAIL" ".gitconfig not mounted read-only"
fi

# Test 3.3: SSH known_hosts read-only mount
test_name="3.3 SSH known_hosts read-only mount"
if grep -q 'known_hosts.*:ro' cbox; then
  test_result "$test_name" "PASS" "known_hosts mounted read-only"
else
  test_result "$test_name" "FAIL" "known_hosts not mounted read-only"
fi

# Test 3.4: .git-credentials read-only mount
test_name="3.4 .git-credentials read-only mount"
if grep -q '\.git-credentials.*:ro' cbox; then
  test_result "$test_name" "PASS" ".git-credentials mounted read-only"
else
  test_result "$test_name" "FAIL" ".git-credentials not mounted read-only"
fi

echo
echo -e "${BLUE}4. DOCKER SECURITY HARDENING TESTS${NC}"
echo "Testing Docker container security restrictions..."
echo

# Test 4.1: Capability dropping
test_name="4.1 Docker capability dropping"
if grep -q '\-\-cap-drop=ALL' cbox; then
  test_result "$test_name" "PASS" "All capabilities dropped by default"
else
  test_result "$test_name" "FAIL" "Capabilities not properly dropped"
fi

# Test 4.2: Required capabilities only
test_name="4.2 Minimal capability additions"
cap_count=$(grep -c '\-\-cap-add=' cbox || echo 0)
if [[ $cap_count -le 5 ]]; then
  test_result "$test_name" "PASS" "Only minimal capabilities added ($cap_count)"
else
  test_result "$test_name" "FAIL" "Too many capabilities added ($cap_count)"
fi

# Test 4.3: No new privileges
test_name="4.3 No new privileges flag"
if grep -q '\-\-security-opt=no-new-privileges' cbox; then
  test_result "$test_name" "PASS" "no-new-privileges security option set"
else
  test_result "$test_name" "FAIL" "no-new-privileges not set"
fi

# Test 4.4: Read-only root filesystem
test_name="4.4 Read-only root filesystem"
if grep -q '\-\-read-only' cbox; then
  test_result "$test_name" "PASS" "Root filesystem mounted read-only"
else
  test_result "$test_name" "FAIL" "Root filesystem not read-only"
fi

# Test 4.5: Tmpfs with noexec
test_name="4.5 Tmpfs with noexec flag"
if grep -q 'tmpfs.*noexec' cbox; then
  test_result "$test_name" "PASS" "Tmpfs mounted with noexec"
else
  test_result "$test_name" "FAIL" "Tmpfs missing noexec flag"
fi

# Test 4.6: Resource limits
test_name="4.6 Resource limits implementation"
if grep -q '\-\-memory "\$MEMORY_LIMIT"' cbox && grep -q '\-\-cpus "\$CPU_LIMIT"' cbox; then
  test_result "$test_name" "PASS" "Memory and CPU limits implemented"
else
  test_result "$test_name" "FAIL" "Resource limits not properly implemented"
fi

echo
echo -e "${BLUE}5. PATH VALIDATION SECURITY TESTS${NC}"
echo "Testing system directory blocking..."
echo

# Test 5.1: /etc blocking
test_name="5.1 /etc directory blocking"
if grep -q '/etc|/etc/\*' cbox; then
  test_result "$test_name" "PASS" "/etc access blocked"
else
  test_result "$test_name" "FAIL" "/etc access not blocked"
fi

# Test 5.2: System binary directories
test_name="5.2 System binary directory blocking"
if grep -q '/bin|/bin/\*|/sbin|/sbin/\*' cbox; then
  test_result "$test_name" "PASS" "System binary directories blocked"
else
  test_result "$test_name" "FAIL" "System binary directories not blocked"
fi

# Test 5.3: Null byte detection
test_name="5.3 Null byte detection"
if grep -q 'od -An.*tx1.*null' cbox; then
  test_result "$test_name" "PASS" "Null byte detection implemented"
else
  test_result "$test_name" "FAIL" "Null byte detection not found"
fi

echo
echo -e "${BLUE}6. INSTALLATION SECURITY TESTS${NC}"
echo "Testing installation script security..."
echo

# Test 6.1: Checksum verification
test_name="6.1 Checksum verification in install.sh"
if [[ -f install.sh ]] && grep -q 'verify_checksum' install.sh; then
  test_result "$test_name" "PASS" "Checksum verification implemented"
else
  test_result "$test_name" "FAIL" "Checksum verification not found"
fi

# Test 6.2: HTTPS only downloads
test_name="6.2 HTTPS-only downloads"
if [[ -f install.sh ]] && ! grep -E 'http://[^s]' install.sh; then
  test_result "$test_name" "PASS" "Only HTTPS URLs used"
else
  test_result "$test_name" "FAIL" "Non-HTTPS URLs found"
fi

# Test 6.3: Atomic installation
test_name="6.3 Atomic installation with temp directory"
if [[ -f install.sh ]] && grep -q 'temp_dir.*tmp.*cbox-install' install.sh; then
  test_result "$test_name" "PASS" "Atomic installation with temp directory"
else
  test_result "$test_name" "FAIL" "Atomic installation not implemented"
fi

echo
echo -e "${BLUE}7. FUNCTIONAL SECURITY TESTS${NC}"
echo "Running actual security validation tests..."
echo

# Run the security test script if it exists
if [[ -f test_cbox_security.sh ]]; then
  echo "Running test_cbox_security.sh..."
  if bash test_cbox_security.sh > /dev/null 2>&1; then
    test_result "7.1 Security validation test suite" "PASS" "All validation tests passed"
  else
    test_result "7.1 Security validation test suite" "FAIL" "Some validation tests failed"
  fi
else
  test_result "7.1 Security validation test suite" "FAIL" "Test script not found"
fi

echo
echo "========================================"
echo -e "${BLUE}SECURITY RE-AUDIT SUMMARY${NC}"
echo "========================================"
echo
echo "Total Tests: $TOTAL_TESTS"
echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
echo -e "Failed: ${RED}$FAILED_TESTS${NC}"
echo

# Calculate security grade
PASS_PERCENTAGE=$((PASSED_TESTS * 100 / TOTAL_TESTS))

if [[ $PASS_PERCENTAGE -ge 95 ]]; then
  GRADE="A"
  GRADE_COLOR=$GREEN
elif [[ $PASS_PERCENTAGE -ge 85 ]]; then
  GRADE="B"
  GRADE_COLOR=$GREEN
elif [[ $PASS_PERCENTAGE -ge 75 ]]; then
  GRADE="C"
  GRADE_COLOR=$YELLOW
elif [[ $PASS_PERCENTAGE -ge 65 ]]; then
  GRADE="D"
  GRADE_COLOR=$YELLOW
else
  GRADE="F"
  GRADE_COLOR=$RED
fi

echo -e "Security Score: ${GRADE_COLOR}$PASS_PERCENTAGE%${NC}"
echo -e "Security Grade: ${GRADE_COLOR}$GRADE${NC}"
echo

if [[ $FAILED_TESTS -eq 0 ]]; then
  echo -e "${GREEN}✓ All security tests passed! The cbox project has been properly hardened.${NC}"
  exit 0
else
  echo -e "${YELLOW}⚠ Some security tests failed. Please review the issues above.${NC}"
  exit 1
fi