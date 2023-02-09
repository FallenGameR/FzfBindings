# FZF Notes

## fzf issues

- bug in cyrillic typing <https://github.com/junegunn/fzf/issues/2921>
- bug in cyrillic output <https://github.com/junegunn/fzf/issues/2922>
- bug in cyrillic FZF_DEFAULT_COMMAND <https://github.com/junegunn/fzf/issues/2923>
- bug in passing escaped query to rg <https://github.com/junegunn/fzf/issues/2947>
- fzf can't exit until piped input will be handled (by design)

## fzf unused features

- it can use SHELL env variable to call different commands using -command switch for pwsh

## ANSI escape sequences test

<https://duffney.io/usingansiescapesequencespowershell/>

```ps1
"`e[36m" + "text" + "`e[0m" # color
"`e[2A" + "test"            # mouse move
"`e[2S" + "test"            # viewport move
```

## FZF bindings debug

- fzf command, fail, repro
    second tab with ntp initialized in the first tab
    from ntp folder
    cdf pfgold
    work
    pending
    sd submit -c
- inline - no repro yet, have repro
    Select-GitBranch
    Select-GitBranch
- revert back completelly, fa53264ce57c6
  - slowly add back, test each change for a day
  - figure out a way how to merge two codebases
  - what is the diff?
    - change name and locations only
    - do diff
      - Initialize-Fzf.ps1 -> Initialize-ShellFzf.ps1
      - Import-GitTools.ps1 -> Initialize-GitFzf.ps1
      - Invoke-Cdf.ps1 -> Get-Folder.ps1
      - Invoke-Codef.ps1 -> Get-FileEntry.ps1
      - Preview-CodeF.ps1 -> Show-FileEntry.ps1
      - Import-GitBranchPreview.ps1 -> Show-GitBranch.ps1
- fast forward, but revert only functionality for cdf/go up
  - repro seem to occur after changing folder only
  - what about codef?
  - old previews, new code didn't work
  - trying out new previews, old code
- repro on Clear-GitBranch

## Future Improvements

- pr selection pre-selects current branch
- fzf shortcut to clean the input
- Cleanup-GitBranch - merge may fail
  - delete branch just after the successfull merge, otherwise another merge may affect it
  - instruct merge to auto pick up theirs changes, there are trivial changes that don't need human interaction in this case
- walker is needed check
