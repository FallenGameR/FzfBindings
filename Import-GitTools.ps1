function Get-GitBranch
{
    $names = git for-each-ref --format "%(refname:short)" refs/heads/
    $current = Resolve-GitBranch "HEAD"

    $itemes = foreach( $name in $names )
    {
        $prBranch = git branch --remotes --list branch "origin/dev/$env:USERNAME/$name" | % trim
        $contains = @($names |
            where{ $psitem -ne $name } |
            where{ $psitem -ne "master" } |
            where{ git merge-base $psitem --is-ancestor $name; $LASTEXITCODE -eq 0 } )

        $properties = [ordered] @{
            Name = $name
            IsCurrent = $name -eq $current
            WasPullRequestSent = [bool] $prBranch
            HasUnreviewedChanges = $prBranch -and (-not (Test-GitPointAtSameCommit $name $prBranch))
            ContainsBranches = $contains
            AffectsBranches = @()
            UpstreamBranch = Resolve-GitBranch "$name@{upstream}"
            PullRequestStatus = "Unknown"
        }

        $properties.PullRequestStatus =
            if( $name -eq "master" ) { "PR None" }
            elseif( $properties.ContainsBranches ) { "PR Blocked" }
            elseif( $properties.WasPullRequestSent )
            {
                if( $properties.HasUnreviewedChanges ) { "PR Update" }
                else { "PR Exists" }
            }
            else { "PR Create" }

        New-Object -TypeName PSObject -Property $properties
    }

    foreach( $item in $itemes )
    {
        $item.AffectsBranches = @($itemes | where{ $item.Name -in $psitem.ContainsBranches } | foreach Name)
    }

    $itemes
}
function Get-GitPrBranch
{
    $itemes = Get-GitBranch

    $itemesReadable = $itemes | select `
        @{ Label = "Branch"; Expression = { $psitem.Name } },
        @{ Label = "Status"; Expression = { $psitem.PullRequestStatus } },
        @{ Label = "Affects"; Expression = { $psitem.AffectsBranches } }

    $sort =
        @{ Expression = "Status"; Descending = $true },
        @{ Expression = "Name"; Descending = $false }

    $itemesReadable | sort $sort
}

function Select-GitBranch( $name )
{
    "Branch selection - Check git status"
    Assert-GitEmptyStatus

    "Branch selection - Getting branches"
    $branches = Get-GitPrBranch

    if( -not $branches ) { return }
    $selected = $branches | Select-GitBranchFzf Branch $name | select -f 1
    if( -not $selected ) { return }

    $current = Resolve-GitBranch "HEAD"
    if( $selected.Branch -ne $current )
    {
        Update-GitCheckoutBranch $selected.Branch
    }
    else
    {
        "Already on branch $current"
    }
}

function Send-GitBranch( $name )
{
    "PR creation - Check git status"
    Assert-GitEmptyStatus

    "PR creation - Getting branches"
    $branches = Get-GitPrBranch | where Status -Match "Create|Update"

    "PR creation - Branch selection"
    if( -not $branches ) { return }
    $selected = $branches | Select-GitBranchFzf Branch $name
    if( -not $selected ) { return }

    "PR creation - Branch verification"
    $created = @($selected | where Status -Match "Create")
    if( $created.Length -gt 1 ) { throw "It is possible to create only one PR at a time. Please send PRs for $(($created | % Branch) -join ',') separatelly"}

    "PR creation - Branch send to origin"
    foreach( $item in $selected )
    {
        "PR creation - $($item.Branch) branch, pushing branch to origin"
        Update-GitPush "$($item.Branch):dev/$env:username/$($item.Branch)"
    }

    if( $created )
    {
        "PR creation - $($created.Branch) branch, opening browser to annotate PR"
        start "URL"
    }
}

function Clear-GitBranch( $name )
{
    "PR cleanup - Check git status"
    Assert-GitEmptyStatus

    "PR cleanup - Getting branches"
    # Create is needed since in some cases we compelted PR and there is is no local mention of the remove branch
    $branches = Get-GitPrBranch | where Status -Match "Exists|Create"
    # Current branch can be null if we didn't select it
    $current = $branches | where IsCurrent

    "PR cleanup - Branch selection"
    if( -not $branches ) { return }
    $selected = $branches | Select-GitBranchFzf Branch $name
    if( -not $selected ) { return }

    "PR cleanup - Branch verification"
    $sent = @($selected | foreach Branch)
    $affected = @($selected | foreach{ $psitem.Affects })
    $conflicts = Compare-Object $sent $affected -PassThru -IncludeEqual -ExcludeDifferent
    if( $conflicts ) { throw "Selected combination of branches conflicts in shared changes: $($conflicts -join ','). Please clear branches separetelly." }

    # Work from the latest master
    "PR cleanup - Updating master"
    Assert-GitCleanMaster
    Update-GitCheckoutBranch "master"
    Update-GitPull

    # Clear the branches
    $toDelete = @()
    "PR cleanup - Clear the branches"
    foreach( $item in $selected )
    {
        "PR cleanup - '$($item.Branch)' branch, temp merge with master to make sure PR was fully merged"
        Update-GitCheckoutBranch $item.Branch
        Update-GitMerge "master"

        "PR cleanup - '$($item.Branch)' branch, testing the merge commit"
        $extraChanges = git diff head..head^2
        if( $extraChanges )
        {
            "PR cleanup - '$($item.Branch)' branch, reverting due to extra changes"
            Update-GitReset "head~1"
            "PR cleanup - '$($item.Branch)' branch reverted, there are extra changes in it that were not present in master. PR was not completed."
            continue
        }

        foreach( $affected in $item.Affects )
        {
            "PR cleanup - '$($item.Branch)' branch, updating affected branch $affected"
            Update-GitCheckoutBranch $affected
            Update-GitMerge $item.Branch
            "PR cleanup - '$($item.Branch)' branch, update of affected branch $affected done"
        }

        $toDelete += $item.Branch
    }

    # Go back to the current branch if it was not deleted or to master
    $returnToBranch = $current.Branch
    if( -not $returnToBranch ) { $returnToBranch = "master" }
    if( $returnToBranch -in $toDelete ) { $returnToBranch = "master" }
    "PR cleanup - Restoring $returnToBranch branch"
    Update-GitCheckoutBranch $returnToBranch
    "PR cleanup - Restored $returnToBranch branch"

    # Safe branch deletion
    "PR cleanup - Safe branch deletion"
    foreach( $branch in $toDelete )
    {
        Remove-GitBranch $branch
        "PR cleanup - Safe deleted '$branch'"
    }
}

function Select-GitBranchFzf( $key, $fzfFilter, $header = 2 )
{
    $fzfArgs = @()

    # Main view
    $fzfArgs += "--header-lines=$header"    # Table header
    $fzfArgs += "--layout=reverse"          # Grow list down, not upwards
    $fzfArgs += "--tabstop=4"               # Standard tab size
    $fzfArgs += "--cycle"                   # Cycle the list
    $fzfArgs += "--ansi"                    # Use Powershell colors
    $fzfArgs += "--no-mouse"                # We need terminal mouse behavior, not custom one
    $fzfArgs += "--info=hidden"             # Finder info style
    $fzfArgs += "--multi"                   # Allow multi selection

    # Pre view
    $fzfArgs += "--margin", "1%"            # To set some borders
    $fzfArgs += "--padding", "1%"           # To set some borders
    $fzfArgs += "--border"                  # To set some borders
    $fzfArgs += "--keep-right"              # Preview to the right
    $fzfArgs += "--preview", "pwsh.exe -nop -f $PSScriptRoot/Preview/Show-GitBranch {}"
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

function SCRIPT:Assert-FzfInstalled
{
    if( -not (gcm fzf) )
    {
        throw "fzf is needed, please install it first"
    }
}

function SCRIPT:Assert-GitEmptyStatus
{
    git diff --quiet
    if( $LASTEXITCODE )
    {
        throw "Git status is not empty, please clean it first"
    }
}

function SCRIPT:Assert-GitCleanMaster
{
    if( -not (Test-GitPointAtSameCommit "master" "origin/master") )
    {
        throw "Git master needs to be the same as origin/master"
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
    git checkout $name *> $null
    if( $LASTEXITCODE ) { throw "Could not complete wihtout errors 'git checkout $name'" }
    if( -not $env:GIT_LINE_ENDINGS_MITIGATION ) { return }

    # Line endings issue that would not go away until the problem will be fixed for good:
    # https://www.aleksandrhovhannisyan.com/blog/crlf-vs-lf-normalizing-line-endings-in-git/
    # https://developercommunity.visualstudio.com/t/git-undo-changes-on-files-that-differ-only-in-crlf/221309
    $paths = $env:GIT_LINE_ENDINGS_MITIGATION -split ";"
    $root = git rev-parse --show-toplevel
    foreach( $path in $paths )
    {
        $path = Get-Item (Join-Path $root $path) -ea Ignore | % FullName
        if( $path )
        {
            git update-index --assume-unchanged $path 2>$null
            "> Git update-index --assume-unchanged $path - done"
        }
    }

    "> Git checkout $name - done"
}

function SCRIPT:Update-GitMerge( $name )
{
    git merge $name *> $null
    if( $LASTEXITCODE ) { throw "Could not complete wihtout errors 'git merge $name" }

    "> Git merge $name - done"
}

function SCRIPT:Update-GitPull
{
    git pull *> $null
    if( $LASTEXITCODE -notin @(0,128) ) { throw "Could not complete wihtout errors 'git pull" }

    "> Git pull - done"
}

function SCRIPT:Update-GitPush( $spec )
{
    git push origin $spec *> $null
    if( $LASTEXITCODE ) { throw "Could not complete wihtout errors 'git push origin $spec" }

    "> Git push $spec - done"
}

function SCRIPT:Update-GitReset( $name )
{
    git reset --hard $name *> $null
    if( $LASTEXITCODE ) { throw "Could not complete wihtout errors 'git reset --hard $name" }

    "> Git reset --hard $name - done"
}

Assert-FzfInstalled
