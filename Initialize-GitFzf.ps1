# Clear-GitBranch or Select-GitBranch messes up with the prompt

function Get-GitBranch
{
    $names = git for-each-ref --format "%(refname:short)" refs/heads/
    $master = Resolve-GitMasterBranch
    $current = Resolve-GitBranch "HEAD"

    $itemes = foreach( $name in $names )
    {
        $prBranch = git branch --remotes --list branch "origin/dev/$env:USERNAME/$name" | % trim

        # Not sure if it is needed anymore
        $contains = @($names |
            where{ $psitem -notmatch "(^$name|$master)$" } |
            where{ git merge-base $psitem --is-ancestor $name; $LASTEXITCODE -eq 0 } )

        $affects = @($names |
        where{ $psitem -notmatch "(^$name|$master)$" } |
        where{
            $base = git merge-base $psitem $name
            git merge-base $base --is-ancestor $master
            $LASTEXITCODE -eq 1
        })

        # %cr is committer date, relative, e.g. "2 weeks ago"
        # %ci is committer date, ISO 8601-like format, e.g. "2020-04-20 14:00:00 +0200"
        $relative, $absolute = (git log $name -1 --pretty=format:'%cr#%ci') -split "#"

        $properties = [ordered] @{
            Name = $name
            IsCurrent = $name -eq $current
            WasPullRequestSent = [bool] $prBranch
            HasUnreviewedChanges = $prBranch -and (-not (Test-GitPointAtSameCommit $name $prBranch))
            ContainsBranches = $contains
            AffectsBranches = $affects
            UpstreamBranch = Resolve-GitBranch "$name@{upstream}"
            PullRequestStatus = "Unknown"
            RelativeDate = $relative -replace " ago", ""
            AbsoluteDate = [datetimeoffset]::Parse($absolute)
        }

        $properties.PullRequestStatus =
            if( $name -match "^(master|main)$" ) { "PR None" }
            elseif( $properties.AffectsBranches ) { "PR Blocked" }
            elseif( $properties.WasPullRequestSent )
            {
                if( $properties.HasUnreviewedChanges ) { "PR Update" }
                else { "PR Exists" }
            }
            else { "PR Create" }

        New-Object -TypeName PSObject -Property $properties
    }

    $itemes
}
function Get-GitPrBranch
{
    $itemes = Get-GitBranch

    $itemesReadable = $itemes | select `
        @{ Label = "Branch"; Expression = { $psitem.Name } },
        @{ Label = "Status"; Expression = { $psitem.PullRequestStatus } },
        @{ Label = "Freshness"; Expression = { $psitem.RelativeDate } },
        @{ Label = "Affects"; Expression = { $psitem.AffectsBranches } },
        @{ Label = "AbsoluteDate"; Expression = { $psitem.AbsoluteDate } }

    $sort =
        @{ Expression = "AbsoluteDate"; Descending = $true },
        @{ Expression = "Status"; Descending = $true },
        @{ Expression = "Name"; Descending = $false }

    $itemesReadable | sort $sort | select Branch, Status, Freshness, Affects
}

function Select-GitBranch( $name )
{
    trap
    {
        Repair-ConsoleMode
        Write-Progress "Branch selection" -Completed
    }

    Write-Progress "Branch selection" "Check git status"
    Assert-GitEmptyStatus

    Write-Progress "Branch selection" "Getting branches"
    $branches = Get-GitPrBranch | select Branch, Freshness, Status
    if( -not $branches ) { return }

    $selected = $branches | Select-GitBranchFzf Branch $name | select -f 1
    if( -not $selected )
    {
        # Sometimes fzf messes up the console mode
        Repair-ConsoleMode
        return
    }

    Write-Progress "Branch selection" "Checking out branch $($selected.Branch)"
    $current = Resolve-GitBranch "HEAD"
    if( $selected.Branch -ne $current )
    {
        Update-GitCheckoutBranch $selected.Branch
    }
    else
    {
        "Already on branch $current"
    }

    # Sometimes fzf messes up the console mode
    Repair-ConsoleMode
}

function Send-GitBranch( $name, [switch] $Force )
{
    trap
    {
        Write-Progress "PR creation" -Completed
    }

    Write-Progress "PR creation" "Check git status"
    Assert-GitEmptyStatus

    Write-Progress "PR creation" "Getting branches"
    $status = "Create|Update"
    if( $forced ) { $status = "$status|Blocked" }
    $branches = Get-GitPrBranch | where Status -Match $status

    Write-Progress "PR creation" "Branch selection"
    if( -not $branches ) { return }
    $selected = $branches | Select-GitBranchFzf Branch $name
    if( -not $selected ) { return }

    Write-Progress "PR creation" "Branch verification"
    $created = @($selected | where Status -Match "Create")
    if( $created.Length -gt 1 ) { throw "It is possible to create only one PR at a time. Please send PRs for $(($created | % Branch) -join ',') separatelly"}

    Write-Progress "PR creation" "Branch send to origin"
    foreach( $item in $selected )
    {
        Write-Progress "PR creation" "$($item.Branch) branch, pushing branch to origin"
        Update-GitPush "$($item.Branch):dev/$env:username/$($item.Branch)"
    }

    if( $created )
    {
        Write-Progress "PR creation" "$($created.Branch) branch, opening browser to annotate PR"
        $url = $env:FZF_BINDINGS_PR_URL
        if( -not $url )
        {
            $url = git config --get remote.origin.url
        }
        start $url
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
    # Create is needed since in some cases we compelted PR and there is is no local mention of the remove branch
    $status = "Create|Exists"
    if( $force ) { $status = "$status|Blocked" }
    $branches = Get-GitPrBranch | where Status -Match $status
    # Current branch can be null if we didn't select it
    $current = $branches | where IsCurrent

    Write-Progress "PR cleanup" "Branch selection"
    if( -not $branches ) { return }
    $selected = $branches | Select-GitBranchFzf Branch $name
    if( -not $selected )
    {
        Repair-ConsoleMode
        return
    }

    Write-Progress "PR cleanup" "Branch verification"
    $sent = @($selected | foreach Branch)
    $affected = @($selected | foreach{ $psitem.Affects })
    $conflicts = Compare-Object $sent $affected -PassThru -IncludeEqual -ExcludeDifferent
    if( $conflicts ) { throw "Selected combination of branches conflicts in shared changes: $($conflicts -join ','). Please clear branches separetelly." }

    # Work from the latest master
    Write-Progress "PR cleanup" "Updating master"
    Assert-GitCleanMaster
    Update-GitCheckoutBranch $master
    Update-GitPull

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

        foreach( $affected in $item.Affects )
        {
            Write-Progress "PR cleanup" "'$($item.Branch)' branch, updating affected branch $affected"
            Update-GitCheckoutBranch $affected
            Update-GitMerge $item.Branch
            Write-Progress "PR cleanup" "'$($item.Branch)' branch, update of affected branch $affected done"
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

    # Sometimes fzf messes up the console mode
    Repair-ConsoleMode
}

function SCRIPT:Select-GitBranchFzf( $key, $fzfFilter, $header = 2 )
{
    # NOTE: it looks like this call ocasionally messes up the CR symbols in the terminal
    # is caused by preview? There is no FZF_COMMAND replacement here.
    $fzfArgs = @()

    # Main view, in adding to default args
    $fzfArgs += "--header-lines=$header"    # Table header
    $fzfArgs += "--info=hidden"             # Finder info style
    $fzfArgs += "--multi"                   # Allow multi selection

    # Pre view
    $fzfArgs += "--margin", "1%"            # To set some borders
    $fzfArgs += "--padding", "1%"           # To set some borders
    $fzfArgs += "--border"                  # To set some borders
    $fzfArgs += "--keep-right"              # Preview to the right
    $fzfArgs += "--preview", "$pwsh -nop -f ""$PSScriptRoot/Preview/Show-GitBranch.ps1"" {}"
    $fzfArgs += "--preview-window=60%"      # Preview size

    # fzf filter
    if( $fzfFilter )
    {
        $fzfArgs += "-q", $fzfFilter        # Pre-populate fzf filter
    }

    # Query via fzf and reconstruct as objects
    $objects = @($input)
    $selected = @($objects | ft -auto | Out-String | % trim | fzf @fzfArgs)
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