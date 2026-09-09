#!/bin/bash
set -e
source dev-container-features-test-lib

check "worktrees dir exists"    test -d /worktrees
check "claude home dir exists"  test -d /mnt/claude-home
check "~/.claude not symlinked" sh -c '! test -L "$HOME/.claude"'

reportResults
