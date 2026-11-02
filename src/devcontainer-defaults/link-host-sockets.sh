#!/usr/bin/env bash
# Installed by the devcontainer-defaults dev container feature.
#
# VS Code forwards the host SSH agent and docker credential store into the
# container as sockets in /tmp, but exports SSH_AUTH_SOCK and
# REMOTE_CONTAINERS_IPC only to processes it spawns itself. Anything else --
# `docker exec`, a daemon, an agent outside the editor -- gets no agent, and
# docker-credential-dev-containers-* exits 255 with no output.
#
# The socket names embed a per-session UUID, so containerEnv points at the
# stable paths below and this links them to the real sockets. Runs from both
# postStartCommand and postAttachCommand, since reattaching makes new sockets.
set -u

LINK_DIR=/tmp/devcontainer-defaults
SSH_LINK="${LINK_DIR}/ssh-auth.sock"
IPC_LINK="${LINK_DIR}/remote-containers-ipc.sock"

mkdir -p "${LINK_DIR}" 2>/dev/null || true
chmod 1777 "${LINK_DIR}" 2>/dev/null || true

# Newest wins: stale sockets from previous sessions linger alongside live ones.
newest_socket() {
    find /tmp -maxdepth 1 -type s -name "$1" -printf '%T@ %p\n' 2>/dev/null |
        sort -rn | head -1 | cut -d' ' -f2-
}

# A socket can exist with nothing behind it -- notably Docker Desktop's
# host-services socket when Docker Desktop was launched without SSH_AUTH_SOCK.
# ssh-add exits 2 for "cannot connect", 0 or 1 for a reachable agent.
agent_reachable() {
    command -v ssh-add >/dev/null 2>&1 || return 0 # cannot probe; assume usable
    local rc
    SSH_AUTH_SOCK="$1" ssh-add -l >/dev/null 2>&1
    rc=$?
    [ "${rc}" -ne 2 ]
}

# Leaves the link absent when nothing is usable: a dangling SSH_AUTH_SOCK is
# worse than an unset one, since ssh warns instead of quietly falling back to
# on-disk identity files.
link_first() {
    local link="$1" probe="$2" cand
    shift 2
    for cand in "$@"; do
        [ -n "${cand}" ] || continue
        [ "${cand}" = "${link}" ] && continue
        [ -S "${cand}" ] || continue
        if [ "${probe}" = "probe" ] && ! agent_reachable "${cand}"; then
            continue
        fi
        ln -sfn "${cand}" "${link}" 2>/dev/null || continue
        echo "devcontainer-defaults: ${link} -> ${cand}"
        return 0
    done
    if [ -L "${link}" ] && [ ! -S "${link}" ]; then
        rm -f "${link}" 2>/dev/null || true
    fi
    echo "devcontainer-defaults: no live socket found for ${link}" >&2
    return 1
}

# Docker Desktop's bridge is a plain socket proxy and is tried first: VS Code's
# relay answers key-list requests but hangs on sign requests with a 1Password
# agent, so `ssh-add -l` succeeds while `git push` fails. The relay is still a
# useful fallback -- on Linux hosts there is no host-services socket, and
# listing-only is better than nothing.
link_first "${SSH_LINK}" probe \
    /run/host-services/ssh-auth.sock \
    "${SSH_AUTH_SOCK:-}" \
    "$(newest_socket 'vscode-ssh-auth-*.sock')" || true

# No probe: the helper speaks HTTP over this socket, with no cheap check.
link_first "${IPC_LINK}" none \
    "${REMOTE_CONTAINERS_IPC:-}" \
    "$(newest_socket 'vscode-remote-containers-ipc-*.sock')" || true

exit 0
