#!/usr/bin/env bash
# herdr-open.sh — open a file from this devcontainer in a new herdr tab.
#
#   herdr-open.sh <viewer> <tab name> <file>
#
# viewer    one of: vi vim view nvim less bat
# tab name  label for the new herdr tab (letters, digits, space . _ - only)
# file      a path inside this container
#
# The file is displayed by the container's own viewer, through the
# vscode-devcontainers-herdr plugin's `exec` -- the mechanism behind `hdc`/`hds`.
# Nothing is copied to the host.
#
# Narrow by design so it can sit on an allowlist: no command, no flags, no
# free-form text. It is not a security boundary, though -- the relayed herdr
# socket is unauthenticated, so anything in this container can drive herdr
# directly regardless of this script.
#
# Exits 0 silently outside herdr, so skills may call it unconditionally.
set -euo pipefail

die() { echo "herdr-open: $*" >&2; exit 2; }

[ "${HERDR_ENV:-}" = "1" ] || exit 0
[ -n "${HERDR_SOCKET_PATH:-}" ] && [ -S "${HERDR_SOCKET_PATH}" ] || exit 0
command -v python3 >/dev/null 2>&1 || die "python3 is required"

[ "$#" -eq 3 ] || die "usage: herdr-open.sh <vi|vim|view|nvim|less|bat> <tab name> <file>"
viewer="$1"; tab_name="$2"; target="$3"

case "$viewer" in
  vi|vim|view|nvim|less|bat) ;;
  *) die "unsupported viewer '$viewer' (allowed: vi vim view nvim less bat)" ;;
esac
command -v "$viewer" >/dev/null 2>&1 || die "'$viewer' is not installed in this container"

case "$tab_name" in
  ''|*[!A-Za-z0-9\ ._-]*) die "tab name may only contain letters, digits, space, dot, underscore, hyphen" ;;
esac
[ "${#tab_name}" -le 40 ] || die "tab name must be 40 characters or fewer"

[ -e "$target" ] || die "no such file: $target"
[ -f "$target" ] || die "not a regular file: $target"
[ -r "$target" ] || die "not readable: $target"
target="$(realpath "$target")"

HO_VIEWER="$viewer" HO_TAB="$tab_name" HO_FILE="$target" exec python3 - <<'PY'
import json, os, socket, sys, time

SOCK = os.environ["HERDR_SOCKET_PATH"]


def sh_quote(s):
    """POSIX single-quote escaping.

    Hand-rolled because some base images ship a trimmed stdlib without shlex.
    """
    return "'" + s.replace("'", "'\"'\"'") + "'"


def call(method, params=None, timeout=15.0, tolerant=False):
    """One newline-delimited JSON request/response against the herdr socket.

    `tolerant` returns None on an error response instead of exiting, for calls
    whose failure is not worth aborting over.
    """
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(timeout)
    try:
        s.connect(SOCK)
        s.sendall((json.dumps({"id": f"herdr-open-{time.time_ns()}",
                               "method": method,
                               "params": params or {}}) + "\n").encode())
        s.shutdown(socket.SHUT_WR)
        buf = b""
        while True:
            chunk = s.recv(65536)
            if not chunk:
                break
            buf += chunk
    finally:
        s.close()
    if not buf.strip():
        sys.exit(f"herdr-open: no response from herdr ({method})")
    resp = json.loads(buf.decode().strip().splitlines()[0])
    if "error" in resp:
        if tolerant:
            return None
        err = resp["error"]
        sys.exit(f"herdr-open: {method}: {err.get('code')}: {err.get('message')}")
    return resp["result"]


def plugin_exe():
    """Absolute path to the vscode-devcontainers-herdr binary on the host.

    Asked for rather than hardcoded: the install directory carries a hash
    suffix that changes on reinstall.
    """
    for p in call("plugin.list")["plugins"]:
        repo = (p.get("source") or {}).get("repo")
        if repo == "vscode-devcontainers-herdr" or p.get("plugin_id") == "devcontainer-status":
            if not p.get("enabled", False):
                sys.exit("herdr-open: the devcontainer plugin is installed but disabled")
            return p["plugin_root"].rstrip("/") + "/bin/herdr-devcontainer-status"
    sys.exit("herdr-open: vscode-devcontainers-herdr is not installed in herdr; "
             "see its USAGE.md step 2")


viewer, tab_name, path = os.environ["HO_VIEWER"], os.environ["HO_TAB"], os.environ["HO_FILE"]

# The plugin's `exec` finds the project's .devcontainer by walking up from the
# pane's cwd, so the new pane needs the project root as the host sees it.
host_root = os.environ.get("LOCAL_WORKSPACE_FOLDER") or ""
if not host_root:
    pane = os.environ.get("HERDR_PANE_ID")
    host_root = call("pane.current", {"caller_pane_id": pane} if pane else {})["pane"]["cwd"]

if viewer in ("vi", "vim", "nvim"):
    inner = [viewer, "-R", path]
elif viewer == "bat":
    inner = ["bat", "--paging=always", path]
else:  # view, less
    inner = [viewer, path]

# A fixed template over validated arguments, never caller-supplied text.
command = " ".join(sh_quote(a) for a in [plugin_exe(), "exec", *inner]) + " 2>/dev/null"

tab = call("tab.create", {"label": tab_name, "cwd": host_root, "focus": False})
pane_id = tab["root_pane"]["pane_id"]
call("pane.send_input", {"pane_id": pane_id, "text": command, "keys": ["enter"]})

# The devcontainer CLI writes to stdout before the viewer takes the screen,
# leaving vim on "Press ENTER or type command to continue". stdout can't be
# redirected away -- it's where the viewer renders -- so dismiss the prompt.
#
# Polled rather than `pane.wait_for_output`, which long-polls: this client
# half-closes the write side after each request, so the server sees the
# disconnect and drops the wait.
if viewer in ("vi", "vim", "nvim", "view"):
    deadline = time.time() + 20.0
    while time.time() < deadline:
        time.sleep(0.4)
        got = call("pane.read", {"pane_id": pane_id, "source": "visible",
                                 "lines": 60}, tolerant=True)
        if got is None:          # pane already closed
            break
        if "ress ENTER" in got.get("read", {}).get("text", ""):
            call("pane.send_input", {"pane_id": pane_id, "keys": ["enter"]},
                 tolerant=True)
            break

print(f"herdr-open: opened {path} as tab '{tab_name}' ({pane_id})")
PY
