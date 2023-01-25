param
(
    $Path
)

# Spell-checker: disable
$resolved = Get-Item $path -Force -ea Ignore
$pictures = ".jpg", ".jpeg", ".bmp", ".gif", ".png", ".webp"
$markdown = ".md"
# Spell-checker: enable

if( -not $resolved )
{
    "Don't know how to render $path"
    return
}

if( $resolved -is [System.IO.DirectoryInfo] )
{
    $folder = Get-ChildItem -LiteralPath $path
    if( $folder )
    {
        $folder | ft -auto
    }
    else
    {
        ""
        "`tEmpty Directory: $resolved"
    }
    return
}

if( $resolved.Extension -in $pictures )
{
    chafa $path
    return
}

if( $resolved.Extension -in $markdown )
{
    glow -s dark $path
    return
}

& bat $path --color=always --plain
