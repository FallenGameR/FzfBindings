if( $args[0] -match "^(\S+)" ) { $branch = $matches[1] }
if( -not $branch ) { return }

# Init
"Branch " + "`e[36m" + $branch + "`e[0m"

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
    "`e[36m" + "# Log" + "`e[0m"
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
"`e[36m" + "# Iteration log" + "`e[0m"
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
"`e[36m" + "# Interation diff" + "`e[0m"
if( gcm delta )
{
    git --no-pager diff $diffStart $branch "--color=always" | delta
}
else
{
    git diff $diffStart $branch "--color=always"
}
