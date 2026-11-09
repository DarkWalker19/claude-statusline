---
description: Update the Claude Code statusline (git pull in the statusline clone)
allowed-tools: Bash
---

Update the statusline from its git clone.

1. Find the script folder: read the `statusLine.command` value in the `settings.json` in the Claude config folder (`~/.claude/` or `$CLAUDE_CONFIG_DIR`). It points at `statusline.ps1` or `statusline.sh`; the folder containing it is the clone.
2. Run the update script in that folder: `pwsh -NoProfile -File <folder>/update.ps1` on Windows, or `bash <folder>/update.sh` on Linux/macOS/WSL. While it runs, the status line shows "Updating...".
3. Report the result in one line. If it failed, say why (usually local changes or diverged history) and do not try to force it.
