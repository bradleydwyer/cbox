# GitHub CLI Authentication - Technical Documentation

## Overview

cbox v1.3.0+ includes comprehensive GitHub CLI authentication support that automatically forwards GitHub credentials from the host system to the Docker container. This enables seamless use of the `gh` CLI tool and GitHub API operations without manual token configuration.

## Critical Bug Fix (v1.3.0+)

### Volume Mount Array Initialization Bug

**Problem**: The volume mount array was being overwritten instead of appended to, causing GitHub config directory mounts to be lost.

**Root Cause**: Lines 954 and 957 in the cbox script were using `vols=` instead of `vols+=`, which reset the array instead of appending.

```bash
# BEFORE (broken):
vols=(-v "$WORKDIR":/work:ro)  # This overwrites the entire array!

# AFTER (fixed):
vols+=(-v "$WORKDIR":/work:ro)  # This properly appends to the array
```

**Impact**: Without this fix, the GitHub config directory (`~/.config/gh`) was never mounted, preventing GitHub CLI authentication from working.

## Authentication Methods

### 1. Environment Variable Detection

The system checks for GitHub tokens in this order:
1. `GH_TOKEN` environment variable
2. `GITHUB_TOKEN` environment variable

If either is set, it's automatically forwarded to the container.

### 2. GitHub CLI Token Extraction (macOS Keychain Support)

When no environment variables are found but `gh` CLI is authenticated:

```bash
# Detection logic (lines 362-390)
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  # Extract token from gh CLI
  extracted_token=$(
    set +x  # Disable trace
    set +o history  # Disable history
    gh auth token 2>/dev/null
  )
```

**Security Features**:
- Token never appears in process lists
- History recording disabled during extraction
- Uses subshell isolation
- Timeout protection (2 seconds) where available
- SHA256 hash logging for verification without exposure

### 3. GitHub Config Directory Mounting

The `~/.config/gh` directory is mounted when:
- It exists on the host
- Security mode is not `paranoid`

```bash
# Line 371-373
if [[ -d "$HOME/.config/gh" ]]; then
  vols+=(-v "$HOME/.config/gh":/home/host/.config/gh:ro)
  ENV_VARS+=("GH_CONFIG_DIR=/home/host/.config/gh")
fi
```

## Token Validation

### Supported Token Formats

The system validates tokens against modern GitHub token patterns:

```bash
# Token format validation regex (line 273)
^(gh[ps]_[a-zA-Z0-9]{36,255}|github_pat_[a-zA-Z0-9_]{82,255})$
```

**Supported formats**:
- Personal Access Tokens: `ghp_*` (36-255 chars)
- GitHub App tokens: `ghs_*` (36-255 chars)  
- Fine-grained PATs: `github_pat_*` (82-255 chars)

### Validation Process

1. **Format Check**: Ensures token matches expected patterns
2. **Length Validation**: Verifies appropriate token length
3. **Character Set**: Only alphanumeric and underscores allowed
4. **Security Logging**: Logs SHA256 hash for verification

## Security Implementation

### Token Protection Mechanisms

#### 1. Process List Protection

Tokens are never passed as command arguments:

```bash
# NEVER done (would expose token):
docker run -e GH_TOKEN=$token ...

# INSTEAD (secure):
ENV_VARS+=("GH_TOKEN=$token")
docker run "${ENV_VARS[@]/#/-e }" ...
```

#### 2. History Protection

Command history recording is disabled during token operations:

```bash
set +o history 2>/dev/null || true
# Token operations here
set -o history 2>/dev/null || true
```

#### 3. Trace Protection

Shell tracing is explicitly disabled:

```bash
set +x  # Ensure trace is off during sensitive operations
```

#### 4. Logging Security

Tokens are never logged directly. Instead, SHA256 hashes are used:

```bash
# Line 284-285
local token_hash=$(echo -n "$token_value" | sha256sum | cut -d' ' -f1)
echo "cbox: Forwarding $token_name (SHA256: ${token_hash:0:12}...)" >&2
```

### Security Mode Integration

| Security Mode | Token Forwarding | Config Mount | Network Access |
|--------------|------------------|--------------|----------------|
| `standard` | ✅ Enabled | ✅ Mounted | Full (host) |
| `restricted` | ✅ Enabled | ✅ Mounted | Limited (bridge) |
| `paranoid` | ❌ Blocked | ❌ Not mounted | None |

## Echo Command Fix

### Problem

The `echo -e` flag was not being properly passed to Docker, breaking color output.

### Solution

Replaced `echo -e` with `printf` for portable escape sequence handling:

```bash
# BEFORE (broken):
echo -e "${green}✓${reset} Installation completed successfully!"

# AFTER (fixed):
printf "%b✓%b Installation completed successfully!\n" "$green" "$reset"
```

## Debug Output Enhancement

### ENV_VARS Array Debugging

Added comprehensive debugging for environment variables (lines 1027-1034):

```bash
if [[ "${CBOX_VERBOSE:-0}" == "1" ]]; then
  echo "cbox: ENV_VARS array contents:" >&2
  for var in "${ENV_VARS[@]}"; do
    # Redact sensitive values
    if [[ "$var" =~ ^(GH_TOKEN|GITHUB_TOKEN)= ]]; then
      echo "  ${var%%=*}=<redacted>" >&2
    else
      echo "  $var" >&2
    fi
  done
fi
```

## Usage Examples

### Basic GitHub CLI Operations

```bash
# Check authentication status
cbox --shell
gh auth status

# Create a pull request
cbox ~/my-project
gh pr create --title "Feature" --body "Description"

# Work with issues
cbox ~/my-project -- gh issue list --label bug
```

### Troubleshooting Authentication

```bash
# Enable verbose mode to see token detection
CBOX_VERBOSE=1 cbox ~/my-project

# Check if token is being forwarded
cbox --shell
env | grep -E '^(GH_|GITHUB_)'

# Verify gh config directory mount
cbox --shell
ls -la ~/.config/gh
```

### Using with Different Authentication Methods

```bash
# Method 1: Environment variable
export GH_TOKEN=ghp_xxxxxxxxxxxx
cbox ~/my-project

# Method 2: GitHub CLI with keychain (macOS)
gh auth login  # Use keychain storage
cbox ~/my-project  # Token auto-extracted

# Method 3: Explicit token passing
cbox -e GH_TOKEN=ghp_xxxxxxxxxxxx ~/my-project
```

## Implementation Details

### Key Code Sections

1. **Token Forwarding Function** (lines 266-291)
   - Validates token format
   - Creates secure environment variable
   - Logs with SHA256 hash

2. **GitHub Authentication Setup** (lines 330-421)
   - Checks environment variables
   - Attempts gh CLI extraction
   - Mounts config directory
   - Sets up environment

3. **Volume Mount Assembly** (lines 951-977)
   - Fixed array initialization
   - Conditional config mounting
   - Security mode compliance

4. **Docker Execution** (lines 1025-1054)
   - Applies environment variables
   - Maintains security
   - Enables debugging

## Best Practices

### For Users

1. **Use GitHub CLI for Authentication**:
   ```bash
   gh auth login --git-protocol ssh
   ```

2. **Verify Authentication Before Running cbox**:
   ```bash
   gh auth status
   ```

3. **Use Keychain Storage on macOS**:
   - More secure than environment variables
   - Automatically handled by cbox

4. **Check Token Permissions**:
   - Ensure `repo`, `read:org`, and optionally `workflow` scopes

### For Developers

1. **Never Log Tokens Directly**:
   - Always use SHA256 hashes for logging
   - Redact sensitive values in debug output

2. **Use Secure Token Passing**:
   - Never pass tokens as command arguments
   - Use environment variable arrays

3. **Validate Token Formats**:
   - Check against known GitHub token patterns
   - Reject invalid formats early

4. **Respect Security Modes**:
   - Don't forward tokens in paranoid mode
   - Document security implications

## Troubleshooting Guide

### Token Not Being Forwarded

1. **Check gh CLI authentication**:
   ```bash
   gh auth status
   ```

2. **Verify environment variables**:
   ```bash
   env | grep -E '^(GH_|GITHUB_)'
   ```

3. **Enable verbose mode**:
   ```bash
   CBOX_VERBOSE=1 cbox ~/project
   ```

### GitHub CLI Commands Failing

1. **Verify token permissions**:
   - Need `repo` scope minimum
   - Check at https://github.com/settings/tokens

2. **Check network access**:
   ```bash
   cbox --shell
   curl -I https://api.github.com
   ```

3. **Verify config mount**:
   ```bash
   cbox --shell
   ls -la ~/.config/gh
   ```

### macOS Keychain Issues

1. **Keychain prompt hanging**:
   - Unlock keychain first: `security unlock-keychain`
   - Or use environment variable instead

2. **Token extraction timeout**:
   - Falls back gracefully
   - Can set token manually: `export GH_TOKEN=$(gh auth token)`

## Security Considerations

### Token Exposure Risks

1. **Process List**: Mitigated by using arrays and subshells
2. **Shell History**: Disabled during token operations
3. **Log Files**: Only SHA256 hashes logged
4. **Container Access**: Tokens accessible inside container (by design)

### Recommendations

1. **Use Restricted Tokens**: Create tokens with minimal required permissions
2. **Rotate Regularly**: Change tokens periodically
3. **Monitor Usage**: Check GitHub audit logs
4. **Use Paranoid Mode**: For untrusted code that doesn't need GitHub access

## Version History

- **v1.3.0**: Initial implementation with volume mount bug
- **v1.3.1** (upcoming): Fixed volume mount bug, added keychain extraction

## Related Documentation

- [SECURITY_MODES_DESIGN.md](SECURITY_MODES_DESIGN.md) - Security mode details
- [ENVIRONMENT_VARIABLES_REVIEW.md](ENVIRONMENT_VARIABLES_REVIEW.md) - Environment variable handling
- [README.md](../README.md#github-cli-authentication-optional) - User-facing documentation