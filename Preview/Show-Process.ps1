$npm_k, $pm_m, $ws_m, $cpu_s, $id, $si, $processName = -split $args[0]
if( -not $id ) { return }

$process = Get-Process -Id $id -ea Ignore
if( -not $process ) { return }

function SCRIPT:e { "`e[" + ($args -join ";") + "m" }

if( $process.Description )
{
    "$(e 36)$($process.Description)$(e 0)"
    ""
}

if( $process.FileVersion )
{
    "$(e 32)FileVersion:$(e 0) " + $process.FileVersion
}

if( $process.ProductVersion -ne $process.FileVersion )
{
    "$(e 32)ProductVersion:$(e 0) " + $process.ProductVersion
}

if( $process.Parent )
{
    "$(e 32)Parent:$(e 0) " + $process.Parent.Name + " (" + $process.Parent.Id + ")"
}

""

if( $process.CommandLine -notmatch '^"(?<path>[^"]+)"(?<args>.+)?' )
{
    -split $process.CommandLine
}
else
{
    "$(e 36)$($matches["path"])$(e 0)"
    if( $matches["args"] ) { -split $matches["args"] }
}

$process.Modules | ft -auto
