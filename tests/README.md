# Cbox Security Modes Test Suite

This directory contains a comprehensive test suite for validating the security modes functionality in cbox. The tests ensure that all security features work correctly and protect against various attack vectors.

## Overview

The security modes functionality includes:
- **Standard Mode**: Default settings with host network, SSH agent enabled, and writable project directory
- **Restricted Mode**: Balanced security with bridge network, SSH agent enabled, and writable project directory  
- **Paranoid Mode**: Maximum security with no network, SSH agent disabled, and read-only project directory

## Test Structure

### 1. Unit Tests (`unit_validation.sh`)
**Purpose**: Test individual validation functions in isolation without Docker execution.

**Coverage**:
- Security mode validation (standard/restricted/paranoid)
- Network type validation (host/bridge/none)
- Boolean value validation for SSH agent
- Resource limit validation (memory/CPU formats)
- Path security validation and system directory protection
- Command injection prevention
- Edge cases and boundary conditions

**Key Features**:
- 62+ individual test cases
- Injection attack prevention testing
- Input sanitization validation
- Comprehensive error handling

### 2. Integration Tests (`integration_config.sh`)
**Purpose**: Test the complete security configuration resolution logic.

**Coverage**:
- Security mode default configurations
- CLI override functionality
- Security warning generation
- Configuration consistency validation
- Verbose mode output testing
- Security bypass detection
- Docker integration components
- Complex configuration scenarios

**Key Features**:
- 35+ integration test cases
- End-to-end configuration testing
- Security warning validation
- Override behavior verification

### 3. Docker Generation Tests (`docker_generation.sh`)
**Purpose**: Validate Docker command generation with security configurations using mock Docker execution.

**Coverage**:
- Network flag generation for each security mode
- Volume mount configuration (read-only vs read-write)
- SSH agent socket handling
- Security hardening features (capabilities, tmpfs)
- Resource limit application
- Override behavior in Docker commands

**Key Features**:
- Mock Docker execution to capture arguments
- 30+ Docker command validation tests
- Security hardening verification
- No actual Docker containers created

### 4. End-to-End CLI Tests (`e2e_cli.sh`)
**Purpose**: Test complete CLI argument parsing and validation with timeouts to prevent hanging.

**Coverage**:
- Help and version output validation
- Security mode argument parsing
- Network type argument parsing
- SSH agent boolean validation
- Read-only flag behavior
- Argument combination testing
- Error message validation
- Security warning output
- Environment variable handling
- Command injection prevention

**Key Features**:
- 70+ CLI behavior tests
- Comprehensive error message validation
- Injection attack prevention
- Environment variable security

## Running Tests

### Individual Test Suites

```bash
# Run unit validation tests
./tests/unit_validation.sh

# Run integration configuration tests
./tests/integration_config.sh

# Run Docker generation tests
./tests/docker_generation.sh

# Run end-to-end CLI tests
./tests/e2e_cli.sh
```

### Comprehensive Test Runner

```bash
# Run all test suites with detailed reporting
./run_security_tests.sh

# Run specific test suite
./run_security_tests.sh --test unit_validation

# Run with verbose output
./run_security_tests.sh --verbose

# Stop on first failure
./run_security_tests.sh --stop-on-failure

# Show help
./run_security_tests.sh --help
```

## Test Results Interpretation

### Success Criteria
- **All tests passed**: Security implementation is ready for production
- **90%+ pass rate**: Good implementation, minor issues to address
- **75-89% pass rate**: Needs improvement before deployment
- **<75% pass rate**: Significant issues requiring attention

### Common Test Patterns

**PASSED**: Test executed successfully and met expectations
**FAILED**: Test failed - indicates potential security issue
**TIMEOUT**: Test exceeded time limit - may indicate hanging
**SKIPPED**: Test was not executed due to missing prerequisites

### Security Validation

The test suite validates:
- ✅ Input validation prevents malicious input
- ✅ Command injection attacks are blocked
- ✅ Security modes apply correct configurations
- ✅ Override logic works as expected
- ✅ Docker integration maintains security
- ✅ Error messages are informative
- ✅ Resource limits are enforced

## Test Environment Requirements

### Required
- Bash shell (4.0+)
- Standard Unix utilities (grep, timeout, chmod, od)
- cbox executable in parent directory

### Optional
- Docker (for enhanced testing, mocks used if unavailable)
- SSH agent (for SSH-related tests)

## Security Test Categories

### 1. Input Validation Tests
- Reject invalid security modes, network types, boolean values
- Block command injection attempts in all parameters
- Validate resource limit formats
- Protect against path traversal attacks

### 2. Configuration Logic Tests
- Verify security mode defaults are applied correctly
- Ensure CLI overrides work as expected
- Validate security warnings are generated appropriately
- Test complex configuration scenarios

### 3. Docker Integration Tests
- Verify network flags are set correctly for each mode
- Ensure volume mounts respect read-only settings
- Validate SSH agent handling
- Confirm security hardening features are applied

### 4. CLI Behavior Tests
- Test argument parsing for all security options
- Validate error messages are helpful
- Ensure help/version information is accurate
- Verify environment variable handling is secure

## Debugging Failed Tests

### Individual Test Debugging
```bash
# Run single test suite with full output
./tests/unit_validation.sh

# Check specific functionality
CBOX_VERBOSE=1 ./cbox --security-mode paranoid --verify
```

### Test Runner Debugging
```bash
# Run specific suite with verbose output
./run_security_tests.sh --test integration_config --verbose

# Stop on first failure for debugging
./run_security_tests.sh --stop-on-failure
```

### Common Issues
1. **Docker not available**: Tests use mocks, some functionality may be limited
2. **Permission errors**: Ensure test scripts are executable (`chmod +x tests/*.sh`)
3. **Timeout issues**: Check system performance, increase timeouts if needed
4. **Path issues**: Ensure cbox executable exists in parent directory

## Test Coverage

The test suite provides comprehensive coverage of:
- **Input Validation**: 62+ test cases covering all input types and injection attempts
- **Configuration Logic**: 35+ test cases covering all security modes and overrides
- **Docker Integration**: 30+ test cases covering command generation and security
- **CLI Behavior**: 70+ test cases covering argument parsing and error handling

**Total**: 200+ automated test cases ensuring security modes work correctly.

## Extending Tests

To add new tests:

1. **Unit Tests**: Add validation function tests to `unit_validation.sh`
2. **Integration Tests**: Add configuration tests to `integration_config.sh`
3. **Docker Tests**: Add command generation tests to `docker_generation.sh`
4. **CLI Tests**: Add argument parsing tests to `e2e_cli.sh`

Follow existing patterns and use the provided test frameworks for consistency.