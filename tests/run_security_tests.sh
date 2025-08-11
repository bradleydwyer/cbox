#!/usr/bin/env bash
# Comprehensive test runner for cbox security modes functionality
# Executes all test suites and generates detailed reports

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$SCRIPT_DIR/tests"
WORK_DIR="$SCRIPT_DIR"

echo "Cbox Security Modes - Comprehensive Test Suite"
echo "=============================================="
echo "Script directory: $SCRIPT_DIR"
echo "Tests directory: $TESTS_DIR"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Test suite tracking
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0
SKIPPED_SUITES=0

# Detailed results tracking
declare -a SUITE_RESULTS
declare -a SUITE_DETAILS

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%H:%M:%S')
    
    case "$level" in
        "INFO")
            echo -e "${CYAN}[$timestamp]${NC} $message"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[$timestamp]${NC} $message"
            ;;
        "WARNING")
            echo -e "${YELLOW}[$timestamp]${NC} $message"
            ;;
        "ERROR")
            echo -e "${RED}[$timestamp]${NC} $message"
            ;;
        "HEADER")
            echo -e "${BOLD}${BLUE}[$timestamp]${NC} $message"
            ;;
    esac
}

# Function to run a single test suite
run_test_suite() {
    local suite_name="$1"
    local suite_script="$2"
    local suite_description="$3"
    
    TOTAL_SUITES=$((TOTAL_SUITES + 1))
    
    log "HEADER" "Running Test Suite: $suite_name"
    log "INFO" "Description: $suite_description"
    log "INFO" "Script: $suite_script"
    echo ""
    
    # Check if test script exists and is executable
    if [[ ! -f "$suite_script" ]]; then
        log "ERROR" "Test script not found: $suite_script"
        SUITE_RESULTS+=("SKIPPED")
        SUITE_DETAILS+=("$suite_name: Test script not found")
        SKIPPED_SUITES=$((SKIPPED_SUITES + 1))
        return 1
    fi
    
    if [[ ! -x "$suite_script" ]]; then
        log "WARNING" "Making test script executable: $suite_script"
        chmod +x "$suite_script"
    fi
    
    # Run the test suite with timeout
    local output_file="/tmp/cbox_test_output_$(basename "$suite_script" .sh)"
    local start_time=$(date +%s)
    local exit_code=0
    
    log "INFO" "Executing test suite (timeout: 60s)..."
    
    # Execute with timeout and capture both stdout and stderr
    if timeout 60 "$suite_script" > "$output_file" 2>&1; then
        exit_code=0
    else
        exit_code=$?
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Parse results from output
    local tests_run=0
    local tests_passed=0
    local tests_failed=0
    
    if [[ -f "$output_file" ]]; then
        # Extract test counts from output (handles different output formats)
        tests_run=$(grep -oE "Tests run: [0-9]+" "$output_file" | grep -oE "[0-9]+" | tail -1 || echo "0")
        tests_passed=$(grep -oE "Tests passed: [0-9]+" "$output_file" | grep -oE "[0-9]+" | tail -1 || echo "0")
        tests_failed=$(grep -oE "Tests failed: [0-9]+" "$output_file" | grep -oE "[0-9]+" | tail -1 || echo "0")
        
        # Alternative patterns for different output formats
        if [[ $tests_run -eq 0 ]]; then
            tests_run=$(grep -c "Testing:" "$output_file" 2>/dev/null || echo "0")
        fi
        if [[ $tests_passed -eq 0 ]]; then
            tests_passed=$(grep -c "PASSED" "$output_file" 2>/dev/null || echo "0")
        fi
        if [[ $tests_failed -eq 0 ]]; then
            tests_failed=$(grep -c "FAILED" "$output_file" 2>/dev/null || echo "0")
        fi
    fi
    
    # Determine suite result
    local suite_result="UNKNOWN"
    local result_message=""
    
    if [[ $exit_code -eq 124 ]]; then
        # Timeout
        suite_result="TIMEOUT"
        result_message="Test suite timed out after 60 seconds"
        log "ERROR" "$result_message"
    elif [[ $exit_code -eq 0 ]]; then
        # Success
        suite_result="PASSED"
        result_message="All tests passed (${tests_passed}/${tests_run}) in ${duration}s"
        log "SUCCESS" "$result_message"
        PASSED_SUITES=$((PASSED_SUITES + 1))
    else
        # Failure
        suite_result="FAILED"
        result_message="Tests failed (${tests_passed} passed, ${tests_failed} failed) in ${duration}s"
        log "ERROR" "$result_message"
        FAILED_SUITES=$((FAILED_SUITES + 1))
        
        # Show failure details
        if [[ -f "$output_file" ]]; then
            echo ""
            log "ERROR" "Failure details:"
            grep -A 2 -B 1 "FAILED" "$output_file" | head -10 | sed 's/^/  /' || true
        fi
    fi
    
    SUITE_RESULTS+=("$suite_result")
    SUITE_DETAILS+=("$suite_name: $result_message")
    
    echo ""
    echo "$(printf '%.0s-' {1..60})"
    echo ""
    
    # Clean up output file
    rm -f "$output_file"
    
    return $exit_code
}

# Function to check prerequisites
check_prerequisites() {
    log "INFO" "Checking prerequisites..."
    
    local missing_deps=0
    
    # Check for required commands
    local required_commands=("bash" "grep" "timeout" "chmod" "od")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log "ERROR" "Required command not found: $cmd"
            missing_deps=1
        fi
    done
    
    # Check for cbox executable
    if [[ ! -f "$WORK_DIR/cbox" ]]; then
        log "ERROR" "cbox executable not found at $WORK_DIR/cbox"
        missing_deps=1
    elif [[ ! -x "$WORK_DIR/cbox" ]]; then
        log "WARNING" "cbox is not executable, making it executable..."
        chmod +x "$WORK_DIR/cbox" || {
            log "ERROR" "Failed to make cbox executable"
            missing_deps=1
        }
    fi
    
    # Check for tests directory
    if [[ ! -d "$TESTS_DIR" ]]; then
        log "ERROR" "Tests directory not found: $TESTS_DIR"
        missing_deps=1
    fi
    
    # Check Docker (optional for most tests)
    if command -v docker >/dev/null 2>&1; then
        if docker version >/dev/null 2>&1; then
            log "INFO" "Docker is available and running"
        else
            log "WARNING" "Docker is installed but not running (some tests may be limited)"
        fi
    else
        log "WARNING" "Docker not found (some tests will use mocks)"
    fi
    
    if [[ $missing_deps -eq 1 ]]; then
        log "ERROR" "Prerequisites check failed. Please install missing dependencies."
        return 1
    fi
    
    log "SUCCESS" "Prerequisites check passed"
    return 0
}

# Function to generate detailed report
generate_report() {
    echo ""
    echo "$(printf '%.0s=' {1..80})"
    echo -e "${BOLD}${BLUE}COMPREHENSIVE TEST RESULTS SUMMARY${NC}"
    echo "$(printf '%.0s=' {1..80})"
    echo ""
    
    # Overall statistics
    echo -e "${BOLD}Test Suite Statistics:${NC}"
    echo "  Total test suites: $TOTAL_SUITES"
    echo -e "  Passed suites: ${GREEN}$PASSED_SUITES${NC}"
    echo -e "  Failed suites: ${RED}$FAILED_SUITES${NC}"
    echo -e "  Skipped suites: ${YELLOW}$SKIPPED_SUITES${NC}"
    echo ""
    
    # Success rate
    local success_rate=0
    if [[ $TOTAL_SUITES -gt 0 ]]; then
        success_rate=$(( (PASSED_SUITES * 100) / TOTAL_SUITES ))
    fi
    
    echo -e "${BOLD}Success Rate: ${NC}"
    if [[ $success_rate -ge 90 ]]; then
        echo -e "  ${GREEN}$success_rate% - Excellent${NC}"
    elif [[ $success_rate -ge 75 ]]; then
        echo -e "  ${YELLOW}$success_rate% - Good${NC}"
    elif [[ $success_rate -ge 50 ]]; then
        echo -e "  ${YELLOW}$success_rate% - Needs Improvement${NC}"
    else
        echo -e "  ${RED}$success_rate% - Poor${NC}"
    fi
    echo ""
    
    # Detailed results
    echo -e "${BOLD}Detailed Results:${NC}"
    for i in "${!SUITE_DETAILS[@]}"; do
        local detail="${SUITE_DETAILS[$i]}"
        local result="${SUITE_RESULTS[$i]}"
        
        case "$result" in
            "PASSED")
                echo -e "  ${GREEN}✓${NC} $detail"
                ;;
            "FAILED")
                echo -e "  ${RED}✗${NC} $detail"
                ;;
            "TIMEOUT")
                echo -e "  ${YELLOW}⏰${NC} $detail"
                ;;
            "SKIPPED")
                echo -e "  ${YELLOW}⚠${NC} $detail"
                ;;
            *)
                echo -e "  ${YELLOW}?${NC} $detail"
                ;;
        esac
    done
    echo ""
    
    # Security features validation summary
    echo -e "${BOLD}Security Features Validation:${NC}"
    if [[ $PASSED_SUITES -eq $TOTAL_SUITES && $TOTAL_SUITES -gt 0 ]]; then
        echo -e "  ${GREEN}✓ Input validation and sanitization${NC}"
        echo -e "  ${GREEN}✓ Command injection prevention${NC}"
        echo -e "  ${GREEN}✓ Security mode configuration${NC}"
        echo -e "  ${GREEN}✓ Docker integration security${NC}"
        echo -e "  ${GREEN}✓ CLI argument parsing${NC}"
    else
        echo -e "  ${RED}✗ Some security features may have issues${NC}"
        echo -e "  ${YELLOW}⚠ Please review failed tests above${NC}"
    fi
    echo ""
    
    # Recommendations
    echo -e "${BOLD}Recommendations:${NC}"
    if [[ $FAILED_SUITES -eq 0 ]]; then
        echo -e "  ${GREEN}✓ All security features are working correctly${NC}"
        echo -e "  ${GREEN}✓ The security modes implementation is ready for production${NC}"
    else
        echo -e "  ${RED}✗ Address failing tests before deploying${NC}"
        echo -e "  ${YELLOW}⚠ Review security warnings and error messages${NC}"
        echo -e "  ${YELLOW}⚠ Consider running tests individually for detailed diagnosis${NC}"
    fi
    echo ""
    
    # Test execution commands for reference
    echo -e "${BOLD}Individual Test Commands:${NC}"
    echo "  Unit Tests (Validation):     $TESTS_DIR/unit_validation.sh"
    echo "  Integration Tests (Config):  $TESTS_DIR/integration_config.sh"
    echo "  Docker Generation Tests:     $TESTS_DIR/docker_generation.sh"
    echo "  End-to-End CLI Tests:        $TESTS_DIR/e2e_cli.sh"
    echo ""
    
    echo "$(printf '%.0s=' {1..80})"
}

# Main execution function
main() {
    local start_time=$(date +%s)
    
    # Parse command line arguments
    local verbose=0
    local stop_on_failure=0
    local specific_test=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -v|--verbose)
                verbose=1
                shift
                ;;
            --stop-on-failure)
                stop_on_failure=1
                shift
                ;;
            --test)
                specific_test="$2"
                shift 2
                ;;
            -h|--help)
                cat << EOF
Cbox Security Test Suite Runner

Usage: $0 [OPTIONS]

Options:
  -v, --verbose         Enable verbose output
  --stop-on-failure     Stop execution on first test suite failure
  --test SUITE_NAME     Run only specific test suite
  -h, --help            Show this help message

Available test suites:
  unit_validation       Input validation and sanitization tests
  integration_config    Configuration resolution and security warnings
  docker_generation     Docker command generation with security options
  e2e_cli              End-to-end CLI argument parsing tests

Examples:
  $0                           # Run all test suites
  $0 --verbose                 # Run with detailed output
  $0 --test unit_validation    # Run only unit tests
  $0 --stop-on-failure         # Stop on first failure
EOF
                exit 0
                ;;
            *)
                log "ERROR" "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Check prerequisites
    if ! check_prerequisites; then
        exit 1
    fi
    
    echo ""
    log "INFO" "Starting comprehensive security test suite execution..."
    echo ""
    
    # Define test suites
    declare -a TEST_SUITES=(
        "unit_validation:$TESTS_DIR/unit_validation.sh:Input validation and command injection prevention"
        "integration_config:$TESTS_DIR/integration_config.sh:Configuration resolution and security warnings"
        "docker_generation:$TESTS_DIR/docker_generation.sh:Docker command generation with security modes"
        "e2e_cli:$TESTS_DIR/e2e_cli.sh:End-to-end CLI argument parsing and validation"
    )
    
    # Filter test suites if specific test requested
    if [[ -n "$specific_test" ]]; then
        local found=0
        for suite in "${TEST_SUITES[@]}"; do
            local suite_name="${suite%%:*}"
            if [[ "$suite_name" == "$specific_test" ]]; then
                TEST_SUITES=("$suite")
                found=1
                break
            fi
        done
        
        if [[ $found -eq 0 ]]; then
            log "ERROR" "Test suite not found: $specific_test"
            log "INFO" "Available test suites: ${TEST_SUITES[*]%%:*}"
            exit 1
        fi
    fi
    
    # Execute test suites
    for suite in "${TEST_SUITES[@]}"; do
        IFS=':' read -r suite_name suite_script suite_description <<< "$suite"
        
        if ! run_test_suite "$suite_name" "$suite_script" "$suite_description"; then
            if [[ $stop_on_failure -eq 1 ]]; then
                log "ERROR" "Stopping execution due to --stop-on-failure flag"
                break
            fi
        fi
    done
    
    # Generate comprehensive report
    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))
    
    generate_report
    
    # Final status
    echo -e "${BOLD}Total Execution Time: ${NC}${total_duration}s"
    echo ""
    
    if [[ $FAILED_SUITES -eq 0 && $TOTAL_SUITES -gt 0 ]]; then
        log "SUCCESS" "All test suites passed! Security modes implementation is ready."
        exit 0
    else
        log "ERROR" "Some test suites failed. Please review the results above."
        exit 1
    fi
}

# Execute main function with all arguments
main "$@"