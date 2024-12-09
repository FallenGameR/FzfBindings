# FZF Notes

- [help](https://junegunn.github.io/fzf/getting-started/)

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

# To do that, you need to feed NUL-separated list to fzf and use --read0 option because a new line character can no longer be used to separate items.
rg --pretty test | perl -0777 -pe 's/\n\n/\n\0/gm' | fzf --read0 

.\W32TimeLogParser.exe -f -i C:\Windows\w32time.log | fzf --tail 100000 --tac --no-sort --exact
tail -f test.txt | fzf --tail 10 --tac --no-sort --exact --wrap

# add --wrap parameter to FzfBindings
cat /dev/random | xxd | fzf --tail 1000 --tac --wrap

fzf --header 'Loading ...' --header-lines 1 --layout reverse --bind 'start:reload:sleep 1; ps'  --bind 'load:change-header:'

fd --type f |
  fzf --header $'[Files] [Directories]' --header-first `
      --bind 'click-header:transform:(( FZF_CLICK_HEADER_COLUMN <= 7 )) && echo "reload(fd --type f)" (( FZF_CLICK_HEADER_COLUMN >= 9 )) && echo "reload(fd --type d)"'

stern . --color always 2>&1 |
    fzf --ansi --tail 100000 --tac --no-sort --exact --wrap \
        --bind 'ctrl-o:execute:vim -n <(kubectl logs {1})' \
        --bind 'enter:execute:kubectl exec -it {1} -- bash' \
        --header '╱ Enter (kubectl exec) ╱ CTRL-O (open log in vim) ╱'

# Ripgrep: multi-line chunks #
rg --pretty bash |
  perl -0 -pe 's/\n\n/\n\0/gm' |
  fzf --read0 --ansi --multi --highlight-line --layout reverse |
  perl -ne '/^([0-9]+:|$)/ or print'        

# Ripgrep: path on a separate line #
rg --column --line-number --no-heading --color=always --smart-case -- bash |
  perl -pe 's/\n/\n\0/; s/^([^:]+:){3}/$&\n  /' |
  fzf --read0 --ansi --highlight-line --multi --delimiter : `
      --preview 'bat --style=numbers --color=always --highlight-line {2} {1}' `
      --preview-window '+{2}/4' |
  perl -ne '/^([^:]+:){3}/ and print'  

# just selector
fzf --disabled

# change on type {q} is the query
fzf --disabled --bind 'change:reload:echo you typed {q}'
fzf --disabled --bind 'change:reload:rg {q}'

rg --column --color=always --smart-case '' |
  fzf --disabled --ansi --bind 'change:reload:rg --column --color=always --smart-case {q}'

# delimeter in the selected line {1} would be name, {2} would be line number
# +{2} is offset to the second token, /2 show it in the middle of the screen
$env:RELOAD='reload:rg --column --color=always --smart-case {q} || exit 0'
fzf --disabled --ansi --bind "start:$env:RELOAD" --bind "change:$env:RELOAD" `
     --delimiter ":" --preview 'bat --style=numbers --color=always --highlight-line {2} {1}' `
     --preview-window '+{2}/2'

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

# --with-shell=STR #
# On Windows, the default value is cmd /s/c when $SHELL is not set.

# actions with default bindings
# backward-kill-word	alt-bs
# backward-word	alt-b shift-left
# beginning-of-line	ctrl-ahome

# Multiple actions can be chained using + separator.
fzf --multi --bind 'ctrl-a:select-all+accept'
fzf --multi --bind 'ctrl-a:select-all' --bind 'ctrl-a:+accept'

# Preview window hidden by default, it appears when you first hit '?'
fzf --bind '?:preview:cat {}' --preview-window hidden
```
