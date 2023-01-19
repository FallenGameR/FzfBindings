param
(
    $Path
)

$resolved = Get-Item $path -Force -ea Ignore
$pictures = Get-Content "$PsScriptRoot/../Data/picture_extensions"
$markdown = ".md"

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

        if( (gcm dust -ea Ignore) )
        {
            "`tSize: $resolved"
            ""
            dust -r -c $resolved
        }
    }
    else
    {
        ""
        "`tEmpty Directory: $resolved"
    }
    return
}

if( ($resolved.Extension -in $pictures) -and (gcm chafa -ea Ignore) )
{
    chafa $path
    return
}

if( ($resolved.Extension -in $markdown) -and (gcm glow -ea Ignore) )
{
    glow -s dark $path
    return
}

& bat $path --color=always --plain
