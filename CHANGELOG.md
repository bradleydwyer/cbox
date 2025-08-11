# Changelog

All notable changes to cbox will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/bradleydwyer/cbox/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/bradleydwyer/cbox/compare/v1.1.6...v1.2.0
[1.1.6]: https://github.com/bradleydwyer/cbox/compare/v1.1.5...v1.1.6
[1.1.5]: https://github.com/bradleydwyer/cbox/compare/v1.1.4...v1.1.5
[1.1.4]: https://github.com/bradleydwyer/cbox/compare/v1.1.3...v1.1.4
[1.1.3]: https://github.com/bradleydwyer/cbox/compare/v1.1.2...v1.1.3
[1.1.2]: https://github.com/bradleydwyer/cbox/compare/v1.1.1...v1.1.2
[1.1.1]: https://github.com/bradleydwyer/cbox/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/bradleydwyer/cbox/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/bradleydwyer/cbox/releases/tag/v1.0.0