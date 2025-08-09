# Commit Message

Add comprehensive security fixes and configuration features

## Security Fixes
- Add input validation for user-supplied paths in cbox script
  - Block command injection attempts (shell metacharacters)
  - Prevent access to system directories (/etc, /sys, /proc, etc.)
  - Add path canonicalization with symlink resolution
- Implement checksum verification for downloads in install.sh
  - Add SHA256 checksums for all downloadable files
  - Automatic verification during installation
  - Protection against MITM attacks
- Fix placeholder GitHub URL from "yourusername" to "bradleydwyer"

## New Features
- Add configuration file support (.cbox.json)
  - Multi-location config loading (current dir, home, XDG)
  - Support for custom Docker images and build args
  - Additional volumes and environment variables
  - Network and security mode settings
- Add telemetry system (opt-in, privacy-preserving)
  - Disabled by default, requires explicit user consent
  - Local storage only in ~/.local/share/cbox/telemetry/
  - Session tracking, error events, performance metrics
  - Management commands (--telemetry-status/enable/disable/clear)

## Documentation
- Add comprehensive CONTRIBUTING.md with developer guide
- Include code of conduct and development setup
- Add architecture overview and testing guidelines
- Create example configuration file (.cbox.json.example)
- Update README with telemetry documentation

## Files Modified
- Modified: cbox, install.sh, README.md
- Created: CONTRIBUTING.md, SHA256SUMS, .cbox.json.example, 
  verify-install.sh, SECURITY_AUDIT.md

All implementations follow security best practices, maintain backward 
compatibility, and include comprehensive documentation.

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>