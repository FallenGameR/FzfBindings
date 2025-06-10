# Can't use Get-History here, this script is called from a separate process
# And that process may have been actually Powershell Classic v5

$id, $duration, $command = -split $args[0]

# PS5 would not have duration listed
if( $duration -notmatch "^\d+\.\d+$")
{
    $command = $duration
    $duration = ""
}

function SCRIPT:e { "`e[" + ($args -join ";") + "m" }

"$(e 32)ID:$(e 0) $id"

if( $duration )
{
    "$(e 32)Duration:$(e 0) $duration seconds"
}

"$(e 32)Command:$(e 0) $command"
