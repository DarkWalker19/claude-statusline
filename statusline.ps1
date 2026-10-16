[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$raw = [Console]::In.ReadToEnd()
try { $j = $raw | ConvertFrom-Json } catch { Write-Host "statusline: bad input"; exit }

$inv = [cultureinfo]::InvariantCulture
$full = [string][char]0x2588
$empty = [string][char]0x2591
$esc = [char]27
$dim = "$esc[90m"
$off = "$esc[0m"

function Get-Bar($pct, $width = 10) {
    $p = [math]::Max(0, [math]::Min(100, [double]$pct))
    $n = [int][math]::Round($p / 100 * $width)
    $color = if ($p -ge 85) { 31 } elseif ($p -ge 60) { 33 } else { 32 }   # red / yellow / green
    "$esc[${color}m" + ($full * $n) + "$dim" + ($empty * ($width - $n)) + "$off $esc[${color}m" + ("{0,3:N0}%" -f $p) + $off
}

function ConvertTo-Time($v) {
    if ($null -eq $v -or "$v" -eq "") { return $null }
    try {
        if ($v -is [datetime]) { [datetimeoffset]$v.ToUniversalTime() }
        elseif ($v -is [string] -and $v -notmatch '^\d+(\.\d+)?$') { [datetimeoffset]::Parse($v, $inv) }
        else { [datetimeoffset]::FromUnixTimeSeconds([long][double]$v) }
    } catch { $null }
}

# Compact countdown for line 1, e.g. "2h12m"
function Get-Countdown($t) {
    if ($null -eq $t) { return "" }
    $left = $t - [datetimeoffset]::UtcNow
    if ($left.TotalSeconds -le 0) { return " ~0m" }
    $in = if ($left.TotalHours -ge 24) { "{0}d{1}h" -f [int]$left.Days, $left.Hours }
          elseif ($left.TotalHours -ge 1) { "{0}h{1:00}m" -f [int]$left.TotalHours, $left.Minutes }
          else { "{0}m" -f [int][math]::Ceiling($left.TotalMinutes) }
    " $dim$in$off"
}

# Absolute reset time for line 2, e.g. "19:06" (today) or "Mon 16:53"
function Get-ResetAt($t) {
    $l = $t.ToLocalTime()
    if ($l.Date -eq [datetime]::Today) { $l.ToString("HH:mm", $inv) } else { $l.ToString("ddd HH:mm", $inv) }
}

# Visible length (ignores ANSI colour codes) and right-padding to a column width
function Get-VLen($s) { ($s -replace "$esc\[[0-9;]*m", "").Length }
function Set-Pad($s, $w) { $s + (" " * [math]::Max(0, $w - (Get-VLen $s))) }

$five = $j.rate_limits.five_hour
$week = $j.rate_limits.seven_day
$fiveAt = ConvertTo-Time $five.resets_at
$weekAt = ConvertTo-Time $week.resets_at

# Each column is a (line 1, line 2) pair, so both lines line up.
$cols = @()

$c1 = @("", "")
# Before the first message the context % is null: show 0 instead of hiding the column
$ctx = if ($null -ne $j.context_window.used_percentage) { $j.context_window.used_percentage } else { 0 }
$c1[0] = "ctx " + (Get-Bar $ctx)
$m = @()
if ($j.model.display_name) { $m += $j.model.display_name }
$c1[1] = "$dim" + ($m -join " ") + "$off"
$cols += , $c1

if ($null -ne $five.used_percentage) {
    $cols += , @(((Get-Bar $five.used_percentage) + (Get-Countdown $fiveAt)),
                 ("session" + $(if ($fiveAt) { "$dim resets " + (Get-ResetAt $fiveAt) + "$off" } else { "" })))
}
if ($null -ne $week.used_percentage) {
    $cols += , @(((Get-Bar $week.used_percentage) + (Get-Countdown $weekAt)),
                 ("week" + $(if ($weekAt) { "$dim resets " + (Get-ResetAt $weekAt) + "$off" } else { "" })))
}

$sep = " $dim|$off "
$l1 = @(); $l2 = @()
for ($i = 0; $i -lt $cols.Count; $i++) {
    $w = [math]::Max((Get-VLen $cols[$i][0]), (Get-VLen $cols[$i][1]))
    if ($i -lt $cols.Count - 1) {
        $l1 += Set-Pad $cols[$i][0] $w
        $l2 += Set-Pad $cols[$i][1] $w
    } else {
        $l1 += $cols[$i][0]
        $l2 += $cols[$i][1]
    }
}

# Top line = labels/details (l2), bottom line = bars (l1)
if ((Get-VLen ($l2 -join "")) -gt 0) { Write-Host ($l2 -join $sep) }
if ((Get-VLen ($l1 -join "")) -gt 0) { Write-Host ($l1 -join $sep) }
