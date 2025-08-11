# cbox - Claude Code Sandbox

[![Version](https://img.shields.io/badge/version-1.3.0-blue.svg)](https://github.com/bradleydwyer/cbox/releases)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Docker](https://img.shields.io/badge/docker-%3E%3D20.10-blue.svg)](https://www.docker.com/)
[![Platform](https://img.shields.io/badge/platform-linux%20%7C%20macos%20%7C%20wsl-lightgrey.svg)](README.md#system-requirements)
[![Shell](https://img.shields.io/badge/shell-bash%20%7C%20zsh-green.svg)](README.md#prerequisites)
[![Maintenance](https://img.shields.io/badge/maintained-yes-brightgreen.svg)](https://github.com/bradleydwyer/cbox/commits/main)

> ⚠️ **WARNING: Experimental Software - Use With Caution** ⚠️
> 
> This project is "vibe-coded" and highly experimental. It is **NOT** ready for production or serious use cases.
> This tool is provided as-is without guarantees. Use at your own risk and thoroughly test in isolated environments before any critical usage.
> Consider this an alpha-quality proof of concept that may have unexpected behaviors, security implications, or breaking changes.

> 🔴 **SECURITY NOTICE: This tool shares significant resources with the Docker container** 🔴
>
> - **Your Claude API token** (`~/.claude.json`) is accessible to the container
> - **Your entire working directory** has full read/write access from the container
> - **Your Git configuration and SSH agent** are exposed to the container
> - **The container has UNRESTRICTED network access** to any service
> - **Up to 1.4 GB of RAM** is used for temporary filesystems
> 
> See [Complete Shared Resources Documentation](#complete-shared-resources-documentation) for full details.

A simple Docker-based sandbox for running Claude Code with full network access and SSH agent forwarding.

## What is cbox?

`cbox` provides a one-command way to run Claude Code in an isolated Docker container while maintaining:
- Full network access (no egress firewall)
- SSH agent forwarding for GitHub push/pull
- Your Claude agents and authentication from `~/.claude`
- Proper file ownership (no root-owned files)
- Git configuration and SSH known hosts

## System Requirements

- **Docker**: Docker Desktop 20.10+ or Docker Engine with BuildKit support
- **Operating System**: macOS, Linux, or WSL2 on Windows
- **Shell**: Bash 4.0+ or Zsh
- **SSH Agent**: Active SSH agent with GitHub key loaded
- **Claude Code CLI**: Installed on host (optional but recommended for authentication)
- **Memory**: At least 4GB RAM available for Docker
- **Disk Space**: ~500MB for Docker image plus project space

## Prerequisites

- Docker Desktop installed and running
- SSH agent running with your GitHub key loaded:
  ```bash
  eval $(ssh-agent -s)
  ssh-add ~/.ssh/id_rsa  # or your key path
  ```

## Installation

### Quick Install (Recommended)

```bash
# Download and run the installation script
curl -fsSL https://raw.githubusercontent.com/bradleydwyer/cbox/main/install.sh | bash

# Verify installation
cbox --version
```

### Manual Installation

1. Clone this repository or copy the `cbox` script
2. Make it executable: `chmod +x cbox`
3. Add to your PATH:

   **For bash users:**
   ```bash
   # Option 1: Copy to a directory already in PATH
   sudo cp cbox /usr/local/bin/
   
   # Option 2: Add this directory to PATH (add to ~/.bashrc for permanent)
   echo 'export PATH="$PATH:/path/to/cbox"' >> ~/.bashrc
   source ~/.bashrc
   ```

   **For zsh users:**
   ```bash
   # Option 1: Copy to a directory already in PATH
   sudo cp cbox /usr/local/bin/
   
   # Option 2: Add this directory to PATH (add to ~/.zshrc for permanent)
   echo 'export PATH="$PATH:/path/to/cbox"' >> ~/.zshrc
   source ~/.zshrc
   ```

## Usage

For complete command-line reference, see [CLI-REFERENCE.md](CLI-REFERENCE.md).

### Quick Help

```bash
cbox --help               # Show help information
cbox --version            # Display version
cbox --verbose            # Run with debug output
cbox --verify             # Verify installation
```

### Security Options (New in v1.3.0)

```bash
# Security modes for different trust levels
cbox --security-mode standard     # Full access (default - same as v1.2.1)
cbox --security-mode restricted   # Bridge network, SSH agent, read/write
cbox --security-mode paranoid     # No network, no SSH, read-only

# Override individual security settings
cbox --network host               # Host network (default)
cbox --network bridge            # Isolated bridge network  
cbox --network none              # No network access
cbox --ssh-agent true            # Enable SSH agent (default)
cbox --ssh-agent false           # Disable SSH agent
cbox --read-only                 # Force read-only project directory

# Security combinations
cbox --security-mode paranoid ~/untrusted-code    # Maximum security
cbox --network bridge --read-only ~/analysis      # Isolated analysis
```

### Basic usage
Run in current directory:
```bash
cbox
```

Run in specific directory:
```bash
cbox ~/code/my-project
```

### Advanced usage
Pass extra arguments to Claude:
```bash
cbox ~/code/my-project -- chat --model sonnet-4.1
```

Force rebuild the Docker image:
```bash
CBOX_REBUILD=1 cbox
```

### More Examples

#### Working with private repositories
```bash
# Clone and work on a private repo
cbox ~/projects -- chat "Clone and analyze https://github.com/myorg/private-repo"
```

#### Switching between multiple projects
```bash
cbox ~/project-a  # Work on project A
cbox ~/project-b  # Switch to project B (separate container instance)
```

#### Using in CI/CD pipelines
```yaml
# Example GitHub Action
- name: Run Claude Code Analysis
  run: |
    eval $(ssh-agent -s)
    ssh-add - <<< "${{ secrets.SSH_PRIVATE_KEY }}"
    ./cbox . -- chat "Review code for security issues"
```

#### Debugging container issues
```bash
# Enable verbose mode to see Docker commands
CBOX_VERBOSE=1 cbox

# Open a shell in the container instead of Claude
cbox --shell

# Check Docker build logs
docker build -t cbox:latest -f ~/.cache/cbox/Dockerfile ~/.cache/cbox

# Manual container inspection
docker run -it --entrypoint /bin/bash cbox:latest
```

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `CBOX_REBUILD` | Force rebuild of Docker image (set to 1) | 0 |
| `CBOX_VERBOSE` | Enable verbose debug output (set to 1) | 0 |
| `XDG_CACHE_HOME` | Override cache directory location | ~/.cache |
| `XDG_CONFIG_HOME` | Override config directory location | ~/.config |
| `XDG_DATA_HOME` | Override data directory location | ~/.local/share |
| `TERM` | Terminal type passed to container | xterm-256color |
| `SSH_AUTH_SOCK` | SSH agent socket path | (required for SSH operations) |

### Passing Environment Variables (New in v1.2.0)

Use the `-e` flag to pass environment variables to the container:

```bash
# Pass variables from host environment  
cbox -e AWS_PROFILE -e AWS_REGION

# Set specific values
cbox -e "ANTHROPIC_MODEL=claude-opus-4-1"

# AWS Bedrock example
export AWS_PROFILE=my-profile
export CLAUDE_CODE_USE_BEDROCK=true
cbox -e AWS_PROFILE -e AWS_REGION -e CLAUDE_CODE_USE_BEDROCK
```

Two formats supported:
- `-e VAR` - Pass variable value from host environment
- `-e VAR=value` - Set specific value in container

Only variables you explicitly specify with `-e` are passed to the container.

## How it works

```
Host System                    Docker Container
-----------                    ----------------
Working Dir      ─────mount────>  /work
SSH Agent        ─────socket───>  /ssh-agent  
~/.claude        ─────mount────>  /home/host/.claude
~/.claude.json   ─────mount────>  /home/host/.claude.json
~/.gitconfig     ─────mount────>  /home/host/.gitconfig (read-only)
~/.ssh/known_hosts ───mount────>  /home/host/.ssh/known_hosts (read-only)
```

1. **First run**: Builds a minimal Docker image with Node.js and Claude Code CLI
2. **Mounts volumes**: Maps host directories and configurations into the container
3. **User mapping**: Uses gosu to ensure files created in container have proper host ownership
4. **Runs Claude**: Launches `claude --dangerously-skip-permissions` in the container

## Complete Shared Resources Documentation

> ⚠️ **CRITICAL SECURITY INFORMATION** ⚠️
> 
> This section documents ALL resources shared between your host system and the Docker container.
> Understanding these shared resources is essential for security awareness.

### 1. Persistent Volume Mounts (Host Files/Directories)

These directories and files from your host system are directly accessible to the container:

| Host Path | Container Path | Access | Purpose | Security Impact |
|-----------|---------------|--------|---------|-----------------|
| **Your working directory** | `/work` | **Read/Write** | Project files you're working on | ⚠️ **FULL ACCESS**: Container can read, modify, or delete ANY file in this directory |
| `$SSH_AUTH_SOCK` (socket) | `/ssh-agent` | **Read/Write** | SSH agent forwarding | ⚠️ Container can use your SSH keys for Git operations (keys stay on host) |
| `~/.claude/` | `/home/host/.claude` | **Read/Write** | Claude agents and settings | ⚠️ Container can access all your custom Claude agents |
| `~/.claude.json` | `/home/host/.claude.json` | **Read/Write** | Claude authentication | 🔴 **CRITICAL**: Contains your Claude API authentication token |
| `~/.gitconfig` | `/home/host/.gitconfig` | **Read-Only** | Git configuration | Container can see your Git username, email, and settings |
| `~/.ssh/known_hosts` | `/home/host/.ssh/known_hosts` | **Read-Only** | SSH known hosts | Container can see which SSH servers you've connected to |
| `~/.git-credentials` (if exists) | `/home/host/.git-credentials` | **Read-Only** | Git credentials helper | ⚠️ May contain stored Git authentication tokens |

**Security Warning**: The container has FULL read/write access to your working directory and Claude configuration. Only use cbox with trusted projects.

### 2. Temporary File Systems (tmpfs Mounts)

These are RAM-based temporary filesystems created for the container. They consume memory but provide fast, isolated storage:

| Container Path | Size Limit | Mount Options | Purpose | Memory Impact |
|----------------|------------|---------------|---------|---------------|
| `/tmp` | 512 MB | `rw,noexec,nosuid` | General temporary files | Uses up to 512 MB of RAM |
| `/run` | 64 MB | `rw,noexec,nosuid` | Runtime state files | Uses up to 64 MB of RAM |
| `/var/tmp` | 64 MB | `rw,noexec,nosuid` | Variable temporary data | Uses up to 64 MB of RAM |
| `/home/host/.cache` | 512 MB | `rw,noexec,nosuid` | User cache directory | Uses up to 512 MB of RAM |
| `/home/host/.npm` | 256 MB | `rw,noexec,nosuid` | NPM package cache | Uses up to 256 MB of RAM |
| `/home/host/bin` | 64 MB | `rw,noexec,nosuid` | User binaries (Hermit) | Uses up to 64 MB of RAM |

**Total Maximum RAM Usage from tmpfs**: 1,472 MB (~1.4 GB)

**Note**: These are maximum limits. Actual RAM usage depends on what the container writes to these directories. The `noexec` flag prevents execution of binaries from these locations for security.

### 3. Environment Variables Passed to Container

The following environment variables from your host are shared with the container:

| Variable | Value/Source | Purpose | Security Impact |
|----------|-------------|---------|-----------------|
| `HOME` | `/home/host` | User home directory in container | Sets container user's home |
| `USER` | `host` | Username in container | Identifies container user |
| `TERM` | Your terminal type | Terminal capabilities | Enables proper terminal display |
| `SSH_AUTH_SOCK` | `/ssh-agent` | SSH agent socket location | Enables SSH key usage |
| `HOST_UID` | Your user ID | User ID mapping | Ensures proper file ownership |
| `HOST_GID` | Your group ID | Group ID mapping | Ensures proper group ownership |

### 4. Docker Security Configuration

The container runs with specific security constraints:

#### Dropped Capabilities (Security Hardening)
- **ALL capabilities dropped by default** via `--cap-drop=ALL`
- This removes all Linux capabilities initially for maximum security

#### Added Capabilities (Required for Operation)
- `CHOWN`: Change file ownership (needed for user mapping)
- `DAC_OVERRIDE`: Override file permissions (needed for file operations)
- `FOWNER`: Bypass permission checks on files you own
- `SETUID`: Set user ID (needed for gosu user switching)
- `SETGID`: Set group ID (needed for group switching)

#### Additional Security Settings
- `--security-opt=no-new-privileges`: Prevents privilege escalation
- `--memory 4g`: Limits container to 4GB RAM (configurable)
- `--cpus 2`: Limits container to 2 CPU cores (configurable)

### 5. Network Access

⚠️ **IMPORTANT**: The container has **FULL, UNRESTRICTED network access**:
- Can connect to ANY internet service
- Can access your local network
- Can reach host services via `host.docker.internal`
- No firewall or egress filtering
- Can download/upload data without restrictions

### 6. What Is NOT Shared

For security, these are explicitly NOT shared with the container:
- Your SSH private keys (only the agent socket is shared)
- System directories (/etc, /usr, /bin, /sbin, /boot, /sys, /proc)
- Other user home directories
- Host system packages and binaries
- Docker socket (container cannot control Docker)
- Host Docker daemon (container cannot control Docker)

### 7. Data Persistence

**Important**: Only data written to `/work` (your mounted directory) persists after the container stops. Everything else is ephemeral:
- Files in `/tmp`, `/var/tmp`, etc. are lost when container stops
- NPM packages in `/home/host/.npm` must be reinstalled each run
- Changes to `/home/host/.cache` are not preserved

### 8. Security Recommendations

1. **Only use cbox with projects you trust** - The container can modify your project files
2. **Be aware of your Claude token** - It's accessible to the container via `~/.claude.json`
3. **Review your working directory** - Everything in it is fully accessible
4. **Monitor memory usage** - tmpfs mounts consume RAM from your system
5. **Understand network access** - The container can communicate with any network service
6. **Keep sensitive files outside the working directory** - They would be fully accessible
7. **Use SSH agent forwarding** - Don't copy SSH keys into the working directory

## Authentication

cbox automatically uses your host Claude authentication:
- If you've already logged into Claude on your host machine, cbox will use that authentication
- Your authentication is stored in `~/.claude.json` on the host
- To authenticate on the host first, run `claude login` outside of cbox
- All your custom agents from `~/.claude/agents/` are also available in the sandbox

## Network Configuration

- **Default network access**: Container runs with **host network** (same as v1.2.1)
- **Internet connectivity**: Can make outbound connections to any host
- **Host access**: Direct access to host services and network interfaces
- **SSH forwarding**: Uses forwarded agent from host for Git operations (when enabled)
- **No egress filtering**: No firewall restrictions on outbound connections
- **Security modes**: Bridge and none network options available for isolation

## File Permissions

- **Ownership preservation**: Files created in container maintain your host user ownership
- **UID/GID mapping**: Uses gosu for proper user ID and group ID mapping
- **No root files**: No root-owned files will be created in your project
- **Mount permissions**: Sensitive files like Git config mounted as read-only
- **Working directory**: Full read/write access to mounted project directory

## Security Notes - MUST READ

### What cbox Exposes to the Container

🔴 **Critical Security Information**:
1. **Your Claude API authentication token** via `~/.claude.json` - This is your API key
2. **Complete read/write access** to your entire working directory - All files can be modified or deleted
3. **Your SSH agent** - Container can use your SSH keys for Git operations (keys remain on host)
4. **Your Git identity and configuration** - Username, email, and all Git settings
5. **Unrestricted internet access** - Can connect to any website or service without limitations
6. **Up to 1.4 GB of your system RAM** for temporary filesystems

### Security Best Practices

- **ONLY use cbox with projects you completely trust**
- **NEVER run cbox in directories containing sensitive data** (passwords, private keys, etc.)
- **Be aware that your Claude API token is exposed** - The container can see it
- **Understand that the container can modify any file** in your working directory
- **Monitor network activity** if working with untrusted code
- **Review the [Complete Shared Resources Documentation](#complete-shared-resources-documentation)** to understand all shared resources

### Why These Resources Are Shared

Each shared resource serves a specific purpose:
- **Claude token**: Enables Claude Code to authenticate with the API
- **Working directory**: Allows Claude to read and modify your project files
- **SSH agent**: Enables Git push/pull to private repositories
- **Git config**: Maintains your Git identity for commits
- **Network access**: Allows package installation and API access
- **tmpfs mounts**: Provides fast temporary storage without writing to disk

If you're uncomfortable with any of these shared resources, **do not use cbox**.

## Maintenance

### Updating cbox

```bash
# Pull latest version
git pull origin main

# Or re-run installation script
curl -fsSL https://raw.githubusercontent.com/bradleydwyer/cbox/main/install.sh | bash
```

### Updating Claude Code CLI

```bash
# Force rebuild to get latest Claude version
CBOX_REBUILD=1 cbox
```

## Cleaning up / Uninstalling

```bash
# Remove the cbox script
sudo rm /usr/local/bin/cbox

# Remove Docker image
docker rmi cbox:latest

# Clean cache directory
rm -rf ~/.cache/cbox

# Remove any stopped containers
docker container prune
```

## Troubleshooting

### SSH agent not detected
```bash
# Start SSH agent
eval $(ssh-agent -s)

# Add your key
ssh-add ~/.ssh/id_rsa

# Verify it's loaded
ssh-add -l
```

### Docker not found
Install Docker Desktop from https://www.docker.com/products/docker-desktop/

### Permission denied
Make sure the script is executable:
```bash
chmod +x cbox
```

## FAQ

### Why use cbox vs direct Claude installation?

- **Isolation**: Keeps Claude Code and its operations separate from your host system
- **Consistency**: Same environment across different machines and team members
- **Easy cleanup**: Simply remove the Docker container when done
- **Security**: Contains Claude's file system access to the container

### Can I use multiple cbox instances simultaneously?

Yes! Each cbox invocation runs in its own container. You can work on multiple projects in parallel:
```bash
# Terminal 1
cbox ~/project-a

# Terminal 2  
cbox ~/project-b
```

### How do I share cbox environments with my team?

1. Commit the `cbox` script to your repository
2. Team members run the installation steps
3. Everyone gets the same containerized environment

### Can I customize the Docker image?

Yes, you can modify the Dockerfile creation in the script. Look for the heredoc section starting around line 22. Future versions will support custom Dockerfiles via configuration.

### Why does first run take longer?

The first run builds the Docker image, which includes:
- Downloading base Node.js image
- Installing Claude Code CLI
- Setting up the container environment

Subsequent runs use the cached image and start instantly.

### How do I use cbox with VS Code or other IDEs?

You can use cbox alongside your IDE - just run cbox in the terminal while editing in your IDE. The mounted volumes ensure both see the same files.

### What if Docker build fails?

Try:
1. Check Docker is running: `docker version`
2. Clear Docker cache: `docker system prune`
3. Rebuild from scratch: `CBOX_REBUILD=1 CBOX_VERBOSE=1 cbox`
4. Check build logs: `docker build -t cbox:latest -f ~/.cache/cbox/Dockerfile ~/.cache/cbox`

## Performance Considerations

- **First run**: Takes 30-60 seconds to build Docker image
- **Subsequent runs**: Start in under 2 seconds using cached image
- **Large directories**: May have slightly slower I/O due to volume mounting
- **Memory usage**: Container typically uses 200-500MB RAM
- **Network latency**: Minimal overhead for network operations

## Currently Implemented vs Planned Features

### ✅ Currently Implemented
- Docker containerization with proper isolation
- SSH agent forwarding for GitHub operations
- Claude Code CLI installation and execution
- Volume mounting for project files and configurations
- User ID/GID mapping for proper file ownership
- Environment variable passthrough (CBOX_REBUILD, CBOX_VERBOSE)
- Basic command-line options (--help, --version, --verbose, --verify, --shell)
- Installation and update scripts

### 📋 Planned Features (Not Yet Implemented)
- **Configuration file support** (.cbox.json parsing)
- **Telemetry system** for usage analytics
- **Custom Dockerfile support**
- **Security modes** (restricted, paranoid)
- **Auto-update functionality**
- **Advanced telemetry commands** (--telemetry-status, etc.)

Note: The `.cbox.json.example` file shows the planned configuration format, but this functionality is not yet implemented in the current version.

## Documentation

- [CLI-REFERENCE.md](CLI-REFERENCE.md) - Complete command-line reference
- [CHANGELOG.md](CHANGELOG.md) - Version history and release notes
- [CONTRIBUTING.md](CONTRIBUTING.md) - Contribution guidelines
- [SECURITY.md](SECURITY.md) - Security features and best practices
- [SECRET_SCANNING.md](SECRET_SCANNING.md) - Git pre-commit hooks and secret scanning setup

## License

MIT