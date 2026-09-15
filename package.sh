#!/usr/bin/env bash
# Package one feature as the .tgz that a dev container can reference by HTTPS URL.
#
# Usage:  ./package.sh <feature-id>            e.g. ./package.sh devcontainer-defaults
# Output: dist/<feature-id>.tgz  (devcontainer-feature.json and install.sh at the archive root)
#
# The archive is what you attach to a GitHub Release; see README.md.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

usage() {
  local ids=()
  for d in src/*/; do ids+=("$(basename "$d")"); done
  echo "usage: package.sh <feature-id>   (one of: ${ids[*]})" >&2
  exit 1
}

id="${1:-}"
[ -n "$id" ] && [ -f "src/$id/devcontainer-feature.json" ] || usage

version="$(jq -r .version "src/$id/devcontainer-feature.json")"
mkdir -p dist
tar czf "dist/$id.tgz" -C "src/$id" .
echo "dist/$id.tgz  (version $version)"
tar tzf "dist/$id.tgz" | sed 's/^/  /'
