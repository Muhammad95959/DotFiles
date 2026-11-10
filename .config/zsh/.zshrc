### Prompt and cursor setup -----------------------------------------------

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f $ZDOTDIR/.p10k.zsh ]] || source $ZDOTDIR/.p10k.zsh

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

# # Enable colors and change prompt
# autoload -U colors && colors
# PS1="%B%{$fg[red]%}[%{$fg[yellow]%}%n%{$fg[green]%}@%{$fg[blue]%}%M %{$fg[magenta]%}%~%{$fg[red]%}]%{$fg[cyan]%}$%b "

### Plugins ---------------------------------------------------------------

source $ZDOTDIR/plugins/powerlevel10k/powerlevel9k.zsh-theme
source $ZDOTDIR/plugins/zsh-vim-mode/zsh-vim-mode.plugin.zsh
source $ZDOTDIR/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source $ZDOTDIR/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source $ZDOTDIR/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh
source $ZDOTDIR/plugins/zsh-completions/zsh-completions.plugin.zsh
source $ZDOTDIR/plugins/fzf-tab-completion/zsh/fzf-zsh-completion.sh
source $ZDOTDIR/plugins/_dircycle/dircycle.plugin.zsh

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
HISTFILE=$ZDOTDIR/.zhistory
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
compinit -u
_comp_options+=(globdots) # Include hidden files

# load kitty completions if in kitty
if test "$TERM" = "xterm-kitty"; then
  if (( $+commands[kitty] )); then
    eval "$(kitty + complete setup zsh)"
  fi
fi

# paru completions
_paru_all_packages() {
  local cache_file="$HOME/.cache/aur/packages.txt"
  local -a aur_matches repo_matches installed_matches
  local cur="${words[CURRENT]}"
  if [[ "${words[1]}" == paru ]] && [[ "${words[(I)-R*]}" -ne 0 ]]; then
    installed_matches=(${(f)"$(pacman -Qq 2>/dev/null | grep -i "^$cur")"})
    compadd -a installed_matches
    return
  fi
  aur_matches=(${(f)"$(grep -i "^$cur" "$cache_file" 2>/dev/null)"})
  repo_matches=(${(f)"$(pacman -Slq 2>/dev/null | grep -i "^$cur")"})
  compadd -a repo_matches aur_matches
}
compdef _paru_all_packages paru

### Command-finish notifications -------------------------------------------

NOTIFY_WHITELIST=(
  "adb" "aria2c" "audio-separator" "cargo" "cmake" "convert" "curl" "deno" "docker"
  "ffmpeg" "flatpak" "gcc" "go" "gradlew" "install-app" "magick" "make" "musicremover"
  "npm" "npx" "pacman" "paru" "pip" "pnpm" "rsync" "uninstall-app" "wget" "yt-dlp"
)
NOTIFY_THRESHOLD=5

zmodload zsh/datetime

_notify_preexec() {
  _notify_cmd_start=$EPOCHSECONDS
  _notify_cmd_name=${1%% *}
}

_notify_precmd() {
  local exit_code=$?
  [[ -z $_notify_cmd_start ]] && return
  local elapsed=$(( EPOCHSECONDS - _notify_cmd_start ))
  local base_cmd=${_notify_cmd_name:t}

  if (( elapsed >= NOTIFY_THRESHOLD )) && (( ${NOTIFY_WHITELIST[(Ie)$base_cmd]} )); then
    case $exit_code in
      0) notify-send "Done" "$_notify_cmd_name finished (${elapsed}s, exit $exit_code)" ;;
      130|131|143) ;;
      *) notify-send -u critical "Error" "$_notify_cmd_name failed (${elapsed}s, exit $exit_code)" ;;
    esac
  fi
  unset _notify_cmd_start _notify_cmd_name
}

add-zsh-hook preexec _notify_preexec
add-zsh-hook precmd _notify_precmd

### Environment variables -------------------------------------------------

export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.local/share/npm/bin:$PATH"
export PATH="$HOME/.local/share/cargo/bin:$PATH"
export PATH="$ANDROID_HOME/platform-tools:$PATH"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"

export EDITOR=nvim
export TERMCMD=kitty
export MANPAGER='nvim +Man!'
export BAT_THEME="tokyonight_moon"
export FZF_CTRL_R_OPTS="--no-multi-line"
export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS \
  --ansi \
  --height=~99% \
  --highlight-line \
  --info=inline-right \
  --layout=reverse \
  --border=rounded \
  --color=bg+:#2d3f76 \
  --color=border:#589ed7 \
  --color=fg:#c8d3f5 \
  --color=gutter:#1e2030 \
  --color=header:#ff966c \
  --color=hl+:#65bcff \
  --color=hl:#65bcff \
  --color=info:#545c7e \
  --color=marker:#ff007c \
  --color=pointer:#ff007c \
  --color=prompt:#65bcff \
  --color=query:#c8d3f5:regular \
  --color=scrollbar:#589ed7 \
  --color=separator:#ff966c \
  --color=spinner:#ff007c \
"

### Aliases ---------------------------------------------------------------

alias d='selected=$(grep -xv "$PWD" ~/.local/share/zdirs | fzf); [[ -n $selected ]] && cd "$selected"'
alias ls='eza --icons -a --group-directories-first'
alias ll='eza --icons -a --group-directories-first -l'
alias wm='workmux'
alias ta='tmux attach'
alias quit='pkill -KILL -u $USER'
alias softreboot='sudo systemctl soft-reboot'
alias tree='eza --tree'
alias cmatrix='unimatrix -n -s 96 -l o'
alias zrefresh='source $ZDOTDIR/.zshrc'
alias zshrc='nvim $ZDOTDIR/.zshrc'
alias autodlp='cd /tmp && auto-ytdlp; cd -'
alias pgcli='echo -ne "\e[2 q" && pgcli'
alias litecli='echo -ne "\e[2 q" && litecli'
alias musicremover='~/Scripts/video_music_remover.sh'
alias hyprconfig='nvim $HOME/.config/hypr/hyprland.lua'
alias webtemplate='cp -r /mnt/Disk_D/Muhammad/Website-Template/* .'
alias cppath='printf "\"%s\"" "$PWD" | wl-copy'
alias salawat='printf "%s" "ﷺ" | wl-copy'
alias copycmd='tail -n 2 $ZDOTDIR/.zhistory | head -n 1 | tr -d "\n" | wl-copy'
alias cbimage='wl-paste --type image/png > /tmp/clipboard.png && kitty +kitten icat /tmp/clipboard.png'
alias free-coding-models='free-coding-models --config-dir ~/.config/free-coding-models'
alias systemd-plot='systemd-analyze plot > /tmp/plot.svg && brave-origin --test-type /tmp/plot.svg'
alias fitwaydroid='for i in 1 2; do hyprctl dispatch "hl.dsp.window.resize({ x = 468, y = 1036 })"; done; waydroid adb connect'

if command -v pacman &> /dev/null; then
  alias paruf='(pacman -Slq; cat ~/.cache/aur/packages.txt) | sort -u \
    | fzf -m --preview "paru -Si {1} | bat --color=always --plain" \
    | xargs -ro paru -S'
  alias pkgsbackup='pacman -Qne | awk "{print \$1}" \
    > $HOME/Arch-Setup/native-packages.txt \
    && pacman -Qme | awk "{print \$1}" \
    > $HOME/Arch-Setup/aur-packages.txt \
    && npm list -g --json | jq -r ".dependencies | keys[]" \
    > $HOME/Arch-Setup/npm-packages.txt'
fi

### zoxide setup ----------------------------------------------------------

if command -v zoxide &> /dev/null; then
  eval "$(zoxide init zsh --cmd cd)"
fi

# Add a `y` function to zsh that opens yazi either at the given directory or
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
function ff() {
  local selected_file
  selected_file=$(fd -H -d 6 -t f -E .Trash -E .git . ~/.config ~/DotFiles ~/Projects ~/Scripts ~/Arch-Setup /mnt/Disk_D/References /mnt/Disk_D/Engineering /mnt/Disk_D/Muhammad \
    | fzf --preview 'bat --style=numbers --color=always --line-range :500 {}')
  if [ -n "$selected_file" ]; then
    cd $(dirname "$selected_file") 
    nvim "$selected_file"
  fi
}

# fzf integration with zsh
[ -x "$(command -v fzf)" ] && eval "$(fzf --zsh)"

### workmux setup --------------------------------------------------------

eval "$(workmux completions zsh)"

### systemd-boot reboot picker --------------------------------------------

reboot-pick() {
  local entries choice id
  entries=$(bootctl list 2>/dev/null | awk '
    /^ *title:/ { t = substr($0, index($0,$2)) }
    /^ *id:/    { printf "%-32s| %s\n", $2, t }
  ')
  [[ -z "$entries" ]] && { echo "No boot entries found (is systemd-boot installed?)" >&2; return 1; }
  entries=$(printf '%s\n' "$entries"
            printf "%-32s| %s\n" "@boot-loader-menu" "Reboot Into Boot Loader Menu"
            printf "%-32s| %s\n" "@firmware-setup" "Reboot Into Firmware Interface (BIOS/UEFI)")
  choice=$(fzf --prompt="reboot to > " --height=50% --reverse --border \
               --delimiter="|" --with-nth=1,2 <<< "$entries") || return 1
  id=$(cut -d'|' -f1 <<< "$choice" | xargs)
  case "$id" in
    @firmware-setup)   sudo systemctl reboot --firmware-setup ;;
    @boot-loader-menu) sudo systemctl reboot --boot-loader-menu ;;
    *)                 sudo systemctl reboot --boot-loader-entry="$id" ;;
  esac
}

### sesh command ----------------------------------------------------------

function seshi() {
  sesh connect "$(
    sesh list --icons | fzf-tmux -p 85%,70% \
      --no-sort --ansi \
      --border-label " sesh " \
      --prompt "⚡  " \
      --header $'ALL    (^a)   FIND    (^f)   CONFIG (^g)\nTMUX   (^t)   ZOXIDE  (^x)   HOME   (^h)   KILL   (^d)' \
      --bind "tab:down,btab:up" \
      --bind "ctrl-a:change-prompt(⚡  )+reload(sesh list --icons)" \
      --bind "ctrl-t:change-prompt(🪟  )+reload(sesh list -t --icons)" \
      --bind "ctrl-g:change-prompt(⚙️  )+reload(sesh list -c --icons)" \
      --bind "ctrl-x:change-prompt(📁  )+reload(sesh list -z --icons)" \
      --bind "ctrl-f:change-prompt(🔎  )+reload(fd -H -d 2 -t d -E .Trash . ~)" \
      --bind "ctrl-d:execute(tmux kill-session -t {2..})+change-prompt(⚡  )+reload(sesh list --icons)" \
      --bind "ctrl-h:execute(tmux new-session -d -s home -c ~)+execute(tmux switch-client -t home)+abort" \
      --preview-window "right:55%" \
      --preview "sesh preview {}"
  )"
}

### yazi wrapper ----------------------------------------------------------

function yy() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	IFS= read -r -d '' cwd < "$tmp"
	[ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
	rm -f -- "$tmp"
}

### audio-separator wrapper -----------------------------------------------

function audiosep() {
  bin_path="$HOME/.local/share/pipx/venvs/audio-separator/bin/audio-separator"
  models_path="$HOME/.local/share/pipx/venvs/audio-separator/models"
  model=$(ls "$models_path" | sed -E '/(yaml$|json$)/d' | fzf)
  [ -z "$model" ] && return 1
  for file in "$@"; do
    if $bin_path --model_file_dir "$models_path" --model_filename "$model" --single_stem Vocals --output_format=MP3 "$file"; then
      setsid paplay /usr/share/sounds/freedesktop/stereo/complete.oga &
    fi
  done
  notify-send -t 7500 "Audio Separation Completed"
}

### redroid setup ---------------------------------------------------------

rd() {
  local v=$1
  [[ -z $v ]] && {
    echo "usage: rd <12|13|14|15>"
    return 1
  }

  local name="redroid$v" port=$((5500 + v)) tries=0

  if ! command -v fzf >/dev/null 2>&1; then
    echo "Error: fzf is not installed."
    return 1
  fi

  # Format: category, resolution, density
  local res_options="\
Small Phone       720x1280   320
Small Phone       720x1600   320
Medium Phone      1080x1920  420
Medium Phone      1080x2400  420
Large Phone       1200x2670  440
Large Phone       1440x3200  560
Foldable (Outer)  904x2316   380
Foldable (Inner)  1812x2176  420
Small Tablet      1200x1920  240
Large Tablet      1600x2560  320"

  local selected_res
  selected_res=$(printf '%s\n' "$res_options" | fzf --prompt="Select Device Screen Size: " --layout=reverse)

  [[ -z "$selected_res" ]] && {
    echo "Aborted by user."
    return 1
  }

  local res_val density width height
  res_val=$(awk '{print $(NF-1)}' <<< "$selected_res")
  density=$(awk '{print $NF}' <<< "$selected_res")

  width=${res_val%x*}
  height=${res_val#*x}

  if ! systemctl is-active --quiet docker; then
    echo "Starting Docker service..."
    sudo systemctl start docker || return 1
  fi

  if sudo docker ps --format '{{.Names}}' | grep -qx "$name"; then
    echo "Android $v is already running. Applying new screen settings..."
  else
    echo "Booting Android $v as ${width}x${height} at ${density} dpi..."

    sudo docker run -itd --rm --privileged --name "$name" \
      -v "${name}-data:/data" \
      -p "$port:5555" \
      "redroid/redroid:${v}.0.0-latest" \
      androidboot.redroid_gpu_mode=host \
      androidboot.redroid_fps=60 \
      androidboot.redroid_width="$width" \
      androidboot.redroid_height="$height" \
      androidboot.redroid_dpi="$density" >/dev/null || return 1
  fi

  echo "Waiting for Android $v..."

  until adb connect "localhost:$port" >/dev/null 2>&1 &&
        [[ "$(adb -s "localhost:$port" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]]; do
    (( ++tries > 60 )) && {
      echo "Timed out. Check: sudo docker logs $name"
      return 1
    }
    sleep 2
  done

  # Apply the selected resolution and density to the running Android instance.
  adb -s "localhost:$port" shell wm size "${width}x${height}" || return 1
  adb -s "localhost:$port" shell wm density "$density" || return 1

  echo "Android $v ready on localhost:$port"
  echo "Resolution: ${width}x${height} | Density: ${density} dpi"

  scrcpy -s "localhost:$port" \
    --no-audio --hwdec=disabled --max-fps=60 -b 16M &!
}

alias rd12='rd 12'
alias rd13='rd 13'
alias rd14='rd 14'
alias rd15='rd 15'

alias rdstop12='sudo docker stop redroid12'
alias rdstop13='sudo docker stop redroid13'
alias rdstop14='sudo docker stop redroid14'
alias rdstop15='sudo docker stop redroid15'
alias rdstopall='sudo docker stop $(sudo docker ps -q --filter "name=redroid")'

alias rdls='sudo docker ps --filter "name=redroid"'
alias rdbinder='sudo modprobe binder_linux devices="binder,hwbinder,vndbinder"'

### android functions -----------------------------------------------------

_adb_pick_device() {
  local -a devs
  local line serial attrs label
  for line in "${(@f)$(adb devices -l)}"; do
    [[ "$line" == *" device "* ]] || continue
    serial="${line%% device *}"
    attrs="${line#* device }"
    label=""
    [[ "$attrs" == *model:* ]] && label="${${attrs#*model:}%%[[:space:]]*}"
    devs+=("${serial}"$'\t'"${label}")
  done
  [[ -z "${devs[1]}" ]] && { echo "No ADB devices found." >&2; return 1; }
  local i avd
  for i in {1..${#devs[@]}}; do
    serial="${devs[i]%%$'\t'*}"
    [[ "$serial" == emulator-* ]] || continue
    avd=$(adb -s "$serial" emu avd name 2>/dev/null | tr -d '\r' | sed '/^OK$/d' | head -n1)
    [[ -n "$avd" ]] && devs[i]="${serial}"$'\t'"${avd}"
  done
  local picked="${devs[1]}"
  if (( ${#devs[@]} > 1 )); then
    picked=$(printf '%s\n' "${devs[@]}" | fzf --prompt="Select device: ") || return 1
    [[ -z "$picked" ]] && return 1
  fi
  REPLY="${picked%%$'\t'*}"
  echo "Using device: $REPLY"
}

_android_app_id() {
  local module="${1:-app}" json="${1:-app}/build/AndroidProject.json" gradle app_id
  gradle="${module}/build.gradle.kts"
  [[ -f "$gradle" ]] || gradle="${module}/build.gradle"
  [[ -f "$json" && "$json" -nt "$gradle" ]] || android describe >/dev/null || return 1
  app_id=$(jq -er '(.variants[] | select(.name == "debug") | .mainArtifact.applicationId) // .variants[0].mainArtifact.applicationId' "$json") ||
    { echo "Couldn't determine applicationId for module :${module}" >&2; return 1; }
  REPLY="$app_id"
}

function install-app() {
  [[ -f ./gradlew ]] || { echo "No gradlew found — run from project root." >&2; return 1; }
  local module="${1:-app}"
  _adb_pick_device || return 1
  local serial="$REPLY"
  echo "Installing :$module on '$serial'"
  android run --device "$serial" ":$module"
}

function uninstall-app() {
  [[ -f ./gradlew ]] || { echo "No gradlew found — run from project root." >&2; return 1; }
  _android_app_id "$1" || return 1
  local app_id="$REPLY"
  _adb_pick_device || return 1
  local serial="$REPLY"
  echo "Uninstalling $app_id from '$serial'"
  adb -s "$serial" shell pm uninstall "$app_id"
}

function logcat() {
  [[ -f ./gradlew ]] || { echo "No gradlew found — run from project root." >&2; return 1; }
  _android_app_id "$1" || return 1
  local app_id="$REPLY"
  _adb_pick_device || return 1
  local serial="$REPLY"
  local uid
  uid=$(adb -s "$serial" shell pm list packages -U 2>/dev/null | tr -d '\r' |
    awk -v p="package:${app_id} " 'index($0, p) == 1 { sub(/.*uid:/, ""); print; exit }')
  [[ -z "$uid" ]] && { echo "$app_id is not installed on $serial." >&2; return 1; }
  echo "Logcat for $app_id (uid $uid) on $serial (Ctrl-C to stop)"
  adb -s "$serial" logcat -v color --uid="$uid"
}

function start-emu() {
  local avds avd
  avds=$(android emulator list 2>/dev/null)
  [[ -z "$avds" ]] && { echo "No AVDs found." >&2; return 1; }
  avd=$(printf '%s\n' "$avds" | fzf --prompt="Select AVD: ")
  [[ -z "$avd" ]] && return 1
  local -x QT_QPA_PLATFORM=xcb
  echo "Starting $avd…"
  android emulator start "$avd" "$@"
}
