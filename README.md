# Claude Code status line

Two-line status line with usage progress bars, color-coded by how high usage is. Two equivalent scripts:

| Platform | Script | Needs |
|----------|--------|-------|
| Windows | `statusline.ps1` | PowerShell 7 (`pwsh`) |
| Linux / macOS / WSL | `statusline.sh` | `bash`, `jq` |

```
Sonnet 5.5          | session resets 19:12  | week resets Mon 16:59
ctx ███████░░░  67% | ██░░░░░░░░  23% 2h12m | █████████░  90% 2d23h
```

- **Top line:** model name, and when the session (5-hour) and week (7-day) limits reset.
- **Bottom line:** context window usage, session usage and weekly usage as 10-block bars, with the time left until reset.
- **Colors:** green under 60%, yellow 60-84%, red 85% and above.
- Refreshes after every message and every 5 seconds (also while Claude is working).

The session/week bars only appear if your Claude Code version and plan send rate-limit data. Otherwise only the `ctx` column is shown. In a fresh session (before the first message) `ctx` shows 0%.

You also need a terminal that supports Unicode block characters and ANSI colors (Windows Terminal, iTerm2, most Linux terminals do).

## Install

1. Get the script. Clone the repo anywhere (recommended, so you can pull updates), or copy the single file you need into your Claude config folder (`~/.claude/` or `C:\Users\<you>\.claude\`; if you set `CLAUDE_CONFIG_DIR`, use that folder):

   ```
   git clone <repo-url> ~/claude-statusline
   ```

2. Check the requirements:
   - Windows: `pwsh -v`. Install with `winget install Microsoft.PowerShell` if missing.
   - Linux / macOS: `jq --version`. Install with `brew install jq` or `sudo apt install jq` if missing.

3. Add this to `settings.json` in your Claude config folder (merge it with what's already there, keep the commas valid):

   Windows:

   ```json
   "statusLine": {
     "type": "command",
     "command": "pwsh -NoProfile -File C:/Users/<you>/claude-statusline/statusline.ps1",
     "refreshInterval": 5
   }
   ```

   Linux / macOS:

   ```json
   "statusLine": {
     "type": "command",
     "command": "bash ~/claude-statusline/statusline.sh",
     "refreshInterval": 5
   }
   ```

   Replace the path with wherever you put the script. On Windows use forward slashes.

4. Restart Claude Code. The status line appears at the bottom.

Alternative: run `/statusline` in Claude Code and ask it to use the script.

## Updates

- **Manually:** `git -C ~/claude-statusline pull`
- **Automatically when Claude Code starts:** add a `SessionStart` hook to `settings.json`:

  ```json
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "git -C ~/claude-statusline pull --ff-only --quiet"
          }
        ]
      }
    ]
  }
  ```

  Use the full path on Windows (e.g. `C:/Users/<you>/claude-statusline`). If `settings.json` already has a `hooks` section, add the entry inside it instead of creating a second one.

> **Security note:** the script runs on your machine every few seconds, so anything pushed to the repo runs as you.
> Only auto-pull from a repo that only you or people you trust can push to.
> With manual pulls you can read the changes first (`git fetch`, then `git log -p ..origin/main`).

## Customize

Edit the script you use:

| What | `statusline.ps1` | `statusline.sh` |
|------|------------------|-----------------|
| Bar length | `$width = 10` in `Get-Bar` | `width=10` in `bar` |
| Color thresholds | `$color = if ($p -ge 85) ...` in `Get-Bar` | `if ((p >= 85))` in `bar` |
| Labels (`session`, `week`) | the `"session"` / `"week"` strings near the end | the `add_limit session` / `add_limit week` calls |

The refresh rate is `refreshInterval` (seconds) in `settings.json`.

## Test it without Claude Code

```powershell
'{"model":{"display_name":"Sonnet 5.5"},"context_window":{"used_percentage":67},"rate_limits":{"five_hour":{"used_percentage":23,"resets_at":1893456000},"seven_day":{"used_percentage":90,"resets_at":1893456000}}}' | pwsh -NoProfile -File .\statusline.ps1
```

```sh
echo '{"model":{"display_name":"Sonnet 5.5"},"context_window":{"used_percentage":67},"rate_limits":{"five_hour":{"used_percentage":23,"resets_at":1893456000},"seven_day":{"used_percentage":90,"resets_at":1893456000}}}' | bash statusline.sh
```

## Troubleshooting

- **Nothing shows:** check the path in `settings.json`, and that `pwsh` (Windows) or `jq` (Linux/macOS) is on your PATH.
- **Garbled blocks:** use a terminal and font with block-character support (e.g. Windows Terminal).
- **Session/week bars missing:** your version or plan doesn't send `rate_limits`. Only context is shown.
- **Not refreshing while working:** your version may not support `refreshInterval`; it then updates after each message only.
- **`statusline: bad input`:** the script got something that isn't JSON on stdin. Only happens when run by hand without the test input above.
- **`^M` / `bad interpreter` errors on Linux/macOS:** the file got Windows line endings. The repo's `.gitattributes` forces LF for `.sh`; re-clone or run `dos2unix statusline.sh`.
