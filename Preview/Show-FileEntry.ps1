param( $Path )

# https://gist.github.com/fnky/458719343aabd01cfb17a3a4f7296797
# https://duffney.io/usingansiescapesequencespowershell/
function SCRIPT:e { "`e[" + ($args -join ";") + "m" }

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
    "Directory $(e 36)$resolved$(e 0)"

    $folder = Get-ChildItem -LiteralPath $path
    if( $folder )
    {
        $stylePreserved = $PSStyle.OutputRendering
        $PSStyle.OutputRendering = "Ansi"
        $rendered = $folder | ft -auto | Out-String
        $PSStyle.OutputRendering = $stylePreserved

        "`n$(e 36)# Contents$(e 0)`n"
        $rendered -split [environment]::NewLine | where{ $psitem } | select -skip 1
    }
    else
    {
        "Is empty"
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
