# Pulls the latest statusline version (fast-forward only). While it runs, the status line shows "Updating...".
$dir = $PSScriptRoot
$gitDir = git -C $dir rev-parse --absolute-git-dir 2>$null
if (-not $gitDir) { Write-Host "Not a git clone: $dir. Nothing to update."; exit 1 }
$marker = Join-Path $gitDir "statusline-updating"
try {
    [IO.File]::WriteAllText($marker, "")
    git -C $dir pull --ff-only
    $code = $LASTEXITCODE
} finally {
    Remove-Item $marker -Force -ErrorAction SilentlyContinue
}
if ($code -eq 0) { Write-Host "Statusline updated." } else { Write-Host "Update failed (exit $code). Check for local changes in $dir." }
exit $code
