# Clear-GitBranch or Select-GitBranch messes up with the prompt

function Get-GitBranch( [switch] $Raw )
{
    $names = git for-each-ref --format "%(refname:short)" refs/heads/
    $master = Resolve-GitMasterBranch
    $current = Resolve-GitBranch "HEAD"

    $itemes = foreach( $name in $names )
    {
        $prBranch = git branch --remotes --list branch "origin/dev/$env:USERNAME/$name" | % trim

        # %cr is committer date, relative, e.g. "2 weeks ago"
        # %ci is committer date, ISO 8601-like format, e.g. "2020-04-20 14:00:00 +0200"
        $relative, $absolute = (git log $name -1 --pretty=format:'%cr#%ci') -split "#"

        $properties = [ordered] @{
            Name = $name
            Current = $name -eq $current
            Remote = ([bool] $prBranch) -and ($name -ne $master)
            Upstream = Resolve-GitBranch "$name@{upstream}"
            RelativeDate = $relative -replace " ago", ""
            AbsoluteDate = [datetimeoffset]::Parse($absolute)
        }

        New-Object -TypeName PSObject -Property $properties
    }

    # No refining for the raw output
    if( $Raw )
    {
        return $itemes
    }

    # Refine the branches
    $master = Resolve-GitBranch "$master@{upstream}"

    function Get-Status( $branch )
    {
        $elements = @()
        if( $branch.Remote ) { $elements += "ADO" }
        if( $branch.Upstream -and ($branch.Upstream -ne $master) ) { $elements += "-> $($branch.Upstream)" }
        return $elements -join " "
    }

    $itemesReadable = $itemes | select `
        @{ Label = "Branch"; Expression = { if( $_.Current ) { "$($psitem.Name) *" } else { $psitem.Name } } },
        @{ Label = "Status"; Expression = { Get-Status $psitem } },
        @{ Label = "Freshness"; Expression = { $psitem.RelativeDate } },
        @{ Label = "AbsoluteDate"; Expression = { $psitem.AbsoluteDate } }

    $sort =
        @{ Expression = "AbsoluteDate"; Descending = $true },
        @{ Expression = "Name"; Descending = $false }

    $itemesReadable | sort $sort | select Branch, Status, Freshness
}

function Select-GitBranch( $name )
{
    trap { Write-Progress "Branch selection" -Completed }

    Write-Progress "Branch selection" "Check git status"
    Assert-GitEmptyStatus

    Write-Progress "Branch selection" "Getting branches"
    $branches = Get-GitBranch
    if( -not $branches ) { return }

    $selected = $branches | Select-FzfGitBranch Branch $name | select -f 1
    if( -not $selected ) { return }

    Write-Progress "Branch selection" "Checking out branch $($selected.Branch)"
    $current = Resolve-GitBranch "HEAD"
    if( $selected.Branch -ne $current )
    {
        Update-GitCheckoutBranch $selected.Branch
        Assert-GitEmptyStatus
    }
    else
    {
        "Already on branch $current"
    }
}

function Resolve-GitMasterBranch
{
    if( git rev-parse --verify "master" 2>$null )
    {
        return "master"
    }

    if( git rev-parse --verify "main" 2>$null )
    {
        return "main"
    }

    throw "Unknown master branch name"
}

function Clear-GitBranch( $name, [switch] $Force )
{
    trap
    {
        Repair-ConsoleMode
        Write-Progress "PR cleanup" -Completed
    }

    Write-Progress "PR cleanup" "Check git status"
    Assert-GitEmptyStatus
    $master = Resolve-GitMasterBranch

    Write-Progress "PR cleanup" "Getting branches"
    $branches = Get-GitBranch
    $current = $branches | where Current

    Write-Progress "PR cleanup" "Branch selection"
    if( -not $branches ) { return }
    $selected = $branches | Select-FzfGitBranch Branch $name | foreach Branch
    $selected = @($branches | where{ $psitem.Branch -in $selected })
    if( -not $selected ) { return }

    # Work from the latest master
    Write-Progress "PR cleanup" "Updating master"
    Assert-GitCleanMaster
    Update-GitCheckoutBranch $master
    Assert-GitEmptyStatus
    Update-GitPull
    Assert-GitEmptyStatus

    # Clear the branches
    $toDelete = @()
    Write-Progress "PR cleanup" "Clear the branches"
    foreach( $item in $selected )
    {
        Write-Progress "PR cleanup" "'$($item.Branch)' branch, temp merge with master to make sure PR was fully merged"
        Update-GitCheckoutBranch $item.Branch
        Update-GitMerge $master

        Write-Progress "PR cleanup" "'$($item.Branch)' branch, testing the merge commit"
        $extraChanges = git diff head..head^2
        if( $extraChanges )
        {
            Write-Progress "PR cleanup" "'$($item.Branch)' branch, reverting due to extra changes"
            Update-GitReset "head~1"
            Write-Progress "PR cleanup" "'$($item.Branch)' branch reverted, there are extra changes in it that were not present in master. PR was not completed."
            continue
        }

        $toDelete += $item.Branch
    }

    # Go back to the current branch if it was not deleted or to master
    $returnToBranch = $current.Branch
    if( -not $returnToBranch ) { $returnToBranch = $master }
    if( $returnToBranch -in $toDelete ) { $returnToBranch = $master }
    Write-Progress "PR cleanup" "Restoring $returnToBranch branch"
    Update-GitCheckoutBranch $returnToBranch
    Write-Progress "PR cleanup" "Restored $returnToBranch branch"

    # Safe branch deletion
    Write-Progress "PR cleanup" "Safe branch deletion"
    foreach( $branch in $toDelete )
    {
        Remove-GitBranch $branch
        Write-Progress "PR cleanup" "Safe deleted '$branch'"
    }
}

function SCRIPT:Select-FzfGitBranch( $key, $fzfFilter )
{
    $objects = @($input)

    $selected =
        $objects |
        Format-Table -auto |
        Out-String |
        foreach Trim |
        Use-Fzf (Initialize-FzfArgs $fzfFilter -BranchPreview)

    $selected |
        where{ $psitem -match "^(\S+)"} |
        foreach{ $matches[1]} |
        foreach{ $value = $psitem; $objects | where{ $psitem.$key -eq $value } }
}

function SCRIPT:Assert-GitEmptyStatus
{
    # Check if status is empty
    git diff --quiet 2>$null
    if( -not $LASTEXITCODE ){ return }

    # Detect if there is some unresettable whitespace changes
    git diff -w --quiet 2>$null
    if( $LASTEXITCODE ) { throw "Git status is not empty, please clean it first" }

    # Ignore the whitespace changes
    git status --porcelain |
        where{ $psitem -match "^\s*M\s+(?<path>.+)$" } |
        foreach{ $env:FZF_BINDINGS_GIT_LINE_ENDINGS_MITIGATION += ";$($Matches["path"])" }
    Update-GitLineEndingsMitigation

    # Check if status is empty
    git diff --quiet 2>$null
    if( $LASTEXITCODE ) { throw "Git status is not empty, please clean it first" }
}

function SCRIPT:Assert-GitCleanMaster
{
    $master = Resolve-GitMasterBranch

    # There is no user commit in master. Meaning master is reachable from origin/master
    # that may went ahead through previous fetch that left master as is.
    git merge-base $master --is-ancestor "origin/$master"

    if( $LASTEXITCODE -ne 0 )
    {
        throw "Git $master needs to be clean, it must be reachable from origin/$master"
    }
}

function SCRIPT:Remove-GitBranch( $name )
{
    git branch -D $name *> $null
    if( $LASTEXITCODE ) { throw "Could not complete wihtout errors 'git branch -D $name" }
}

function SCRIPT:Resolve-GitBranch( $reference )
{
    git rev-parse --symbolic-full-name --abbrev-ref $reference 2>$null
}

function SCRIPT:Test-GitPointAtSameCommit( $first, $second )
{
    (git rev-parse --verify $first) -eq (git rev-parse --verify $second)
}

function SCRIPT:Update-GitCheckoutBranch( $name )
{
    Write-Debug "git checkout $name"
    git checkout $name *> $null
    if( $LASTEXITCODE ) { throw "Could not complete wihtout errors 'git checkout $name'" }

    Update-GitLineEndingsMitigation
}

function SCRIPT:Update-GitMerge( $name )
{
    Write-Debug "git merge $name -X theirs"
    git merge $name -X theirs *> $null
    if( $LASTEXITCODE ) { throw "Could not complete wihtout errors 'git merge $name" }
}

function SCRIPT:Update-GitPull
{
    Write-Debug "git pull"
    git pull
    if( $LASTEXITCODE -notin @(0,128) ) { throw "Could not complete wihtout errors 'git pull" }
}

function SCRIPT:Update-GitPush( $spec )
{
    Write-Debug "git push origin $spec"
    git push origin $spec *> $null
    if( $LASTEXITCODE ) { throw "Could not complete wihtout errors 'git push origin $spec" }
}

function SCRIPT:Update-GitReset( $name )
{
    Write-Debug "git reset --hard $name"
    git reset --hard $name *> $null
    if( $LASTEXITCODE ) { throw "Could not complete wihtout errors 'git reset --hard $name" }
}

function Update-GitLineEndingsMitigation
{
    if( -not $env:FZF_BINDINGS_GIT_LINE_ENDINGS_MITIGATION ) { return }

    # Line endings issue that would not go away until the problem will be fixed for good:
    # https://www.aleksandrhovhannisyan.com/blog/crlf-vs-lf-normalizing-line-endings-in-git/
    # https://developercommunity.visualstudio.com/t/git-undo-changes-on-files-that-differ-only-in-crlf/221309
    $paths = $env:FZF_BINDINGS_GIT_LINE_ENDINGS_MITIGATION -split ";"
    $root = git rev-parse --show-toplevel
    foreach( $path in $paths )
    {
        $path = Get-Item (Join-Path $root $path) -ea Ignore | % FullName
        if( $path )
        {
            Write-Debug "git update-index --assume-unchanged $path"
            git update-index --assume-unchanged $path 2>$null
        }
    }
}