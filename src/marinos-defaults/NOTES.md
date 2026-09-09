## How it is meant to be used

Reference this feature from your **host** VS Code user settings, not from a project's `devcontainer.json`, so every dev container you open gets it:

```jsonc
// settings.json (user scope, on the host)
"dev.containers.defaultFeatures": {
    "https://github.com/chrismarinos/devcontainer-features/releases/download/v1.0.0/marinos-defaults.tgz": {}
}
```

Project-level `devcontainer.json` files stay project-specific. Anything a project also declares wins over these defaults.

## What it does

| Concern | Mechanism |
|---|---|
| `/worktrees` for git worktrees | Named volume `worktrees-${devcontainerId}`, one per dev container config, so projects never share a worktree directory. `WORKTREES_DIR=/worktrees` is exported. |
| Claude Code persistence | Named volume `devcontainer-claude-home` mounted at `/mnt/claude-home`, shared by **all** containers. `~/.claude` is symlinked to it and `CLAUDE_CONFIG_DIR` points at it, so login, settings, plugins, and project memory survive rebuilds. |
| Ownership | Mount points are created for the remote user at build time (Docker copies that ownership into a fresh volume). A `postStartCommand` fixes the top-level owner of volumes that already existed. |

## Caveats

- Feature mounts cannot bind-mount host paths (no `${localEnv:...}` substitution), which is why `~/.claude` is a named volume rather than your host `~/.claude`.
- Existing named volumes keep their contents. If you previously used a differently named volume, copy it across with a throwaway container or start fresh.
- If a project's own `devcontainer.json` also mounts `/worktrees` or `~/.claude`, the two mounts conflict; remove one.
