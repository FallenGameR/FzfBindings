$fzfOptions = @(
    "--layout=reverse",             # Grow list down, not upwards
    "--tabstop=4",                  # Standard tab size
    "--multi",                      # Multi select possible
    "--bind",                       # Shortcuts:
    "alt-t:toggle-all",             # Alt+t toggles selection
    "--cycle",                      # Cycle the list
    "--ansi",                       # Use Powershell colors
    "--no-mouse",                   # We need terminal mouse behavior, not custom one
    "--tiebreak='length,index'",    # Priorities to resolve ties (index comes last always)
    "--color=bg:#0C0C0C",           # Background (current line) = Black
    "--color=bg+:#0C0C0C",          # Background (current line) = Black
    "--color=fg+:#F2F2F2",          # Text (current line) = White
    "--color=hl+:#13A10E",          # Highlighted substrings (current line) = DarkGreen
    "--color=pointer:#3A96DD",      # Pointer to the current line = DarkCyan
    "--color=preview-bg:#0C0C0C",   # Preview window background = Black
    "--color=prompt:#CCCCCC"        # Prompt = Gray

    #"--height 60%"                 # Leave some space intact - breaks cyrillic typing, bug created
    #"--color=bg:#RRGGBB",          # Background
    #"--color=bg+:#RRGGBB",         # Background (current line)
    #"--color=border:#RRGGBB",      # Border of the preview window and horizontal separators (--border)
    #"--color=fg:#RRGGBB",          # Text
    #"--color=fg+:#RRGGBB",         # Text (current line)
    #"--color=gutter:#RRGGBB",      # Gutter on the left (defaults to bg+)
    #"--color=header:#RRGGBB",      # Header
    #"--color=hl:#RRGGBB",          # Highlighted substrings
    #"--color=hl+:#RRGGBB",         # Highlighted substrings (current line)
    #"--color=info:#RRGGBB",        # Info
    #"--color=marker:#RRGGBB",      # Multi-select marker
    #"--color=pointer:#RRGGBB",     # Pointer to the current line
    #"--color=preview-bg:#RRGGBB",  # Preview window background
    #"--color=preview-fg:#RRGGBB",  # Preview window text
    #"--color=prompt:#RRGGBB",      # Prompt
    #"--color=spinner:#RRGGBB",     # Streaming input indicator
)
$env:FZF_DEFAULT_OPTS = $fzfOptions -join " "

$SCRIPT:pwsh = "pwsh"
if( Test-Windows ) { $SCRIPT:pwsh += ".exe" }

Register-Shortcut "Alt+h" "hf" "History search"
Register-Shortcut "Alt+o" "startf" "Open file"
Register-Shortcut "Alt+r" "rgf" "Ripgrep search"
Register-Shortcut "Alt+k" "killf" "Kill process"
Register-Shortcut "Alt+f" "codef" "Code to open file or directory"
Register-Shortcut "Alt+v" "codef" "Code to open file or directory (shortcut from Vim"
Register-Shortcut "Alt+d" "cdf" "Change directory"
Register-Shortcut "Alt+u" "pushf" "Go up fuzzy"

Set-Alias hlp Show-Help
Set-Alias pf Show-PreviewFzf
Set-Alias startf Start-ProcessFzf
Set-Alias cdf Set-LocationFzf
Set-Alias killf Stop-ProcessFzf
Set-Alias pushf Push-LocationFzf
Set-Alias hf Invoke-HistoryFzf
Set-Alias codef Invoke-CodeFzf
Set-Alias rgf Search-RipgrepFzf

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

# SCRIPT: after debugging
function Get-PreviewArgsFzf( $path )
{
    $fzfArgs =
        "--margin", "1%",
        "--padding", "1%",
        "--border",
        "--keep-right",
        "--preview", "$pwsh -nop -f $PSScriptRoot/../FZF/Preview-CodeF.ps1 {}",
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
        switch( Get-Platform )
        {
            "Win32NT" { start $destination }
            "Unix" { & $destination }
            default { & $destination }
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
    $cdf = "$PSScriptRoot/../FZF/Invoke-Cdf.ps1"

    $destination = @(& $cdf | fzf @fzfArgs)
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

        foreach( $part in $parts[1..($parts.Length-2)] )
        {
            $path += [io.path]::DirectorySeparatorChar + $part
            $path
        }

        if( Test-Unix )
        {
            "/"
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
        $codef = "$PSScriptRoot/../FZF/Invoke-Codef.ps1"
        $paths = @(& $codef | fzf @fzfArgs)
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

    $oldFzfCommand = $env:FZF_DEFAULT_COMMAND
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
        $env:FZF_DEFAULT_COMMAND = $oldFzfCommand
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

tm (Split-Path $PSCommandPath -Leaf)
