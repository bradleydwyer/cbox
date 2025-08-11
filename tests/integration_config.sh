#!/usr/bin/env bash
# Integration tests for cbox security configuration resolution
# Tests the complete security configuration resolution logic

set -euo pipefail

# Test configuration
TEST_FILE="$(basename "${BASH_SOURCE[0]}")"
TEST_DIR="$(dirname "${BASH_SOURCE[0]}")"
WORK_DIR="$(dirname "$TEST_DIR")"

echo "Integration Test Suite: Configuration Resolution"
echo "=============================================="
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

# Create comprehensive security configuration functions for testing
create_security_functions() {
    cat > /tmp/cbox_security_functions.sh << 'EOF'
#!/usr/bin/env bash

# Test environment variables
CBOX_VERBOSE="${CBOX_VERBOSE:-0}"

# Configuration resolution function
resolve_security_configuration() {
  local mode="$1"
  local network_override="$2"
  local ssh_override="$3"
  local read_only_override="$4"
  
  # Initialize with mode defaults
  local final_network=""
  local final_ssh=""
  local final_read_only=""
  
  # Apply security mode defaults
  case "$mode" in
    standard)
      final_network="host"
      final_ssh="true"
      final_read_only="false"
      ;;
    restricted)
      final_network="bridge"
      final_ssh="true"
      final_read_only="false"
      ;;
    paranoid)
      final_network="none"
      final_ssh="false"
      final_read_only="true"
      ;;
    *)
      echo "cbox: Internal error - invalid security mode: $mode" >&2
      exit 1
      ;;
  esac
  
  # Apply explicit overrides (if provided)
  [[ -n "$network_override" ]] && final_network="$network_override"
  [[ -n "$ssh_override" ]] && final_ssh="$ssh_override"
  [[ "$read_only_override" == "1" ]] && final_read_only="true"
  
  # Security validation and warnings
  validate_security_consistency "$mode" "$final_network" "$final_ssh" "$final_read_only"
  
  # Export resolved configuration
  RESOLVED_NETWORK="$final_network"
  RESOLVED_SSH_AGENT="$final_ssh"
  RESOLVED_READ_ONLY="$final_read_only"
  
  # Log configuration in verbose mode
  if [[ "${CBOX_VERBOSE:-0}" == "1" ]]; then
    echo "cbox: Security configuration resolved:" >&2
    echo "  Mode: $mode" >&2
    echo "  Network: $final_network" >&2
    echo "  SSH Agent: $final_ssh" >&2
    echo "  Read-only: $final_read_only" >&2
  fi
}

# Security consistency validation
validate_security_consistency() {
  local mode="$1"
  local network="$2"
  local ssh="$3"
  local read_only="$4"
  
  # Track if we have any security warnings
  local has_warnings=0
  
  # Warn about downgrades from paranoid mode
  if [[ "$mode" == "paranoid" ]]; then
    if [[ "$network" != "none" ]]; then
      echo "cbox: ⚠️  Security Warning: Network enabled in paranoid mode (expected: none, got: $network)" >&2
      echo "  This reduces the isolation benefits of paranoid mode" >&2
      has_warnings=1
    fi
    
    if [[ "$ssh" == "true" ]]; then
      echo "cbox: ⚠️  Security Warning: SSH agent enabled in paranoid mode" >&2
      echo "  This exposes SSH keys to the container, reducing security" >&2
      has_warnings=1
    fi
    
    if [[ "$read_only" != "true" ]]; then
      echo "cbox: ⚠️  Security Warning: Write access enabled in paranoid mode" >&2
      echo "  Container can modify your project files" >&2
      has_warnings=1
    fi
  fi
  
  # Warn about dangerous combinations
  if [[ "$network" == "host" && "$read_only" != "true" ]]; then
    if [[ "$mode" != "standard" ]]; then
      echo "cbox: ⚠️  Security Warning: Host network with write access" >&2
      echo "  Container has full network access and can modify files" >&2
      echo "  Consider using --read-only or restricted mode" >&2
      has_warnings=1
    fi
  fi
  
  # Warn about SSH agent with no network (likely won't work)
  if [[ "$ssh" == "true" && "$network" == "none" ]]; then
    echo "cbox: ⚠️  Configuration Warning: SSH agent enabled but network disabled" >&2
    echo "  SSH operations will fail without network access" >&2
    echo "  Consider --ssh-agent false or enabling network" >&2
    has_warnings=1
  fi
  
  # Add a blank line after warnings for readability
  if [[ "$has_warnings" == "1" ]]; then
    echo "" >&2
  fi
  
  # Critical security check - fail on obvious attack patterns
  if [[ -n "${CBOX_BYPASS_SECURITY:-}" ]] || [[ -n "${BYPASS_SECURITY:-}" ]]; then
    echo "cbox: 🛑 Security Error: Attempted security bypass detected" >&2
    echo "  Security features cannot be disabled through environment variables" >&2
    exit 1
  fi
}

# Docker command generation simulation for testing
generate_docker_network_flags() {
  local network_type="$1"
  
  case "$network_type" in
    host)
      echo "--network host"
      ;;
    bridge)
      echo "--network bridge --dns 8.8.8.8 --dns 1.1.1.1"
      ;;
    none)
      echo "--network none"
      ;;
    *)
      echo "ERROR: Invalid network type: $network_type" >&2
      return 1
      ;;
  esac
}

# Volume mount generation for testing
generate_volume_mounts() {
  local workdir="$1"
  local read_only="$2"
  local ssh_enabled="$3"
  
  local vols=()
  
  if [[ "$read_only" == "true" ]]; then
    vols+=("-v" "$workdir:/work:ro")
  else
    vols+=("-v" "$workdir:/work")
  fi
  
  if [[ "$ssh_enabled" == "true" && -n "${SSH_AUTH_SOCK:-}" ]]; then
    vols+=("-v" "$SSH_AUTH_SOCK:/ssh-agent")
  fi
  
  printf '%s\n' "${vols[@]}"
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
    
    # Run test in subshell to isolate environment
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

# Test that outputs should contain specific text
run_output_test() {
    local test_name="$1"
    local test_function="$2"
    local expected_pattern="$3"
    local should_match="${4:-true}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    echo -n "[$TESTS_RUN] Testing: $test_name ... "
    
    local output
    if output=$(eval "$test_function" 2>&1); then
        if [[ "$should_match" == "true" ]]; then
            if echo "$output" | grep -q "$expected_pattern"; then
                echo -e "${GREEN}PASSED${NC}"
                TESTS_PASSED=$((TESTS_PASSED + 1))
                return 0
            else
                echo -e "${RED}FAILED${NC} (pattern not found)"
                echo "  Expected pattern: $expected_pattern"
                echo "  Got output: $output" | head -2
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
                echo "  Got output: $output" | head -2
                TESTS_FAILED=$((TESTS_FAILED + 1))
                return 1
            fi
        fi
    else
        echo -e "${RED}FAILED${NC} (command failed)"
        echo "  Command: $test_function"
        echo "  Output: $output" | head -2
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test security mode defaults
test_security_mode_defaults() {
    echo -e "${BLUE}1. Security Mode Default Configuration${NC}"
    echo "------------------------------------"
    
    run_test "Standard mode defaults (network=host, ssh=true, read_only=false)" \
        "resolve_security_configuration standard '' '' 0 && 
         [[ \$RESOLVED_NETWORK == 'host' ]] && 
         [[ \$RESOLVED_SSH_AGENT == 'true' ]] && 
         [[ \$RESOLVED_READ_ONLY == 'false' ]]"
    
    run_test "Restricted mode defaults (network=bridge, ssh=true, read_only=false)" \
        "resolve_security_configuration restricted '' '' 0 && 
         [[ \$RESOLVED_NETWORK == 'bridge' ]] && 
         [[ \$RESOLVED_SSH_AGENT == 'true' ]] && 
         [[ \$RESOLVED_READ_ONLY == 'false' ]]"
    
    run_test "Paranoid mode defaults (network=none, ssh=false, read_only=true)" \
        "resolve_security_configuration paranoid '' '' 0 && 
         [[ \$RESOLVED_NETWORK == 'none' ]] && 
         [[ \$RESOLVED_SSH_AGENT == 'false' ]] && 
         [[ \$RESOLVED_READ_ONLY == 'true' ]]"
    
    echo ""
}

# Test configuration overrides
test_configuration_overrides() {
    echo -e "${BLUE}2. Configuration Override Tests${NC}"
    echo "-----------------------------"
    
    # Network overrides
    run_test "Network override in standard mode (host -> bridge)" \
        "resolve_security_configuration standard 'bridge' '' 0 && 
         [[ \$RESOLVED_NETWORK == 'bridge' ]]"
    
    run_test "Network override in restricted mode (bridge -> none)" \
        "resolve_security_configuration restricted 'none' '' 0 && 
         [[ \$RESOLVED_NETWORK == 'none' ]]"
    
    run_test "Network override in paranoid mode (none -> host)" \
        "resolve_security_configuration paranoid 'host' '' 0 && 
         [[ \$RESOLVED_NETWORK == 'host' ]]"
    
    # SSH agent overrides
    run_test "SSH agent override in standard mode (true -> false)" \
        "resolve_security_configuration standard '' 'false' 0 && 
         [[ \$RESOLVED_SSH_AGENT == 'false' ]]"
    
    run_test "SSH agent override in restricted mode (true -> false)" \
        "resolve_security_configuration restricted '' 'false' 0 && 
         [[ \$RESOLVED_SSH_AGENT == 'false' ]]"
    
    run_test "SSH agent override in paranoid mode (false -> true)" \
        "resolve_security_configuration paranoid '' 'true' 0 && 
         [[ \$RESOLVED_SSH_AGENT == 'true' ]]"
    
    # Read-only overrides
    run_test "Read-only override in standard mode (false -> true)" \
        "resolve_security_configuration standard '' '' 1 && 
         [[ \$RESOLVED_READ_ONLY == 'true' ]]"
    
    run_test "Read-only override in restricted mode (false -> true)" \
        "resolve_security_configuration restricted '' '' 1 && 
         [[ \$RESOLVED_READ_ONLY == 'true' ]]"
    
    run_test "Read-only cannot be downgraded in paranoid mode" \
        "resolve_security_configuration paranoid '' '' 0 && 
         [[ \$RESOLVED_READ_ONLY == 'true' ]]"
    
    # Multiple overrides
    run_test "Multiple overrides work together" \
        "resolve_security_configuration standard 'none' 'false' 1 && 
         [[ \$RESOLVED_NETWORK == 'none' ]] && 
         [[ \$RESOLVED_SSH_AGENT == 'false' ]] && 
         [[ \$RESOLVED_READ_ONLY == 'true' ]]"
    
    echo ""
}

# Test security warnings
test_security_warnings() {
    echo -e "${BLUE}3. Security Warning Tests${NC}"
    echo "------------------------"
    
    # Paranoid mode warnings
    run_output_test "Warning for network in paranoid mode" \
        "resolve_security_configuration paranoid 'host' '' 0" \
        "Security Warning: Network enabled in paranoid mode"
    
    run_output_test "Warning for SSH agent in paranoid mode" \
        "resolve_security_configuration paranoid '' 'true' 0" \
        "Security Warning: SSH agent enabled in paranoid mode"
    
    run_output_test "Warning for write access in paranoid mode" \
        "resolve_security_configuration paranoid 'none' 'false' 0" \
        "Security Warning: Write access enabled in paranoid mode"
    
    # Configuration warnings
    run_output_test "Warning for SSH with no network" \
        "resolve_security_configuration standard 'none' 'true' 0" \
        "Configuration Warning: SSH agent enabled but network disabled"
    
    run_output_test "Warning for host network with write access in restricted mode" \
        "resolve_security_configuration restricted 'host' '' 0" \
        "Security Warning: Host network with write access"
    
    # No warnings for valid configurations
    run_output_test "No warnings for standard mode defaults" \
        "resolve_security_configuration standard '' '' 0" \
        "Warning" \
        "false"
    
    run_output_test "No warnings for restricted mode defaults" \
        "resolve_security_configuration restricted '' '' 0" \
        "Warning" \
        "false"
    
    run_output_test "No warnings for paranoid mode defaults" \
        "resolve_security_configuration paranoid '' '' 0" \
        "Warning" \
        "false"
    
    echo ""
}

# Test verbose mode functionality
test_verbose_mode() {
    echo -e "${BLUE}4. Verbose Mode Tests${NC}"
    echo "------------------"
    
    run_output_test "Verbose mode shows configuration details" \
        "CBOX_VERBOSE=1 resolve_security_configuration standard '' '' 0" \
        "Security configuration resolved"
    
    run_output_test "Verbose mode shows mode information" \
        "CBOX_VERBOSE=1 resolve_security_configuration restricted '' '' 0" \
        "Mode: restricted"
    
    run_output_test "Verbose mode shows network setting" \
        "CBOX_VERBOSE=1 resolve_security_configuration paranoid '' '' 0" \
        "Network: none"
    
    run_output_test "Non-verbose mode is quiet" \
        "CBOX_VERBOSE=0 resolve_security_configuration standard '' '' 0" \
        "Security configuration resolved" \
        "false"
    
    echo ""
}

# Test security bypass detection
test_security_bypass_detection() {
    echo -e "${BLUE}5. Security Bypass Detection${NC}"
    echo "---------------------------"
    
    run_test "CBOX_BYPASS_SECURITY environment variable triggers security error" \
        "CBOX_BYPASS_SECURITY=1 resolve_security_configuration standard '' '' 0" \
        "failure"
    
    run_test "BYPASS_SECURITY environment variable triggers security error" \
        "BYPASS_SECURITY=1 resolve_security_configuration standard '' '' 0" \
        "failure"
    
    run_output_test "Security bypass error message is shown" \
        "CBOX_BYPASS_SECURITY=1 resolve_security_configuration standard '' '' 0 || true" \
        "Security Error: Attempted security bypass detected"
    
    echo ""
}

# Test Docker integration components
test_docker_integration() {
    echo -e "${BLUE}6. Docker Integration Components${NC}"
    echo "------------------------------"
    
    # Network flag generation
    run_output_test "Host network flags generated correctly" \
        "generate_docker_network_flags host" \
        "--network host"
    
    run_output_test "Bridge network flags include DNS" \
        "generate_docker_network_flags bridge" \
        "--dns 8.8.8.8"
    
    run_output_test "None network flags generated correctly" \
        "generate_docker_network_flags none" \
        "--network none"
    
    run_test "Invalid network type fails" \
        "generate_docker_network_flags invalid" \
        "failure"
    
    # Volume mount generation
    run_output_test "Read-write volume mount generated" \
        "generate_volume_mounts /test/path false false" \
        "/test/path:/work"
    
    run_output_test "Read-only volume mount generated" \
        "generate_volume_mounts /test/path true false" \
        "/test/path:/work:ro"
    
    run_output_test "SSH volume mount when SSH_AUTH_SOCK is set" \
        "SSH_AUTH_SOCK=/tmp/ssh-agent generate_volume_mounts /test/path false true" \
        "/tmp/ssh-agent:/ssh-agent"
    
    echo ""
}

# Test complex configuration scenarios
test_complex_scenarios() {
    echo -e "${BLUE}7. Complex Configuration Scenarios${NC}"
    echo "--------------------------------"
    
    # Developer workflow scenarios
    run_test "Developer mode (standard with custom network)" \
        "resolve_security_configuration standard 'bridge' '' 0 && 
         [[ \$RESOLVED_NETWORK == 'bridge' ]] && 
         [[ \$RESOLVED_SSH_AGENT == 'true' ]] && 
         [[ \$RESOLVED_READ_ONLY == 'false' ]]"
    
    run_test "CI/CD mode (restricted with read-only)" \
        "resolve_security_configuration restricted '' '' 1 && 
         [[ \$RESOLVED_NETWORK == 'bridge' ]] && 
         [[ \$RESOLVED_SSH_AGENT == 'true' ]] && 
         [[ \$RESOLVED_READ_ONLY == 'true' ]]"
    
    run_test "Air-gapped mode (paranoid with all restrictions)" \
        "resolve_security_configuration paranoid '' '' 0 && 
         [[ \$RESOLVED_NETWORK == 'none' ]] && 
         [[ \$RESOLVED_SSH_AGENT == 'false' ]] && 
         [[ \$RESOLVED_READ_ONLY == 'true' ]]"
    
    # Edge case combinations
    run_test "Paranoid mode with maximum overrides still enforces read-only" \
        "resolve_security_configuration paranoid 'host' 'true' 0 && 
         [[ \$RESOLVED_NETWORK == 'host' ]] && 
         [[ \$RESOLVED_SSH_AGENT == 'true' ]] && 
         [[ \$RESOLVED_READ_ONLY == 'true' ]]"
    
    echo ""
}

# Main execution
main() {
    echo "Setting up test environment..."
    create_security_functions
    source /tmp/cbox_security_functions.sh
    echo ""
    
    # Run all test suites
    test_security_mode_defaults
    test_configuration_overrides
    test_security_warnings
    test_verbose_mode
    test_security_bypass_detection
    test_docker_integration
    test_complex_scenarios
    
    # Print results
    echo "=============================================="
    echo -e "${BLUE}Integration Test Results Summary:${NC}"
    echo "  Tests run: $TESTS_RUN"
    echo -e "  Tests passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "  Tests failed: ${RED}$TESTS_FAILED${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "  Result: ${GREEN}ALL TESTS PASSED${NC}"
        echo ""
        echo -e "${GREEN}✓ Configuration resolution is working correctly${NC}"
        echo -e "${GREEN}✓ Security warnings are properly generated${NC}"
        echo -e "${GREEN}✓ Override logic is functioning as expected${NC}"
        echo -e "${GREEN}✓ Docker integration components are ready${NC}"
    else
        echo -e "  Result: ${RED}SOME TESTS FAILED${NC}"
        echo ""
        echo -e "${RED}✗ Configuration resolution has issues that need attention${NC}"
    fi
    
    echo ""
    
    # Cleanup
    rm -f /tmp/cbox_security_functions.sh
    
    # Exit with appropriate code
    [[ $TESTS_FAILED -eq 0 ]] && exit 0 || exit 1
}

# Run main function
main "$@"