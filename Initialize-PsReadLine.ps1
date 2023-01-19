function SCRIPT:Register-Shortcut
{
    param
    (
        [Parameter(Mandatory)]
        $Key,
        [Parameter(Mandatory)]
        $Command,
        $Description
    )

    Set-PSReadlineKeyHandler `
        -Key $Key `
        -BriefDescription $Command `
        -LongDescription $Description `
        -ScriptBlock `
        {
            [Microsoft.Powershell.PSConsoleReadLine]::RevertLine()
            [Microsoft.Powershell.PSConsoleReadLine]::Insert($Command)
            [Microsoft.Powershell.PSConsoleReadLine]::AcceptLine()
        }.GetNewClosure()
}

Register-Shortcut "Alt+h" "hf" "History search"
Register-Shortcut "Alt+o" "startf" "Open file"
Register-Shortcut "Alt+r" "rgf" "Ripgrep search"
Register-Shortcut "Alt+k" "killf" "Kill process"
Register-Shortcut "Alt+f" "codef" "Code to open file or directory"
Register-Shortcut "Alt+v" "codef" "Code to open file or directory (shortcut from Vim"
Register-Shortcut "Alt+d" "cdf" "Change directory"
Register-Shortcut "Alt+u" "pushf" "Go up fuzzy"
Register-Shortcut "Alt+s" "Select-GitBranch" "Switch to a git branch"
Register-Shortcut "Alt+p" "Send-GitBranch" "Pull request for a git branch"
Register-Shortcut "Alt+l" "Clear-GitBranch" "Clear a completed pull request for a git branch"
