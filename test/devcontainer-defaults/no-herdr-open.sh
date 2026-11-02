#!/bin/bash
# installHerdrOpen: false must leave nothing behind.
set -e
source dev-container-features-test-lib

check "no herdr-open binary" test ! -e /usr/local/bin/herdr-open.sh
check "no herdr-open skill"  test ! -e /etc/claude-code/.claude/skills/opening-herdr-tabs
check "no herdr-open policy" test ! -e /etc/claude-code/managed-settings.d/50-devcontainer-defaults.json

# The rest of the feature is unaffected.
check "worktrees dir exists"  test -d /worktrees
check "claude home dir exists" test -d /mnt/claude-home

reportResults
