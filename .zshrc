### Tmux ------------------------------------------------------------------

# if command -v tmux &> /dev/null && [ -z "$TMUX" ]; then
#   if [ "$(pgrep -x kitty | wc -l)" -le 1 ]; then
#     (tmux attach-session || tmux new-session) &> /dev/null
#   else
#     tmux new-session &> /dev/null
#   fi
# fi

### Prompt and cursor setup -----------------------------------------------

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Enable colors and change prompt
# autoload -U colors && colors
# PS1="%B%{$fg[red]%}[%{$fg[yellow]%}%n%{$fg[green]%}@%{$fg[blue]%}%M %{$fg[magenta]%}%~%{$fg[red]%}]%{$fg[cyan]%}$%b "

# Change cursor shape for different vi modes.
function zle-keymap-select {
  if [[ ${KEYMAP} == vicmd ]] ||
     [[ $1 = 'block' ]]; then
    echo -ne '\e[1 q'
  elif [[ ${KEYMAP} == main ]] ||
       [[ ${KEYMAP} == viins ]] ||
       [[ ${KEYMAP} = '' ]] ||
       [[ $1 = 'beam' ]]; then
    echo -ne '\e[5 q'
  fi
}
zle -N zle-keymap-select
zle-line-init() {
    echo -ne "\e[5 q"
}
zle -N zle-line-init
echo -ne '\e[5 q' # Use beam shape cursor on startup.
preexec() { echo -ne '\e[5 q' ;} # Use beam shape cursor for each new prompt.

### Plugins ---------------------------------------------------------------

source ~/.config/zsh/powerlevel10k/powerlevel9k.zsh-theme
source ~/.config/zsh/zsh-vim-mode/zsh-vim-mode.plugin.zsh
source ~/.config/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
source ~/.config/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source ~/.config/zsh/zsh-history-substring-search/zsh-history-substring-search.zsh
source ~/.config/zsh/zsh-completions/zsh-completions.plugin.zsh
source ~/.config/zsh/fzf-tab-completion/zsh/fzf-zsh-completion.sh
source ~/.config/zsh/dircycle.plugin.zsh

### VI mode ---------------------------------------------------------------

bindkey -v
export KEYTIMEOUT=1

### Bindings --------------------------------------------------------------

# Fix backspace bug
bindkey '^?' backward-delete-char

# Edit line in vim with ctrl-e:
export VISUAL=nvim
autoload edit-command-line; zle -N edit-command-line
bindkey -M vicmd '^e' edit-command-line

# bind UP and DOWN arrow keys to history substring search
zmodload zsh/terminfo
bindkey "$terminfo[kcuu1]" history-substring-search-up
bindkey "$terminfo[kcud1]" history-substring-search-down
bindkey '^[[A' history-substring-search-up			
bindkey '^[[B' history-substring-search-down

### Dirs setup ------------------------------------------------------------

setopt AUTO_PUSHD
setopt PUSHDMINUS
setopt PUSHD_MINUS
setopt CDABLE_VARS
setopt PUSHD_IGNORE_DUPS

DIRSTACKSIZE=${DIRSTACKSIZE:-100}
dirstack_file=${dirstack_file:-${HOME}/.local/share/zdirs}

if [[ -f ${dirstack_file} ]] && [[ ${#dirstack[*]} -eq 0 ]] ; then
  dirstack=( ${(f)"$(< $dirstack_file)"} )
  dirstack=(${dirstack:#$PWD})
  # "cd -" won't work after login by just setting $OLDPWD, so
  [[ -d $dirstack[1] ]] && cd $dirstack[1] && cd $OLDPWD
fi

autoload -U add-zsh-hook
add-zsh-hook chpwd chpwd_dirpersist
chpwd_dirpersist() {
  if (( $DIRSTACKSIZE <= 0 )) || [[ -z $dirstack_file ]]; then return; fi
  local -ax my_stack
  my_stack=( ${PWD} ${dirstack} )
  builtin print -l ${(u)my_stack} >! ${dirstack_file}
}

### History setup ---------------------------------------------------------

setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_SAVE_NO_DUPS
setopt INC_APPEND_HISTORY
HISTFILE=~/.zhistory
HISTSIZE=100000
SAVEHIST=100000

### Completion setup ------------------------------------------------------

autoload -U compinit
zstyle ':completion:*' matcher-list 'm:{[:lower:][:upper:]}={[:upper:][:lower:]}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' rehash true
zstyle ':completion:*' menu select
zstyle ':completion:*' accept-exact '*(N)'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ~/.cache/zsh/cache
zmodload zsh/complist
compinit
_comp_options+=(globdots) # Include hidden files

# load kitty completions if in kitty
if test "$TERM" = "xterm-kitty"; then
  if (( $+commands[kitty] )); then
    eval "$(kitty + complete setup zsh)"
  fi
fi

### Environment variables -------------------------------------------------

export MANPAGER='nvim +Man!'
export TERMCMD=kitty
export EDITOR=nvim
export BAT_THEME="Catppuccin Mocha"
export FZF_DEFAULT_OPTS=" \
--border=rounded --height=~99% --reverse \
--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
--color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
--color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8"

### Aliases ---------------------------------------------------------------

alias d='selected=$(grep -xv "$PWD" ~/.local/share/zdirs | fzf); [[ -n $selected ]] && cd "$selected"'
alias ff='fzf-nvim'
alias ls='exa --icons -a --group-directories-first'
alias ll='exa --icons -a --group-directories-first -l'
alias ta='tmux attach'
alias os='sesh connect $(sesh list | fzf) &>/dev/null'
alias quit='pkill -KILL -u $USER'
alias wget='wget --hsts-file=$HOME/.local/share/wget-hsts'
alias tree='eza --tree'
alias cmatrix='unimatrix -n -s 96 -l o'
alias yayf='yay -Slq | fzf -m --preview "yay -Si {1}" | xargs -ro yay -S'
alias nvim-custom='NVIM_APPNAME=nvim-custom nvim'
alias nvim-new='NVIM_APPNAME=nvim-new nvim'
alias zrefresh='source $HOME/.zshrc'
alias zshrc='nvim $HOME/.zshrc'
alias pgcli='echo -ne "\e[2 q" && pgcli'
alias litecli='echo -ne "\e[2 q" && litecli'
alias i3config='nvim $HOME/.config/i3/config'
alias hyprconfig='nvim $HOME/.config/hypr/hyprland.conf'
alias barconfig='nvim $HOME/.config/polybar/config.ini'
alias noticenter='kill -s USR1 $(pidof deadd-notification-center)'
alias update-grub='sudo grub-mkconfig -o /boot/grub/grub.cfg'
alias webtemplate='cp -r /mnt/Disk_D/Muhammad/Website-Template/* .'
alias replaceunderscore="find . -depth -name '*_*' | while read -r file; do mv "$file" "$(dirname "$file")/$(basename "$file" | tr '_' ' ')"; done"
alias replacespace="find . -depth -name '* *' | while read -r file; do mv "$file" "$(dirname "$file")/$(basename "$file" | tr ' ' '_')"; done"

if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
  alias rofi-systemd='XDG_CONFIG_HOME=$HOME/.config/rofi/wayland bash ~/.config/rofi/scripts/rofi-systemd'
  alias cppath="pwd | sed 's/\(^.*$\)/\"\1\"/' | wl-copy"
  alias copycmd='tail -n 2 ~/.zhistory | head -n 1 | tr -d '\n' | wl-copy'
  alias cbimage='wl-paste --type image/png > /tmp/clipboard.png && kitty +kitten icat /tmp/clipboard.png'
else
  alias rofi-systemd='bash ~/.config/rofi/scripts/rofi-systemd'
  alias cppath="pwd | sed 's/\(^.*$\)/\"\1\"/' | xclip -selection clipboard"
  alias copycmd='tail -n 2 ~/.zhistory | head -n 1 | tr -d '\n' | xclip -selection clipboard'
  alias cbimage='xclip -selection clipboard -t image/png -o > /tmp/clipboard.png && kitty +kitten icat /tmp/clipboard.png'
fi

if command -v pacman &> /dev/null; then
  alias pkgsbackup="pacman -Qne | awk '{print \$1}' \
    > /mnt/Disk_D/Muhammad/Repositories/Arch-Backup/ArchNativePackages.txt \
    && pacman -Qme | awk '{print \$1}' \
    > /mnt/Disk_D/Muhammad/Repositories/Arch-Backup/ArchAurPackages.txt"
fi

### zoxide setup ----------------------------------------------------------

if command -v zoxide &> /dev/null; then
  eval "$(zoxide init zsh --cmd cd)"
fi

# Add a `y` function to zsh that opens ranger either at the given directory or
# at the one zoxide suggests
yz() {
  if [ "$1" != "" ]; then
    if [ -d "$1" ]; then
      yazi "$1"
    else
      yazi "$(zoxide query $1)"
    fi
  else
    yazi
  fi
    return $?
}

### fzf setup -------------------------------------------------------------

# fzf function for searching and opening files using nvim
fzf-nvim() {
  local selected_file
  selected_file=$(find ~ /mnt/Disk_D/Muhammad /mnt/Disk_D/Engineering \( \
    -path '*/.git/*' \
    -o -path '*/node_modules/*' \
    -o -path ~/.android \
    -o -path ~/.cache \
    -o -path ~/.npm \
    -o -path ~/.config/BraveSoftware \
    -o -path ~/.config/Microsoft \
    -o -path ~/.config/chromium \
    -o -path ~/.config/content_shell \
    -o -path ~/.config/thorium \
    -o -path ~/.local/share/JetBrains \
    -o -path ~/.local/share/android \
    -o -path ~/.local/share/cargo \
    -o -path ~/.local/share/gradle \
    -o -path ~/.local/share/nvim \
    -o -path ~/.local/share/nvim-custom \
    -o -path ~/.local/share/pyenv \
    -o -path ~/.local/share/tldr \
    -o -path /mnt/Disk_D/Muhammad/Android_Studio/ASProjects \) \
    -prune -o -type f -print \
    | fzf --preview 'bat --style=numbers --color=always --line-range :500 {}')
  if [ -n "$selected_file" ]; then
    cd $(dirname "$selected_file") 
    nvim "$selected_file"
  fi
}

# fzf integration with zsh
[ -x "$(command -v fzf)" ] && eval "$(fzf --zsh)"

### yazi wrapper ----------------------------------------------------------

function yy() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		cd "$cwd"
	fi
	rm -f -- "$tmp"
}

### audio-separator wrapper -----------------------------------------------

function audio-separator() {
  bin_path="/mnt/Disk_D/برامج/Linux/python312/bin/audio-separator"
  models_path="/mnt/Disk_D/Muhammad/Audio-Separator-Models"
  model=$(ls "$models_path" | sed -E '/(yaml$|json$)/d' | fzf)
  [ -z "$model" ] && return 1
  for file in "$@"; do
    if $bin_path --model_file_dir "$models_path" --model_filename "$model" --single_stem Vocals --output_format=MP3 "$file"; then
      setsid paplay ~/.config/completion.mp3 &
    fi
  done
  notify-send -t 7500 "Audio Separation Completed"
}
