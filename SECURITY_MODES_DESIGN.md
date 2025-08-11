# Security Modes and Configuration System - Detailed Technical Design

**Version:** 1.0  
**Date:** August 2025  
**Target Release:** cbox v1.3.0

## Executive Summary

This document provides a comprehensive technical design for implementing security modes and configuration file support in cbox. The design maintains backward compatibility while adding granular security controls through CLI arguments and JSON configuration files.

## Design Principles

1. **Security First**: Each mode provides clear security boundaries with no ambiguous configurations
2. **Backward Compatibility**: Existing users see no behavior changes (standard mode is default)
3. **CLI Override Priority**: Command-line arguments always take precedence over configuration files
4. **Fail-Safe Defaults**: Invalid configurations fail to more secure modes, not less secure
5. **Clear User Feedback**: Comprehensive validation and error messages
6. **Maintainability**: Clean separation of concerns and testable components

## Architecture Overview

```
User Input (CLI + Config File) → Configuration Resolution → Security Mode Application → Docker Execution
                                        ↓
                                  Validation & Error Handling
```

### Data Flow

1. **Configuration Discovery**: Find and load `.cbox.json` files in priority order
2. **CLI Parsing**: Parse command-line arguments including new security options  
3. **Configuration Merging**: Merge config file and CLI with CLI taking precedence
4. **Validation**: Validate final configuration for consistency and security
5. **Docker Arguments Generation**: Build Docker run command based on resolved config
6. **Execution**: Run container with security-appropriate settings

## Step 1: Security Mode CLI Arguments Implementation

### 1.1 Security Mode Definitions

#### Standard Mode (Default)
```yaml
security_profile: standard
network:
  type: host
  access: full
  dns: inherit_host
ssh_agent: 
  enabled: true
  socket_mount: true
volumes:
  project_dir: read_write
  host_mounts: read_only_selective
capabilities:
  - CHOWN
  - DAC_OVERRIDE  
  - FOWNER
  - SETUID
  - SETGID
  - KILL
restrictions: minimal
use_cases:
  - General development
  - Git operations required
  - Package installation needed
```

#### Restricted Mode  
```yaml
security_profile: restricted
network:
  type: bridge
  access: limited
  dns: [8.8.8.8, 1.1.1.1]  # Explicit DNS servers only
  egress_filtering: none    # Future enhancement
ssh_agent:
  enabled: true
  socket_mount: true
volumes:
  project_dir: read_write
  host_mounts: read_only_selective  
capabilities:
  - CHOWN
  - DAC_OVERRIDE
  - FOWNER
  - SETUID
  - SETGID
  # Note: Removed KILL capability
restrictions:
  - no_host_network_access
  - explicit_dns_only
use_cases:
  - Untrusted code with Git needs
  - Network isolation required
  - SSH operations needed
```

#### Paranoid Mode
```yaml
security_profile: paranoid  
network:
  type: none
  access: blocked
  dns: none
ssh_agent:
  enabled: false
  socket_mount: false
volumes:
  project_dir: read_only
  host_mounts: none
capabilities:
  - CHOWN     # Minimal for file operations
  - FOWNER    # File ownership only
restrictions:
  - no_network_access
  - no_ssh_operations
  - read_only_filesystem
  - minimal_capabilities
use_cases:
  - Maximum security analysis
  - Untrusted code examination  
  - Air-gapped environments
```

### 1.2 CLI Interface Design

#### New Command-Line Arguments
```bash
# Primary security mode selection
--security-mode MODE         # standard|restricted|paranoid (default: standard)

# Granular overrides (override security mode defaults)  
--network MODE              # host|bridge|none
--ssh-agent ENABLED         # true|false  
--read-only                 # Force read-only project directory
--no-network                # Alias for --network none
--no-ssh                    # Alias for --ssh-agent false

# Configuration file selection
--config FILE               # Override default config file discovery
--no-config                 # Ignore all configuration files
```

#### Updated Help Text
```
Security Options:
  --security-mode MODE     Security level (default: standard)
                           standard  - Full access (current behavior)
                           restricted - Limited network, SSH enabled
                           paranoid  - No network, no SSH, read-only

  --network MODE           Network access override: host|bridge|none
  --ssh-agent BOOL         SSH agent access override: true|false
  --read-only              Force read-only project directory
  --no-network             Disable all network access (alias for --network none)
  --no-ssh                 Disable SSH agent (alias for --ssh-agent false)
  
Configuration:
  --config FILE            Use specific configuration file
  --no-config              Ignore configuration files
```

### 1.3 Implementation Structure

#### New Variables and Data Structures
```bash
# Security mode configuration state
declare -A SECURITY_CONFIG=(
  [mode]="standard"                    # standard|restricted|paranoid
  [network_type]=""                    # host|bridge|none (empty = mode default)
  [ssh_agent_enabled]=""               # true|false (empty = mode default)  
  [volume_mode]=""                     # rw|ro (empty = mode default)
  [config_file]=""                     # Path to config file (empty = auto-discover)
  [ignore_config]="false"              # true to ignore all config files
)

# Resolved final configuration (after merging config file + CLI + mode defaults)
declare -A FINAL_CONFIG=(
  [network_type]=""
  [ssh_agent_enabled]=""
  [volume_mode]=""
  [docker_network_args]=""
  [docker_ssh_args]=""  
  [docker_volume_args]=""
)
```

#### Core Implementation Functions

**Security Mode Validation:**
```bash
validate_security_mode() {
  local mode="$1"
  case "$mode" in
    standard|restricted|paranoid)
      return 0
      ;;
    *)
      echo "cbox: Invalid security mode: $mode" >&2
      echo "Valid modes: standard, restricted, paranoid" >&2
      echo "Use 'cbox --help' for details on each mode." >&2
      return 1
      ;;
  esac
}

validate_network_mode() {
  local mode="$1"
  case "$mode" in
    host|bridge|none)
      return 0
      ;;
    *)
      echo "cbox: Invalid network mode: $mode" >&2  
      echo "Valid modes: host, bridge, none" >&2
      return 1
      ;;
  esac
}

validate_boolean() {
  local value="$1"
  local param_name="$2"
  case "$value" in
    true|false)
      return 0
      ;;
    *)
      echo "cbox: Invalid value for $param_name: $value" >&2
      echo "Valid values: true, false" >&2
      return 1
      ;;
  esac
}
```

**Configuration Resolution Logic:**
```bash
resolve_security_mode_defaults() {
  local mode="${SECURITY_CONFIG[mode]}"
  
  case "$mode" in
    standard)
      # Standard mode defaults (current behavior)
      [[ -z "${FINAL_CONFIG[network_type]}" ]] && FINAL_CONFIG[network_type]="host"
      [[ -z "${FINAL_CONFIG[ssh_agent_enabled]}" ]] && FINAL_CONFIG[ssh_agent_enabled]="true"  
      [[ -z "${FINAL_CONFIG[volume_mode]}" ]] && FINAL_CONFIG[volume_mode]="rw"
      ;;
    restricted)
      # Restricted mode defaults
      [[ -z "${FINAL_CONFIG[network_type]}" ]] && FINAL_CONFIG[network_type]="bridge"
      [[ -z "${FINAL_CONFIG[ssh_agent_enabled]}" ]] && FINAL_CONFIG[ssh_agent_enabled]="true"
      [[ -z "${FINAL_CONFIG[volume_mode]}" ]] && FINAL_CONFIG[volume_mode]="rw"
      ;;  
    paranoid)
      # Paranoid mode defaults
      [[ -z "${FINAL_CONFIG[network_type]}" ]] && FINAL_CONFIG[network_type]="none"
      [[ -z "${FINAL_CONFIG[ssh_agent_enabled]}" ]] && FINAL_CONFIG[ssh_agent_enabled]="false"
      [[ -z "${FINAL_CONFIG[volume_mode]}" ]] && FINAL_CONFIG[volume_mode]="ro"
      ;;
  esac
}

apply_cli_overrides() {
  # CLI arguments override everything (config file + mode defaults)
  [[ -n "${SECURITY_CONFIG[network_type]}" ]] && FINAL_CONFIG[network_type]="${SECURITY_CONFIG[network_type]}"
  [[ -n "${SECURITY_CONFIG[ssh_agent_enabled]}" ]] && FINAL_CONFIG[ssh_agent_enabled]="${SECURITY_CONFIG[ssh_agent_enabled]}"  
  [[ -n "${SECURITY_CONFIG[volume_mode]}" ]] && FINAL_CONFIG[volume_mode]="${SECURITY_CONFIG[volume_mode]}"
}
```

**Docker Arguments Generation:**
```bash
build_docker_network_args() {
  local network_type="${FINAL_CONFIG[network_type]}"
  local -a args=()
  
  case "$network_type" in
    host)
      args+=("--network=host")
      ;;
    bridge)  
      args+=("--network=bridge")
      # Add explicit DNS servers for restricted mode
      args+=("--dns=8.8.8.8" "--dns=1.1.1.1")
      ;;
    none)
      args+=("--network=none")
      ;;
  esac
  
  FINAL_CONFIG[docker_network_args]="${args[*]}"
}

build_docker_ssh_args() {
  local ssh_enabled="${FINAL_CONFIG[ssh_agent_enabled]}"  
  local -a args=()
  
  if [[ "$ssh_enabled" == "true" ]]; then
    # Validate SSH agent is available
    if [[ -n "${SSH_AUTH_SOCK:-}" && -S "${SSH_AUTH_SOCK:-}" ]]; then
      args+=("-v" "$SSH_AUTH_SOCK:/ssh-agent")
      args+=("-e" "SSH_AUTH_SOCK=/ssh-agent")
    else
      echo "cbox: Warning - SSH agent requested but not available" >&2
      echo "  Start SSH agent: eval \$(ssh-agent -s)" >&2
      echo "  Add key: ssh-add ~/.ssh/id_rsa" >&2
    fi
  fi
  
  FINAL_CONFIG[docker_ssh_args]="${args[*]}"
}

build_docker_volume_args() {
  local volume_mode="${FINAL_CONFIG[volume_mode]}"
  local -a args=()
  
  # Primary project directory mount
  args+=("-v" "$WORKDIR:/work:$volume_mode")
  
  # SSH agent args (if enabled)
  if [[ -n "${FINAL_CONFIG[docker_ssh_args]}" ]]; then
    read -ra ssh_args <<< "${FINAL_CONFIG[docker_ssh_args]}"
    args+=("${ssh_args[@]}")
  fi
  
  # Standard host mounts (always read-only for security)
  args+=("-v" "$HOME/.claude:/home/host/.claude")
  [[ -f "$HOME/.claude.json" ]] && args+=("-v" "$HOME/.claude.json:/home/host/.claude.json")
  [[ -f "$HOME/.gitconfig" ]] && args+=("-v" "$HOME/.gitconfig:/home/host/.gitconfig:ro")
  [[ -f "$HOME/.ssh/known_hosts" ]] && args+=("-v" "$HOME/.ssh/known_hosts:/home/host/.ssh/known_hosts:ro")
  [[ -f "$HOME/.git-credentials" ]] && args+=("-v" "$HOME/.git-credentials:/home/host/.git-credentials:ro")
  
  # Persistent Cargo cache directories
  args+=("-v" "$CACHE_DIR/cargo-registry:/opt/rust/registry")
  args+=("-v" "$CACHE_DIR/cargo-git:/opt/rust/git")
  
  FINAL_CONFIG[docker_volume_args]="${args[*]}"
}
```

#### Updated CLI Argument Parsing
```bash
while [[ $# -gt 0 ]]; do
  case "$1" in
    # Existing arguments...
    
    --security-mode)
      if [[ $# -lt 2 ]]; then
        echo "cbox: Option --security-mode requires an argument" >&2
        exit 1
      fi
      if ! validate_security_mode "$2"; then
        exit 1
      fi
      SECURITY_CONFIG[mode]="$2"  
      shift 2
      ;;
    --network)
      if [[ $# -lt 2 ]]; then
        echo "cbox: Option --network requires an argument" >&2
        exit 1
      fi
      if ! validate_network_mode "$2"; then
        exit 1  
      fi
      SECURITY_CONFIG[network_type]="$2"
      shift 2
      ;;
    --ssh-agent)
      if [[ $# -lt 2 ]]; then
        echo "cbox: Option --ssh-agent requires an argument" >&2
        exit 1
      fi  
      if ! validate_boolean "$2" "ssh-agent"; then
        exit 1
      fi
      SECURITY_CONFIG[ssh_agent_enabled]="$2"
      shift 2
      ;;
    --read-only)
      SECURITY_CONFIG[volume_mode]="ro"
      shift
      ;;
    --no-network)
      SECURITY_CONFIG[network_type]="none"  
      shift
      ;;
    --no-ssh)
      SECURITY_CONFIG[ssh_agent_enabled]="false"
      shift
      ;;
    --config)
      if [[ $# -lt 2 ]]; then
        echo "cbox: Option --config requires an argument" >&2
        exit 1
      fi
      SECURITY_CONFIG[config_file]="$2"
      shift 2
      ;;
    --no-config)
      SECURITY_CONFIG[ignore_config]="true"
      shift
      ;;
    # ... existing cases
  esac
done
```

## Step 2: Configuration File Implementation  

### 2.1 Configuration Schema Design

#### JSON Schema Structure
```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "cbox Configuration",
  "type": "object",
  "properties": {
    "version": {
      "type": "string", 
      "enum": ["1.0"],
      "description": "Configuration format version"
    },
    "security": {
      "type": "object",
      "properties": {
        "mode": {
          "type": "string",
          "enum": ["standard", "restricted", "paranoid"], 
          "default": "standard",
          "description": "Security mode preset"
        },
        "network": {
          "type": "string",
          "enum": ["auto", "host", "bridge", "none"],
          "default": "auto", 
          "description": "Network configuration (auto = use security mode default)"
        },
        "sshAgent": {
          "type": "boolean",
          "default": null,
          "description": "Enable SSH agent (null = use security mode default)"
        },
        "readOnly": {
          "type": "boolean", 
          "default": false,
          "description": "Force read-only project directory"
        }
      }
    },
    "container": {
      "type": "object",
      "properties": {
        "image": {
          "type": "string",
          "default": "cbox:latest",
          "description": "Docker image to use"  
        },
        "memory": {
          "type": "string",
          "pattern": "^[0-9]+[kmgtKMGT]?$",
          "default": "4g",
          "description": "Memory limit (e.g., 4g, 512m)"
        },
        "cpus": {
          "type": "string", 
          "pattern": "^[0-9]+(\\.[0-9]+)?$",
          "default": "2",
          "description": "CPU limit (e.g., 2, 0.5)"
        }
      }
    },
    "volumes": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "host": {
            "type": "string",
            "description": "Host path to mount"
          },
          "container": {
            "type": "string", 
            "description": "Container mount point"
          },
          "mode": {
            "type": "string",
            "enum": ["ro", "rw"],
            "default": "ro",
            "description": "Mount mode"
          }
        },
        "required": ["host", "container"]
      }
    },
    "environment": {
      "type": "array",
      "items": {
        "type": "string",
        "pattern": "^[A-Z_][A-Z0-9_]*=.*$",
        "description": "Environment variables in VAR=value format"
      }
    }
  }
}
```

#### Example Configuration Files

**Project-Specific Configuration (`./.cbox.json`):**
```json
{
  "version": "1.0",
  "security": {
    "mode": "restricted",
    "network": "bridge"
  },
  "volumes": [
    {
      "host": "/project/data",
      "container": "/data", 
      "mode": "rw"
    }
  ],
  "environment": [
    "DEBUG_LEVEL=info",
    "PROJECT_ENV=development"
  ]
}
```

**User-Global Configuration (`~/.cbox.json`):**
```json
{
  "version": "1.0", 
  "security": {
    "mode": "standard"
  },
  "container": {
    "memory": "8g",
    "cpus": "4"
  },
  "environment": [
    "AWS_PROFILE=development",
    "EDITOR=vim"
  ]
}
```

### 2.2 Configuration Loading Implementation

#### Configuration File Discovery
```bash
discover_config_file() {
  local config_file=""
  
  # Skip discovery if explicitly disabled
  if [[ "${SECURITY_CONFIG[ignore_config]}" == "true" ]]; then
    return 0
  fi
  
  # Use explicit config file if provided
  if [[ -n "${SECURITY_CONFIG[config_file]}" ]]; then
    config_file="${SECURITY_CONFIG[config_file]}"
    if [[ ! -f "$config_file" ]]; then
      echo "cbox: Configuration file not found: $config_file" >&2
      exit 1
    fi
  else
    # Auto-discovery in priority order
    local candidates=(
      "./.cbox.json"                                           # Project-specific  
      "$HOME/.cbox.json"                                       # User-specific
      "${XDG_CONFIG_HOME:-$HOME/.config}/cbox/config.json"    # XDG standard
    )
    
    for candidate in "${candidates[@]}"; do
      if [[ -f "$candidate" ]]; then
        config_file="$candidate"
        break
      fi
    done
  fi
  
  if [[ -n "$config_file" ]]; then
    echo "cbox: Loading configuration from: $config_file" >&2
    SECURITY_CONFIG[config_file]="$config_file"
  fi
}
```

#### JSON Validation and Parsing
```bash
validate_json_syntax() {
  local config_file="$1"
  
  if ! command -v jq >/dev/null 2>&1; then
    echo "cbox: Warning - jq not found. Configuration files require jq for parsing." >&2
    echo "  Install jq: apt-get install jq  # or  brew install jq" >&2
    return 1
  fi
  
  if ! jq empty "$config_file" 2>/dev/null; then
    echo "cbox: Invalid JSON syntax in configuration file: $config_file" >&2
    echo "  Use 'jq . $config_file' to check syntax." >&2
    return 1
  fi
  
  return 0
}

load_config_values() {
  local config_file="$1"
  
  if ! validate_json_syntax "$config_file"; then
    return 1
  fi
  
  # Load security configuration
  local config_mode
  local config_network  
  local config_ssh_agent
  local config_read_only
  
  config_mode=$(jq -r '.security.mode // "standard"' "$config_file")
  config_network=$(jq -r '.security.network // "auto"' "$config_file")  
  config_ssh_agent=$(jq -r '.security.sshAgent // null' "$config_file")
  config_read_only=$(jq -r '.security.readOnly // false' "$config_file")
  
  # Validate loaded values
  if ! validate_security_mode "$config_mode"; then
    echo "cbox: Invalid security mode in config file: $config_mode" >&2
    return 1
  fi
  
  if [[ "$config_network" != "auto" ]] && ! validate_network_mode "$config_network"; then
    echo "cbox: Invalid network mode in config file: $config_network" >&2  
    return 1
  fi
  
  if [[ "$config_ssh_agent" != "null" ]] && ! validate_boolean "$config_ssh_agent" "sshAgent"; then
    echo "cbox: Invalid sshAgent value in config file: $config_ssh_agent" >&2
    return 1
  fi
  
  # Apply config file values (only if not already set by CLI)
  [[ -z "${SECURITY_CONFIG[mode]}" ]] && SECURITY_CONFIG[mode]="$config_mode"
  [[ -z "${SECURITY_CONFIG[network_type]}" && "$config_network" != "auto" ]] && SECURITY_CONFIG[network_type]="$config_network"
  [[ -z "${SECURITY_CONFIG[ssh_agent_enabled]}" && "$config_ssh_agent" != "null" ]] && SECURITY_CONFIG[ssh_agent_enabled]="$config_ssh_agent"
  [[ -z "${SECURITY_CONFIG[volume_mode]}" && "$config_read_only" == "true" ]] && SECURITY_CONFIG[volume_mode]="ro"
  
  # Load container configuration  
  local config_memory
  local config_cpus
  
  config_memory=$(jq -r '.container.memory // "4g"' "$config_file")
  config_cpus=$(jq -r '.container.cpus // "2"' "$config_file")
  
  # Apply container configuration (if not set by environment variables)
  [[ -z "${MEMORY_LIMIT}" ]] && MEMORY_LIMIT="$config_memory"
  [[ -z "${CPU_LIMIT}" ]] && CPU_LIMIT="$config_cpus"
}
```

### 2.3 Configuration Integration

#### Main Configuration Flow  
```bash
main_config_flow() {
  # 1. Discover and load configuration file
  discover_config_file
  if [[ -n "${SECURITY_CONFIG[config_file]}" ]]; then
    if ! load_config_values "${SECURITY_CONFIG[config_file]}"; then
      echo "cbox: Failed to load configuration file" >&2
      exit 1
    fi
  fi
  
  # 2. Apply security mode defaults  
  resolve_security_mode_defaults
  
  # 3. Apply CLI overrides (highest priority)
  apply_cli_overrides
  
  # 4. Build final Docker arguments
  build_docker_network_args
  build_docker_ssh_args  
  build_docker_volume_args
  
  # 5. Show configuration in verbose mode
  if [[ "${CBOX_VERBOSE:-0}" == "1" ]]; then
    show_final_configuration
  fi
}

show_final_configuration() {
  echo "cbox: Final configuration:" >&2
  echo "  Security Mode: ${SECURITY_CONFIG[mode]}" >&2
  echo "  Network: ${FINAL_CONFIG[network_type]}" >&2  
  echo "  SSH Agent: ${FINAL_CONFIG[ssh_agent_enabled]}" >&2
  echo "  Volume Mode: ${FINAL_CONFIG[volume_mode]}" >&2
  if [[ -n "${SECURITY_CONFIG[config_file]}" ]]; then
    echo "  Config File: ${SECURITY_CONFIG[config_file]}" >&2
  fi
}
```

## Security Considerations

### 2.4 Security Validation

#### Configuration Security Validation
```bash
validate_security_consistency() {
  local mode="${SECURITY_CONFIG[mode]}"
  local network="${FINAL_CONFIG[network_type]}"
  local ssh_agent="${FINAL_CONFIG[ssh_agent_enabled]}"
  local volume_mode="${FINAL_CONFIG[volume_mode]}"
  
  # Warn about potentially insecure combinations
  if [[ "$mode" == "paranoid" && "$network" != "none" ]]; then
    echo "cbox: Warning - Paranoid mode with network access enabled" >&2
    echo "  Consider using --no-network for maximum security" >&2
  fi
  
  if [[ "$mode" == "paranoid" && "$ssh_agent" == "true" ]]; then
    echo "cbox: Warning - Paranoid mode with SSH agent enabled" >&2  
    echo "  Consider using --no-ssh for maximum security" >&2
  fi
  
  if [[ "$mode" == "restricted" && "$network" == "host" ]]; then
    echo "cbox: Warning - Restricted mode with host network access" >&2
    echo "  This reduces network isolation benefits" >&2
  fi
  
  # Block dangerous combinations
  if [[ "$volume_mode" == "rw" && "$network" == "host" && "$ssh_agent" == "true" ]]; then
    echo "cbox: Notice - Full access configuration (host network + SSH + read/write)" >&2
    echo "  This is the standard mode behavior - consider restricted mode for untrusted code" >&2
  fi
}
```

#### Path Security for Config Files
```bash
validate_config_file_security() {
  local config_file="$1"
  
  # Ensure config file is not world-writable
  if [[ -f "$config_file" ]]; then
    local perms
    perms=$(stat -c %a "$config_file" 2>/dev/null || stat -f %Lp "$config_file" 2>/dev/null)
    
    if [[ "${perms: -1}" -gt 4 ]]; then
      echo "cbox: Security warning - Configuration file is world-readable: $config_file" >&2
      echo "  Consider: chmod 600 $config_file" >&2
    fi
    
    if [[ "${perms: -2:1}" -gt 4 ]]; then
      echo "cbox: Security error - Configuration file is group-writable: $config_file" >&2
      echo "  Fix with: chmod 600 $config_file" >&2
      return 1
    fi
  fi
  
  return 0
}
```

## Error Handling and User Experience

### 2.5 Comprehensive Error Handling

#### Validation Error Messages
```bash
show_validation_help() {
  local error_type="$1"
  
  case "$error_type" in
    security_mode)
      cat << EOF >&2
Security Mode Help:
  standard   - Full network access, SSH agent (current default behavior)
             - Use for: General development, trusted code
             
  restricted - Bridge network only, SSH agent enabled  
             - Use for: Untrusted code that needs Git operations
             
  paranoid   - No network, no SSH agent, read-only project
             - Use for: Maximum security, code analysis only

Examples:
  cbox --security-mode restricted ~/untrusted-project
  cbox --security-mode paranoid --read-only ~/analysis
EOF
      ;;
    network_mode)
      cat << EOF >&2
Network Mode Help:
  host    - Full access to host network (default for standard mode)
  bridge  - Isolated Docker bridge network (default for restricted mode) 
  none    - No network access (default for paranoid mode)

Examples:
  cbox --network bridge     # Isolated network with internet access
  cbox --network none       # Complete network isolation
EOF
      ;;
  esac
}
```

#### Configuration File Error Recovery
```bash
handle_config_error() {
  local config_file="$1"
  local error_type="$2"
  
  echo "cbox: Configuration error in $config_file" >&2
  
  case "$error_type" in
    json_syntax)
      echo "  JSON syntax error. Validate with: jq . '$config_file'" >&2
      echo "  Common issues: trailing commas, unquoted strings, missing brackets" >&2
      ;;
    invalid_mode)
      echo "  Invalid security mode. Valid options: standard, restricted, paranoid" >&2
      ;;
    invalid_network)  
      echo "  Invalid network mode. Valid options: auto, host, bridge, none" >&2
      ;;
  esac
  
  echo "" >&2
  echo "  To ignore configuration files, use: cbox --no-config" >&2
  echo "  To use a different config file: cbox --config /path/to/config.json" >&2
}
```

### 2.6 User Experience Enhancements

#### Configuration Discovery Feedback
```bash
show_config_discovery() {
  if [[ "${CBOX_VERBOSE:-0}" == "1" ]]; then
    echo "cbox: Configuration file discovery:" >&2
    
    local candidates=(
      "./.cbox.json"
      "$HOME/.cbox.json" 
      "${XDG_CONFIG_HOME:-$HOME/.config}/cbox/config.json"
    )
    
    for candidate in "${candidates[@]}"; do
      if [[ -f "$candidate" ]]; then
        echo "  ✓ Found: $candidate" >&2
      else
        echo "  ✗ Not found: $candidate" >&2
      fi
    done
  fi
}
```

#### Interactive Configuration Generation
```bash
generate_config_template() {
  local output_file="${1:-.cbox.json}"
  
  cat > "$output_file" << 'EOF'
{
  "_comment": "cbox configuration file",
  "_comment2": "See: https://github.com/bradleydwyer/cbox#configuration",
  
  "version": "1.0",
  
  "security": {
    "mode": "standard",
    "_mode_options": ["standard", "restricted", "paranoid"],
    
    "network": "auto", 
    "_network_options": ["auto", "host", "bridge", "none"],
    
    "sshAgent": null,
    "_sshAgent_comment": "null = use mode default, true/false = override",
    
    "readOnly": false
  },
  
  "container": {
    "image": "cbox:latest",
    "memory": "4g",
    "cpus": "2"
  },
  
  "volumes": [
    {
      "_comment": "Example additional volume mount",
      "host": "/host/path",
      "container": "/container/path",
      "mode": "ro"
    }
  ],
  
  "environment": [
    "DEBUG_LEVEL=info",
    "CUSTOM_VAR=value"
  ]
}
EOF

  echo "cbox: Generated configuration template: $output_file" >&2
  echo "  Edit this file and remove example entries as needed." >&2
}
```

## Testing Strategy

### 2.7 Test Coverage Requirements

#### Unit Tests
```bash
# Test configuration parsing
test_config_parsing() {
  local test_config="/tmp/test-config.json"
  
  # Test valid configuration
  cat > "$test_config" << 'EOF'
{"version": "1.0", "security": {"mode": "restricted"}}
EOF
  
  load_config_values "$test_config"
  assert_equals "${SECURITY_CONFIG[mode]}" "restricted"
  
  # Test invalid JSON
  echo "invalid json" > "$test_config"
  assert_fails load_config_values "$test_config"
  
  rm -f "$test_config"
}

# Test CLI argument parsing  
test_cli_parsing() {
  # Reset state
  declare -A SECURITY_CONFIG=()
  
  # Simulate CLI arguments
  set -- --security-mode paranoid --network none
  parse_cli_arguments "$@"
  
  assert_equals "${SECURITY_CONFIG[mode]}" "paranoid"
  assert_equals "${SECURITY_CONFIG[network_type]}" "none"
}

# Test configuration resolution
test_config_resolution() {
  # Test CLI override priority
  SECURITY_CONFIG[mode]="standard"  # From config
  SECURITY_CONFIG[network_type]="bridge"  # From CLI
  
  resolve_security_mode_defaults
  apply_cli_overrides
  
  assert_equals "${FINAL_CONFIG[network_type]}" "bridge"  # CLI wins
  assert_equals "${FINAL_CONFIG[ssh_agent_enabled]}" "true"  # Standard mode default
}
```

#### Integration Tests
```bash
# Test end-to-end configuration flow
test_e2e_configuration() {
  local test_dir="/tmp/cbox-test"
  mkdir -p "$test_dir"
  
  # Create test config
  cat > "$test_dir/.cbox.json" << 'EOF'
{"version": "1.0", "security": {"mode": "restricted"}}  
EOF
  
  cd "$test_dir"
  
  # Test config loading
  run_cbox_config_flow
  assert_equals "${FINAL_CONFIG[network_type]}" "bridge"
  
  cd - && rm -rf "$test_dir"
}

# Test Docker argument generation
test_docker_args() {
  FINAL_CONFIG[network_type]="none"
  FINAL_CONFIG[ssh_agent_enabled]="false"  
  FINAL_CONFIG[volume_mode]="ro"
  
  build_docker_network_args
  build_docker_ssh_args
  build_docker_volume_args
  
  assert_contains "${FINAL_CONFIG[docker_network_args]}" "--network=none"
  assert_not_contains "${FINAL_CONFIG[docker_ssh_args]}" "ssh-agent"
  assert_contains "${FINAL_CONFIG[docker_volume_args]}" ":ro"
}
```

## Implementation Timeline

### 2.8 Development Phases

#### Phase 1: CLI Arguments (Week 1, Days 1-3)
- [ ] Add new CLI argument parsing logic  
- [ ] Implement validation functions
- [ ] Add security mode resolution logic
- [ ] Update help text and error messages
- [ ] Basic unit tests for CLI parsing

#### Phase 2: Docker Integration (Week 1, Days 4-5)  
- [ ] Implement Docker argument generation functions
- [ ] Modify main Docker run command
- [ ] Test all security mode combinations
- [ ] Integration tests for Docker argument generation

#### Phase 3: Configuration File Support (Week 2, Days 1-3)
- [ ] Implement JSON schema validation
- [ ] Add configuration file discovery logic  
- [ ] Implement configuration loading and merging
- [ ] Add error handling and user feedback
- [ ] Unit tests for configuration parsing

#### Phase 4: Integration and Testing (Week 2, Days 4-5)
- [ ] Integrate CLI and config file systems
- [ ] End-to-end integration tests
- [ ] Security validation testing  
- [ ] Performance benchmarking
- [ ] Documentation updates

#### Phase 5: Polish and Documentation (Week 3)
- [ ] User experience improvements
- [ ] Comprehensive error messages
- [ ] Configuration generation tools
- [ ] Complete documentation
- [ ] Security audit and review

## Migration and Compatibility

### 2.9 Backward Compatibility

#### Existing User Impact
- **Zero breaking changes**: Default behavior remains identical (standard mode)
- **New features are opt-in**: Existing scripts and workflows unchanged
- **Environment variable compatibility**: Existing CBOX_* variables still work
- **Gradual adoption**: Users can adopt new features incrementally

#### Migration Path
```bash
# Current usage - no changes required
cbox ~/project

# Gradual security hardening
cbox --security-mode restricted ~/project     # Step 1: Network isolation
cbox --security-mode paranoid ~/project      # Step 2: Maximum security  

# Configuration file adoption
cbox --config ~/.cbox.json ~/project         # Step 3: Use config files
```

## Risk Assessment

### 2.10 Implementation Risks

#### High Risk Items
1. **CLI Parsing Complexity**: Complex argument interactions could introduce bugs
   - **Mitigation**: Comprehensive unit tests, clear validation logic

2. **Configuration File Security**: Malicious config files could modify behavior
   - **Mitigation**: Strict validation, permission checks, fail-safe defaults

3. **Docker Argument Generation**: Incorrect arguments could break container security  
   - **Mitigation**: Extensive testing, security review of all modes

#### Medium Risk Items
1. **User Experience**: Complex configuration options might confuse users
   - **Mitigation**: Clear documentation, helpful error messages, gradual rollout

2. **Performance Impact**: Additional configuration parsing could slow startup
   - **Mitigation**: Optimize parsing, lazy loading where possible

#### Low Risk Items  
1. **Maintenance Overhead**: Additional code complexity increases maintenance burden
   - **Mitigation**: Clean architecture, good test coverage, documentation

This comprehensive design provides a robust foundation for implementing security modes and configuration file support while maintaining cbox's security-first philosophy and user-friendly operation.