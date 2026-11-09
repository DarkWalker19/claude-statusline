#!/usr/bin/env bash
# Pulls the latest statusline version (fast-forward only). While it runs, the status line shows "Updating...".
dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd) || exit 1
git_dir=$(git -C "$dir" rev-parse --absolute-git-dir 2>/dev/null) || { echo "Not a git clone: $dir. Nothing to update."; exit 1; }
marker="$git_dir/statusline-updating"
trap 'rm -f "$marker"' EXIT
: >"$marker"
git -C "$dir" pull --ff-only
code=$?
if ((code == 0)); then echo "Statusline updated."; else echo "Update failed (exit $code). Check for local changes in $dir."; fi
exit $code
