if( $args[0] -match "^(\S+)" ) { $branch = $matches[1] }
if( -not $branch ) { return }

function SCRIPT:e { "`e[" + ($args -join ";") + "m" }

# Init
"Branch $(e 36)$branch$(e 0)"

# Fast preview - leave only this if calling anything else additionally is slow
#""
#git show --color=always $branch
#return

# Affects - very slow
#$affects = Get-GitBranch | where Branch -eq $branch | foreach Affects
#if( $affects )
#{
#    "Affects: $(e 36)$affects$(e 0)"
#}

$master = Resolve-GitMasterBranch
$prBranch = git branch --remotes --list branch "origin/dev/$env:USERNAME/$branch" | % trim
if( $prBranch )
{
    $isSameCommit = (git rev-parse --verify $branch) -eq (git rev-parse --verify $prBranch)
    if( $isSameCommit ) { $prBranch = $null }
}
$logParams = @(
    "--color=always",
    "--graph",
    "--pretty=format:%C(reset)%C(yellow)%h%C(reset) -%C(bold yellow)%d%C(reset) %s %C(green)(%cr) %C(cyan)<%an>%C(reset)",
    "--abbrev-commit",
    "--date=relative",
    "--first-parent"
)

# Master branch
if( $branch -eq $master )
{
    "`n$(e 36)# Log$(e 0)`n"
    $param = @("log", $branch, "-40", $logParams)
    git @param
    return
}

# Output latest unpublished PR iteration
if( $prBranch )
{
    $diffStart = $prBranch

    "`n$(e 36)# Commits since last PR in $prBranch$(e 0)`n"
    $param = @("log", "$diffStart..$branch", "-10", $logParams)
    git @param

    "`n`n$(e 36)# Diff since last PR in $prBranch$(e 0)"
    if( gcm delta )
    {
        # for some reason delta is not picked up by default
        git --no-pager diff $diffStart $branch "--color=always" | delta
    }
    else
    {
        git diff $diffStart $branch "--color=always"
    }
}

# Output completelly unpublished PR
"`n$(e 36)# Commits since origin/master$(e 0)`n"
$diffStart = git merge-base $branch "origin/$master"
$param = @("log", "$diffStart..$branch", "-10", $logParams)
git @param

"`n`n$(e 36)# Diff since origin/master$(e 0)"
if( gcm delta )
{
    # for some reason delta is not picked up by default
    git --no-pager diff $diffStart $branch "--color=always" | delta
}
else
{
    git diff $diffStart $branch "--color=always"
}
