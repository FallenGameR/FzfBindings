# Notes

## ANSI Escape Codes

- [ANSI Escape Sequences](https://gist.github.com/fnky/458719343aabd01cfb17a3a4f7296797)
- [Using ANSI Escape Sequences in PowerShell](https://duffney.io/usingansiescapesequencespowershell/)

## FZF Help

- [Help](https://junegunn.github.io/fzf/getting-started/)
- [Events](https://junegunn.github.io/fzf/reference/#available-events)
- [Keys](https://junegunn.github.io/fzf/reference/#available-keys)
- [Actions](https://junegunn.github.io/fzf/reference/#available-actions)

## fzf issues

- bug in cyrillic typing <https://github.com/junegunn/fzf/issues/2921>
- bug in cyrillic output <https://github.com/junegunn/fzf/issues/2922>
- bug in cyrillic FZF_DEFAULT_COMMAND <https://github.com/junegunn/fzf/issues/2923>
- bug in passing escaped query to rg <https://github.com/junegunn/fzf/issues/2947>
- fzf can't exit until piped input will be handled (by design)

## ANSI escape sequences test

<https://duffney.io/usingansiescapesequencespowershell/>

```ps1
"`e[36m" + "text" + "`e[0m" # color
"`e[2A" + "test"            # mouse move
"`e[2S" + "test"            # viewport move
```

## Notes from the help doc

```ps1

# Multiline input is possible - you need to have NUL-separated list on input and add --read0 option
rg --pretty test | perl -0 -pe 's/\n\n/\n\0/gm' | fzf --read0 

# Tail is supported, but this needs to be tried out
.\W32TimeLogParser.exe -f -i C:\Windows\w32time.log | fzf --tail 100000 --tac --no-sort --exact
tail -f test.txt                                    | fzf --tail 10     --tac --no-sort --exact --wrap
cat /dev/random | xxd                               | fzf --tail 1000   --tac                   --wrap

# Shell can be changed, but pwsh doesn't fix the cyrilic issue and is slow. Win default is "cmd /s/c"
# --with-shell "pwsh -nop -nologo -c"

# Binding 1-1

## just selector
fzf --disabled

## change on type {q} is the query
fzf --disabled --bind 'change:reload:echo you typed {q}'
fzf --disabled --bind 'change:reload:rg {q}'
rg --column --color=always --smart-case '' | fzf --disabled --ansi --bind ('change:reload:' + 
'rg --column --color=always --smart-case {q}')

## || exit 0 to handle errors from rg
## delimeter split the fzf-selected line, {1} would be file name name, {2} would be line number
## +{2} is offset to the second token (line number), /2 show it in the middle of the screen
$env:RELOAD='reload:rg --column --color=always --smart-case {q} || exit 0'
fzf --disabled --ansi --bind "start:$env:RELOAD" --bind "change:$env:RELOAD" `
     --delimiter ":" --preview 'bat --style=numbers --color=always --highlight-line {2} {1}' `
     --preview-window '+{2}/2'

# +{2} is offset to the second token (line number), /2 show it in the middle of the screen
# ~4 makes the top four lines “sticky”
# +4 — We add 4 lines to the base offset to compensate for the header
# /3 adjusts the offset so that the matching line is shown at a 1/3 position in the window
# if the width is narrower than 80 columns, it will open above the main window with 50% height !!!
$env:RELOAD='reload:(rg --column --color=always --smart-case {q} || exit 0)'
fzf --disabled --ansi `
    --bind "start:$env:RELOAD" --bind "change:$env:RELOAD"`
    --delimiter ":" `
    --preview 'bat --style=full --color=always --highlight-line {2} {1}' `
    --preview-window '~4,+{2}+4/3,<80(up)' `
    --bind 'ctrl-o:execute-silent:code {1}'

#     --bind 'enter:become:vim {1} +{2}' \    
#     --bind 'ctrl-o:execute:code {1}:{2}' \ opens in new windows

# We use {2..} instead of {2} in case the directory name contains spaces.

# Multiple actions can be chained using + separator.
fzf --multi --bind 'ctrl-a:select-all+accept'
fzf --multi --bind 'ctrl-a:select-all' --bind 'ctrl-a:+accept'

# Preview window hidden by default, it appears when you first hit '?'
fzf --bind '?:preview:cat {}' --preview-window hidden
```
