#!/usr/bin/env bash
# Direct test of security validation logic from cbox

set -euo pipefail

echo "=== Direct Testing of cbox Security Logic ==="
echo

# Test function extracted from cbox
test_path_validation() {
  local WORKDIR="$1"
  local expected="$2"
  local test_name="$3"
  
  echo "Test: $test_name"
  echo "Input: $WORKDIR"
  
  # Check for shell metacharacters that could lead to command injection
  if [[ "$WORKDIR" == *";"* ]] || [[ "$WORKDIR" == *"|"* ]] || [[ "$WORKDIR" == *"&"* ]] || \
     [[ "$WORKDIR" == *">"* ]] || [[ "$WORKDIR" == *"<"* ]] || [[ "$WORKDIR" == *'$('* ]] || \
     [[ "$WORKDIR" == *'${'* ]] || [[ "$WORKDIR" == *'`'* ]]; then
    echo "Result: BLOCKED - Path contains dangerous shell characters"
    if [[ "$expected" == "block" ]]; then
      echo "✓ PASS"
    else
      echo "✗ FAIL - Should have been allowed"
    fi
  else
    echo "Result: ALLOWED"
    if [[ "$expected" == "allow" ]]; then
      echo "✓ PASS"
    else
      echo "✗ FAIL - Should have been blocked"
    fi
  fi
  echo
}

# Test system directory blocking
test_system_dir() {
  local CANONICAL_PATH="$1"
  local expected="$2"
  local test_name="$3"
  
  echo "Test: $test_name"
  echo "Path: $CANONICAL_PATH"
  
  case "$CANONICAL_PATH" in
    /etc|/etc/*)
      echo "Result: BLOCKED - System directory"
      if [[ "$expected" == "block" ]]; then
        echo "✓ PASS"
      else
        echo "✗ FAIL - Should have been allowed"
      fi
      ;;
    /sys|/sys/*|/proc|/proc/*|/dev|/dev/*|/boot|/boot/*|/root|/root/*)
      echo "Result: BLOCKED - System directory"
      if [[ "$expected" == "block" ]]; then
        echo "✓ PASS"
      else
        echo "✗ FAIL - Should have been allowed"
      fi
      ;;
    /bin|/bin/*|/sbin|/sbin/*|/lib|/lib/*|/lib64|/lib64/*)
      echo "Result: BLOCKED - System directory"
      if [[ "$expected" == "block" ]]; then
        echo "✓ PASS"
      else
        echo "✗ FAIL - Should have been allowed"
      fi
      ;;
    /usr/bin|/usr/bin/*|/usr/sbin|/usr/sbin/*|/usr/lib|/usr/lib/*)
      echo "Result: BLOCKED - System directory"
      if [[ "$expected" == "block" ]]; then
        echo "✓ PASS"
      else
        echo "✗ FAIL - Should have been allowed"
      fi
      ;;
    /var/log|/var/log/*|/var/run|/var/run/*|/var/lock|/var/lock/*)
      echo "Result: BLOCKED - System directory"
      if [[ "$expected" == "block" ]]; then
        echo "✓ PASS"
      else
        echo "✗ FAIL - Should have been allowed"
      fi
      ;;
    /var/spool|/var/spool/*|/var/mail|/var/mail/*)
      echo "Result: BLOCKED - System directory"
      if [[ "$expected" == "block" ]]; then
        echo "✓ PASS"
      else
        echo "✗ FAIL - Should have been allowed"
      fi
      ;;
    *)
      echo "Result: ALLOWED"
      if [[ "$expected" == "allow" ]]; then
        echo "✓ PASS"
      else
        echo "✗ FAIL - Should have been blocked"
      fi
      ;;
  esac
  echo
}

echo "=== Shell Metacharacter Tests ==="
test_path_validation '$(echo pwned)' "block" "Command injection with $()"
test_path_validation '/tmp;ls' "block" "Semicolon injection"
test_path_validation '/tmp`whoami`' "block" "Backtick injection"
test_path_validation '/tmp|cat /etc/passwd' "block" "Pipe injection"
test_path_validation '/tmp&& rm -rf /' "block" "AND operator injection"
test_path_validation '/tmp>${HOME}/output' "block" "Redirect injection"
test_path_validation '/tmp${PATH}' "block" "Variable expansion injection"
test_path_validation '/tmp/safe/path' "allow" "Safe path"

echo "=== System Directory Tests ==="
test_system_dir '/etc' "block" "Block /etc"
test_system_dir '/etc/passwd' "block" "Block /etc/passwd"
test_system_dir '/sys/kernel' "block" "Block /sys/kernel"
test_system_dir '/proc/1/mem' "block" "Block /proc"
test_system_dir '/dev/null' "block" "Block /dev"
test_system_dir '/root/.ssh' "block" "Block /root"
test_system_dir '/bin/bash' "block" "Block /bin"
test_system_dir '/usr/bin/ls' "block" "Block /usr/bin"
test_system_dir '/var/log/auth.log' "block" "Block /var/log"
test_system_dir '/home/user/project' "allow" "Allow /home"
test_system_dir '/tmp/test' "allow" "Allow /tmp"
test_system_dir '/var/tmp/cache' "allow" "Allow /var/tmp"

echo "=== Test Complete ==="/antml:parameter>
</invoke>