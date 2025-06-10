if( $PSVersionTable.PSVersion -ge 7 )
{
    $id, $duration, $command = -split $args[0]
}
else
{
    $id, $command = -split $args[0]
}

# Can't use Get-History here, this script is called from a separate process

function SCRIPT:e { "`e[" + ($args -join ";") + "m" }

"$(e 32)ID:$(e 0) $id"

if( $duration )
{
    "$(e 32)Duration:$(e 0) $duration seconds"
}

"$(e 32)Command:$(e 0) $command"
