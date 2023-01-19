# Test that all dependencies are satisfied
function SCRIPT:Assert-ToolInstalled( $name, [switch] $IsWarning )
{
    if( -not (Get-Command $name -ea Ignore) )
    {
        $info = "$name is needed, please install it first"

        if( $IsWarning )
        {
            Write-Warning "$info, although it is not critical"
        }
        else
        {
            throw $info
        }
    }
}

Assert-ToolInstalled fzf
Assert-ToolInstalled bat
Assert-ToolInstalled dust -IsWarning
Assert-ToolInstalled chafa -IsWarning
Assert-ToolInstalled glow -IsWarning

$fzfVersion = (fzf --version) -split " " | select -f 1
$fzfMinVersion = "0.31"
if( [version]::Parse($fzfVersion) -lt $fzfMinVersion )
{
    throw "fzf version $fzfVersion installed, but at least $fzfMinVersion is needed, please update it first"
}

# Include all used files in the right order
. "$PSScriptRoot\Initialize-Vars.ps1"       # Sets common variables, needs to go first
. "$PSScriptRoot\Initialize-ShellFzf.ps1"   # Older portion of the codebase, safer to place first
. "$PSScriptRoot\Initialize-GitFzf.ps1"     # Newer portion of the codebase, safer to place second

# Set up aliases
Set-Alias cdf Set-LocationFzf
Set-Alias clrf Clear-GitBranch
Set-Alias codef Invoke-CodeFzf
Set-Alias cof Select-GitBranch
Set-Alias hf Invoke-HistoryFzf
Set-Alias hlp Show-Help
Set-Alias killf Stop-ProcessFzf
Set-Alias pf Show-PreviewFzf
Set-Alias prf Send-GitBranch
Set-Alias pushf Push-LocationFzf
Set-Alias rgf Search-RipgrepFzf
Set-Alias startf Start-ProcessFzf