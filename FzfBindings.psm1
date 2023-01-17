# Include all used files
#. "$PSScriptRoot\..."

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

# Setting up aliases
# Set-Alias ...