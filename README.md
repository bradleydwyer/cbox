# cbox - Claude Code Sandbox

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
curl -fsSL https://raw.githubusercontent.com/yourusername/cbox/main/install.sh | bash

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

### Quick Help

```bash
cbox --help        # Show help information
cbox --version     # Display version
cbox --verbose     # Run with debug output
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

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `CBOX_REBUILD` | Force rebuild of Docker image (set to 1) | 0 |
| `CBOX_VERBOSE` | Enable verbose debug output (set to 1) | 0 |
| `XDG_CACHE_HOME` | Override cache directory location | ~/.cache |
| `TERM` | Terminal type passed to container | xterm-256color |
| `SSH_AUTH_SOCK` | SSH agent socket path | (required) |

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

## Authentication

cbox automatically uses your host Claude authentication:
- If you've already logged into Claude on your host machine, cbox will use that authentication
- Your authentication is stored in `~/.claude.json` on the host
- To authenticate on the host first, run `claude login` outside of cbox
- All your custom agents from `~/.claude/agents/` are also available in the sandbox

## Network Configuration

- **Full network access**: Container runs with default Docker bridge network
- **Internet connectivity**: Can make outbound connections to any host
- **Host access**: Can reach host services via `host.docker.internal`
- **SSH forwarding**: Uses forwarded agent from host for Git operations
- **No egress filtering**: No firewall restrictions on outbound connections

## File Permissions

- **Ownership preservation**: Files created in container maintain your host user ownership
- **UID/GID mapping**: Uses gosu for proper user ID and group ID mapping
- **No root files**: No root-owned files will be created in your project
- **Mount permissions**: Sensitive files like Git config mounted as read-only
- **Working directory**: Full read/write access to mounted project directory

## Security notes

- `--dangerously-skip-permissions` gives Claude broad access within the container
- The container has full network access (no firewall)
- Your `~/.claude` directory (including auth tokens) is mounted
- Only use on trusted repositories and projects

## Maintenance

### Updating cbox

```bash
# Pull latest version
git pull origin main

# Or re-run installation script
curl -fsSL https://raw.githubusercontent.com/yourusername/cbox/main/install.sh | bash
```

### Updating Claude Code CLI

```bash
# Force rebuild to get latest Claude version
CBOX_REBUILD=1 cbox
```

### Cleaning up / Uninstalling

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

## License

MIT