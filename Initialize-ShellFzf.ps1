function Show-BatHelp
{
    <#
    .SYNOPSIS
        Show colorized via bat help for a native command (hlp)

    .PARAMETER Path
        (Optional) Path to the native executable. In this mode --help will be
        called and STDOUT and STDERR will be merged.

    .PARAMETER InputObject
        (Optional) Help text to render. In this mode just pipe in the help text.

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
        # First mode - try to call --help for a native command that usually uses STDERR for output
        if( $path )
        {
            & $path --help 2>&1 | Show-BatHelp
            return
        }

        # Second mode - treat any input as help text
        $accumulator = @()
    }
    process
    {
        $accumulator += $psitem
    }
    end
    {
        $accumulator | bat -pl help
    }
}

function Get-FzfFilePreviewArgs
{
    # Compatiblity with different terminals:
    # - VS code does not work with Alt+arrow
    # - Windows terminal doesn't work with Alt+Shift+arrow
    $mod = if( (Get-Process -id $pid).Parent.Name -eq "Code" ) { "-shift" } else { "" }

    "--padding=1%",
    "--border=rounded",
    "--preview", "$pwsh -nop -f ""$PSScriptRoot/Preview/Show-FileEntry.ps1"" {}",
    "--preview-window=right,55%",
    "--bind=alt-w:toggle-wrap",
    "--bind=alt-p:change-preview-window(down|right)",
    "--bind=alt$mod-up:change-preview-window(down,65%|down,75%|down,85%|down,35%|down,45%|down,55%)",
    "--bind=alt$mod-down:change-preview-window(down,45%|down,35%|down,85%|down,75%|down,65%|down,55%)",
    "--bind=alt$mod-left:change-preview-window(right,65%|right,75%|right,85%|right,35%|right,45%|right,55%)",
    "--bind=alt$mod-right:change-preview-window(right,45%|right,35%|right,85%|right,75%|right,65%|right,55%)",
    "--color=preview-bg:#222222"
}

function Show-FzfFilePreview
{
    <#
    .SYNOPSIS
        Preview piped in files with fzf (pf)

    .DESCRIPTION
        This command will not pipe the input to the fzf until all
        the input would be collected. That is important for huge inputs.

        If you want async fast output your would need to fzf directly
        and maybe to combine it with walker as it is done in cdf and CodeF.

    .EXAMPLE
        ls | % FullName | pf
    #>

    try{ $input | fzf @(Get-FzfFilePreviewArgs) }
    finally{ Repair-ConsoleMode }
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

    param
    (
        [string] $Path
    )

    $fzfArgs = @()
    if( $Path )
    {
        $fzfArgs += "-q"
        $fzfArgs += $Path
    }

    $destination = try{ fzf @fzfArgs } finally { Repair-ConsoleMode }
    $destination

    if( $destination )
    {
        # Shell start is different on Unix and Windows
        if( $PSVersionTable.Platform -eq "Unix" )
        {
            & $destination
        }
        else
        {
            start $destination
        }
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

    param
    (
        [string] $Path,
        [switch] $Hidden,
        [switch] $NoIgnore
    )

    $fzfArgs = Get-FzfFilePreviewArgs

    if( $path )
    {
        $fzfArgs += "-q"
        $fzfArgs += $path
    }

    $fzfPreserved = $env:FZF_DEFAULT_COMMAND
    $env:FZF_DEFAULT_COMMAND = "$pwsh -nop -f ""$PSScriptRoot/Walk/Get-Folder.ps1"""
    if( $Hidden ) { $env:FZF_DEFAULT_COMMAND += " -Hidden" }
    if( $NoIgnore ) { $env:FZF_DEFAULT_COMMAND += " -NoIgnore" }
    try { $destination = @(fzf @fzfArgs) }
    finally { $env:FZF_DEFAULT_COMMAND = $fzfPreserved; Repair-ConsoleMode }
    $destination

    if( $destination.Length -eq 1 )
    {
        cd $destination[0]
    }
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

    $lines = try{ gps | fzf @fzfArgs } finally { Repair-ConsoleMode }
    if( -not $lines ) { return }

    $lines | foreach{
        $split = $psitem -split "\s+" | where{ $psitem }
        $id = $split[4]
        Stop-Process -Id $id -Verbose -ea Ignore
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

    $path = Get-DirectoryStack | Sort-Object -desc | Show-FzfFilePreview
    if( $path )
    {
        pushd $path
    }
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

    trap { Repair-ConsoleMode }

    # Get history reversed
    $commands = @(Get-History)
    [array]::Reverse($commands)

    # Select commands to execute with fzf
    $text = ($commands | Out-String) -split [Environment]::NewLine | select -Skip 3
    $result = try{ $text | fzf } finally { Repair-ConsoleMode }

    if( $result )
    {
        $ids = $result | where{ $psitem -match "^\s*(\d+)" } | foreach{ [int] $matches[1] }
        $toExecute = $commands | where Id -in $ids
        $command = $toExecute.CommandLine -join "; "

        Clear-Host
        $command
        Invoke-Expression $command
    }

    Repair-ConsoleMode
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
            $fzfArgs = Get-FzfFilePreviewArgs
            $fzfPreserved = $env:FZF_DEFAULT_COMMAND
            $env:FZF_DEFAULT_COMMAND = "$pwsh -nop -f ""$PSScriptRoot/Walk/Get-FileEntry.ps1"""
            try { $paths = @(fzf @fzfArgs) }
            finally { $env:FZF_DEFAULT_COMMAND = $fzfPreserved; Repair-ConsoleMode }
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

    trap { Repair-ConsoleMode }

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

    if( $Hidden )
    {
        $rg += "--hidden "
    }

    if( $NoIgnore )
    {
        $rg += "--no-ignore "
    }

    $fzfPreserved = $env:FZF_DEFAULT_COMMAND
    $env:FZF_DEFAULT_COMMAND = "$rg ""$Query"""

    <#
    $env:RELOAD='reload:(rg --column --color=always --smart-case {q} || exit 0)'
    fzf --disabled --ansi `
        --bind "start:$env:RELOAD" --bind "change:$env:RELOAD"`
        --delimiter ":" `
        --preview 'bat -n --color=always --highlight-line {2} {1} --terminal-width %FZF_PREVIEW_COLUMNS%' `
        --bind "alt-p:change-preview-window(right|down)" `
        --preview-window '~4,+{2}+4/3,down' `
        --bind 'ctrl-o:execute-silent:code {1}'
    #>

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
            --bind "alt-p:change-preview-window(down|hidden|)" `
            --prompt "rg> " `
            --delimiter ":" `
            --tiebreak "begin,length" `
            --header '<ALT-R: rg> <ALT-F: fzf>' `
            --preview 'bat --color=always {1} --highlight-line {2}' `
            --preview-window 'up,border-bottom,+{2}/3,~3'
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

    Repair-ConsoleMode
}

function Repair-ConsoleMode
{
    <#
    .SYNOPSIS
        fzf sets DISABLE_NEWLINE_AUTO_RETURN console mode flag that breaks the console.
        This command can be used to restore the correct console mode.

    .NOTES
        https://github.com/junegunn/fzf/issues/3334
    #>

    $GetStdHandle = '[DllImport("kernel32.dll", SetLastError = true)] public static extern IntPtr GetStdHandle(int nStdHandle);'
    $GetConsoleMode = '[DllImport("kernel32.dll", SetLastError = true)] public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);'
    $SetConsoleMode = '[DllImport("kernel32.dll", SetLastError = true)] public static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint lpMode);'
    $Kernel32 = Add-Type `
        -Name 'Kernel32' `
        -Namespace 'Win32' `
        -PassThru `
        -MemberDefinition "$GetStdHandle $GetConsoleMode $SetConsoleMode"

    [UInt32] $mode = 0
    $Kernel32::GetConsoleMode($Kernel32::GetStdHandle(-11), [ref]$mode) | Out-Null

    $DISABLE_NEWLINE_AUTO_RETURN = 0x8
    $mode = $mode -band (-bnot $DISABLE_NEWLINE_AUTO_RETURN)
    $Kernel32::SetConsoleMode($Kernel32::GetStdHandle(-11), $mode) | Out-Null
}