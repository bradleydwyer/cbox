# Documentation Preservation Guidelines

**NEVER delete documentation to avoid git hooks or linting issues.** Security audits, implementation analyses, and review documents contain valuable information that should be preserved. If documentation triggers security scanners:

1. Clean up example tokens/secrets in the documentation
2. Use placeholder syntax like `<your-token-here>` instead of realistic examples
3. Add scanner exclusion comments where appropriate (e.g., `# gitleaks:allow`)
4. Move sensitive examples to a dedicated security docs folder with appropriate ignore rules

Deleting documentation to bypass checks undermines the project's knowledge base and security posture.