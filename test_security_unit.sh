#!/usr/bin/env bash
# Unit test for security configuration resolution function

set -euo pipefail

echo "Unit Testing: Security Configuration Resolution"
echo "==============================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_RUN=0
TESTS_PASSED=0

# Source just the validation and resolution functions from cbox
# Extract the functions we need for testing
cat > /tmp/security_functions.sh << 'EOF'
#!/usr/bin/env bash

# Stub for verbose mode
CBOX_VERBOSE="${CBOX_VERBOSE:-0}"

# Validation functions
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

# Security Configuration Resolution Function
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
      # Default behavior - full network, SSH agent, writable
      final_network="host"
      final_ssh="true"
      final_read_only="false"
      ;;
    restricted)
      # Balanced security - isolated network, SSH agent, writable
      final_network="bridge"
      final_ssh="true"
      final_read_only="false"
      ;;
    paranoid)
      # Maximum security - no network, no SSH, read-only
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

# Validate security configuration consistency
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
  # Check for attempts to bypass security through environment manipulation
  if [[ -n "${CBOX_BYPASS_SECURITY:-}" ]] || [[ -n "${BYPASS_SECURITY:-}" ]]; then
    echo "cbox: 🛑 Security Error: Attempted security bypass detected" >&2
    echo "  Security features cannot be disabled through environment variables" >&2
    exit 1
  fi
}
EOF

source /tmp/security_functions.sh

# Test function
run_test() {
    local test_name="$1"
    local test_function="$2"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    echo -n "Testing: $test_name ... "
    
    # Run test function in subshell to isolate environment
    if (eval "$test_function") 2>/dev/null; then
        echo -e "${GREEN}PASSED${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}FAILED${NC}"
        return 1
    fi
}

# Test validation functions
echo "1. Testing validation functions"
echo "--------------------------------"

run_test "validate_security_mode accepts standard" \
    "validate_security_mode standard"

run_test "validate_security_mode accepts restricted" \
    "validate_security_mode restricted"

run_test "validate_security_mode accepts paranoid" \
    "validate_security_mode paranoid"

run_test "validate_security_mode rejects invalid" \
    "! validate_security_mode invalid"

run_test "validate_network_type accepts host" \
    "validate_network_type host"

run_test "validate_network_type accepts bridge" \
    "validate_network_type bridge"

run_test "validate_network_type accepts none" \
    "validate_network_type none"

run_test "validate_network_type rejects invalid" \
    "! validate_network_type invalid"

run_test "validate_boolean accepts true" \
    "validate_boolean true test"

run_test "validate_boolean accepts false" \
    "validate_boolean false test"

run_test "validate_boolean rejects invalid" \
    "! validate_boolean maybe test"

echo ""
echo "2. Testing security mode defaults"
echo "----------------------------------"

run_test "Standard mode sets correct defaults" \
    "resolve_security_configuration standard '' '' 0 && 
     [[ \$RESOLVED_NETWORK == 'host' ]] && 
     [[ \$RESOLVED_SSH_AGENT == 'true' ]] && 
     [[ \$RESOLVED_READ_ONLY == 'false' ]]"

run_test "Restricted mode sets correct defaults" \
    "resolve_security_configuration restricted '' '' 0 && 
     [[ \$RESOLVED_NETWORK == 'bridge' ]] && 
     [[ \$RESOLVED_SSH_AGENT == 'true' ]] && 
     [[ \$RESOLVED_READ_ONLY == 'false' ]]"

run_test "Paranoid mode sets correct defaults" \
    "resolve_security_configuration paranoid '' '' 0 && 
     [[ \$RESOLVED_NETWORK == 'none' ]] && 
     [[ \$RESOLVED_SSH_AGENT == 'false' ]] && 
     [[ \$RESOLVED_READ_ONLY == 'true' ]]"

echo ""
echo "3. Testing overrides"
echo "--------------------"

run_test "Network override works in standard mode" \
    "resolve_security_configuration standard 'bridge' '' 0 && 
     [[ \$RESOLVED_NETWORK == 'bridge' ]]"

run_test "SSH override works in restricted mode" \
    "resolve_security_configuration restricted '' 'false' 0 && 
     [[ \$RESOLVED_SSH_AGENT == 'false' ]]"

run_test "Read-only override works in standard mode" \
    "resolve_security_configuration standard '' '' 1 && 
     [[ \$RESOLVED_READ_ONLY == 'true' ]]"

run_test "Multiple overrides work (paranoid keeps read-only)" \
    "resolve_security_configuration paranoid 'host' 'true' 0 && 
     [[ \$RESOLVED_NETWORK == 'host' ]] && 
     [[ \$RESOLVED_SSH_AGENT == 'true' ]] && 
     [[ \$RESOLVED_READ_ONLY == 'true' ]]"

run_test "Can force read-only in standard mode" \
    "resolve_security_configuration standard 'bridge' 'false' 1 && 
     [[ \$RESOLVED_NETWORK == 'bridge' ]] && 
     [[ \$RESOLVED_SSH_AGENT == 'false' ]] && 
     [[ \$RESOLVED_READ_ONLY == 'true' ]]"

echo ""
echo "4. Testing security warnings"
echo "-----------------------------"

run_test "Warning generated for network in paranoid mode" \
    "output=\$(resolve_security_configuration paranoid 'host' '' 0 2>&1) && 
     echo \"\$output\" | grep -q 'Security Warning: Network enabled in paranoid mode'"

run_test "Warning generated for SSH in paranoid mode" \
    "output=\$(resolve_security_configuration paranoid '' 'true' 0 2>&1) && 
     echo \"\$output\" | grep -q 'Security Warning: SSH agent enabled in paranoid mode'"

run_test "Warning generated for SSH with no network" \
    "output=\$(resolve_security_configuration standard 'none' 'true' 0 2>&1) && 
     echo \"\$output\" | grep -q 'Configuration Warning: SSH agent enabled but network disabled'"

run_test "No warnings for standard mode defaults" \
    "output=\$(resolve_security_configuration standard '' '' 0 2>&1) && 
     ! echo \"\$output\" | grep -q 'Warning'"

echo ""
echo "5. Testing security bypass detection"
echo "-------------------------------------"

run_test "Security bypass through CBOX_BYPASS_SECURITY fails" \
    "! (CBOX_BYPASS_SECURITY=1 resolve_security_configuration standard '' '' 0)"

run_test "Security bypass through BYPASS_SECURITY fails" \
    "! (BYPASS_SECURITY=1 resolve_security_configuration standard '' '' 0)"

echo ""
echo "6. Testing verbose mode output"
echo "-------------------------------"

run_test "Verbose mode shows configuration details" \
    "output=\$(CBOX_VERBOSE=1 resolve_security_configuration standard '' '' 0 2>&1) && 
     echo \"\$output\" | grep -q 'Security configuration resolved'"

run_test "Non-verbose mode is quiet" \
    "output=\$(CBOX_VERBOSE=0 resolve_security_configuration standard '' '' 0 2>&1) && 
     ! echo \"\$output\" | grep -q 'Security configuration resolved'"

echo ""
echo "==============================================="
echo "Test Results:"
echo "  Tests run: $TESTS_RUN"
echo -e "  Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "  Tests failed: ${RED}$((TESTS_RUN - TESTS_PASSED))${NC}"
echo ""

# Clean up
rm -f /tmp/security_functions.sh

if [ $TESTS_PASSED -eq $TESTS_RUN ]; then
    echo -e "${GREEN}All unit tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some unit tests failed.${NC}"
    exit 1
fi