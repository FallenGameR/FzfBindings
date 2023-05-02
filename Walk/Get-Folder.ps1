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

$excludedFolders = excluded_folders | where{ $psitem }
$includedFolders = included_folders | where{ $psitem }

$walker = "$PsScriptRoot/../Bin/Walker/walker"
$param = @()
$param += $pwd
$param += "-f" # don't show files, only directories

foreach( $excluded in $excludedFolders )
{
    $param += "-e"
    $param +=  '"' + $excluded + '"'
}

foreach( $included in $includedFolders )
{
    $param += "-I"
    $param += '"' + $included + '"'
}

if( $PSVersionTable.Platform -ne "Unix" )
{
    $walker += ".exe"
    $param += "-D" # traverse into .directories
}

if( Get-Item $walker -ea Ignore )
{
    # Calling it as & walker makes console to mess up the formatting
    # Trying out the process start approach for now
    # Folders and files with spaces are escaped with single quotation arguments
    # and the quotes are not being sent to the target app as per the documentation
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

filter normalize_quick_access
{
    $psitem | where{ Test-Path $psitem -ea Ignore } | foreach{ [System.IO.Path]::GetFullPath($psitem) }
}

$includedFolders | normalize_quick_access
find_recursive "."