function Show-Help
{
    <#
    .SYNOPSIS
        Show colorized via bat help for a native command

    .PARAMETER Path
        Path to the native executable.
        Or you can pipe in the help text to render.

    .EXAMPLE
        hlp ping

    .EXAMPLE
        walker --help | hlp
    #>

    param
    (
        [string] $Path
    )

    begin
    {
        if( $path )
        {
            & $path --help 2>&1 | Show-Help
            return
        }
        $accumulator = @()
    }
    process { $accumulator += $psitem }
    end
    {
        # NOTE: On Unix it may be 'man'
        $accumulator | bat -pl help
    }
}

function Get-PreviewArgsFzf( $path )
{
    $fzfArgs =
        "--margin", "1%",
        "--padding", "1%",
        "--border",
        "--keep-right",
        "--preview", "$pwsh -nop -f $PSScriptRoot/Preview/Show-FileEntry.ps1 {}",
        "--preview-window=55%"

    $executedFromCode = (gps -id $pid | % parent | % name) -eq "Code"
    if( -not $executedFromCode )
    {
        # For some reason in VS code terminal background color remains
        $fzfArgs += "--color", "preview-bg:#222222"
    }

    if( $path )
    {
        $fzfArgs += "-q"
        $fzfArgs += $path
    }

    $fzfArgs
}

function Show-PreviewFzf
{
    <#
    .SYNOPSIS
        Preview piped in files with fzf

    .DESCRIPTION
        This command will not pipe in input to fzf until all the input
        will be collected. That is important on huge inputs. If you want
        async fast output call fzf directly (but no preview) or combine
        it with walker (as it is done in cdf and CodeF).

    .EXAMPLE
        ls | % FullName | pf src
    #>

    $fzfArgs = Get-PreviewArgsFzf
    $input | fzf @fzfArgs
}

function Start-ProcessFzf($path)
{
    <#
    .SYNOPSIS
        Find app with fzf and execute it via shell

    .PARAMETER Path
        Part of the path to the started executable somewhere
        in the current folder or it's descendants.

        Or don't select anything and find it interactively via fzf.

    .EXAMPLE
        startf sln
    #>

    $fzfArgs = @()
    if( $path )
    {
        $fzfArgs += "-q"
        $fzfArgs += $path
    }

    $destination = fzf @fzfArgs
    $destination

    if( $destination )
    {
        if( $PSVersionTable.Platform -eq "Unix" )
        {
            # Unix
            & $destination
        }
        else
        {
            # Windows
            start $destination
        }
    }
}

function Set-LocationFzf
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
    #>

    param
    (
        [string] $Path
    )

    $fzfArgs = Get-PreviewArgsFzf $path

    $fzfPreserved = $env:FZF_DEFAULT_COMMAND
    $env:FZF_DEFAULT_COMMAND = "$pwsh -nop -f $PSScriptRoot/Walk/Get-Folder.ps1"
    try { $destination = @(fzf @fzfArgs) }
    finally { $env:FZF_DEFAULT_COMMAND = $fzfPreserved }

    # This is a slower way to do the same. But there is a related walker/pwsh/FZF bug
    # that can be mitigated this way. But recently I found a workaround for that bug.
    #$destination = @(& "$PSScriptRoot/Walk/Get-Folder.ps1" | fzf @fzfArgs)

    $destination

    if( $destination.Length -eq 1 )
    {
        cd $destination[0]
    }
}

function Stop-ProcessFzf
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

    param
    (
        [string] $Name
    )

    $fzfArgs = @()
    $fzfArgs += "--header-lines=3"  # PS output table header
    $fzfArgs += "--height"          # To see few lines of previous input in case we want to kill pwsh
    $fzfArgs += "90%"               #   and we dumped $pid to the console just before the killf

    if( $name )
    {
        $fzfArgs += "-q"
        $fzfArgs += $name
    }

    $lines = gps | fzf @fzfArgs
    if( -not $lines ) {return}

    $lines | foreach{
        $split = $psitem -split "\s+" | where{ $psitem }
        $id = $split[4]
        Stop-Process -Id $id -Verbose -ea Ignore
    }
}

function Push-LocationFzf
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

    $path = Get-DirectoryStack | Sort-Object -desc | pf
    if( $path )
    {
        pushd $path
    }
}

function Invoke-HistoryFzf
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

    # Get history reversed
    $commands = @(Get-History)
    [array]::Reverse($commands)

    # Select commands to execute with fzf
    $text = ($commands | Out-String) -split [Environment]::NewLine | select -Skip 3
    $result = $text | fzf

    if( $result )
    {
        $ids = $result | where{ $psitem -match "^\s*(\d+)" } | foreach{ [int] $matches[1] }
        $toExecute = $commands | where Id -in $ids
        $command = $toExecute.CommandLine -join "; "

        Clear-Host
        $command
        Invoke-Expression $command
    }
}

function Invoke-CodeFzf
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

    param
    (
        $Paths
    )

    # Select paths
    if( -not $paths )
    {
        $fzfArgs = Get-PreviewArgsFzf

        $fzfPreserved = $env:FZF_DEFAULT_COMMAND
        $env:FZF_DEFAULT_COMMAND = "$pwsh -nop -f $PSScriptRoot/Walk/Get-FileEntry.ps1"
        try { $paths = @(fzf @fzfArgs) }
        finally { $env:FZF_DEFAULT_COMMAND = $fzfPreserved }

        # This is a slower way to do the same. But there is a related walker/pwsh/FZF bug
        # that can be mitigated this way. But recently I found a workaround for that bug.
        #$paths = @(& "$PSScriptRoot/Walk/Get-FileEntry.ps1" | fzf @fzfArgs)
    }

    if( -not $paths )
    {
        return
    }

    # Invoke code
    foreach( $path in $paths )
    {
        $invoke = "code --goto ""{0}""" -f $path
        $invoke
        code --goto $path
    }
}

function Search-RipgrepFzf
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
    #>

    param
    (
        [Parameter(Mandatory=$true)] $Query,
        [Parameter(Mandatory=$false, ValueFromRemainingArguments=$true)] $Options,
        [switch] $NoRecasing,
        [switch] $NoEditor
    )

    if( -not $NoRecasing )
    {
        $Query = $Query.ToLower()
    }

    $rgArgs =
        "rg",
        "--column",
        "--line-number",
        "--no-heading",
        "--color=always",
        "--colors ""path:fg:0x3A,0x96,0xDD""",      # cyan
        "--colors ""line:fg:0x13,0xA1,0x0E""",      # green
        "--colors ""column:fg:0xF9,0xF1,0xA5""",    # bright yellow
        "--colors ""match:fg:0xE7,0x48,0x56""",     # bright red
        "--colors ""match:style:underline""",
        "--smart-case"

    $rg = ($rgArgs -join " ") + " "

    if( $options )
    {
        $rg += ($options -join " ") + " "
    }

    $fzfPreserved = $env:FZF_DEFAULT_COMMAND
    $env:FZF_DEFAULT_COMMAND = "$rg ""$Query"""

    $result = try
    {
        # 'command || cd .' is used as analog of 'command || true' in linux samples
        # it makes sure that on rg find failure the command  would still return non error exit code
        # and thus would not terminate fzf
        #--height "99%" `
        fzf `
            --ansi `
            --color "hl:-1:bold,hl+:-1:bold:reverse" `
            --disabled `
            --query $Query `
            --bind "change:reload: $rg ""{q}"" || cd ." `
            --bind "alt-f:unbind(change,alt-f)+change-prompt(rg|fzf> )+enable-search+clear-query+rebind(alt-r)" `
            --bind "alt-r:unbind(alt-r)+change-prompt(rg> )+disable-search+reload($rg ""{q}"" || cd .)+rebind(change,alt-f)" `
            --prompt "rg> " `
            --delimiter ":" `
            --tiebreak "begin,length" `
            --header '<ALT-R: rg> <ALT-F: fzf>' `
            --preview 'bat --color=always {1} --highlight-line {2}' `
            --preview-window 'up,72%,border-bottom,+{2}/3,~3'
            # +{2} - place in bat output, base offset to use for scrolling bat output to the highlighted line, from {2} token
            # /3   - place in viewport to place the highlighted line, in fraction of the preview window height - near the middle of the screen but a bit higher
            # ,~3  - pin top 3 lines from the bat output as the header, it would show the name of the file
    }
    finally
    {
        $env:FZF_DEFAULT_COMMAND = $fzfPreserved
    }

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
