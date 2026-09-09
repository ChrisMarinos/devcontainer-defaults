#!/usr/bin/env bash
# Package one feature as the .tgz that a dev container can reference by HTTPS URL.
#
# Usage:  ./package.sh <feature-id>            e.g. ./package.sh marinos-defaults
# Output: dist/<feature-id>.tgz  (devcontainer-feature.json and install.sh at the archive root)
#
# The archive is what you attach to a GitHub Release; see README.md.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

id="${1:-}"
[ -n "$id" ] && [ -f "src/$id/devcontainer-feature.json" ] \
  || { echo "usage: package.sh <feature-id>   (one of: $(ls src | tr '\n' ' '))" >&2; exit 1; }

version="$(jq -r .version "src/$id/devcontainer-feature.json")"
mkdir -p dist
tar czf "dist/$id.tgz" -C "src/$id" .
echo "dist/$id.tgz  (version $version)"
tar tzf "dist/$id.tgz" | sed 's/^/  /'
