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
