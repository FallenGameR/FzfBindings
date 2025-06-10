# Test that all dependencies are satisfied
function SCRIPT:Assert-ToolInstalled( $name, [switch] $IsWarning )
{
    if( -not (Get-Command $name -ea Ignore) )
    {
        $info = "$name is needed, please install it first"

        if( $IsWarning )
        {
            Write-Warning "$info, some functionality would not work for now"
        }
        else
        {
            throw $info
        }
    }
}

Assert-ToolInstalled fzf
Assert-ToolInstalled pwsh
Assert-ToolInstalled bat -IsWarning
Assert-ToolInstalled rg -IsWarning
#Assert-ToolInstalled chafa -IsWarning
#Assert-ToolInstalled glow -IsWarning

# This variable would be used to call preview scripts
# Theoretically previews in classic Powershell could be faster if we don't call modern powershell
# from classic powershell. But then the preview scripts would need to be reworked as well
$SCRIPT:pwsh = "pwsh"

if( $PSVersionTable.Platform -ne "Unix" )
{
    # Cross platform way to call pwsh
    $SCRIPT:pwsh += ".exe"
}

# Include all used files
. "$PSScriptRoot\Defaults.ps1"
. "$PSScriptRoot\Utils.ps1"
. "$PSScriptRoot\Initialize-ShellFzf.ps1"
. "$PSScriptRoot\Initialize-GitFzf.ps1"

$fzfMinVersion = "0.31"
if( $SCRIPT:fzfVersion -lt $fzfMinVersion )
{
    throw "fzf version $fzfVersion installed, but at least $fzfMinVersion is needed, please update it first"
}

# Set up aliases
Set-Alias cdf Set-FzfLocation
Set-Alias clrf Clear-GitBranch
Set-Alias codef Invoke-FzfCode
Set-Alias cof Select-GitBranch
Set-Alias hf Invoke-FzfHistory
Set-Alias hlp Show-BatHelp
Set-Alias killf Stop-FzfProcess
Set-Alias pf Show-FzfFilePreview
Set-Alias prf Send-GitBranch
Set-Alias pushf Push-FzfLocation
Set-Alias rgf Search-FzfRipgrep
Set-Alias startf Start-FzfProcess
