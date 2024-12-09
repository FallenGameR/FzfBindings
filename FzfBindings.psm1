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
Assert-ToolInstalled chafa -IsWarning
Assert-ToolInstalled glow -IsWarning

$fzfVersion = (fzf --version) -split " " | select -f 1
$fzfMinVersion = "0.31"
if( [version]::Parse($fzfVersion) -lt $fzfMinVersion )
{
    throw "fzf version $fzfVersion installed, but at least $fzfMinVersion is needed, please update it first"
}

# Cross platform way to call pwsh
$SCRIPT:pwsh = "pwsh"
if( $PSVersionTable.Platform -ne "Unix" ) { $SCRIPT:pwsh += ".exe" }

# Include all used files
. "$PSScriptRoot\Initialize-ShellFzf.ps1"
. "$PSScriptRoot\Initialize-GitFzf.ps1"

# Set up aliases
Set-Alias cdf Set-FzfLocation
Set-Alias clrf Clear-GitBranch
Set-Alias codef Invoke-CodeFzf
Set-Alias cof Select-GitBranch
Set-Alias hf Invoke-HistoryFzf
Set-Alias hlp Show-BatHelp
Set-Alias killf Stop-ProcessFzf
Set-Alias pf Show-FzfFilePreview
Set-Alias prf Send-GitBranch
Set-Alias pushf Push-LocationFzf
Set-Alias rgf Search-RipgrepFzf
Set-Alias startf Start-FzfProcess