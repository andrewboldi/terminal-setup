# Terminal Setup

## CLIs
1. Vim/Neovim: highly important for ultrafast code writing
2. Tmux: essential remote terminal window/tab management
3. Tmuxinator: automatically manage and configure tmux sessions
4. eza: a much better ls with many features
5. rgrep: find any text in all subdirectories with regex matching
6. fzf: a "fuzzy" file search tool (i.e. abc matches **a**ll**b**rainsare**c**ool.txt)
7. p10k: a nice zsh terminal theme (make sure to install MesloNGF font in your base terminal)
8. black: consistent python formatter (see the [.vimrc section](#vim-config) for automatically formatting on save in vim).
9. shfmt: also a nice tool to automatically format your shell scripts

## Aliases/Functions

### AWS-specific shortcuts

Make sure to replace the below "user"s with your remote username and the "ipv4" with your actual ipv4 of the remote machine.

```zsh
alias aws='ssh -i "~/.ssh/tf-key-pair.pem" user@ipv4' 
alias ..="cd .." 

awssend() { 
    local src="$1" 
    local dest="$2" 
    rsync -chavzP --stats -e "ssh -i ~/.ssh/tf-key-pair.pem" "$src" "user@ipv4:/home/user/$dest" 
} 

awsget() { 
    local remotepath="$1" 
    local localdest="$2" 
    rsync -chavzP --stats -e "ssh -i ~/.ssh/tf-key-pair.pem" "user@ipv4:$remotepath" "$localdest" 
} 

alias awsreceive=awsget
```

### zsh Config
- save all zsh commands to a `~/.zsh_history` file.
- zsh partial matching with up arrow. Example: `py[UP-ARROW]` matches `python3 main.py`, `pyenv activate main`, `python3 -m pip install pip`, etc.
```zsh
# zsh history
setopt appendhistory
setopt extended_history
setopt inc_append_history
HISTFILE=$HOME/.zsh_history
HISTSIZE=1000000000000000000
SAVEHIST=1000000000000000000

# partial matching with up arrow
autoload -Uz history-search-end
zle -N history-beginning-search-backward-end history-search-end
zle -N history-beginning-search-forward-end history-search-end
bindkey "$terminfo[kcuu1]" history-beginning-search-backward-end
bindkey "$terminfo[kcud1]" history-beginning-search-forward-end

# aliases
alias rg="rgrep --color"
alias ..="cd .."
alias ls="eza -loaX --icons=always --no-time --no-user"
alias diff="diff -r --color"
alias exa="ls"
alias sl="ls"
alias l="ls"
alias updatesnap="sudo snap refresh"
alias updateapt="sudo apt update -y && sudo apt dist-upgrade -y && sudo apt autoremove -y && sudo apt clean -y"
# first get sudo permission. then run all update commands concurrently (except discord after apt update).
alias up="sudo echo \"Updating software...\n\" & updateapt & updatesnap"

# functions
# efficient git usage
function g () {
    git add .;
    git commit -m "$1";
    git push;
}

# git init
function gi() {
  if git rev-parse --show-toplevel > /dev/null 2>&1; then
      echo "❌ A parent directory is already a git repository. Aborting git init."
      return 1
  else
      git init "$@"
  fi
}


# Safely remove files to a temporary folder
function saferm() { 
    mkdir -p $HOME/.local/share/Trash/files/;
    mv -n "$@" $HOME/.local/share/Trash/files/; 
}

# Unremove files in your trash folder
function urm() { 
    mkdir -p $HOME/.local/share/Trash/files/;
    for arg in "$@"; do
        mv -n "$HOME/.local/share/Trash/files/$arg" "."; 
    done
}

# view files in your trash folder
function showtrash() {
    mkdir -p $HOME/.local/share/Trash/files/;
    ls "$HOME/.local/share/Trash/files"; 
}

alias mv="mv -n" # move without overwriting
alias rm="saferm"
# this permanently deletes the contents in your temporary trash folder
alias emptytrash="showtrash && \rm -r $HOME/.local/share/Trash/files/*"
```

### vim Config

If you use vim, I highly recommend rebinding your caps lock key on your laptop (locally) to be Ctrl and use Ctrl-C to get into command mode. This makes long vim sessions much more comfortable and fast.

```vimrc
set rnu
syntax on
set shiftwidth=4 smarttab
set expandtab
set tabstop=8 softtabstop=0

autocmd BufWritePost *.py silent !black --quiet % 2>/dev/null
autocmd BufWritePost *.sh silent !shfmt -i 4 -w % 2>/dev/null
set autoread
```

### tmux Config
Here the primary things we chnage are binding the default modifier to a backtick (\`). To insert an actual backtick, simply enter the backtick twice.
```tmux
unbind C-b
set -g prefix \`
bind '\`' send-keys '\`'
bind-key e send-prefix

set -g status-position bottom
set -g status-bg colour234
#set -g default-terminal "screen-256color"
set-option -ga terminal-overrides ",xterm-256color:Tc"
set -g status-fg colour137
set -g status-left ''
set -g status-right '#(TZ=America/Los_Angeles date "+#[fg=colour233,bg=colour241,bold] %d/%m #[fg=colour233,bg=colour245,bold] %H:%M:%S")'
set -g status-right-length 50
set -g status-left-length 20
set -g status-interval 1
setw -g mode-keys vi

setw -g window-status-current-format ' #I#[fg=colour250]:#[fg=colour255]#W#[fg=colour50]#F '
setw -g window-status-format ' #I#[fg=colour237]:#[fg=colour250]#W#[fg=colour244]#F '

set-option -g history-limit 1000000

set -g default-shell /usr/bin/zsh
```

### File Organization
In my working directory, I keep projects/minitasks organized in chronological order prefixed with a 3 digit number and an underscore (you can increase the digits if you wish). For example, `001_finetuning_llama`, `002_llama_sentiment_analysis_inference`, etc. 

So for example, if I'm finetuning a model, I will create a new directory and keep/symlink all files in that directory.

#### Automatic Artifact Tracking

Another cool feature I have for my setup is to automatically track artifacts/datasets (e.g. ckpt, h5, pkl, npz, pt, pth) in a directory called 00a\_artifacts.
I have a cron job that will automatically run the script `sync_symlinks.sh` every 10 minutes.

Keeping a symlink to these files makes it easier for me to track artifacts even if decide to change the directory name. For example, I might have created a directory called `003_rsa` and can easily rename it to `003_failed_attempt_at_cracking_rsa_with_cnns` because the artifacts I store, are named according only to the base prefix and the hash of the file.

So for example, if I have a file `003_rsa/semiprimes.npz`, the script will automatically create a symlink to this file as `00a_artifacts/npz/003_271e6baf_semiprimes.npz`. That way, I could use this filename in any other directory regardless of directory name.

The symlinks are named according to base prefix name, an md5sum truncated to 8 characters, and the filename, all delimted by underscores.

Another nice benefit with this `00a_artifacts` directory is that you have a very organized way of finding artifacts by the extension.

## Miscellaneous Tips

- Learn to touch type/type faster. Very high productivity gains. (Goal is to reduce latency between ideation and execution).
