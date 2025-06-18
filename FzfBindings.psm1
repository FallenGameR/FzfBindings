# This variable would be used to call preview scripts
# Theoretically previews in classic Powershell could be faster if we don't call modern powershell
# from classic powershell. But then the preview scripts would need to be reworked as well
$SCRIPT:pwsh = "pwsh"

if( $PSVersionTable.Platform -ne "Unix" )
{
    # Cross platform way to call pwsh
    $SCRIPT:pwsh += ".exe"
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
Set-Alias pushf Push-FzfLocation
Set-Alias rgf Search-FzfRipgrep
Set-Alias startf Start-FzfProcess

# Nested modules
. $PSScriptRoot\Defaults.ps1
. $PSScriptRoot\Utils.ps1
. $PSScriptRoot\Git.ps1
. $PSScriptRoot\Shell.ps1
