# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# History setup
HISTFILE=~/.zhistory
HISTSIZE=100000
SAVEHIST=100000
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_SAVE_NO_DUPS
setopt INC_APPEND_HISTORY

# Enable colors and change prompt
autoload -U colors && colors
PS1="%B%{$fg[red]%}[%{$fg[yellow]%}%n%{$fg[green]%}@%{$fg[blue]%}%M %{$fg[magenta]%}%~%{$fg[red]%}]%{$fg[cyan]%}$%b "

# Basic auto/tab complete:
autoload -U compinit
zstyle ':completion:*' menu select
zmodload zsh/complist
compinit
_comp_options+=(globdots) # Include hidden files

# vi mode
bindkey -v
export KEYTIMEOUT=1

# Use vim keys in tab complete menu:
bindkey -M menuselect 'h' vi-backward-char
bindkey -M menuselect 'k' vi-up-line-or-history
bindkey -M menuselect 'l' vi-forward-char
bindkey -M menuselect 'j' vi-down-line-or-history
bindkey '^?' backward-delete-char # Fix backspace bug

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
    zle -K viins # initiate `vi insert` as keymap (can be removed if `bindkey -V` has been set elsewhere)
    echo -ne "\e[5 q"
}
zle -N zle-line-init
echo -ne '\e[5 q' # Use beam shape cursor on startup.
preexec() { echo -ne '\e[5 q' ;} # Use beam shape cursor for each new prompt.

# Edit line in vim with ctrl-e:
export VISUAL=nvim
autoload edit-command-line; zle -N edit-command-line
bindkey -M vicmd '^e' edit-command-line

# Cycle through history based on characters already typed on the line
autoload -U up-line-or-beginning-search
autoload -U down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey "^[[A" up-line-or-beginning-search # Up
bindkey "^[[B" down-line-or-beginning-search # Down

# Zsh function for searching and opening files using nvim
fzf-nvim() {
    local file
    # file=$(find . -type f | fzf) && [ -n "$file" ] && nvim "$file"
    file=$(find ~ /mnt/Disk_D/Muhammad /mnt/Disk_D/Engineering \( -path '*/.git/*' -o -path ~/.android -o -path ~/.cache -o -path ~/.gradle -o -path ~/.npm -o -path ~/.pyenv -o -path ~/.config/BraveSoftware -o -path ~/.config/chromium -o -path ~/.config/content_shell -o -path ~/.config/thorium -o -path ~/.local/share/Android -o -path ~/.local/share/JetBrains -o -path ~/.local/share/nvim -o -path /mnt/Disk_D/Muhammad/Android_Studio/ASProjects \) -prune -o -type f -print | fzf) && [ -n "$file" ] && nvim "$file"
}
zle -N fzf-nvim
bindkey '^z' fzf-nvim

# Environment variables
export MANPAGER='nvim +Man!'
export TERMCMD=kitty
export EDITOR=nvim

# Aliases
alias logout="pkill -KILL -u $USER"
alias ls="exa --icons -a --group-directories-first"
alias ll="exa --icons -a --group-directories-first -l"
alias zrefresh="source $HOME/.zshrc"
alias cppath="pwd | sed 's/ /\\\\ /g' | xclip -selection clipboard"
alias copycmd="tail -n 2 ~/.zhistory | head -n 1 | xclip -selection clipboard"
alias zshrc="nvim $HOME/.zshrc"
alias i3config="nvim $HOME/.config/i3/config"
alias dwmconfig="nvim $HOME/.config/dwm/config.h"
alias barconfig="nvim $HOME/.config/polybar/config.ini"
alias uvrautoplay="bash ~/Scripts/UVR_autoplay.sh"
alias update-grub="sudo grub-mkconfig -o /boot/grub/grub.cfg"
alias cleandeps="sudo pacman -Rsn $(pacman -Qdtq)"
alias pkgsbackup="pacman -Qne | awk '{print \$1}' \
  > /mnt/Disk_D/Muhammad/Repositories/Arch-Backup/ArchNativePackages.txt \
  && pacman -Qm | awk '{print \$1}' \
  > /mnt/Disk_D/Muhammad/Repositories/Arch-Backup/ArchAurPackages.txt"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Plugins
source ~/.config/zsh/autojump/autojump.plugin.zsh
source ~/.config/zsh/zsh-kitty/zsh-kitty.plugin.zsh
source ~/.config/zsh/powerlevel10k/powerlevel9k.zsh-theme
source ~/.config/zsh/zsh-vim-mode/zsh-vim-mode.plugin.zsh
source ~/.config/zsh/zsh-fzf-history-search/zsh-fzf-history-search.zsh
source ~/.config/zsh/zsh-peco-history/zsh-peco-history.zsh
source ~/.config/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
source ~/.config/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
