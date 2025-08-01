function Show-FzfFilePreview
{
    <#
    .SYNOPSIS
        Preview piped in files with fzf (pf)

    .DESCRIPTION
        This command will not pipe the input to the fzf until all
        the input would be collected. That is important for huge inputs.

        If you want async fast output your would need to fzf directly
        or redefine it's walker command similarly how cdf and codef do it.

    .EXAMPLE
        ls | % FullName | pf
    #>

    [cmdletbinding()]
    param
    (
        [Parameter(ValueFromPipeline = $true)]
        $Item
    )

    begin
    {
        $pipeline = @()
    }
    process
    {
        $pipeline += $item
    }
    end
    {
        $pipeline | Use-Fzf (Initialize-FzfArgs -FilePreview)
    }
}

function Start-FzfProcess
{
    <#
    .SYNOPSIS
        Find an app via the fzf and execute it via the shell

    .PARAMETER Path
        Part of the path to the started executable somewhere
        in the current folder or it's descendants.

        Or don't select anything and find it interactively via fzf.

    .EXAMPLE
        startf sln
    #>

    [cmdletbinding()]
    param
    (
        [string] $Path
    )

    $result = Use-Fzf (Initialize-FzfArgs $Path)
    if( -not $result ) { return }
    $result

    # Shell start is different on Unix and Windows
    if( $PSVersionTable.Platform -eq "Unix" )
    {
        & $result
    }
    else
    {
        start $result
    }
}

function Set-FzfLocation
{
    <#
    .SYNOPSIS
        Change current folder with fzf preview

    .DESCRIPTION
        Specify excluded and included folders in
        FZF/Invoke-sdf.ps1 and via $env:FZF_QUICK_PATHS

    .PARAMETER Path
        Part of the folder path to for initial filtration.
        Or just do the search interactively with fzf.

    .PARAMETER Hidden
        Show hidden folders, these are the ones that start with .

    .PARAMETER NoIgnore
        Show folders that are excluded via .gitignore.

        Note that in case these folders are commited, they would still
        be treated as ignored.
    #>

    [cmdletbinding()]
    param
    (
        [string] $Path,
        [switch] $Hidden,
        [switch] $NoIgnore
    )

    $command = "$pwsh -nop -f ""$PSScriptRoot/Walk/Get-Folder.ps1"""
    if( $Hidden ) { $command += " -Hidden" }
    if( $NoIgnore ) { $command += " -NoIgnore" }

    function Get-FzfArgs
    {
        Initialize-FzfArgs $path -FilePreview
        "--bind", "alt-o:execute-silent:code {1}"
        "--bind", "start:reload:$command"
        "--preview-label", "Folder"
    }

    $result = @(Use-Fzf (Get-FzfArgs))
    if( -not $result ) { return }
    $result

    if( $result.Length -eq 1 )
    {
        Push-Location $result[0]
    }
}

function Push-FzfLocation
{
    <#
    .SYNOPSIS
        Push current location onto location stack
        and change directory to something that is
        higher in the directory tree

    .DESCRIPTION
        This function is complimentary to cdf that does something
        similar but it searches for the new location down in
        the directory tree.

        Plus this command does pushd so that it is easy to
        return to the folder where you did stand on before
        this command. This is useful if you want to do quick
        look around up the file tree but then get back with
        the results to the current folder.

    .EXAMPLE
        pushd mv
    #>

    function Get-DirectoryStack
    {
        $parts = $pwd -split "\\|/"
        $path = $parts | select -f 1
        $paths = @()
        $path + [io.path]::DirectorySeparatorChar

        foreach( $part in $parts[1..($parts.Length-2)] )
        {
            $path += [io.path]::DirectorySeparatorChar + $part
            $path
        }

        if( $PSVersionTable.Platform -eq "Unix")
        {
            [io.path]::DirectorySeparatorChar
        }
    }

    $result = Get-DirectoryStack | Sort-Object -desc | Show-FzfFilePreview
    if( -not $result ) { return }

    Push-Location $result
}

function Stop-FzfProcess
{
    <#
    .SYNOPSIS
        Kill processes after a fzf search by name

    .PARAMETER Name
        Part of the process name to initialize fzf filter.
        Or search the process in an interactive way without initialization.

    .EXAMPLE
        killf nuget
    #>

    [cmdletbinding()]
    param
    (
        [string] $Name
    )

    function Get-FzfArgs
    {
        Initialize-FzfArgs $Name -ProcessPreview
        "--height=90%" # See a few lines of PS console in case we just dumped $pid to kill it
    }

    $lines = Get-Process | Format-Table -Auto | Out-String | foreach Trim | Use-Fzf (Get-FzfArgs)
    $lines | foreach{ Stop-Process -Id (-split $psitem)[4] -Verbose -ea Ignore }
}

function Invoke-FzfHistory
{
    <#
    .SYNOPSIS
        Find a history command (or multiple) with fzf and execute it again

    .DESCRIPTION
        Complimentary to PSReadLine:
        - autocompletion from history
        - F2 argument lookup (Unix only)
        - Alt+a argument highlight (Unix only)
    #>

    $commands = @(Get-History)
    [array]::Reverse($commands)
    $result = $commands | Format-Table -Auto | Out-String | foreach Trim | Use-Fzf (Initialize-FzfArgs -HistoryPreview)
    if( -not $result ) { return }

    $ids = $result | where{ $psitem -match "^\s*(\d+)" } | foreach{ [int] $matches[1] }
    $toExecute = $commands | where Id -in $ids
    $command = $toExecute.CommandLine -join "; "

    Clear-Host
    $command
    Invoke-Expression $command
}

function Invoke-FzfCode
{
    <#
    .SYNOPSIS
        Invoke VS code after finding path to file or folder via fzf

    .DESCRIPTION
        Another use case for this function is to be a preview and
        then open found files in VS code after lookup via ripgrep.

    .PARAMETER Paths
        Paths that were found via ripgrep. Each path can be of form:
        - path
        - path:line
        - path:line:char

        Preview and VS Code will move to the specified
        location in that file in case it is provided.
    #>

    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        $Path
    )

    begin
    {
        $paths = @()
    }
    process
    {
        $paths += $path
    }
    end
    {
        # Select paths
        if( -not $paths )
        {
            $command = "$pwsh -nop -f ""$PSScriptRoot/Walk/Get-FileEntry.ps1"""

            function Get-FzfArgs
            {
                Initialize-FzfArgs -FilePreview
                "--bind", "start:reload:$command"
                "--bind", "alt-o:execute-silent:code --goto {1}"
            }

            $paths = Use-Fzf (Get-FzfArgs)
        }

        # Invoke code
        foreach( $path in $paths )
        {
            $invoke = "code --goto ""{0}""" -f $path
            $invoke
            code --goto $path
        }
    }
}

function Search-FzfRipgrep
{
    <#
    .SYNOPSIS
        Search files via ripgrep with fzf preview and filtration

    .DESCRIPTION
        Selected files will be opened in VS code on the matched lines

    .PARAMETER Query
        Text query to look for in files

    .PARAMETER Options
        Options that will be passed to ripgrep

    .PARAMETER Hidden
        Grep in the normally hidden files (like history)

    .PARAMETER NoIgnore
        Grep in the normally ignored files (like binaries excluded by .gitignore)

    .PARAMETER NoRecasing
        I use ripgrep with the default --ignore-case argument that makes rg
        to ignore case but only if the input is in lowercase. That feels strange -
        I usually copy-paste searched term from somewhere and it may be specified
        in any case and I expect the search to be case insensitive.

        This command does lowercase normalization to mitigate that issue.
        But if you want to have the default rg casing logic use this switch.

    .PARAMETER NoEditor
        Use this switch if you don't need to open VS code
        and you want the list of the found files with line info.

    .EXAMPLE
        rgf args -g *.rsq

    .NOTES
        Adopted from https://github.com/junegunn/fzf/blob/master/ADVANCED.md#switching-between-ripgrep-mode-and-fzf-mode
        And refined with https://junegunn.github.io/fzf/getting-started/
    #>

    param
    (
        [Parameter(Mandatory=$true)] $Query,
        [Parameter(Mandatory=$false, ValueFromRemainingArguments=$true)] $Options,
        [switch] $Hidden,
        [switch] $NoIgnore,
        [switch] $NoRecasing,
        [switch] $NoEditor
    )

    # Compose ripgrep command
    $rg =
        "rg",
        "--column",
        "--line-number",
        "--no-heading",
        "--color=always",
        "--smart-case",
        "--colors ""path:fg:0x3A,0x96,0xDD""",      # cyan
        "--colors ""line:fg:0x13,0xA1,0x0E""",      # green
        "--colors ""column:fg:0xF9,0xF1,0xA5""",    # bright yellow
        "--colors ""match:fg:0xE7,0x48,0x56""",     # bright red
        "--colors ""match:style:underline"""

    $rg = ($rg -join " ") + " "
    if( $Options )  { $rg += ($Options -join " ") + " " }
    if( $Hidden )   { $rg += "--hidden " }
    if( $NoIgnore ) { $rg += "--no-ignore " }
    if( -not $NoRecasing ) { $Query = $Query.ToLower() }

    # Compose fzf command
    function Get-FzfArgs
    {
        Initialize-FzfArgs $Query
        "--disabled"
        "--ansi"
        "--bind", "start:reload:$rg ""$Query"" || exit 0"
        "--bind", "change:reload:$rg {q} || exit 0"
        "--bind", "alt-o:execute-silent:code --goto {1}:{2}"
        "--bind", "alt-f:unbind(change,alt-f)+change-prompt(fzf> )+enable-search+rebind(alt-r)"
        "--bind", "alt-r:unbind(alt-r)+change-prompt(rg> )+disable-search+reload($rg {q} || exit 0)+rebind(change,alt-f)"
        "--bind", "enter:accept"
        "--header-first"
        "--header", "  alt shortcuts: Fzf | Ripgrep | Open | Wrap | arrows to resize"
        "--prompt", "rg> "
        "--tiebreak", "begin,length"
        "--color", "hl:-1:bold,hl+:-1:bold:reverse:"
        "--delimiter=:"
        "--preview", "bat --color=always {1} --highlight-line {2}"
        "--preview-label", "Match"
        "--preview-window", '~4,+{2}+4/3,down'
    }

    ## reload - '|| exit 0' needed to handle errors from rg
    ## --delimiter - split the fzf-selected line, {1} would be file name name, {2} would be line number

    # ~4 makes the top four lines as a sticky header
    # +{2} is offset to the second token (line number)
    # +4 — add 4 lines to the base offset to compensate for the header
    # /3 adjusts the offset so that the matching line is shown at a 1/3 position in the window
    # start preview window in the down position (alt-arrows or double alt-p can change it)

    $result = Use-Fzf (Get-FzfArgs)

    $paths = $result |
        foreach{ ($psitem -split ":" | select -f 3) -join ":" } |
        foreach{ $psitem -replace '\x1b\[[0-9;]*[a-z]' }

    if( -not $paths ) { return }
    $paths

    if( -not $NoEditor )
    {
        codef $paths
    }
}
