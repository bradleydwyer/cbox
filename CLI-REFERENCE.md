# cbox CLI Reference

Complete command-line interface reference for cbox v1.3.0

## Synopsis

```bash
cbox [OPTIONS] [DIRECTORY] [-- CLAUDE_ARGS...]
```

## Description

cbox runs Claude Code in a Docker sandbox with full network access and SSH agent forwarding. It provides an isolated environment while maintaining access to your host's authentication, Git configuration, and SSH keys.

## Options

### Core Options

#### `-h, --help`
Display help information and exit.

```bash
cbox --help
```

#### `-v, --version`
Display version information and exit.

```bash
cbox --version
# Output: cbox version 1.3.0
```

#### `--verbose`
Enable verbose debug output. Shows detailed information about Docker commands, volume mounts, and container execution.

```bash
cbox --verbose
# Equivalent to: CBOX_VERBOSE=1 cbox
```

#### `--shell`
Open an interactive bash shell in the container instead of running Claude Code. Useful for debugging and manual operations.

```bash
cbox --shell
# Opens: /bin/bash in container
```

#### `--verify`
Verify the installation and exit. Checks for Docker, SSH agent, and Claude authentication without running a container.

```bash
cbox --verify
# Output:
# ✓ cbox v1.3.0 installed successfully
# ✓ Docker is available and running
# ✓ SSH agent is running
# ✓ Claude authentication found
```

#### `-e VAR` or `-e VAR=value`
Pass environment variables to the container. Supports two formats:
- `-e VAR`: Pass variable from host environment (value taken from host)
- `-e VAR=value`: Set specific value directly

**New in v1.2.0**: Explicit control over environment variable passthrough.

```bash
# Pass variables from host environment
export AWS_PROFILE=production
cbox -e AWS_PROFILE -e AWS_REGION

# Set specific values
cbox -e "DEBUG=true" -e "LOG_LEVEL=verbose"

# Mix both formats
cbox -e AWS_PROFILE -e "ANTHROPIC_MODEL=claude-opus-4-1"

# Multiple variables for AWS Bedrock
cbox -e AWS_PROFILE -e AWS_REGION -e CLAUDE_CODE_USE_BEDROCK
```

**Important notes:**
- No automatic passthrough - you must explicitly specify each variable
- Empty or unset variables produce a warning in verbose mode
- Use multiple `-e` flags to pass multiple variables
- Values with spaces should be quoted: `-e "MY_VAR=value with spaces"`

### Security Options (New in v1.3.0)

#### `--security-mode MODE`
Set the security mode for the container. Controls network access, SSH agent availability, and file system permissions.

**Modes:**
- `standard`: Host network, SSH agent enabled, read/write access (default - same as v1.2.1)
- `restricted`: Bridge network with DNS, SSH agent enabled, read/write access  
- `paranoid`: Isolated bridge network, no SSH agent, read-only file system

```bash
cbox --security-mode standard   # Default mode (backward compatible)
cbox --security-mode restricted # Isolated network
cbox --security-mode paranoid   # Maximum security
```

#### `--network TYPE`
Override the network configuration for the container. Takes precedence over security mode defaults.

**Types:**
- `host`: Direct access to host network (default for standard mode)
- `bridge`: Isolated bridge network with DNS (default for restricted mode)
- `none`: No network access (not recommended - breaks Claude Code functionality)

```bash
cbox --network host     # Host network access
cbox --network bridge   # Isolated bridge network
cbox --network none     # No network access
```

#### `--ssh-agent BOOL`
Control SSH agent forwarding to the container. Takes precedence over security mode defaults.

**Values:**
- `true`: Enable SSH agent forwarding (default for standard/restricted modes)
- `false`: Disable SSH agent forwarding (default for paranoid mode)

```bash
cbox --ssh-agent true   # Enable SSH agent
cbox --ssh-agent false  # Disable SSH agent
```

#### `--read-only`
Force the project directory to be mounted as read-only, preventing the container from modifying files.

```bash
cbox --read-only                           # Read-only project directory
cbox --security-mode paranoid --read-only  # Explicit read-only in paranoid mode
```

**Security Combinations:**
```bash
# Maximum security for untrusted code
cbox --security-mode paranoid ~/untrusted-project

# Isolated network analysis 
cbox --network bridge --read-only ~/analysis

# Custom security configuration
cbox --network none --ssh-agent false --read-only ~/suspicious-code
```

## Arguments

### `DIRECTORY`
Optional. The directory to mount as the working directory in the container. If not specified, uses the current directory.

```bash
cbox                    # Use current directory
cbox ~/projects/myapp   # Use specific directory
cbox /tmp/test         # Use absolute path
```

**Security restrictions:**
- Cannot access system directories (/etc, /sys, /proc, /dev, /boot, /root)
- Cannot access binary directories (/bin, /sbin, /lib, /usr/bin, /usr/sbin)
- Cannot access system service directories (/var/log, /var/run, /var/lock)
- Allowed: /home, /tmp, /var/tmp, and user directories

### `-- CLAUDE_ARGS...`
Optional. Arguments to pass directly to the Claude Code CLI. Must be preceded by `--` to separate from cbox options.

```bash
cbox -- chat                           # Start chat mode
cbox -- chat --model opus              # Use specific model
cbox -- chat "Fix the bug in main.py"  # Direct command
```

## Environment Variables

### Required Variables

#### `SSH_AUTH_SOCK`
Path to SSH agent socket. Required for Git operations with private repositories when SSH agent is enabled (default for standard and restricted modes, disabled in paranoid mode).

```bash
# Start SSH agent if not running
eval $(ssh-agent -s)
ssh-add ~/.ssh/id_rsa
```

### Optional Variables

#### `GH_TOKEN` / `GITHUB_TOKEN`
GitHub authentication tokens. Automatically forwarded to the container in standard and restricted modes (blocked in paranoid mode for security). If both are set, `GH_TOKEN` takes precedence.

```bash
# Use environment variable
export GH_TOKEN=<your-github-token>
cbox

# Or set inline
GH_TOKEN=<token> cbox
```

**Security Notes:**
- Tokens are validated for proper GitHub format before forwarding
- Invalid tokens are rejected with warnings in verbose mode
- Tokens are never forwarded in paranoid mode
- Token presence is logged with SHA256 hash (first 8 chars) in verbose mode

#### `CBOX_REBUILD`
Force rebuild of the Docker image. Set to `1` to rebuild.

```bash
CBOX_REBUILD=1 cbox
```

#### `CBOX_VERBOSE`
Enable verbose debug output. Set to `1` to enable.

```bash
CBOX_VERBOSE=1 cbox
# Equivalent to: cbox --verbose
```

#### `XDG_CACHE_HOME`
Override cache directory location. Default: `~/.cache`

```bash
XDG_CACHE_HOME=/tmp/cache cbox
```

#### `XDG_CONFIG_HOME`
Override config directory location. Default: `~/.config`

```bash
XDG_CONFIG_HOME=/tmp/config cbox
```

#### `XDG_DATA_HOME`
Override data directory location. Default: `~/.local/share`

```bash
XDG_DATA_HOME=/tmp/data cbox
```

#### `TERM`
Terminal type passed to container. Default: `xterm-256color`

```bash
TERM=xterm cbox
```

## Volume Mounts

cbox automatically mounts the following volumes:

| Host Path | Container Path | Access | Purpose |
|-----------|---------------|--------|---------|
| `$WORKDIR` | `/work` | read-write/read-only* | Project files |
| `$SSH_AUTH_SOCK` | `/ssh-agent` | socket | SSH authentication** |
| `~/.claude` | `/home/host/.claude` | read-write | Claude config/agents |
| `~/.claude.json` | `/home/host/.claude.json` | read-write | Claude authentication |
| `~/.gitconfig` | `/home/host/.gitconfig` | read-only | Git configuration |
| `~/.config/gh` | `/home/host/.config/gh` | read-only | GitHub CLI config*** |
| `~/.ssh/known_hosts` | `/home/host/.ssh/known_hosts` | read-only | SSH known hosts |
| `~/.git-credentials` | `/home/host/.git-credentials` | read-only | Git credentials |

**Notes:**
- \* Read-only in paranoid mode, read-write in standard/restricted modes
- \*\* Not mounted in paranoid mode (SSH agent disabled)
- \*\*\* Only mounted in standard/restricted modes if directory exists

## Docker Container Details

### Base Image
`node:20-bookworm-slim`

### Installed Packages
- git
- openssh-client
- ca-certificates
- tini (init system)
- bash
- less
- curl
- wget
- procps (process utilities)
- gosu (user switching)
- @anthropic-ai/claude-code (latest)
- gh (GitHub CLI)
- hermit (package manager)

### Resource Limits
- Memory: 2GB
- CPUs: 2 cores

### User Mapping
Container automatically maps to your host user ID/GID to ensure proper file ownership.

## Examples

### Basic Usage

```bash
# Run in current directory
cbox

# Run in specific project
cbox ~/projects/myapp

# Open shell for debugging
cbox --shell
```

### With Claude Arguments

```bash
# Start chat with specific model
cbox -- chat --model opus

# Execute a specific task
cbox -- chat "Write unit tests for auth.py"

# Review code changes
cbox ~/project -- chat "Review the changes in my last commit"
```

### Advanced Usage

```bash
# Force rebuild and run verbose
CBOX_REBUILD=1 CBOX_VERBOSE=1 cbox

# Use custom cache directory
XDG_CACHE_HOME=/tmp/cbox-cache cbox

# Run with custom terminal
TERM=xterm-256color cbox

# Multiple environment variables
CBOX_VERBOSE=1 TERM=xterm cbox --shell
```

### CI/CD Integration

```yaml
# GitHub Actions example
- name: Code Review with Claude
  run: |
    eval $(ssh-agent -s)
    ssh-add - <<< "${{ secrets.SSH_PRIVATE_KEY }}"
    ./cbox . -- chat "Review code for security issues"

# GitLab CI example
code_review:
  script:
    - eval $(ssh-agent -s)
    - echo "$SSH_PRIVATE_KEY" | ssh-add -
    - cbox . -- chat "Check for code quality issues"
```

### Troubleshooting Commands

```bash
# Verify installation
cbox --verify

# Check Docker image
docker images | grep cbox

# Remove and rebuild image
docker rmi cbox:latest
CBOX_REBUILD=1 cbox --verify

# Debug mode
CBOX_VERBOSE=1 cbox 2>&1 | tee cbox-debug.log

# Check container processes
docker ps | grep cbox

# Clean up stopped containers
docker container prune
```

## GitHub Authentication Troubleshooting

### Issue: GitHub CLI not authenticated

**Symptoms:** `gh: error: auth required` or similar errors

**Solutions:**

1. **Check authentication status:**
```bash
cbox --shell
gh auth status
```

2. **Verify token is set on host:**
```bash
# Check if token exists
echo $GH_TOKEN
echo $GITHUB_TOKEN

# Set token if missing
export GH_TOKEN=<your-github-token>
```

3. **Verify token format:**
- Modern tokens start with: `ghp_`, `gho_`, `ghu_`, `ghs_`, `ghr_`, or `github_pat_`
- Legacy tokens are 40-character hex strings
- Invalid formats are rejected with warnings in verbose mode

4. **Check security mode:**
```bash
# GitHub auth is disabled in paranoid mode
cbox --security-mode paranoid  # No GitHub access
cbox --security-mode standard  # Full GitHub access (default)
```

### Issue: GitHub config not mounted

**Symptoms:** GitHub CLI doesn't remember settings or authentication

**Solutions:**

1. **Check if config directory exists:**
```bash
ls -la ~/.config/gh
```

2. **Authenticate on host first:**
```bash
# Run this on your host system, not in cbox
gh auth login
```

3. **Verify mounting in verbose mode:**
```bash
CBOX_VERBOSE=1 cbox 2>&1 | grep "GitHub"
# Should show: "GitHub authentication: config directory mounted"
```

### Issue: Token validation failures

**Symptoms:** "Invalid token format" warnings

**Solutions:**

1. **Check token format:**
   - Must be alphanumeric with underscores only
   - No spaces, quotes, or special characters
   - Correct length (40 chars for classic, 93 for fine-grained)

2. **Debug with verbose mode:**
```bash
CBOX_VERBOSE=1 cbox  # Check for GitHub auth messages
```

3. **Test token directly:**
```bash
# Test on host
gh auth status --show-token
```

## Configuration File

cbox supports an optional `.cbox.json` configuration file. See the main README for configuration options.

```bash
# Use project-specific config
echo '{"network": "host"}' > .cbox.json
cbox

# Use user-specific config
echo '{"memory": "4g"}' > ~/.cbox.json
cbox
```

## Exit Codes

| Code | Description |
|------|-------------|
| 0 | Success |
| 1 | General error |
| 2 | Docker not found or not running |
| 3 | SSH agent not available |
| 4 | Invalid directory or path |
| 5 | Security violation (blocked directory) |
| 127 | Command not found |

## Security Considerations

1. **Path Validation**: cbox validates all paths to prevent access to system directories
2. **Shell Injection**: Input is sanitized to prevent shell command injection
3. **Container Isolation**: Runs with limited resources (2GB RAM, 2 CPUs)
4. **Read-only Mounts**: Sensitive files mounted as read-only
5. **User Mapping**: Proper UID/GID mapping prevents permission issues

## Caching

cbox caches the Docker image and Dockerfile in:
```
~/.cache/cbox/
├── Dockerfile
└── [other cache files]
```

To clear the cache:
```bash
rm -rf ~/.cache/cbox
docker rmi cbox:latest
```

## Uninstallation

```bash
# Remove cbox script
sudo rm /usr/local/bin/cbox

# Remove Docker image
docker rmi cbox:latest

# Clean cache and config
rm -rf ~/.cache/cbox
rm -rf ~/.config/cbox
rm -rf ~/.local/share/cbox

# Remove any stopped containers
docker container prune
```

## See Also

- [README.md](README.md) - Main documentation
- [CONTRIBUTING.md](CONTRIBUTING.md) - Contribution guidelines
- [CHANGELOG.md](CHANGELOG.md) - Version history
- [SECURITY_AUDIT_REPORT.md](docs/SECURITY_AUDIT_REPORT.md) - Security analysis

## Support

For issues, questions, or contributions, visit:
https://github.com/bradleydwyer/cbox