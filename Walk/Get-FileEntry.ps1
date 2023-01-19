# This allows us to control
# - what folders are excluded (hidden folders and files and folders that start with dot like .git)
# - in what order do we see the output (similar to ls order)
# - make sure that we use command that is OneDrive friendly (Linux find downloads everything while enumerating)
# - allow fzf to terminate output early (piped in input blocks fzf from exit)
#

function excluded_folders
{
    Get-Content "$PsScriptRoot/../Data/excluded_folders"
}

$excludedFolders = excluded_folders | where{ $psitem }

$walker = "$PsScriptRoot/../Bin/Walker/walker"
$param = @()
$param += $pwd

foreach( $excluded in $excludedFolders )
{
    $param += "-e"
    $param += $excluded
}

if( $PSVersionTable.Platform -ne "Unix" )
{
    $walker += ".exe"
    $param += "-D" # traverse into .directories
}

if( Get-Item $walker -ea Ignore )
{
    return & $walker @param
}

# Until walker will be published to choco, let's not add the binary to the codebase
Write-Warning "Could not find $walker, falling back to slow pwsh implementation"

$commonPathPrefixLength = $pwd.ToString().Length + 1

function find_files($root)
{
    Get-ChildItem $root -File -ea Ignore
}

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
    # Read current level
    $files = find_files $root | %{ normalize $psitem }
    $folders = find_folders $root

    # Output current level
    $folders | %{ (normalize $psitem) + [io.path]::DirectorySeparatorChar }
    $files

    # Then recurse into every folder if it is not excluded
    foreach( $folder in $folders | where Name -notin $excludedFolders )
    {
        find_recursive $folder
    }
}

"."
find_recursive "."
