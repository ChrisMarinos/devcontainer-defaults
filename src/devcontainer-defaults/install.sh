#!/usr/bin/env bash
# Build-time install for the devcontainer-defaults feature.
#
# Runs as root while the image is being built, BEFORE any volume is mounted.
# It prepares the mount points with the right owner so that Docker seeds
# brand-new volumes with that ownership, symlinks ~/.claude to the shared
# claude-home mount, and installs a small runtime script (fix-perms.sh) that
# the postStartCommand runs to correct ownership on volumes that already
# existed (Docker only seeds ownership into an EMPTY volume).
set -e

SYMLINK_CLAUDE="${SYMLINKCLAUDE:-true}"
REMOTE_USER="${_REMOTE_USER:-root}"
REMOTE_USER_HOME="${_REMOTE_USER_HOME:-/root}"

# Fixed paths: they are also the mount targets in devcontainer-feature.json
# and the values of WORKTREES_DIR / CLAUDE_CONFIG_DIR in containerEnv.
WORKTREES_DIR=/worktrees
CLAUDE_HOME=/mnt/claude-home
SHARE_DIR=/usr/local/share/devcontainer-defaults

echo "=== devcontainer-defaults ==="
echo "Remote user:  ${REMOTE_USER} (${REMOTE_USER_HOME})"
echo "Worktrees:    ${WORKTREES_DIR}"
echo "Claude home:  ${CLAUDE_HOME} (symlink ~/.claude: ${SYMLINK_CLAUDE})"

# --- Mount points, owned by the remote user so new volumes inherit it ---
mkdir -p "${WORKTREES_DIR}" "${CLAUDE_HOME}"
chown "${REMOTE_USER}:${REMOTE_USER}" "${WORKTREES_DIR}" "${CLAUDE_HOME}" 2>/dev/null || true

# --- ~/.claude -> shared volume ---
if [ "${SYMLINK_CLAUDE}" = "true" ]; then
    CLAUDE_DIR="${REMOTE_USER_HOME}/.claude"
    if [ -L "${CLAUDE_DIR}" ]; then
        rm -f "${CLAUDE_DIR}"
    elif [ -d "${CLAUDE_DIR}" ]; then
        echo "WARNING: ${CLAUDE_DIR} exists as a directory; moving to ${CLAUDE_DIR}.bak"
        mv "${CLAUDE_DIR}" "${CLAUDE_DIR}.bak"
    elif [ -e "${CLAUDE_DIR}" ]; then
        rm -f "${CLAUDE_DIR}"
    fi
    ln -s "${CLAUDE_HOME}" "${CLAUDE_DIR}"
    chown -h "${REMOTE_USER}:${REMOTE_USER}" "${CLAUDE_DIR}" 2>/dev/null || true
    echo "Symlinked ${CLAUDE_DIR} -> ${CLAUDE_HOME}"
fi

# --- Runtime ownership fix, run by postStartCommand ---
# Pre-existing volumes keep whatever owner they had (often root when created
# by an earlier image with a different user). Only the top level is fixed:
# everything inside is created by the remote user anyway, and a recursive
# chown over a large Claude cache would slow every container start.
mkdir -p "${SHARE_DIR}"
cat > "${SHARE_DIR}/fix-perms.sh" <<EOF
#!/usr/bin/env bash
# Installed by the devcontainer-defaults dev container feature.
set -e
for dir in "${WORKTREES_DIR}" "${CLAUDE_HOME}"; do
    [ -d "\$dir" ] || continue
    if [ "\$(stat -c %U "\$dir")" != "${REMOTE_USER}" ]; then
        if [ "\$(id -u)" -eq 0 ]; then
            chown "${REMOTE_USER}:${REMOTE_USER}" "\$dir"
        elif command -v sudo >/dev/null 2>&1; then
            sudo chown "${REMOTE_USER}:${REMOTE_USER}" "\$dir"
        else
            echo "devcontainer-defaults: cannot chown \$dir (no root, no sudo)" >&2
        fi
    fi
done
EOF
chmod 755 "${SHARE_DIR}/fix-perms.sh"

echo "=== devcontainer-defaults installed ==="
