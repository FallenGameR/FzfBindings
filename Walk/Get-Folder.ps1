# This allows us to control
# - what folders are excluded (hidden folders and files and folders that start with dot like .git)
# - in what order do we see the output (similar to ls order)
# - make sure that we use command that is OneDrive friendly (Linux find downloads everything while enumerating)
# - allow fzf to terminate output early (piped in input blocks fzf from exit)

function excluded_folders
{
    Get-Content "$PsScriptRoot/../Data/excluded_folders"
}

function included_folders
{
    Join-Path $env:HOME Downloads
    Join-Path $env:HOME Documents
    $env:FZF_QUICK_PATHS -split [io.path]::PathSeparator
}

$walker = "$PsScriptRoot/../Bin/Walker/walker"
$param = @()
$param += $pwd
$param += "-f" # don't show files, only directories

foreach( $excluded in excluded_folders | where{ $psitem } )
{
    $param += "-e"
    $param += $excluded
}

foreach( $included in included_folders | where{ $psitem } )
{
    $param += "-I"
    $param += $included
}

if( $PSVersionTable.Platform -ne "Unix" )
{
    $walker += ".exe"
    $param += "-D" # traverse into .directories
}

& $walker @param