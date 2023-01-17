if( $args[0] -match "^(\S+)" ) { $branch = $matches[1] }
if( -not $branch ) { return }

# https://gist.github.com/fnky/458719343aabd01cfb17a3a4f7296797
# https://duffney.io/usingansiescapesequencespowershell/
function SCRIPT:e { "`e[" + ($args -join ";") + "m" }

# Init
"Branch $(e 36m)$branch$(e 0)"

$prBranch = git branch --remotes --list branch "origin/dev/$env:USERNAME/$branch" | % trim
if( $prBranch )
{
    $isSameCommit = (git rev-parse --verify $branch) -eq (git rev-parse --verify $prBranch)
    if( $isSameCommit ) { $prBranch = $null }
}
$diffStart = if( $prBranch ) { $prBranch } else { git merge-base $branch "origin/master" }

# Master branch
if( $branch -eq "master" )
{
    ""
    "$(e 36)# Log$(e 0)"
    ""

    $param = @(
        "log",
        $branch
        "--color=always",
        "-100",
        "--graph",
        "--pretty=format:%C(reset)%C(yellow)%h%C(reset) -%C(bold yellow)%d%C(reset) %s %C(green)(%cr) %C(cyan)<%an>%C(reset)",
        "--abbrev-commit",
        "--date=relative"
    )
    git @param
    return
}

# Log output
""
"$(e 36)# Iteration log$(e 0)"
""
$param = @(
    "log",
    "--color=always",
    "$diffStart..$branch",
    "--graph",
    "--pretty=format:%C(reset)%C(yellow)%h%C(reset) -%C(bold yellow)%d%C(reset) %s %C(green)(%cr) %C(cyan)<%an>%C(reset)",
    "--abbrev-commit",
    "--date=relative"
)
git @param

# Diff, for some reason delta is not picked up by default
""
""
"$(e 36)# Interation diff$(e 0)"
if( gcm delta )
{
    git --no-pager diff $diffStart $branch "--color=always" | delta
}
else
{
    git diff $diffStart $branch "--color=always"
}
