# Walker notes

```ps1
# Colorized fast walker, I use it in profile
$env:FZF_DEFAULT_COMMAND = 'fd -I --type f --color always'

# When FZF_DEFAULT_COMMAND is not set one can setup fast but not colored default walker
fzf --walker "file,dir,follow,hidden" --walker-skip ".git,node_modules,target,bin" --preview 'bat -n --color=always {}' --bind 'ctrl-y:change-preview-window(down|hidden|)' --header 'Press CTRL-Y to toggle preview'

# The scripts in the walker folders are different samples how walk 
# can be done when you are looking for something specific
```
