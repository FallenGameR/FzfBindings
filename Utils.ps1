function Use-Fzf
{
    [cmdletbinding()]
    param
    (
        [string[]] $Args,

        [Parameter(ValueFromPipeline = $true)]
        [object] $Item
    )

    begin
    {
        $pipeline = @()
        $startReloadCommandFallback = ""

        # All not supported arguments are removed or mitigated
        $args = @(for( $i = 0; $i -lt $args.Count; $i++ )
        {
            if( ($args[$i] -eq "--bind") -and
                ($args[$i+1] -match "^start:reload:(.+)$") -and
                ($SCRIPT:fzfVersion -lt 0.54) )
            {
                $startReloadCommandFallback = $matches[1]
                Write-Verbose "FZF start:reload mitigation for: $startReloadCommandFallback"
                $i += 1
                continue
            }

            if( ($args[$i] -eq "--preview-label") -and
                ($SCRIPT:fzfVersion -lt 0.35) )
            {
                Write-Verbose "FZF --preview-label $($args[$i+1]) skip"
                $i += 1
                continue
            }

            $args[$i]
        })

        Write-Verbose "FZF args: $args"
    }
    process
    {
        # Async processing coould be possible only if we do [Process]::Start
        $pipeline += $item
    }
    end
    {
        try
        {
            if( $startReloadCommandFallback )
            {
                $preserved = $env:FZF_DEFAULT_COMMAND
                $env:FZF_DEFAULT_COMMAND = $startReloadCommandFallback
            }

            if( $pipeline )
            {
                $pipeline | fzf @Args
            }
            else
            {
                fzf @Args
            }
        }
        finally
        {
            if( $startReloadCommandFallback )
            {
                $env:FZF_DEFAULT_COMMAND = $preserved
            }

            Repair-ConsoleMode
        }
    }
}

function Initialize-FzfArgs
{
    param
    (
        [string] $Query,
        [switch] $FilePreview,
        [switch] $BranchPreview,
        [switch] $ProcessPreview
    )

    # Optional pre-populated fzf query string
    if( $Query )
    {
        "--query"
        $Query
    }

    # Preview engine
    if( $FilePreview )
    {
        Use-Version 0.35 "--preview-label", "File Entry"
        "--preview"
        "$pwsh -nop -f ""$PSScriptRoot/Preview/Show-FileEntry.ps1"" {}"

        # Height parameter is a workaround for fzf bug https://github.com/junegunn/fzf/issues/4399
        # It forces fzf to use a different preview engine, the one that supports sixels
        # Older fzf versions do not support negative height
        # and likelly don't know about sixels (it was confirmed on 0.34)
        Use-Version 0.56 "--height=-1"
    }

    if( $BranchPreview )
    {
        Use-Version 0.35 "--preview-label", "Branch"

        "--header-lines=2"
        "--preview"
        "$pwsh -nop -f ""$PSScriptRoot/Preview/Show-GitBranch.ps1"" {}"
    }

    if( $ProcessPreview )
    {
        Use-Version 0.35 "--preview-label", "Process"

        "--header-lines=2"
        "--preview"
        "$pwsh -nop -f ""$PSScriptRoot/Preview/Show-Process.ps1"" {}"
    }

    # Preview defaults
    "--preview-window=right,55%"
    "--color=preview-bg:#222222"
    "--padding=1%"
    "--border=rounded"
    Use-Version 0.54 "--bind=alt-w:toggle-wrap"

    # Preview size changes need to be compatible with different terminals:
    # - VS code does not work with Alt+arrow
    # - Windows terminal doesn't work with Alt+Shift+arrow
    $mod = if( (Get-Process -id $pid).Parent.Name -eq "Code" ) { "-shift" } else { "" }
    "--bind=alt-p:change-preview-window(down|right)"
    "--bind=alt$mod-up:change-preview-window(down,65%|down,75%|down,85%|down,35%|down,45%|down,55%)"
    "--bind=alt$mod-down:change-preview-window(down,45%|down,35%|down,85%|down,75%|down,65%|down,55%)"
    "--bind=alt$mod-left:change-preview-window(right,65%|right,75%|right,85%|right,35%|right,45%|right,55%)"
    "--bind=alt$mod-right:change-preview-window(right,45%|right,35%|right,85%|right,75%|right,65%|right,55%)"
}

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