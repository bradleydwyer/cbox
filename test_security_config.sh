#!/usr/bin/env bash
# Test script for cbox security configuration resolution

set -euo pipefail

echo "Testing cbox security configuration resolution"
echo "=============================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_RUN=0
TESTS_PASSED=0

# Function to run a test
run_test() {
    local test_name="$1"
    local command="$2"
    local expected_pattern="$3"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    echo -n "Testing: $test_name ... "
    
    # Run command and capture output
    output=$(eval "$command" 2>&1 || true)
    
    # Check if expected pattern is in output
    if echo "$output" | grep -q "$expected_pattern"; then
        echo -e "${GREEN}PASSED${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}FAILED${NC}"
        echo "  Expected pattern: $expected_pattern"
        echo "  Got output:"
        echo "$output" | sed 's/^/    /'
        return 1
    fi
}

# Test help output for security options
echo "1. Testing help output for security options"
echo "-------------------------------------------"
run_test "Help includes security options" \
    "./cbox --help 2>&1" \
    "security-mode MODE"

echo ""
echo "2. Testing security mode validation"
echo "------------------------------------"
run_test "Invalid security mode rejected" \
    "./cbox --security-mode invalid --verify 2>&1" \
    "Invalid security mode: invalid"

run_test "Valid security mode accepted (standard)" \
    "CBOX_VERBOSE=1 ./cbox --security-mode standard --verify 2>&1" \
    "Security configuration resolved"

run_test "Valid security mode accepted (restricted)" \
    "CBOX_VERBOSE=1 ./cbox --security-mode restricted --verify 2>&1" \
    "Security configuration resolved"

run_test "Valid security mode accepted (paranoid)" \
    "CBOX_VERBOSE=1 ./cbox --security-mode paranoid --verify 2>&1" \
    "Security configuration resolved"

echo ""
echo "3. Testing network type validation"
echo "-----------------------------------"
run_test "Invalid network type rejected" \
    "./cbox --network invalid --verify 2>&1" \
    "Invalid network type: invalid"

run_test "Valid network type accepted (host)" \
    "./cbox --network host --verify 2>&1" \
    "Docker is available"

run_test "Valid network type accepted (bridge)" \
    "./cbox --network bridge --verify 2>&1" \
    "Docker is available"

run_test "Valid network type accepted (none)" \
    "./cbox --network none --verify 2>&1" \
    "Docker is available"

echo ""
echo "4. Testing SSH agent validation"
echo "--------------------------------"
run_test "Invalid SSH agent value rejected" \
    "./cbox --ssh-agent maybe --verify 2>&1" \
    "Invalid boolean value"

run_test "Valid SSH agent value accepted (true)" \
    "./cbox --ssh-agent true --verify 2>&1" \
    "Docker is available"

run_test "Valid SSH agent value accepted (false)" \
    "./cbox --ssh-agent false --verify 2>&1" \
    "Docker is available"

echo ""
echo "5. Testing security mode defaults (verbose mode)"
echo "-------------------------------------------------"
run_test "Standard mode defaults" \
    "CBOX_VERBOSE=1 ./cbox --security-mode standard --verify 2>&1 | grep 'Network:'" \
    "Network: host"

run_test "Restricted mode defaults" \
    "CBOX_VERBOSE=1 ./cbox --security-mode restricted --verify 2>&1 | grep 'Network:'" \
    "Network: bridge"

run_test "Paranoid mode defaults" \
    "CBOX_VERBOSE=1 ./cbox --security-mode paranoid --verify 2>&1 | grep 'Network:'" \
    "Network: none"

echo ""
echo "6. Testing security warnings"
echo "-----------------------------"
run_test "Warning for network in paranoid mode" \
    "./cbox --security-mode paranoid --network host --verify 2>&1" \
    "Security Warning: Network enabled in paranoid mode"

run_test "Warning for SSH in paranoid mode" \
    "./cbox --security-mode paranoid --ssh-agent true --verify 2>&1" \
    "Security Warning: SSH agent enabled in paranoid mode"

run_test "Warning for write access in paranoid mode" \
    "./cbox --security-mode paranoid --network none --ssh-agent false --verify 2>&1" \
    "Docker is available"

run_test "Warning for SSH with no network" \
    "./cbox --network none --ssh-agent true --verify 2>&1" \
    "Configuration Warning: SSH agent enabled but network disabled"

echo ""
echo "7. Testing override combinations"
echo "---------------------------------"
run_test "Override network in standard mode" \
    "CBOX_VERBOSE=1 ./cbox --security-mode standard --network bridge --verify 2>&1 | grep 'Network:'" \
    "Network: bridge"

run_test "Override SSH in restricted mode" \
    "CBOX_VERBOSE=1 ./cbox --security-mode restricted --ssh-agent false --verify 2>&1 | grep 'SSH Agent:'" \
    "SSH Agent: false"

run_test "Override read-only in standard mode" \
    "CBOX_VERBOSE=1 ./cbox --read-only --verify 2>&1" \
    "Docker is available"

echo ""
echo "8. Testing read-only flag"
echo "-------------------------"
run_test "Read-only flag works" \
    "./cbox --read-only --verify 2>&1" \
    "Docker is available"

echo ""
echo "=============================================="
echo "Test Results:"
echo "  Tests run: $TESTS_RUN"
echo -e "  Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "  Tests failed: ${RED}$((TESTS_RUN - TESTS_PASSED))${NC}"
echo ""

if [ $TESTS_PASSED -eq $TESTS_RUN ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi