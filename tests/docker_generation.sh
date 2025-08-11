#!/usr/bin/env bash
# Docker command generation tests for cbox security modes
# Tests the Docker command generation with security configurations

set -euo pipefail

# Test configuration
TEST_FILE="$(basename "${BASH_SOURCE[0]}")"
TEST_DIR="$(dirname "${BASH_SOURCE[0]}")"
WORK_DIR="$(dirname "$TEST_DIR")"

echo "Docker Command Generation Test Suite"
echo "===================================="
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

# Mock Docker execution by intercepting Docker calls
create_docker_mock() {
    # Create a mock docker command that captures arguments instead of executing
    mkdir -p /tmp/cbox_test
    cat > /tmp/cbox_test/docker << 'EOF'
#!/usr/bin/env bash
# Mock docker command for testing
# Captures docker arguments and saves them for validation

# Save all arguments to a file for inspection
echo "DOCKER_COMMAND: $*" > /tmp/cbox_test/docker_args
echo "DOCKER_ARGS_COUNT: $#" >> /tmp/cbox_test/docker_args

# Parse key arguments we care about for security testing
for arg in "$@"; do
    case "$arg" in
        --network)
            echo "NETWORK_FLAG_FOUND: true" >> /tmp/cbox_test/docker_args
            ;;
        --network=*)
            echo "NETWORK_VALUE: ${arg#--network=}" >> /tmp/cbox_test/docker_args
            ;;
        host|bridge|none)
            if [[ "${prev_arg:-}" == "--network" ]]; then
                echo "NETWORK_VALUE: $arg" >> /tmp/cbox_test/docker_args
            fi
            ;;
        -v)
            echo "VOLUME_FLAG_FOUND: true" >> /tmp/cbox_test/docker_args
            ;;
        *:/work:ro)
            echo "READ_ONLY_MOUNT: $arg" >> /tmp/cbox_test/docker_args
            ;;
        *:/work)
            if [[ "$arg" != *":ro" ]]; then
                echo "READ_WRITE_MOUNT: $arg" >> /tmp/cbox_test/docker_args
            fi
            ;;
        *:/ssh-agent)
            echo "SSH_AGENT_MOUNT: $arg" >> /tmp/cbox_test/docker_args
            ;;
        --dns)
            echo "DNS_FLAG_FOUND: true" >> /tmp/cbox_test/docker_args
            ;;
        8.8.8.8|1.1.1.1)
            echo "DNS_SERVER: $arg" >> /tmp/cbox_test/docker_args
            ;;
        --memory)
            echo "MEMORY_FLAG_FOUND: true" >> /tmp/cbox_test/docker_args
            ;;
        --cpus)
            echo "CPUS_FLAG_FOUND: true" >> /tmp/cbox_test/docker_args
            ;;
        --cap-drop=ALL)
            echo "SECURITY_CAP_DROP: true" >> /tmp/cbox_test/docker_args
            ;;
        --cap-add=*)
            echo "SECURITY_CAP_ADD: ${arg#--cap-add=}" >> /tmp/cbox_test/docker_args
            ;;
        --security-opt=no-new-privileges)
            echo "SECURITY_NO_NEW_PRIVS: true" >> /tmp/cbox_test/docker_args
            ;;
        --tmpfs)
            echo "TMPFS_FLAG_FOUND: true" >> /tmp/cbox_test/docker_args
            ;;
    esac
    prev_arg="$arg"
done

# Simulate successful execution
exit 0
EOF
    chmod +x /tmp/cbox_test/docker
    
    # Prepend mock docker to PATH
    export PATH="/tmp/cbox_test:$PATH"
    
    # Clear previous test results
    rm -f /tmp/cbox_test/docker_args
}

# Test execution framework
run_test() {
    local test_name="$1"
    local test_function="$2"
    local expected_result="${3:-success}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    echo -n "[$TESTS_RUN] Testing: $test_name ... "
    
    # Clear previous Docker mock results
    rm -f /tmp/cbox_test/docker_args
    
    local output
    local exit_code
    if output=$(eval "$test_function" 2>&1); then
        exit_code=0
    else
        exit_code=$?
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
            echo "  Output: $output" | head -2
            TESTS_FAILED=$((TESTS_FAILED + 1))
            return 1
        fi
    fi
}

# Test that checks for specific content in Docker args
run_docker_args_test() {
    local test_name="$1"
    local test_function="$2"
    local expected_pattern="$3"
    local should_match="${4:-true}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    echo -n "[$TESTS_RUN] Testing: $test_name ... "
    
    # Clear previous Docker mock results
    rm -f /tmp/cbox_test/docker_args
    
    # Run the test function (which should trigger Docker mock)
    local output
    if output=$(eval "$test_function" 2>/dev/null); then
        # Check if docker_args file was created and contains expected pattern
        if [[ -f /tmp/cbox_test/docker_args ]]; then
            if [[ "$should_match" == "true" ]]; then
                if grep -q "$expected_pattern" /tmp/cbox_test/docker_args; then
                    echo -e "${GREEN}PASSED${NC}"
                    TESTS_PASSED=$((TESTS_PASSED + 1))
                    return 0
                else
                    echo -e "${RED}FAILED${NC} (pattern not found in Docker args)"
                    echo "  Expected pattern: $expected_pattern"
                    echo "  Docker args:"
                    cat /tmp/cbox_test/docker_args | head -5 | sed 's/^/    /'
                    TESTS_FAILED=$((TESTS_FAILED + 1))
                    return 1
                fi
            else
                if ! grep -q "$expected_pattern" /tmp/cbox_test/docker_args; then
                    echo -e "${GREEN}PASSED${NC} (pattern correctly absent)"
                    TESTS_PASSED=$((TESTS_PASSED + 1))
                    return 0
                else
                    echo -e "${RED}FAILED${NC} (unexpected pattern found)"
                    echo "  Should not match: $expected_pattern"
                    echo "  Found in Docker args:"
                    grep "$expected_pattern" /tmp/cbox_test/docker_args | head -3 | sed 's/^/    /'
                    TESTS_FAILED=$((TESTS_FAILED + 1))
                    return 1
                fi
            fi
        else
            echo -e "${RED}FAILED${NC} (Docker not called)"
            echo "  Test function: $test_function"
            TESTS_FAILED=$((TESTS_FAILED + 1))
            return 1
        fi
    else
        echo -e "${RED}FAILED${NC} (test function failed)"
        echo "  Output: $output" | head -2
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test standard mode Docker generation
test_standard_mode_docker() {
    echo -e "${BLUE}1. Standard Mode Docker Generation${NC}"
    echo "--------------------------------"
    
    run_docker_args_test "Standard mode uses host network" \
        "cd '$WORK_DIR' && timeout 5 ./cbox --security-mode standard --verify 2>/dev/null || true" \
        "NETWORK_VALUE: host"
    
    run_docker_args_test "Standard mode enables read-write volumes" \
        "cd '$WORK_DIR' && timeout 5 ./cbox --security-mode standard --verify 2>/dev/null || true" \
        "READ_WRITE_MOUNT:" \
        "true"
    
    run_docker_args_test "Standard mode does not use read-only volumes by default" \
        "cd '$WORK_DIR' && timeout 5 ./cbox --security-mode standard --verify 2>/dev/null || true" \
        "READ_ONLY_MOUNT:" \
        "false"
    
    run_docker_args_test "Standard mode includes security hardening" \
        "cd '$WORK_DIR' && timeout 5 ./cbox --security-mode standard --verify 2>/dev/null || true" \
        "SECURITY_CAP_DROP: true"
    
    run_docker_args_test "Standard mode includes no-new-privileges" \
        "cd '$WORK_DIR' && timeout 5 ./cbox --security-mode standard --verify 2>/dev/null || true" \
        "SECURITY_NO_NEW_PRIVS: true"
    
    run_docker_args_test "Standard mode includes memory limits" \
        "cd '$WORK_DIR' && timeout 5 ./cbox --security-mode standard --verify 2>/dev/null || true" \
        "MEMORY_FLAG_FOUND: true"
    
    run_docker_args_test "Standard mode includes CPU limits" \
        "cd '$WORK_DIR' && timeout 5 ./cbox --security-mode standard --verify 2>/dev/null || true" \
        "CPUS_FLAG_FOUND: true"
    
    echo ""
}

# Test restricted mode Docker generation
test_restricted_mode_docker() {
    echo -e "${BLUE}2. Restricted Mode Docker Generation${NC}"
    echo "----------------------------------"
    
    run_docker_args_test "Restricted mode uses bridge network" \
        "cd '$WORK_DIR' && timeout 5 ./cbox --security-mode restricted --verify 2>/dev/null || true" \
        "NETWORK_VALUE: bridge"
    
    run_docker_args_test "Restricted mode includes DNS servers" \
        "cd '$WORK_DIR' && timeout 5 ./cbox --security-mode restricted --verify 2>/dev/null || true" \
        "DNS_FLAG_FOUND: true"
    
    run_docker_args_test "Restricted mode includes 8.8.8.8 DNS" \
        "cd '$WORK_DIR' && timeout 5 ./cbox --security-mode restricted --verify 2>/dev/null || true" \
        "DNS_SERVER: 8.8.8.8"
    
    run_docker_args_test "Restricted mode includes 1.1.1.1 DNS" \
        "cd '$WORK_DIR' && timeout 5 ./cbox --security-mode restricted --verify 2>/dev/null || true" \
        "DNS_SERVER: 1.1.1.1"
    
    run_docker_args_test "Restricted mode enables read-write volumes" \
        "cd '$WORK_DIR' && timeout 5 ./cbox --security-mode restricted --verify 2>/dev/null || true" \
        "READ_WRITE_MOUNT:" \
        "true"
    
    echo ""
}

# Test paranoid mode Docker generation
test_paranoid_mode_docker() {
    echo -e "${BLUE}3. Paranoid Mode Docker Generation${NC}"
    echo "--------------------------------"
    
    run_docker_args_test "Paranoid mode uses no network" \
        "cd '$WORK_DIR' && timeout 5 ./cbox --security-mode paranoid --verify 2>/dev/null || true" \
        "NETWORK_VALUE: none"
    
    run_docker_args_test "Paranoid mode enables read-only volumes" \
        "cd '$WORK_DIR' && timeout 5 ./cbox --security-mode paranoid --verify 2>/dev/null || true" \
        "READ_ONLY_MOUNT:"
    
    run_docker_args_test "Paranoid mode does not include DNS servers" \
        "cd '$WORK_DIR' && timeout 5 ./cbox --security-mode paranoid --verify 2>/dev/null || true" \
        "DNS_FLAG_FOUND: true" \
        "false"
    
    run_docker_args_test "Paranoid mode does not mount SSH agent" \
        "cd '$WORK_DIR' && SSH_AUTH_SOCK=/tmp/fake-ssh timeout 5 ./cbox --security-mode paranoid --verify 2>/dev/null || true" \
        "SSH_AGENT_MOUNT:" \
        "false"
    
    echo ""
}

# Test override behavior in Docker generation
test_override_docker_generation() {
    echo -e "${BLUE}4. Override Docker Generation${NC}"
    echo "----------------------------"
    
    run_docker_args_test "Network override changes Docker network flag" \
        "cd '$WORK_DIR' && timeout 5 ./cbox --security-mode standard --network bridge --verify 2>/dev/null || true" \
        "NETWORK_VALUE: bridge"
    
    run_docker_args_test "Read-only override adds :ro to volume mount" \
        "cd '$WORK_DIR' && timeout 5 ./cbox --security-mode standard --read-only --verify 2>/dev/null || true" \
        "READ_ONLY_MOUNT:"
    
    run_docker_args_test "SSH agent false prevents SSH mount even when available" \
        "cd '$WORK_DIR' && SSH_AUTH_SOCK=/tmp/fake-ssh timeout 5 ./cbox --security-mode standard --ssh-agent false --verify 2>/dev/null || true" \
        "SSH_AGENT_MOUNT:" \
        "false"
    
    # Test that overriding paranoid mode network changes Docker args
    run_docker_args_test "Paranoid mode network override to host" \
        "cd '$WORK_DIR' && timeout 5 ./cbox --security-mode paranoid --network host --verify 2>/dev/null || true" \
        "NETWORK_VALUE: host"
    
    echo ""
}

# Test SSH agent handling
test_ssh_agent_handling() {
    echo -e "${BLUE}5. SSH Agent Handling${NC}"
    echo "-------------------"
    
    # Test with SSH_AUTH_SOCK set
    run_docker_args_test "SSH agent mounted when enabled and available" \
        "cd '$WORK_DIR' && SSH_AUTH_SOCK=/tmp/fake-ssh timeout 5 ./cbox --security-mode standard --ssh-agent true --verify 2>/dev/null || true" \
        "SSH_AGENT_MOUNT: /tmp/fake-ssh:/ssh-agent"
    
    # Test without SSH_AUTH_SOCK
    run_docker_args_test "SSH agent not mounted when SSH_AUTH_SOCK not set" \
        "cd '$WORK_DIR' && unset SSH_AUTH_SOCK && timeout 5 ./cbox --security-mode standard --ssh-agent true --verify 2>/dev/null || true" \
        "SSH_AGENT_MOUNT:" \
        "false"
    
    # Test SSH agent explicitly disabled
    run_docker_args_test "SSH agent not mounted when explicitly disabled" \
        "cd '$WORK_DIR' && SSH_AUTH_SOCK=/tmp/fake-ssh timeout 5 ./cbox --security-mode standard --ssh-agent false --verify 2>/dev/null || true" \
        "SSH_AGENT_MOUNT:" \
        "false"
    
    echo ""
}

# Test security hardening features
test_security_hardening() {
    echo -e "${BLUE}6. Security Hardening Features${NC}"
    echo "-----------------------------"
    
    run_docker_args_test "All modes include cap-drop=ALL" \
        "cd '$WORK_DIR' && timeout 5 ./cbox --security-mode restricted --verify 2>/dev/null || true" \
        "SECURITY_CAP_DROP: true"
    
    run_docker_args_test "Security capabilities are added back selectively" \
        "cd '$WORK_DIR' && timeout 5 ./cbox --security-mode standard --verify 2>/dev/null || true" \
        "SECURITY_CAP_ADD: CHOWN"
    
    run_docker_args_test "Required capabilities include SETUID" \
        "cd '$WORK_DIR' && timeout 5 ./cbox --security-mode standard --verify 2>/dev/null || true" \
        "SECURITY_CAP_ADD: SETUID"
    
    run_docker_args_test "Required capabilities include SETGID" \
        "cd '$WORK_DIR' && timeout 5 ./cbox --security-mode standard --verify 2>/dev/null || true" \
        "SECURITY_CAP_ADD: SETGID"
    
    run_docker_args_test "No-new-privileges security option is set" \
        "cd '$WORK_DIR' && timeout 5 ./cbox --security-mode paranoid --verify 2>/dev/null || true" \
        "SECURITY_NO_NEW_PRIVS: true"
    
    run_docker_args_test "Tmpfs mounts are created for security" \
        "cd '$WORK_DIR' && timeout 5 ./cbox --security-mode standard --verify 2>/dev/null || true" \
        "TMPFS_FLAG_FOUND: true"
    
    echo ""
}

# Test resource limit application
test_resource_limits() {
    echo -e "${BLUE}7. Resource Limit Application${NC}"
    echo "----------------------------"
    
    run_docker_args_test "Memory limits are applied" \
        "cd '$WORK_DIR' && timeout 5 ./cbox --security-mode standard --verify 2>/dev/null || true" \
        "MEMORY_FLAG_FOUND: true"
    
    run_docker_args_test "CPU limits are applied" \
        "cd '$WORK_DIR' && timeout 5 ./cbox --security-mode standard --verify 2>/dev/null || true" \
        "CPUS_FLAG_FOUND: true"
    
    run_docker_args_test "Custom memory limit via environment" \
        "cd '$WORK_DIR' && CBOX_MEMORY=8g timeout 5 ./cbox --verify 2>/dev/null || true" \
        "MEMORY_FLAG_FOUND: true"
    
    run_docker_args_test "Custom CPU limit via environment" \
        "cd '$WORK_DIR' && CBOX_CPUS=4 timeout 5 ./cbox --verify 2>/dev/null || true" \
        "CPUS_FLAG_FOUND: true"
    
    echo ""
}

# Test volume mount generation
test_volume_mounts() {
    echo -e "${BLUE}8. Volume Mount Generation${NC}"
    echo "------------------------"
    
    # Test read-write mounts
    run_docker_args_test "Standard mode creates read-write work mount" \
        "cd '$WORK_DIR' && timeout 5 ./cbox --security-mode standard --verify 2>/dev/null || true" \
        "READ_WRITE_MOUNT:"
    
    # Test read-only mounts
    run_docker_args_test "Read-only flag creates read-only work mount" \
        "cd '$WORK_DIR' && timeout 5 ./cbox --read-only --verify 2>/dev/null || true" \
        "READ_ONLY_MOUNT:"
    
    # Test that paranoid mode creates read-only mounts
    run_docker_args_test "Paranoid mode creates read-only work mount" \
        "cd '$WORK_DIR' && timeout 5 ./cbox --security-mode paranoid --verify 2>/dev/null || true" \
        "READ_ONLY_MOUNT:"
    
    # Test volume flag presence
    run_docker_args_test "Volume flags are present" \
        "cd '$WORK_DIR' && timeout 5 ./cbox --verify 2>/dev/null || true" \
        "VOLUME_FLAG_FOUND: true"
    
    echo ""
}

# Main execution
main() {
    echo "Setting up Docker mock environment..."
    create_docker_mock
    echo ""
    
    # Run all test suites
    test_standard_mode_docker
    test_restricted_mode_docker
    test_paranoid_mode_docker
    test_override_docker_generation
    test_ssh_agent_handling
    test_security_hardening
    test_resource_limits
    test_volume_mounts
    
    # Print results
    echo "=============================================="
    echo -e "${BLUE}Docker Generation Test Results Summary:${NC}"
    echo "  Tests run: $TESTS_RUN"
    echo -e "  Tests passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "  Tests failed: ${RED}$TESTS_FAILED${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "  Result: ${GREEN}ALL TESTS PASSED${NC}"
        echo ""
        echo -e "${GREEN}✓ Docker commands are generated correctly for all security modes${NC}"
        echo -e "${GREEN}✓ Network configurations are applied properly${NC}"
        echo -e "${GREEN}✓ Volume mounts respect read-only settings${NC}"
        echo -e "${GREEN}✓ SSH agent handling works as expected${NC}"
        echo -e "${GREEN}✓ Security hardening features are included${NC}"
        echo -e "${GREEN}✓ Resource limits are properly applied${NC}"
    else
        echo -e "  Result: ${RED}SOME TESTS FAILED${NC}"
        echo ""
        echo -e "${RED}✗ Docker command generation has issues that need attention${NC}"
    fi
    
    echo ""
    
    # Cleanup
    rm -rf /tmp/cbox_test
    
    # Exit with appropriate code
    [[ $TESTS_FAILED -eq 0 ]] && exit 0 || exit 1
}

# Run main function
main "$@"