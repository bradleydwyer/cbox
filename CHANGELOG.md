# Changelog

All notable changes to cbox will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.4.0] - 2025-08-11

### Added
- **Auto-Update System**: Complete auto-update functionality with safety checks
  - `--update`: Performs actual auto-update (not just instructions)
    - Detects installation method (git vs standalone)
    - Git: Requires main branch, checks uncommitted changes, uses --ff-only
    - Standalone: Downloads and runs installer script
    - Includes user confirmation prompts for safety
  - `--update-check`: Forces immediate update check
  - `--update-skip`: Disables notifications for 7 days
  - Daily update checks via GitHub API with fallback to curl, wget, python
  - 24-hour cache to prevent excessive API calls
  - Respects security modes (disabled in paranoid mode)
  - User can disable with `CBOX_NO_UPDATE_CHECK=1`
- **Claude Code Self-Updates**: Claude Code can now update itself within containers
  - Persistent npm directory mounted at `~/.cache/cbox/npm-user`
  - Claude Code installed to user-owned directory on first run
  - Auto-updates work without rebuilding Docker image
  - Significantly reduces update friction for frequent Claude Code releases

### Changed
- **Claude Code Installation**: Moved from build-time to runtime installation
  - Removed global npm install from Dockerfile
  - Added user-space npm installation in entrypoint
  - Creates persistent `/opt/npm-user` directory with proper permissions
  - First run includes one-time Claude Code installation (~30 seconds)
- **Volume Mounts**: Added persistent directories for npm packages
  - `~/.cache/cbox/npm-user` → `/opt/npm-user` (Claude Code installation)
  - `~/.cache/cbox/npm-cache` → `/opt/npm-user/cache` (npm cache)
- **cbox-update Script**: Enhanced to work with new architecture
  - Now mentions Claude Code will update automatically
  - Maintains existing Docker rebuild functionality

### Security
- **Container Blast Radius Reduction**: Self-updates are safer in containers than host
  - Limited filesystem access (only mounted project directory)
  - No access to SSH keys/configs unless explicitly mounted
  - Process isolation through container boundaries
  - Cannot modify host npm packages or PATH
- **Update Check Security**: Secure GitHub API integration
  - HTTPS-only requests with timeout limits
  - Input validation on all API responses
  - No telemetry or user tracking
  - Respects paranoid mode restrictions

### Technical
- **Backward Compatibility**: 100% compatible with v1.3.0
  - All existing commands and options work identically
  - Environment variables preserved
  - Security modes unchanged
  - No breaking changes to user workflows
- **Performance**: Minimal overhead for new features
  - Update checks run in background (non-blocking)
  - Claude Code installation cached after first run
  - npm packages persist across container restarts

### Safety Features (Auto-Update)
- **Repository Protection**: Validates that update target is actually the cbox repository
- **Branch Protection**: Only allows updates from main branch to prevent losing development work
- **Work Protection**: Detects uncommitted changes and prevents updates until resolved
- **Safe Merging**: Uses `--ff-only` flag to ensure clean fast-forward updates only
- **User Confirmation**: Requires explicit user consent before making any changes
- **Installation Detection**: Intelligently identifies git vs standalone installations
- **Fallback Methods**: Provides alternative update paths if primary method fails

### Fixed
- **Update Notification Alignment**: Fixed printf formatting for perfect box alignment
- **Auto-Update Implementation**: Replaced instruction display with actual update functionality
  - Git installations now perform `git pull --ff-only origin main`
  - Standalone installations download and run latest installer
  - Both methods include safety checks and user confirmations
- **Critical Volume Mount Bug**: Fixed volume array initialization that was overwriting mounts
  - Changed `vols=` to `vols+=` to properly append volume mounts (lines 954, 957)
  - This bug was preventing GitHub config directory from being mounted correctly
  - Now all volume mounts work as intended, enabling proper GitHub CLI authentication
- **GitHub CLI Token Extraction**: Fixed automatic token extraction for macOS keychain users
  - Added automatic extraction of GitHub tokens from `gh` CLI when authenticated
  - Properly handles macOS keychain authentication without exposing tokens
  - Uses secure subprocess to prevent token exposure in process lists
  - Added timeout handling to prevent hanging on keychain prompts
- **Echo Command Compatibility**: Fixed echo -e flag issue in Docker environment
  - Replaced `echo -e` with `printf` for proper escape sequence handling
  - Ensures color codes and formatting work correctly in all environments
- **Environment Variable Debugging**: Added proper debug output for ENV_VARS array
  - Fixed debug output to show actual environment variables being passed
  - Helps troubleshoot authentication and configuration issues

### Security
- **Token Security**: Enhanced security for GitHub token handling
  - Tokens never appear in process lists or command history
  - Uses secure piping and subshells for token extraction
  - Validates tokens before use with proper format checking
  - SHA256 hash redaction in logs for security

## [1.3.0] - 2025-08-11

### Added
- **Security Modes**: Three distinct security levels for different use cases
  - `standard` mode: Current behavior (default) - host network, SSH agent, read/write
  - `restricted` mode: Bridge network with DNS, SSH agent enabled, read/write
  - `paranoid` mode: No network, no SSH agent, read-only volumes
- **Security CLI Options**: Comprehensive command-line security controls
  - `--security-mode MODE`: Set security level (standard|restricted|paranoid)
  - `--network TYPE`: Override network access (host|bridge|none)
  - `--ssh-agent BOOL`: Override SSH agent setting (true|false)
  - `--read-only`: Force read-only project directory mount
- **Input Validation**: Comprehensive validation preventing command injection
  - Strict whitelist validation for all security parameters
  - Command injection prevention throughout CLI parsing
  - Path traversal protection for all file operations
- **Security Warnings**: Clear warnings for potentially dangerous configurations
  - Warns when overriding paranoid mode with less secure options
  - Validates security configuration consistency
  - Anti-bypass detection for security environment variables
- **GitHub CLI Authentication**: Automatic forwarding of GitHub credentials
  - Supports `GH_TOKEN` and `GITHUB_TOKEN` environment variables
  - Mounts `~/.config/gh` directory for seamless GitHub CLI access
  - Full token validation with modern GitHub token format support
  - Security-aware: tokens blocked in paranoid mode, forwarded in standard/restricted
  - Secure logging with SHA256 hash redaction for token presence
- **Enhanced Documentation**: Complete security mode documentation
  - Updated help text with security options and examples
  - Security quick reference guide for common scenarios
  - Comprehensive technical design documentation
- **GitHub CLI Integration**: Added `gh` command-line tool to Docker image
  - Enables pull request creation, issue management, and repository operations
  - Supports GitHub workflow automation from within cbox
  - Pre-installed and ready to use with host GitHub authentication

### Security
- Enhanced container security with granular network and access controls
- Maintained all existing security hardening (capabilities, tmpfs mounts, etc.)
- Added fail-safe error handling with security-first approach
- Implemented defense-in-depth security validation

### Documentation
- Added security mode examples to help text and README
- Created comprehensive security audit reports and user guides
- Updated CLI reference with complete security option documentation
- Added migration guidance for users wanting enhanced security controls

### Changed
- Extended help text to include all new security options
- Enhanced Docker integration with network configuration control
- Improved error messages for security-related failures

## [1.2.1] - 2025-08-11

### Fixed
- Fixed "unbound variable" error when running cbox without -e flags
- Properly handle empty CLI_ENV_VARS and ENV_VARS arrays in bash strict mode
- Environment variable processing now works correctly with `set -euo pipefail`

## [1.2.0] - 2025-08-11

### Added
- New `-e` flag for explicit environment variable control
  - Pass variables from host: `-e VAR`
  - Set specific values: `-e VAR=value`
  - Multiple variables supported with multiple `-e` flags
- AWS Bedrock integration support through environment variables
- Comprehensive documentation for environment variable usage
- Security-focused design with no automatic variable passthrough
- Warning messages for empty/unset variables in verbose mode

### Changed
- Environment variables must now be explicitly passed using `-e` flag
- Enhanced security by requiring explicit specification of each variable
- Updated help text to include new `-e` flag documentation
- Improved documentation with AWS Bedrock examples and best practices

### Security
- No automatic environment variable inheritance - explicit control only
- Prevents accidental exposure of sensitive environment variables
- Makes security auditable with clear visibility of shared variables
- Reduces attack surface by only passing necessary variables

## [1.1.6] - 2025-08-10

### Changed
- Removed Docker image build prompt from install script
- Docker image now builds automatically on first cbox run
- Simplified installation process with cleaner completion message

### Removed
- Interactive Docker build prompt and associated build_docker_image function

## [1.1.5] - 2025-08-10

### Fixed
- Temporary directory cleanup issue causing "No such file or directory" errors during installation
- Moved cleanup trap to main function to prevent premature temp directory removal

## [1.1.4] - 2025-08-10

### Fixed
- Install script output redirection issues causing command execution failures
- Color code interference with sudo cp commands during installation
- GitHub CDN caching issues preventing install script updates

## [1.1.3] - 2025-08-10

### Fixed
- Install script checksum verification failures after version updates
- Updated SHA256SUMS file with correct checksums for all release files

## [1.1.2] - 2025-08-10

### Fixed
- Rust compilation issues with persistent Cargo cache
- Improved Rust development environment stability

### Added
- Rust to cbox developer tooling with enhanced caching support

## [1.1.1] - 2025-01-09

### Added
- Complete shared resources documentation for full transparency
  - All 7 persistent volume mounts documented with security warnings
  - All 6 tmpfs RAM mounts documented (1.4 GB total memory usage)
  - All environment variables and Docker capabilities documented
- Git pre-commit hooks for secret scanning (Gitleaks + TruffleHog)
- Hermit package manager for development tool management
- Prominent experimental/vibe-coded warning in README
- "Currently Implemented vs Planned Features" section for transparency
- Comprehensive security documentation (SECURITY.md)
- Secret scanning setup guide (SECRET_SCANNING.md)
- Critical security warnings for sensitive mounts (Claude API token)

### Changed
- Consolidated three security audit reports into single SECURITY.md
- Enhanced security warnings with clear visual indicators (🔴 ⚠️)
- Improved documentation structure for better clarity

### Fixed
- Removed false documentation for unimplemented features (telemetry, config parsing)
- Fixed placeholder URLs in help text
- Removed outdated reference to COMMIT_MESSAGE.md
- Corrected Hermit configuration syntax errors

### Removed
- Telemetry documentation (feature never implemented)
- Configuration file parsing documentation (code doesn't parse .cbox.json)
- Temporary test scripts and backup files
- Redundant security audit reports

## [1.1.0] - 2025-01-09

### Added
- Enhanced security features with path validation and system directory protection
- Telemetry system foundation (opt-in, privacy-preserving) - documentation only, not yet implemented
- Resource limits (2GB memory, 2 CPUs) to prevent container crashes
- Process monitoring with `procps` package
- `curl` and `wget` utilities in Docker image
- `cbox-update` script for force rebuilding Docker environment
- Hermit package manager integration for development tools
- Comprehensive documentation improvements:
  - CONTRIBUTING.md with detailed contributor guidelines
  - SECURITY_AUDIT.md with security analysis
  - Installation and verification scripts
- Example configuration file (.cbox.json.example)
- Better error messages and validation
- Support for .git-credentials mounting
- Shell mode with `--shell` flag
- Verification mode with `--verify` flag

### Changed
- Improved Docker image build process with better caching
- Enhanced SSH agent detection and error reporting
- Better handling of file permissions and ownership
- Updated documentation with more examples and troubleshooting

### Fixed
- SSH agent socket permission issues
- Directory path handling with spaces
- Container cleanup on exit
- Memory and CPU resource constraints

### Security
- Added comprehensive path validation to prevent access to system directories
- Input sanitization for shell command injection prevention
- Read-only mounts for sensitive configuration files
- Restricted access to system directories while allowing /tmp, /home, /var/tmp

## [1.0.0] - 2025-01-08

### Added
- Initial release of cbox
- Docker-based sandbox for running Claude Code
- Full network access with no egress firewall
- SSH agent forwarding for GitHub operations
- Automatic user ID/GID mapping for proper file ownership
- Volume mounting for:
  - Working directory
  - Claude configuration (~/.claude)
  - Git configuration
  - SSH known hosts
- Support for passing arguments to Claude
- Verbose mode for debugging
- Automatic Docker image building and caching
- Installation script for easy setup
- Comprehensive README documentation

### Features
- Run Claude Code in isolated Docker container
- Maintain host authentication and configurations
- Preserve file ownership (no root-owned files)
- Support for multiple concurrent instances
- Easy cleanup and uninstallation

[Unreleased]: https://github.com/bradleydwyer/cbox/compare/v1.3.0...HEAD
[1.3.0]: https://github.com/bradleydwyer/cbox/compare/v1.2.1...v1.3.0
[1.2.1]: https://github.com/bradleydwyer/cbox/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/bradleydwyer/cbox/compare/v1.1.6...v1.2.0
[1.1.6]: https://github.com/bradleydwyer/cbox/compare/v1.1.5...v1.1.6
[1.1.5]: https://github.com/bradleydwyer/cbox/compare/v1.1.4...v1.1.5
[1.1.4]: https://github.com/bradleydwyer/cbox/compare/v1.1.3...v1.1.4
[1.1.3]: https://github.com/bradleydwyer/cbox/compare/v1.1.2...v1.1.3
[1.1.2]: https://github.com/bradleydwyer/cbox/compare/v1.1.1...v1.1.2
[1.1.1]: https://github.com/bradleydwyer/cbox/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/bradleydwyer/cbox/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/bradleydwyer/cbox/releases/tag/v1.0.0