# Test that all dependencies are satisfied
if( -not (Get-Command 'fzf' -ErrorAction Ignore) )
{
    throw "fzf is needed, please install it first"
}

if( -not (Get-Command 'pwsh' -ErrorAction Ignore) )
{
    throw "pwsh is needed for fzf previews, please install it first"
}

if( -not (Get-Command 'bat' -ErrorAction Ignore) )
{
    Write-Warning "bat is needed for colorful previews, please install it first, preview functionality is would be limited"
}

if( -not (Get-Command 'rg' -ErrorAction Ignore) )
{
    Write-Warning "rg is needed, please install it first, text search would not work"
}

#Assert-ToolInstalled chafa -IsWarning
#Assert-ToolInstalled glow -IsWarning

