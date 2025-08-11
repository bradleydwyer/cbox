#!/bin/bash
# Debug script to test environment variable passthrough

echo "=== Environment Variable Debug Test ==="
echo

# Set up test variables
export AWS_PROFILE="test-profile"
export AWS_REGION="us-east-1"
export CLAUDE_CODE_USE_BEDROCK="true"
export ANTHROPIC_MODEL="claude-3-sonnet-20240229"

echo "Host environment variables:"
echo "AWS_PROFILE=$AWS_PROFILE"
echo "AWS_REGION=$AWS_REGION"
echo "CLAUDE_CODE_USE_BEDROCK=$CLAUDE_CODE_USE_BEDROCK"
echo "ANTHROPIC_MODEL=$ANTHROPIC_MODEL"
echo

echo "Testing cbox with verbose mode to see what gets passed..."
echo "Command: CBOX_VERBOSE=1 ./cbox -e AWS_PROFILE -e AWS_REGION -e CLAUDE_CODE_USE_BEDROCK -e ANTHROPIC_MODEL --shell"
echo

# Run with verbose mode and shell to check environment
CBOX_VERBOSE=1 ./cbox -e AWS_PROFILE -e AWS_REGION -e CLAUDE_CODE_USE_BEDROCK -e ANTHROPIC_MODEL --shell