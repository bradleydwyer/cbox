#!/usr/bin/env bash
# End-to-end CLI argument parsing tests for cbox security modes
# Tests complete command-line argument parsing and validation

set -euo pipefail

# Test configuration
TEST_FILE="$(basename "${BASH_SOURCE[0]}")"
TEST_DIR="$(dirname "${BASH_SOURCE[0]}")"
WORK_DIR="$(dirname "$TEST_DIR")"

echo "End-to-End CLI Argument Parsing Test Suite"
echo "=========================================="
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

# Test execution framework with timeout
run_cli_test() {
    local test_name="$1"
    local command="$2"
    local expected_result="${3:-success}"
    local timeout_seconds="${4:-5}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    echo -n "[$TESTS_RUN] Testing: $test_name ... "
    
    local output
    local exit_code
    
    # Run command with timeout to prevent hanging
    if output=$(timeout "$timeout_seconds" bash -c "cd '$WORK_DIR' && $command" 2>&1); then
        exit_code=0
    else
        exit_code=$?
        # Handle timeout (exit code 124)
        if [[ $exit_code -eq 124 ]]; then
            output="$output\nTIMEOUT: Command exceeded ${timeout_seconds}s"
        fi
    fi
    
    if [[ $exit_code -eq 0 ]]; then
        if [[ "$expected_result" == "success" ]]; then
            echo -e "${GREEN}PASSED${NC}"
            TESTS_PASSED=$((TESTS_PASSED + 1))
            return 0
        else
            echo -e "${RED}FAILED${NC} (expected failure but got success)"
            echo "  Output: $output" | head -2
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
            echo "  Exit code: $exit_code"
            echo "  Output: $output" | head -2
            TESTS_FAILED=$((TESTS_FAILED + 1))
            return 1
        fi
    fi
}

# Test that checks for specific patterns in CLI output
run_output_test() {
    local test_name="$1"
    local command="$2"
    local expected_pattern="$3"
    local should_match="${4:-true}"
    local timeout_seconds="${5:-5}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    echo -n "[$TESTS_RUN] Testing: $test_name ... "
    
    local output
    if output=$(timeout "$timeout_seconds" bash -c "cd '$WORK_DIR' && $command" 2>&1 || true); then
        if [[ "$should_match" == "true" ]]; then
            if echo "$output" | grep -q "$expected_pattern"; then
                echo -e "${GREEN}PASSED${NC}"
                TESTS_PASSED=$((TESTS_PASSED + 1))
                return 0
            else
                echo -e "${RED}FAILED${NC} (pattern not found)"
                echo "  Expected pattern: $expected_pattern"
                echo "  Got output: $output" | head -3
                TESTS_FAILED=$((TESTS_FAILED + 1))
                return 1
            fi
        else
            if ! echo "$output" | grep -q "$expected_pattern"; then
                echo -e "${GREEN}PASSED${NC} (pattern correctly absent)"
                TESTS_PASSED=$((TESTS_PASSED + 1))
                return 0
            else
                echo -e "${RED}FAILED${NC} (unexpected pattern found)"
                echo "  Should not match: $expected_pattern"
                TESTS_FAILED=$((TESTS_FAILED + 1))
                return 1
            fi
        fi
    else
        echo -e "${RED}FAILED${NC} (command timeout or error)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test basic CLI help and version
test_basic_cli() {
    echo -e "${BLUE}1. Basic CLI Functionality${NC}"
    echo "-------------------------"
    
    run_output_test "Help flag shows usage information" \
        "./cbox --help" \
        "Usage: cbox"
    
    run_output_test "Version flag shows version" \
        "./cbox --version" \
        "cbox version"
    
    run_output_test "Help includes security mode option" \
        "./cbox --help" \
        "--security-mode MODE"
    
    run_output_test "Help includes network option" \
        "./cbox --help" \
        "--network TYPE"
    
    run_output_test "Help includes SSH agent option" \
        "./cbox --help" \
        "--ssh-agent BOOL"
    
    run_output_test "Help includes read-only option" \
        "./cbox --help" \
        "--read-only"
    
    run_output_test "Help shows security mode examples" \
        "./cbox --help" \
        "--security-mode restricted"
    
    echo ""
}

# Test security mode argument parsing
test_security_mode_parsing() {
    echo -e "${BLUE}2. Security Mode Argument Parsing${NC}"
    echo "-------------------------------"
    
    # Valid security modes (using --verify to avoid Docker execution)
    run_cli_test "Standard security mode accepted" \
        "./cbox --security-mode standard --verify" \
        "success"
    
    run_cli_test "Restricted security mode accepted" \
        "./cbox --security-mode restricted --verify" \
        "success"
    
    run_cli_test "Paranoid security mode accepted" \
        "./cbox --security-mode paranoid --verify" \
        "success"
    
    # Invalid security modes
    run_cli_test "Invalid security mode rejected" \
        "./cbox --security-mode invalid --verify" \
        "failure"
    
    run_cli_test "Empty security mode rejected" \
        "./cbox --security-mode '' --verify" \
        "failure"
    
    run_cli_test "Numeric security mode rejected" \
        "./cbox --security-mode 123 --verify" \
        "failure"
    
    # Missing argument
    run_cli_test "Security mode without argument fails" \
        "./cbox --security-mode" \
        "failure"
    
    # Case sensitivity
    run_cli_test "Uppercase security mode rejected (case sensitive)" \
        "./cbox --security-mode STANDARD --verify" \
        "failure"
    
    echo ""
}

# Test network type argument parsing
test_network_parsing() {
    echo -e "${BLUE}3. Network Type Argument Parsing${NC}"
    echo "-----------------------------"
    
    # Valid network types
    run_cli_test "Host network type accepted" \
        "./cbox --network host --verify" \
        "success"
    
    run_cli_test "Bridge network type accepted" \
        "./cbox --network bridge --verify" \
        "success"
    
    run_cli_test "None network type accepted" \
        "./cbox --network none --verify" \
        "success"
    
    # Invalid network types
    run_cli_test "Invalid network type rejected" \
        "./cbox --network invalid --verify" \
        "failure"
    
    run_cli_test "Container network type rejected" \
        "./cbox --network container --verify" \
        "failure"
    
    run_cli_test "Overlay network type rejected" \
        "./cbox --network overlay --verify" \
        "failure"
    
    # Missing argument
    run_cli_test "Network flag without argument fails" \
        "./cbox --network" \
        "failure"
    
    # Case sensitivity
    run_cli_test "Uppercase network type rejected" \
        "./cbox --network HOST --verify" \
        "failure"
    
    echo ""
}

# Test SSH agent argument parsing
test_ssh_agent_parsing() {
    echo -e "${BLUE}4. SSH Agent Argument Parsing${NC}"
    echo "---------------------------"
    
    # Valid boolean values
    run_cli_test "SSH agent true accepted" \
        "./cbox --ssh-agent true --verify" \
        "success"
    
    run_cli_test "SSH agent false accepted" \
        "./cbox --ssh-agent false --verify" \
        "success"
    
    # Invalid boolean values
    run_cli_test "SSH agent 'yes' rejected" \
        "./cbox --ssh-agent yes --verify" \
        "failure"
    
    run_cli_test "SSH agent 'no' rejected" \
        "./cbox --ssh-agent no --verify" \
        "failure"
    
    run_cli_test "SSH agent '1' rejected" \
        "./cbox --ssh-agent 1 --verify" \
        "failure"
    
    run_cli_test "SSH agent '0' rejected" \
        "./cbox --ssh-agent 0 --verify" \
        "failure"
    
    # Missing argument
    run_cli_test "SSH agent flag without argument fails" \
        "./cbox --ssh-agent" \
        "failure"
    
    # Case sensitivity
    run_cli_test "SSH agent 'TRUE' rejected (case sensitive)" \
        "./cbox --ssh-agent TRUE --verify" \
        "failure"
    
    echo ""
}

# Test read-only flag parsing
test_read_only_parsing() {
    echo -e "${BLUE}5. Read-Only Flag Parsing${NC}"
    echo "-----------------------"
    
    run_cli_test "Read-only flag accepted" \
        "./cbox --read-only --verify" \
        "success"
    
    run_cli_test "Read-only flag works with security mode" \
        "./cbox --security-mode standard --read-only --verify" \
        "success"
    
    run_cli_test "Read-only flag works with other options" \
        "./cbox --network bridge --read-only --ssh-agent false --verify" \
        "success"
    
    # Read-only flag doesn't take arguments
    run_cli_test "Read-only with argument fails" \
        "./cbox --read-only true --verify" \
        "failure"
    
    echo ""
}

# Test argument combinations
test_argument_combinations() {
    echo -e "${BLUE}6. Argument Combination Tests${NC}"
    echo "---------------------------"
    
    # Valid combinations
    run_cli_test "Security mode with network override" \
        "./cbox --security-mode standard --network bridge --verify" \
        "success"
    
    run_cli_test "Security mode with SSH override" \
        "./cbox --security-mode restricted --ssh-agent false --verify" \
        "success"
    
    run_cli_test "All security options together" \
        "./cbox --security-mode paranoid --network host --ssh-agent true --read-only --verify" \
        "success"
    
    run_cli_test "Multiple overrides on standard mode" \
        "./cbox --security-mode standard --network none --ssh-agent false --read-only --verify" \
        "success"
    
    # Test order independence
    run_cli_test "Options work in different order" \
        "./cbox --read-only --security-mode restricted --ssh-agent false --network none --verify" \
        "success"
    
    run_cli_test "Verify flag works with security options" \
        "./cbox --verify --security-mode paranoid --network bridge" \
        "success"
    
    echo ""
}

# Test error handling and validation messages
test_error_messages() {
    echo -e "${BLUE}7. Error Message Validation${NC}"
    echo "-------------------------"
    
    run_output_test "Invalid security mode shows helpful error" \
        "./cbox --security-mode badmode --verify" \
        "Invalid security mode: badmode"
    
    run_output_test "Invalid security mode lists valid options" \
        "./cbox --security-mode badmode --verify" \
        "Valid modes: standard, restricted, paranoid"
    
    run_output_test "Invalid network type shows helpful error" \
        "./cbox --network badnetwork --verify" \
        "Invalid network type: badnetwork"
    
    run_output_test "Invalid network type lists valid options" \
        "./cbox --network badnetwork --verify" \
        "Valid types: host, bridge, none"
    
    run_output_test "Invalid boolean shows helpful error" \
        "./cbox --ssh-agent maybe --verify" \
        "Invalid boolean value"
    
    run_output_test "Invalid boolean lists valid options" \
        "./cbox --ssh-agent maybe --verify" \
        "Valid values: true, false"
    
    run_output_test "Unknown option shows error" \
        "./cbox --unknown-option --verify" \
        "Unknown option: --unknown-option"
    
    run_output_test "Unknown option suggests help" \
        "./cbox --unknown-option --verify" \
        "Try 'cbox --help'"
    
    echo ""
}

# Test security warnings in CLI output
test_security_warnings() {
    echo -e "${BLUE}8. Security Warning Output${NC}"
    echo "------------------------"
    
    run_output_test "Paranoid mode with network override shows warning" \
        "./cbox --security-mode paranoid --network host --verify" \
        "Security Warning: Network enabled in paranoid mode"
    
    run_output_test "Paranoid mode with SSH enabled shows warning" \
        "./cbox --security-mode paranoid --ssh-agent true --verify" \
        "Security Warning: SSH agent enabled in paranoid mode"
    
    run_output_test "SSH with no network shows configuration warning" \
        "./cbox --network none --ssh-agent true --verify" \
        "Configuration Warning: SSH agent enabled but network disabled"
    
    run_output_test "Restricted mode with host network shows warning" \
        "./cbox --security-mode restricted --network host --verify" \
        "Security Warning: Host network with write access"
    
    run_output_test "Standard mode defaults show no warnings" \
        "./cbox --security-mode standard --verify" \
        "Warning" \
        "false"
    
    echo ""
}

# Test verbose mode output
test_verbose_mode() {
    echo -e "${BLUE}9. Verbose Mode Output${NC}"
    echo "-------------------"
    
    run_output_test "Verbose mode shows configuration details" \
        "CBOX_VERBOSE=1 ./cbox --security-mode restricted --verify" \
        "Security configuration resolved"
    
    run_output_test "Verbose mode shows network setting" \
        "CBOX_VERBOSE=1 ./cbox --security-mode paranoid --verify" \
        "Network: none"
    
    run_output_test "Verbose mode shows SSH agent setting" \
        "CBOX_VERBOSE=1 ./cbox --security-mode standard --verify" \
        "SSH Agent: true"
    
    run_output_test "Verbose mode shows read-only setting" \
        "CBOX_VERBOSE=1 ./cbox --security-mode paranoid --verify" \
        "Read-only: true"
    
    run_output_test "Non-verbose mode is quieter" \
        "CBOX_VERBOSE=0 ./cbox --security-mode standard --verify" \
        "Security configuration resolved" \
        "false"
    
    echo ""
}

# Test environment variable handling
test_environment_variables() {
    echo -e "${BLUE}10. Environment Variable Tests${NC}"
    echo "----------------------------"
    
    run_output_test "CBOX_VERBOSE environment variable works" \
        "CBOX_VERBOSE=1 ./cbox --verify" \
        "Verbose mode enabled"
    
    run_cli_test "Custom memory limit via environment" \
        "CBOX_MEMORY=8g ./cbox --verify" \
        "success"
    
    run_cli_test "Custom CPU limit via environment" \
        "CBOX_CPUS=4 ./cbox --verify" \
        "success"
    
    run_cli_test "Invalid memory format fails" \
        "CBOX_MEMORY=invalid ./cbox --verify" \
        "failure"
    
    run_cli_test "Invalid CPU format fails" \
        "CBOX_CPUS=invalid ./cbox --verify" \
        "failure"
    
    # Test security bypass detection
    run_cli_test "CBOX_BYPASS_SECURITY is blocked" \
        "CBOX_BYPASS_SECURITY=1 ./cbox --verify" \
        "failure"
    
    run_cli_test "BYPASS_SECURITY is blocked" \
        "BYPASS_SECURITY=1 ./cbox --verify" \
        "failure"
    
    echo ""
}

# Test CLI flag combinations and edge cases
test_edge_cases() {
    echo -e "${BLUE}11. Edge Cases and Boundary Conditions${NC}"
    echo "------------------------------------"
    
    # Test double dash handling
    run_cli_test "Double dash separates Claude arguments" \
        "./cbox --security-mode standard --verify -- --help" \
        "success"
    
    run_cli_test "Security flags before double dash work" \
        "./cbox --read-only --security-mode restricted -- chat" \
        "success" \
        "2"
    
    # Test argument parsing edge cases
    run_cli_test "Security mode as last argument works" \
        "./cbox --verify --security-mode paranoid" \
        "success"
    
    run_cli_test "Multiple verify flags work" \
        "./cbox --verify --verify" \
        "success"
    
    # Test with directory argument
    run_cli_test "Directory argument with security options" \
        "./cbox . --security-mode standard --verify" \
        "success"
    
    run_cli_test "Directory argument with double dash" \
        "./cbox . --security-mode restricted -- --version" \
        "success" \
        "2"
    
    echo ""
}

# Test injection prevention
test_injection_prevention() {
    echo -e "${BLUE}12. Command Injection Prevention${NC}"
    echo "------------------------------"
    
    # Test command injection in arguments
    run_cli_test "Command injection in security mode blocked" \
        "./cbox --security-mode 'standard; rm -rf /' --verify" \
        "failure"
    
    run_cli_test "Shell substitution in network type blocked" \
        "./cbox --network 'host\$(whoami)' --verify" \
        "failure"
    
    run_cli_test "Backtick injection in SSH agent blocked" \
        "./cbox --ssh-agent 'true\`id\`' --verify" \
        "failure"
    
    # Test that normal arguments with special characters still work appropriately
    run_cli_test "Legitimate special characters in directory names work" \
        "./cbox '/home/user/my-project' --verify" \
        "success" \
        "3"
    
    echo ""
}

# Main execution
main() {
    echo "Preparing CLI test environment..."
    echo ""
    
    # Verify cbox exists and is executable
    if [[ ! -x "$WORK_DIR/cbox" ]]; then
        echo -e "${RED}ERROR: cbox executable not found at $WORK_DIR/cbox${NC}"
        exit 1
    fi
    
    # Run all test suites
    test_basic_cli
    test_security_mode_parsing
    test_network_parsing
    test_ssh_agent_parsing
    test_read_only_parsing
    test_argument_combinations
    test_error_messages
    test_security_warnings
    test_verbose_mode
    test_environment_variables
    test_edge_cases
    test_injection_prevention
    
    # Print results
    echo "=============================================="
    echo -e "${BLUE}End-to-End CLI Test Results Summary:${NC}"
    echo "  Tests run: $TESTS_RUN"
    echo -e "  Tests passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "  Tests failed: ${RED}$TESTS_FAILED${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "  Result: ${GREEN}ALL TESTS PASSED${NC}"
        echo ""
        echo -e "${GREEN}✓ CLI argument parsing is working correctly${NC}"
        echo -e "${GREEN}✓ Input validation is effective${NC}"
        echo -e "${GREEN}✓ Error messages are helpful and informative${NC}"
        echo -e "${GREEN}✓ Security warnings are displayed appropriately${NC}"
        echo -e "${GREEN}✓ Command injection prevention is working${NC}"
        echo -e "${GREEN}✓ Environment variable handling is secure${NC}"
    else
        echo -e "  Result: ${RED}SOME TESTS FAILED${NC}"
        echo ""
        echo -e "${RED}✗ CLI argument parsing has issues that need attention${NC}"
    fi
    
    echo ""
    
    # Exit with appropriate code
    [[ $TESTS_FAILED -eq 0 ]] && exit 0 || exit 1
}

# Run main function
main "$@"