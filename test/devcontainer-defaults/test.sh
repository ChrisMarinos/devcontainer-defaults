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

LINKER=/usr/local/share/devcontainer-defaults/link-host-sockets.sh
SSH_LINK=/tmp/devcontainer-defaults/ssh-auth.sock
IPC_LINK=/tmp/devcontainer-defaults/remote-containers-ipc.sock

check "SSH_AUTH_SOCK exported"       test "$SSH_AUTH_SOCK" = "$SSH_LINK"
check "REMOTE_CONTAINERS_IPC exported" test "$REMOTE_CONTAINERS_IPC" = "$IPC_LINK"
check "link-host-sockets installed"  test -x "$LINKER"
check "link dir writable"            sh -c 'touch /tmp/devcontainer-defaults/.probe && rm /tmp/devcontainer-defaults/.probe'

# No VS Code is attached during `devcontainer features test`, so there are no
# sockets to find. The script must still succeed and leave no dangling link.
check "linker succeeds with no sockets" "$LINKER"
check "no dangling ssh link"         sh -c '! test -L "$SSH_LINK" || test -S "$SSH_LINK"'

# ssh-agent gives a real, live socket matching the glob the script looks for.
check "links a live ssh socket" sh -c '
    eval "$(ssh-agent -a /tmp/vscode-ssh-auth-probe.sock)" >/dev/null &&
    '"$LINKER"' >/dev/null &&
    test "$(readlink /tmp/devcontainer-defaults/ssh-auth.sock)" = /tmp/vscode-ssh-auth-probe.sock &&
    SSH_AUTH_SOCK=/tmp/devcontainer-defaults/ssh-auth.sock ssh-add -l; rc=$?
    ssh-agent -k >/dev/null 2>&1
    test "$rc" -ne 2'

# Killing that agent leaves the socket file behind with nothing listening --
# the same shape as Docker Desktop host-services when it forwards nothing.
check "rejects a dead ssh socket" sh -c '
    test -e /tmp/vscode-ssh-auth-probe.sock &&
    '"$LINKER"' >/dev/null 2>&1
    ! test -L /tmp/devcontainer-defaults/ssh-auth.sock'

check "links an ipc socket" sh -c '
    eval "$(ssh-agent -a /tmp/vscode-remote-containers-ipc-probe.sock)" >/dev/null &&
    '"$LINKER"' >/dev/null &&
    test "$(readlink /tmp/devcontainer-defaults/remote-containers-ipc.sock)" = /tmp/vscode-remote-containers-ipc-probe.sock
    ssh-agent -k >/dev/null 2>&1'

rm -f /tmp/vscode-ssh-auth-probe.sock /tmp/vscode-remote-containers-ipc-probe.sock

SKILL=/etc/claude-code/.claude/skills/opening-herdr-tabs/SKILL.md
POLICY=/etc/claude-code/managed-settings.d/50-devcontainer-defaults.json

check "herdr-open installed"        test -x /usr/local/bin/herdr-open.sh
check "herdr-open skill installed"  test -r "$SKILL"
check "herdr-open policy installed" test -r "$POLICY"
check "policy allowlists herdr-open" grep -q 'Bash(herdr-open.sh:\*)' "$POLICY"
check "policy is valid json"        python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$POLICY"

# Outside herdr there is nothing to open, and skills call it unconditionally,
# so it must stay silent rather than erroring.
check "herdr-open inert off-herdr"  sh -c 'out=$(env -u HERDR_ENV /usr/local/bin/herdr-open.sh vi tab /etc/hostname) && test -z "$out"'

reportResults
