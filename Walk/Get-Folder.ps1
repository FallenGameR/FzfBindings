# This allows us to control
# - what folders are excluded (hidden folders and files and folders that start with dot like .git)
# - in what order do we see the output (similar to ls order)
# - make sure that we use command that is OneDrive friendly (Linux find downloads everything while enumerating)
# - allow fzf to terminate output early (piped in input blocks fzf from exit)
[CmdletBinding()]
param
(
    [switch] $Hidden,
    [switch] $NoIgnore
)

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

filter normalize_quick_access
{
    $psitem | where{ Test-Path $psitem -ea Ignore } | foreach{ [System.IO.Path]::GetFullPath($psitem) }
}

$excludedFolders = excluded_folders | where{ $psitem }
$includedFolders = included_folders | where{ $psitem }

# fd is faster and maintained way to do the same stuff as walker
# it doesn't understand hidden windows folders though
if( Get-Command fd -ea Ignore )
{
    $includedFolders | normalize_quick_access

    $fd = @("-t", "d", "--color=always")

    if( $Hidden )
    {
        $fd += "-H"
    }

    if( $NoIgnore )
    {
        $fd += "-I"
    }

    foreach( $excluded in $excludedFolders )
    {
        $fd += "-E"
        $fd += $excluded
    }

    & fd @fd
    return
}

$walker = "$PsScriptRoot/../Bin/Walker/walker"
$param = @()
$param += $pwd
$param += "-f" # don't show files, only directories

foreach( $excluded in $excludedFolders )
{
    $param += "-e"
    $param += $excluded
}

foreach( $included in $includedFolders )
{
    $param += "-I"
    $param += $included
}

if( $PSVersionTable.Platform -ne "Unix" )
{
    $walker += ".exe"
    $param += "-D" # traverse into .directories
}

if( Get-Item $walker -ea Ignore )
{
    # Calling walker with & while using FZF_DEFAULT_COMMAND makes console to
    # mess up the output formatting in some cases. It seems like CR is not being
    # processed correctly after some walker incocations from FZF.
    #return & $walker @param

    # Trying out the process start approach for now.

    # Folders and files with spaces should be escaped with single quotation arguments
    # but when I'm trying to do that something gets broken along the way, so
    # for now we don't do any escaping so that non-space-containing paths would
    # be processed. And in the mean time I gather info what doesn't work.

    # https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.processstartinfo.arguments?view=net-8.0

    $process = [Diagnostics.Process] @{
        StartInfo = [Diagnostics.ProcessStartInfo] @{
            FileName = $walker
            Arguments = $param -join " "
            WorkingDirectory = (Get-Location).Path
            UseShellExecute = $false
        }
    }
    $process.Start() | Out-Null
    $process.WaitForExit()
    return
}

# Until walker will be published to choco, let's not add the binary to the codebase
Write-Warning "Could not find $walker, falling back to slow pwsh implementation"

$commonPathPrefixLength = $pwd.ToString().Length + 1

function find_folders($root)
{
    Get-ChildItem $root -Directory -ea Ignore
}

function normalize($path)
{
    $path.FullName.Substring($commonPathPrefixLength)
}

function find_recursive($root)
{
    # Current level
    $folders = find_folders $root
    $folders | %{ normalize $psitem }

    # Then recurse into every folder if it is not excluded
    foreach( $folder in $folders | where Name -notin $excludedFolders )
    {
        find_recursive $folder
    }
}



$includedFolders | normalize_quick_access
find_recursive "."