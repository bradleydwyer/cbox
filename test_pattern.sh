#!/bin/bash
WORKDIR='$(echo pwned)'
echo "Testing: $WORKDIR"
if [[ "$WORKDIR" == *'$('* ]]; then 
  echo "Pattern matched - command injection detected"
else
  echo "Pattern not matched"
fi