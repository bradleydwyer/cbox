# Changelog

All notable changes to cbox will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Comprehensive CLI reference documentation
- Status badges in README
- Configuration file documentation in README

### Fixed
- GitHub URL placeholders updated to correct repository
- Telemetry documentation clarified (feature not yet implemented)

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

[Unreleased]: https://github.com/bradleydwyer/cbox/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/bradleydwyer/cbox/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/bradleydwyer/cbox/releases/tag/v1.0.0