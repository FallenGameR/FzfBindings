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
    Write-Warning "bat is needed for colorful previews, file previews would be limited"
}

if( -not (Get-Command 'delta' -ErrorAction Ignore) )
{
    Write-Warning "delta is needed, please install it first, git diff preview would be limited"
}

if( -not (Get-Command 'rg' -ErrorAction Ignore) )
{
    Write-Warning "rg is needed, please install it first, text search would not work"
}

if( -not (Get-Command 'chafa' -ErrorAction Ignore) )
{
    Write-Warning "chafa is needed, please install it first, image previews would not work"
}

if( -not (Get-Command 'glow' -ErrorAction Ignore) )
{
    Write-Warning "glow is needed, please install it first, markdown previews would be limited"
}
