# Contributing to cbox

Thank you for your interest in contributing to cbox! We're excited to have you join our community. This guide will help you get started with contributing to the project, whether you're fixing bugs, adding features, improving documentation, or helping in other ways.

## Table of Contents

1. [Welcome and Code of Conduct](#welcome-and-code-of-conduct)
2. [Development Environment Setup](#development-environment-setup)
3. [Project Architecture Overview](#project-architecture-overview)
4. [How to Run Tests](#how-to-run-tests)
5. [Coding Standards and Style Guide](#coding-standards-and-style-guide)
6. [How to Submit Issues](#how-to-submit-issues)
7. [How to Submit Pull Requests](#how-to-submit-pull-requests)
8. [Commit Message Conventions](#commit-message-conventions)
9. [Security Vulnerability Reporting](#security-vulnerability-reporting)
10. [Release Process](#release-process)

## Welcome and Code of Conduct

### Our Pledge

We as members, contributors, and leaders pledge to make participation in our community a harassment-free experience for everyone, regardless of age, body size, visible or invisible disability, ethnicity, sex characteristics, gender identity and expression, level of experience, education, socio-economic status, nationality, personal appearance, race, religion, or sexual identity and orientation.

### Our Standards

**Examples of behavior that contributes to a positive environment:**

- Using welcoming and inclusive language
- Being respectful of differing viewpoints and experiences
- Gracefully accepting constructive criticism
- Focusing on what is best for the community
- Showing empathy towards other community members
- Helping newcomers get started

**Examples of unacceptable behavior:**

- The use of sexualized language or imagery, and sexual attention or advances of any kind
- Trolling, insulting or derogatory comments, and personal or political attacks
- Public or private harassment
- Publishing others' private information without explicit permission
- Other conduct which could reasonably be considered inappropriate in a professional setting

### Enforcement

Instances of abusive, harassing, or otherwise unacceptable behavior may be reported by opening an issue or contacting the project maintainers directly. All complaints will be reviewed and investigated promptly and fairly.

## Development Environment Setup

### Prerequisites

Before you begin, ensure you have the following installed:

1. **Git** (2.25+)
   ```bash
   git --version
   ```

2. **Docker** (20.10+)
   ```bash
   docker --version
   ```

3. **Bash** (4.0+) or **Zsh**
   ```bash
   bash --version
   # or
   zsh --version
   ```

4. **SSH Agent** with GitHub key loaded
   ```bash
   eval $(ssh-agent -s)
   ssh-add ~/.ssh/id_rsa  # or your GitHub key
   ssh-add -l  # Verify key is loaded
   ```

5. **Claude Code CLI** (optional, for testing authentication)
   ```bash
   npm i -g @anthropic-ai/claude-code@latest
   claude --version
   ```

### Setting Up Your Development Environment

1. **Fork and clone the repository**
   ```bash
   # Fork the repository on GitHub first, then:
   git clone git@github.com:YOUR_USERNAME/cbox.git
   cd cbox
   
   # Add upstream remote
   git remote add upstream git@github.com:bradleydwyer/cbox.git
   ```

2. **Create a development branch**
   ```bash
   git checkout -b feature/your-feature-name
   # or
   git checkout -b fix/issue-description
   ```

3. **Make the script executable**
   ```bash
   chmod +x cbox
   chmod +x install.sh
   chmod +x cbox-update
   ```

4. **Test your local version**
   ```bash
   # Run directly from the repository
   ./cbox --verify
   
   # Or install to /usr/local/bin for system-wide testing
   sudo cp cbox /usr/local/bin/
   ```

5. **Build the Docker image**
   ```bash
   CBOX_REBUILD=1 ./cbox --verify
   ```

### Development Workflow

1. **Use verbose mode for debugging**
   ```bash
   CBOX_VERBOSE=1 ./cbox
   ```

2. **Test in shell mode**
   ```bash
   ./cbox --shell
   ```

3. **Monitor Docker logs**
   ```bash
   # In another terminal
   docker logs -f $(docker ps -q --filter ancestor=cbox:latest)
   ```

4. **Clean development environment**
   ```bash
   # Remove Docker image
   docker rmi cbox:latest
   
   # Clean cache
   rm -rf ~/.cache/cbox
   
   # Remove test containers
   docker container prune
   ```

## Project Architecture Overview

### Component Structure

```
cbox/
├── cbox                 # Main executable script
├── cbox-update         # Force rebuild utility
├── install.sh          # Installation script
├── README.md           # User documentation
├── CONTRIBUTING.md     # This file
└── LICENSE            # MIT license

~/.cache/cbox/          # Runtime cache (created automatically)
└── Dockerfile         # Generated Docker configuration
```

### Core Components

#### 1. **cbox Script** (`/work/cbox`)
The main executable that orchestrates the Docker container lifecycle.

**Key responsibilities:**
- Command-line argument parsing
- Docker image building and caching
- Volume mount configuration
- SSH agent forwarding setup
- User ID/GID mapping for proper file ownership
- Claude Code CLI invocation

**Key functions:**
- `show_help()`: Display usage information
- Argument parsing loop: Process CLI options
- Sanity checks: Validate Docker, SSH agent, and directories
- Dockerfile generation: Create minimal container specification
- Container execution: Run with proper mounts and environment

#### 2. **Installation Script** (`/work/install.sh`)
Automated installer for setting up cbox on new systems.

**Key features:**
- OS detection (Linux, macOS, Windows/WSL)
- Prerequisite checking
- Download and installation
- Shell integration
- Verification

#### 3. **Docker Container**
Minimal Node.js environment with Claude Code CLI.

**Base image:** `node:20-bookworm-slim`
**Additional packages:** git, openssh-client, gosu, tini, curl, wget
**Entry point:** Custom script for user mapping

### Data Flow

```
User Input → cbox script → Docker Build (if needed) → Container Launch
                ↓                                            ↓
            Parse Args                               Mount Volumes
                ↓                                            ↓
            Validate                                 Setup Environment
                ↓                                            ↓
            Configure                                Run Claude Code
```

### Volume Mounts

| Host Path | Container Path | Purpose | Mode |
|-----------|---------------|---------|------|
| `$WORKDIR` | `/work` | Project files | read-write |
| `$SSH_AUTH_SOCK` | `/ssh-agent` | SSH authentication | socket |
| `~/.claude` | `/home/host/.claude` | Claude config/agents | read-write |
| `~/.claude.json` | `/home/host/.claude.json` | Authentication | read-write |
| `~/.gitconfig` | `/home/host/.gitconfig` | Git configuration | read-only |
| `~/.ssh/known_hosts` | `/home/host/.ssh/known_hosts` | SSH hosts | read-only |

## How to Run Tests

Currently, cbox uses manual testing procedures. We're working on automated tests for future releases.

### Manual Testing Checklist

#### Basic Functionality
```bash
# 1. Verify installation
./cbox --verify

# 2. Check version
./cbox --version

# 3. Display help
./cbox --help

# 4. Run in current directory
./cbox

# 5. Run in specific directory
./cbox /tmp/test-project

# 6. Pass arguments to Claude
./cbox -- chat --model opus

# 7. Open shell mode
./cbox --shell
```

#### Docker Integration
```bash
# 1. Force rebuild
CBOX_REBUILD=1 ./cbox --verify

# 2. Check image creation
docker images | grep cbox

# 3. Verify container cleanup
./cbox -- chat "exit"
docker ps -a | grep cbox  # Should be empty
```

#### File Permissions
```bash
# 1. Create test directory
mkdir /tmp/cbox-test
cd /tmp/cbox-test

# 2. Run cbox and create a file
./cbox -- chat "Create a test.txt file with 'Hello World'"

# 3. Check ownership
ls -la test.txt  # Should be owned by your user, not root
```

#### SSH Agent Forwarding
```bash
# 1. Ensure SSH agent is running
ssh-add -l

# 2. Test Git operations in container
./cbox --shell
# Inside container:
ssh -T git@github.com  # Should authenticate
```

### Testing Different Scenarios

1. **Fresh installation**
   ```bash
   # Remove all cbox artifacts
   sudo rm /usr/local/bin/cbox
   docker rmi cbox:latest
   rm -rf ~/.cache/cbox
   
   # Run installation
   ./install.sh
   ```

2. **Network connectivity**
   ```bash
   ./cbox --shell
   # Inside container:
   ping -c 1 google.com
   curl https://api.github.com
   ```

3. **Claude authentication**
   ```bash
   # Without auth
   rm ~/.claude.json
   ./cbox  # Should warn about missing auth
   
   # With auth
   claude login  # On host
   ./cbox  # Should use existing auth
   ```

## Coding Standards and Style Guide

### Shell Script Standards

#### General Principles

1. **Use Bash strict mode**
   ```bash
   #!/usr/bin/env bash
   set -euo pipefail
   ```

2. **Quote variables**
   ```bash
   # Good
   echo "$VARIABLE"
   
   # Bad
   echo $VARIABLE
   ```

3. **Use meaningful variable names**
   ```bash
   # Good
   DOCKER_IMAGE="cbox:latest"
   
   # Bad
   IMG="cbox:latest"
   ```

4. **Check command availability**
   ```bash
   if ! command -v docker >/dev/null 2>&1; then
     echo "Docker is required but not found" >&2
     exit 1
   fi
   ```

5. **Use functions for repeated code**
   ```bash
   show_error() {
     echo "Error: $1" >&2
     exit "${2:-1}"
   }
   ```

#### Code Style

- **Indentation:** 2 spaces (no tabs)
- **Line length:** Maximum 100 characters
- **Function names:** lowercase with underscores
- **Constants:** UPPERCASE with underscores
- **Local variables:** lowercase with underscores

#### Comments

```bash
# Section header
# =============

# Multi-line explanation for complex logic
# that spans multiple lines should be
# formatted like this

# Single line comment for simple explanation
command --with-args

# TODO: Future improvement note
# FIXME: Known issue that needs addressing
# NOTE: Important information for maintainers
```

### Docker Best Practices

1. **Minimize layers**
   ```dockerfile
   # Good - single RUN command
   RUN apt-get update && \
       apt-get install -y package1 package2 && \
       rm -rf /var/lib/apt/lists/*
   ```

2. **Use specific versions**
   ```dockerfile
   FROM node:20-bookworm-slim
   # Not: FROM node:latest
   ```

3. **Clean up after installations**
   ```dockerfile
   RUN apt-get update && \
       apt-get install -y packages && \
       rm -rf /var/lib/apt/lists/*
   ```

### Documentation Standards

- Use clear, concise language
- Include examples for all features
- Explain both the "what" and "why"
- Keep README focused on users
- Use CONTRIBUTING for developers
- Update documentation with code changes

## How to Submit Issues

### Before Submitting an Issue

1. **Search existing issues** to avoid duplicates
2. **Check the README** for solutions to common problems
3. **Gather system information**:
   ```bash
   cbox --version
   docker --version
   echo $SHELL
   uname -a
   ```

### Issue Templates

#### Bug Report

**Title:** [BUG] Brief description

**Body:**
```markdown
## Description
A clear description of the bug.

## Steps to Reproduce
1. Run command '...'
2. See error '...'

## Expected Behavior
What should happen.

## Actual Behavior
What actually happens.

## System Information
- cbox version: 
- Docker version: 
- OS: 
- Shell: 

## Additional Context
Any other relevant information, error messages, or screenshots.
```

#### Feature Request

**Title:** [FEATURE] Brief description

**Body:**
```markdown
## Problem Statement
What problem does this solve?

## Proposed Solution
How would you like it to work?

## Alternatives Considered
What other solutions have you considered?

## Additional Context
Use cases, examples, or mockups.
```

#### Documentation Issue

**Title:** [DOCS] Brief description

**Body:**
```markdown
## Location
Where in the documentation?

## Issue
What's wrong or missing?

## Suggested Improvement
How should it be fixed?
```

### Issue Labels

- `bug`: Something isn't working
- `enhancement`: New feature or request
- `documentation`: Documentation improvements
- `good first issue`: Good for newcomers
- `help wanted`: Extra attention needed
- `question`: Further information requested
- `wontfix`: This will not be worked on
- `duplicate`: This issue already exists

## How to Submit Pull Requests

### Pull Request Process

1. **Fork and clone** the repository
2. **Create a feature branch** from `main`
3. **Make your changes** following our coding standards
4. **Test thoroughly** using the manual testing checklist
5. **Update documentation** if needed
6. **Commit with meaningful messages** (see commit conventions)
7. **Push to your fork**
8. **Open a Pull Request**

### Pull Request Template

**Title:** Brief description of changes

**Body:**
```markdown
## Description
What does this PR do?

## Type of Change
- [ ] Bug fix (non-breaking change)
- [ ] New feature (non-breaking change)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update

## Related Issues
Fixes #(issue number)

## Testing
How has this been tested?
- [ ] Test A
- [ ] Test B

## Checklist
- [ ] My code follows the project's style guidelines
- [ ] I have performed a self-review of my own code
- [ ] I have commented my code, particularly in hard-to-understand areas
- [ ] I have made corresponding changes to the documentation
- [ ] My changes generate no new warnings
- [ ] I have tested my changes thoroughly
- [ ] I have checked my code and corrected any misspellings

## Screenshots (if applicable)
Add screenshots to help explain your changes.

## Additional Notes
Any additional information or context.
```

### Pull Request Guidelines

1. **Keep changes focused** - One feature/fix per PR
2. **Write descriptive PR titles** - Will be used in release notes
3. **Link related issues** - Use "Fixes #123" in description
4. **Update tests** - Add tests for new features
5. **Maintain backwards compatibility** - Or clearly document breaking changes
6. **Respond to feedback** - Address review comments promptly
7. **Keep PR updated** - Rebase on main if needed

### Code Review Process

1. **Automated checks** run on all PRs
2. **Maintainer review** within 48-72 hours
3. **Address feedback** through new commits or discussion
4. **Approval and merge** once all checks pass

## Commit Message Conventions

We follow a modified version of [Conventional Commits](https://www.conventionalcommits.org/).

### Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code changes that neither fix bugs nor add features
- `perf`: Performance improvements
- `test`: Adding or updating tests
- `chore`: Maintenance tasks
- `ci`: CI/CD changes
- `build`: Build system changes

### Scope (optional)

- `docker`: Docker-related changes
- `install`: Installation script changes
- `cli`: Command-line interface changes
- `config`: Configuration changes

### Examples

```bash
# Feature
feat(docker): add support for custom Dockerfiles

# Bug fix
fix: correctly handle spaces in directory paths

# Documentation
docs: update installation instructions for Windows users

# Refactoring
refactor(cli): simplify argument parsing logic

# With body
fix(docker): resolve SSH agent socket permission issues

The SSH agent socket was not accessible inside the container
due to incorrect permission mapping. This fix ensures the
socket is properly mounted with the correct ownership.

Fixes #42
```

### Commit Message Guidelines

1. **Use the imperative mood** ("Add feature" not "Added feature")
2. **Keep subject line under 72 characters**
3. **Capitalize the subject line**
4. **Don't end subject with a period**
5. **Separate subject from body with blank line**
6. **Use body to explain what and why** vs. how
7. **Reference issues and PRs** in the footer

## Security Vulnerability Reporting

### Reporting Security Issues

**DO NOT** create public issues for security vulnerabilities. Instead:

1. **Email the maintainers** directly with details
2. **Include:**
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

3. **Wait for response** (usually within 48 hours)
4. **Coordinate disclosure** timeline with maintainers

### Security Best Practices

When contributing code:

1. **Never commit secrets** (API keys, passwords, tokens)
2. **Validate all inputs** especially from user or network
3. **Use secure defaults** for configuration options
4. **Avoid shell injection** by properly escaping variables
5. **Minimize privileges** required for operations
6. **Document security implications** of new features

### Security Checklist for PRs

- [ ] No hardcoded credentials
- [ ] Input validation added where needed
- [ ] No new attack surfaces introduced
- [ ] Dependencies are from trusted sources
- [ ] File permissions are restrictive
- [ ] Network connections use HTTPS where possible

## Release Process

### Version Numbering

We use [Semantic Versioning](https://semver.org/): `MAJOR.MINOR.PATCH`

- **MAJOR**: Incompatible API changes
- **MINOR**: Backwards-compatible functionality additions
- **PATCH**: Backwards-compatible bug fixes

### Release Workflow

1. **Prepare Release Branch**
   ```bash
   git checkout -b release/v1.2.0
   ```

2. **Update Version Numbers**
   - `cbox` script: `VERSION="1.2.0"`
   - `install.sh`: `VERSION="1.2.0"`
   - `README.md`: Update any version references

3. **Update Documentation**
   - Add release notes to `CHANGELOG.md` (if exists)
   - Update README with new features
   - Review and update CONTRIBUTING.md

4. **Testing**
   - Run full manual test suite
   - Test installation script on clean system
   - Verify Docker image builds correctly
   - Test on different platforms (Linux, macOS, WSL)

5. **Create Pull Request**
   ```bash
   git push origin release/v1.2.0
   # Create PR: "Release v1.2.0"
   ```

6. **Merge and Tag**
   ```bash
   git checkout main
   git pull origin main
   git tag -a v1.2.0 -m "Release version 1.2.0"
   git push origin v1.2.0
   ```

7. **Create GitHub Release**
   - Go to GitHub releases page
   - Create release from tag
   - Add release notes
   - Mark as latest release

8. **Post-Release**
   - Announce in discussions/community channels
   - Update documentation site (if applicable)
   - Close related milestone
   - Plan next release

### Release Notes Template

```markdown
## [1.2.0] - 2025-01-15

### Added
- New feature X (#123)
- Support for Y (#124)

### Changed
- Improved Z performance (#125)
- Updated documentation (#126)

### Fixed
- Bug in A (#127)
- Issue with B (#128)

### Security
- Fixed vulnerability in C (#129)

### Contributors
- @username1
- @username2

**Full Changelog**: https://github.com/bradleydwyer/cbox/compare/v1.1.0...v1.2.0
```

## Getting Help

### Resources

- **README.md**: User documentation and quick start
- **Issues**: Search existing issues or create new ones
- **Discussions**: Community Q&A and ideas
- **Wiki**: Extended documentation (if available)

### Communication Channels

- **GitHub Issues**: Bug reports and feature requests
- **GitHub Discussions**: General questions and community discussion
- **Pull Requests**: Code contributions and reviews

### For Maintainers

If you're interested in becoming a maintainer:

1. Contribute consistently over time
2. Help others in issues and discussions
3. Review pull requests
4. Improve documentation
5. Contact current maintainers about joining

## Recognition

We value all contributions, not just code:

- **Code contributions**: Features, bug fixes, refactoring
- **Documentation**: README, guides, examples
- **Testing**: Bug reports, test cases, platform testing
- **Community**: Helping users, reviewing PRs, discussions
- **Design**: UI/UX improvements, diagrams, logos
- **Ideas**: Feature suggestions, architecture discussions

All contributors are recognized in our releases and README.

---

## Thank You!

Thank you for taking the time to contribute to cbox! Your efforts help make containerized development environments more accessible to everyone. Whether you're fixing a typo, adding a feature, or helping another user, every contribution matters.

We're excited to see what you'll build with us!

---

*This contributing guide is a living document. If you find areas that need improvement, please submit a PR or open an issue.*