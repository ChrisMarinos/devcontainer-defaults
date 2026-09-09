#!/bin/bash
# Runs inside a container built with the feature applied (devcontainer features test).
set -e
source dev-container-features-test-lib

check "worktrees dir exists"        test -d /worktrees
check "claude home dir exists"      test -d /mnt/claude-home
check "~/.claude is a symlink"      test -L "$HOME/.claude"
check "~/.claude resolves to mount" test "$(readlink -f "$HOME/.claude")" = "/mnt/claude-home"
check "WORKTREES_DIR exported"      test "$WORKTREES_DIR" = "/worktrees"
check "CLAUDE_CONFIG_DIR exported"  test "$CLAUDE_CONFIG_DIR" = "/mnt/claude-home"
check "fix-perms installed"         test -x /usr/local/share/devcontainer-defaults/fix-perms.sh
check "fix-perms runs"              /usr/local/share/devcontainer-defaults/fix-perms.sh
check "worktrees writable"          sh -c 'touch /worktrees/.probe && rm /worktrees/.probe'
check "claude home writable"        sh -c 'touch /mnt/claude-home/.probe && rm /mnt/claude-home/.probe'

reportResults
