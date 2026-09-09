# devcontainer-features

Personal [Dev Container Features](https://containers.dev/implementors/features/), distributed as `.tgz` assets on GitHub Releases and applied to every dev container through VS Code's `dev.containers.defaultFeatures`.

| Feature | Purpose |
|---|---|
| [`marinos-defaults`](src/marinos-defaults) | Per-project `/worktrees` volume for git worktrees, and a shared volume behind `~/.claude` so Claude Code login, settings, and memory survive rebuilds. |

## Apply to every dev container

Add to your **host** VS Code user `settings.json`, pinned to a release:

```jsonc
"dev.containers.defaultFeatures": {
    "https://github.com/chrismarinos/devcontainer-features/releases/download/v1.0.0/marinos-defaults.tgz": {}
}
```

Rebuild a container and the feature is layered on top of the project's own `devcontainer.json`. Project settings win where they overlap.

## Releasing a change

1. Edit the feature under `src/<id>/` and bump `version` in its `devcontainer-feature.json`.
2. Test locally (needs Docker):
   ```bash
   npm install -g @devcontainers/cli
   devcontainer features test -f marinos-defaults -i mcr.microsoft.com/devcontainers/base:ubuntu .
   ```
3. Package and release from the host:
   ```bash
   ./package.sh marinos-defaults
   git tag v1.0.0 && git push --tags
   gh release create v1.0.0 dist/marinos-defaults.tgz --title v1.0.0 --notes "..."
   ```
4. Update the URL in your host `settings.json` to the new tag.

The repository must be public for the Dev Containers extension to download release assets without credentials.

## Layout

```
src/<feature>/devcontainer-feature.json   metadata, options, mounts, containerEnv, lifecycle hooks
src/<feature>/install.sh                  build-time install (runs as root)
src/<feature>/NOTES.md                    usage notes for the feature
test/<feature>/test.sh                    default test for `devcontainer features test`
test/<feature>/scenarios.json + *.sh      option scenarios
package.sh                                builds dist/<feature>.tgz
```
