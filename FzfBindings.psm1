# Test that all dependencies are satisfied
function SCRIPT:Assert-ToolInstalled( $name )
{
    if( -not (Get-Command $name -ea Ignore) )
    {
        throw "$name is needed, please install it first"
    }
}

Assert-ToolInstalled fzf
Assert-ToolInstalled bat
Assert-ToolInstalled chafa
Assert-ToolInstalled glow

$fzfVersion = (fzf --version) -split " " | select -f 1
$fzfMinVersion = "0.31"
if( [version]::Parse($fzfVersion) -lt $fzfMinVersion )
{
    throw "fzf version $fzfVersion installed, but at least $fzfMinVersion is needed, please update it first"
}

# Include all used files in the right order
. "$PSScriptRoot\Initialize-Vars.ps1"
. "$PSScriptRoot\Initialize-ShellFzf.ps1"
. "$PSScriptRoot\Initialize-PsReadLine.ps1"
. "$PSScriptRoot\Initialize-GitFzf.ps1"

# Set up aliases
Set-Alias hlp Show-Help
Set-Alias pf Show-PreviewFzf
Set-Alias startf Start-ProcessFzf
Set-Alias cdf Set-LocationFzf
Set-Alias killf Stop-ProcessFzf
Set-Alias pushf Push-LocationFzf
Set-Alias hf Invoke-HistoryFzf
Set-Alias codef Invoke-CodeFzf
Set-Alias rgf Search-RipgrepFzf