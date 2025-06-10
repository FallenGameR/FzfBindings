# Detected fzf version
$SCRIPT:fzfVersion = [version]((fzf --version) -split " " | select -f 1)

# If fzf is of a specific version, use the following options
function SCRIPT:Use-Version( [version] $minVersion, [string[]] $fzfOptions )
{
    if( $fzfVersion -lt $minVersion )
    {
        Write-Debug "fzf version $currentVersion installed, but at least $minVersion is needed, skipping options $fzfOptions"
        return
    }

    $fzfOptions
}

# Default FZF options
function SCRIPT:Get-DefaultFzfOptions
{
    "--layout=reverse"              # Grow list down, not upwards
    "--tabstop=4"                   # Standard tab size
    "--multi"                       # Multi select possible

    # Can't bind ctrl+arrows, but shift-left is backward-word
    "--bind"                        # Alt+t toggles selection
        "alt-t:toggle-all"
    "--bind"                        # Alt+q kills word
        "alt-q:backward-kill-word"

    "--cycle"                       # Cycle the list
    "--ansi"                        # Use Powershell colors
    "--tiebreak='length,index'"     # Priorities to resolve ties (index comes last always)

    "--color=bg:#0C0C0C"            # Background = Black
    "--color=bg+:#0C0C0C"           # Background (current line) = Black
    "--color=fg+:#F2F2F2"           # Text (current line) = White
    "--color=hl+:#13A10E"           # Highlighted substrings (current line) = DarkGreen
    "--color=pointer:#3A96DD"       # Pointer to the current line = DarkCyan
    "--color=preview-bg:#0C0C0C"    # Preview window background = Black
    "--color=prompt:#CCCCCC"        # Prompt = Gray

    #"--color=border:#RRGGBB"       # Border of the preview window and horizontal separators (--border)
    #"--color=gutter:#RRGGBB"       # Gutter on the left (defaults to bg+)
    #"--color=header:#RRGGBB"       # Header
    #"--color=info:#RRGGBB"         # Info
    #"--color=marker:#RRGGBB"       # Multi-select marker
    #"--color=preview-fg:#RRGGBB"   # Preview window text
    #"--color=spinner:#RRGGBB"      # Streaming input indicator

    Use-Version 0.42 "--info=right" # Show found element count on the right
    Use-Version 0.54 "--wrap",      # Don't show multiline entries
                     "--bind",      # Alt+t toggles wrap
                     "alt-w:toggle-wrap"
}

$env:FZF_DEFAULT_OPTS = (Get-DefaultFzfOptions) -join " "

if( Get-Command fd -ea Ignore )
{
    # -I needed to show up sln files on Alt+o
    $env:FZF_DEFAULT_COMMAND = 'fd -I --type f --color always'
}

# Shortcuts
if( Get-Command Register-Shortcut -ea Ignore )
{
    Register-Shortcut "Alt+h" "hf" "History search"
    Register-Shortcut "Alt+o" "startf" "Open file"
    Register-Shortcut "Alt+r" "rgf" "Ripgrep search"
    Register-Shortcut "Alt+k" "killf" "Kill process"
    Register-Shortcut "Alt+f" "codef" "Code to open file or directory"
    Register-Shortcut "Alt+d" "cdf" "Change directory"
    Register-Shortcut "Alt+u" "pushf" "Go up fuzzy"
    Register-Shortcut "Alt+s" "Select-GitBranch" "Switch to a git branch"
    Register-Shortcut "Alt+p" "Send-GitBranch" "Pull request for a git branch"
    Register-Shortcut "Alt+l" "Clear-GitBranch" "Clear a completed pull request for a git branch"
}
