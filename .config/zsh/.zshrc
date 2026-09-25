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
  "aria2c" "audio-separator" "cargo" "cmake" "convert" "curl" "deno" "ffmpeg"
  "flatpak" "flutter" "gcc" "go" "gradlew" "install-app" "magick" "make"
  "musicremover" "npm" "npx" "pacman" "paru" "pip" "pnpm" "rsync" "wget" "yt-dlp"
)
NOTIFY_THRESHOLD=10

zmodload zsh/datetime

_notify_preexec() {
  _notify_cmd_start=$EPOCHSECONDS
  _notify_cmd_name=${1%% *}
}

_notify_precmd() {
  local exit_code=$?
  [[ -z $_notify_cmd_start ]] && return
  local elapsed=$(( EPOCHSECONDS - _notify_cmd_start ))
  local base_cmd=${_notify_cmd_name:t}  # strip path, e.g. /usr/bin/npm -> npm

  if (( elapsed >= NOTIFY_THRESHOLD )) && (( ${NOTIFY_WHITELIST[(Ie)$base_cmd]} )); then
    if (( exit_code == 0 )); then
      notify-send "Done" "$_notify_cmd_name finished (${elapsed}s, exit $exit_code)"
    else
      notify-send -u critical "Error" "$_notify_cmd_name failed (${elapsed}s, exit $exit_code)"
    fi
  fi
  unset _notify_cmd_start _notify_cmd_name
}

add-zsh-hook preexec _notify_preexec
add-zsh-hook precmd _notify_precmd

### Environment variables -------------------------------------------------

export EDITOR=nvim
export TERMCMD=kitty
export MANPAGER='nvim +Man!'
export BAT_THEME="tokyonight_moon"
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$HOME/.local/bin:$PATH"
export CLOUDFLARE_ACCOUNT_ID=$([ -f ~/.config/opencode/api_keys/cloudflare_account_id ] && cat ~/.config/opencode/api_keys/cloudflare_account_id)
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
alias cppath="pwd | sed 's/\(^.*$\)/\"\1\"/' | wl-copy"
alias salawat='printf "%s" "ﷺ" | wl-copy'
alias copycmd='tail -n 2 ~/.zhistory | head -n 1 | tr -d "\n" | wl-copy'
alias cbimage='wl-paste --type image/png > /tmp/clipboard.png && kitty +kitten icat /tmp/clipboard.png'
alias free-coding-models='free-coding-models --config-dir ~/.config/free-coding-models'
alias systemd-plot='systemd-analyze plot > /tmp/plot.svg && brave-origin --test-type /tmp/plot.svg'
alias fitwaydroid='for i in 1 2; do hyprctl dispatch "hl.dsp.window.resize({ x = 468, y = 1036 })"; done; adb connect 192.168.240.112:5555'

if command -v pacman &> /dev/null; then
  alias paruf='(pacman -Slq; cat ~/.cache/aur/packages.txt) | sort -u \
    | fzf -m --preview "paru -Si {1} | bat --color=always --plain" \
    | xargs -ro paru -S'
  alias pkgsbackup="pacman -Qne | awk '{print \$1}' \
    > $HOME/Arch-Setup/native-packages.txt \
    && pacman -Qme | awk '{print \$1}' \
    > $HOME/Arch-Setup/aur-packages.txt"
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
      --header $'ALL    (^a)   FIND    (^f)   CONFIG (^g)\nTMUX   (^t)   ZOXIDE  (^x)   KILL   (^d)' \
      --bind "tab:down,btab:up" \
      --bind "ctrl-a:change-prompt(⚡  )+reload(sesh list --icons)" \
      --bind "ctrl-t:change-prompt(🪟  )+reload(sesh list -t --icons)" \
      --bind "ctrl-g:change-prompt(⚙️  )+reload(sesh list -c --icons)" \
      --bind "ctrl-x:change-prompt(📁  )+reload(sesh list -z --icons)" \
      --bind "ctrl-f:change-prompt(🔎  )+reload(fd -H -d 2 -t d -E .Trash . ~)" \
      --bind "ctrl-d:execute(tmux kill-session -t {2..})+change-prompt(⚡  )+reload(sesh list --icons)" \
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
      setsid paplay ~/.config/completion.mp3 &
    fi
  done
  notify-send -t 7500 "Audio Separation Completed"
}

### android functions -----------------------------------------------------

_android_module() {
  [[ ! -f "./gradlew" ]] && { echo "No gradlew found — run from project root." >&2; return 1; }
  REPLY="${1:-app}"
}

_adb_pick_device() {
  local devices_raw
  devices_raw=$(adb devices | awk -F'\t' 'NR>1 && $2=="device" {print $1}')
  [[ -z "$devices_raw" ]] && { echo "No ADB devices found." >&2; return 1; }
  local -a serials labels
  local -A seen serial_idx
  local raw_s label extra key current_serial current_len candidate_len idx android_id
  raw_s=("${(@f)devices_raw}")
  for raw_s in "${raw_s[@]}"; do
    key=$(adb -s "$raw_s" shell getprop ro.serialno 2>/dev/null | tr -d '\r')
    [[ -z "$key" ]] && key=$(adb -s "$raw_s" shell getprop ro.boot.serialno 2>/dev/null | tr -d '\r')
    android_id=$(adb -s "$raw_s" shell settings get secure android_id 2>/dev/null | tr -d '\r')
    [[ -z "$key" && "$android_id" != "null" && -n "$android_id" ]] && key="android:$android_id"
    [[ -z "$key" || "$key" == "null" ]] && key="$raw_s"
    if [[ -n "${seen[$key]}" ]]; then
      current_serial=${seen[$key]}
      current_len=${#current_serial}
      candidate_len=${#raw_s}
      if (( candidate_len < current_len )); then
        idx=${serial_idx[$key]}
        serials[$idx]="$raw_s"
        seen[$key]="$raw_s"
      fi
      continue
    fi
    seen[$key]="$raw_s"
    serial_idx[$key]=$(( ${#serials[@]} + 1 ))
    serials+=("$raw_s")
    label=""
    if [[ "$raw_s" == emulator-* ]]; then
      label=$(adb -s "$raw_s" emu avd name 2>/dev/null | sed '/^OK$/d' | tr -d '\r' | head -n1)
    fi
    if [[ -z "$label" ]]; then
      extra=$(adb devices -l | awk -v s="$raw_s" 'index($0, s)==1')
      label=${extra##*model:}
      label=${label%% *}
    fi
    labels+=("$label")
  done
  local serial
  if [[ ${#serials[@]} -eq 1 ]]; then
    serial=${serials[1]}
    echo "Using device: $serial  ${labels[1]}"
  else
    local i picked picked_idx
    local -a display
    for i in {1..${#serials[@]}}; do
      display+=("$i) ${serials[$i]}   ${labels[$i]}")
    done
    picked=$(printf '%s\n' "${display[@]}" | fzf --prompt="Select device: ")
    [[ -z "$picked" ]] && { echo "No device selected." >&2; return 1; }
    picked_idx=${picked%%)*}
    serial=${serials[$picked_idx]}
  fi
  REPLY="$serial"
}

_android_app_id() {
  local module="$1" app_id suffix gradle_file manifest_file
  manifest_file=$(find "${module}/build/intermediates" -path "*merged_manifest*" -name "AndroidManifest.xml" -print -quit 2>/dev/null)
  [[ -n "$manifest_file" ]] && app_id=$(grep -m1 -oE 'package="[^"]+"' "$manifest_file" | cut -d'"' -f2)
  if [[ -z "$app_id" ]]; then
    gradle_file="${module}/build.gradle.kts"
    [[ -f "$gradle_file" ]] || gradle_file="${module}/build.gradle"
    [[ -f "$gradle_file" ]] || { echo "No build.gradle(.kts) in module '${module}'." >&2; return 1; }
    app_id=$(grep -m1 -oE 'applicationId[[:space:]]*=?[[:space:]]*"[^"]+"' "$gradle_file" | sed -E 's/.*"([^"]+)".*/\1/')
    [[ -z "$app_id" ]] && app_id=$(grep -m1 -oE 'namespace[[:space:]]*=?[[:space:]]*"[^"]+"' "$gradle_file" | sed -E 's/.*"([^"]+)".*/\1/')
    suffix=$(awk '/debug[[:space:]]*\{/{f=1} f && /}/{exit} f' "$gradle_file" | grep -m1 -oE 'applicationIdSuffix[[:space:]]*=?[[:space:]]*"[^"]+"' | sed -E 's/.*"([^"]+)".*/\1/')
    app_id="${app_id}${suffix}"
  fi
  [[ -z "$app_id" ]] && { echo "Couldn't determine applicationId for module :${module}" >&2; return 1; }
  REPLY="$app_id"
}

_logcat_filter() {
  awk -v app="$1" -v minlvl="$2" -v seed="$3" '
    function marker(color, text) {
      printf "@@ %d %s %s\n", color, time, text
      fflush()
    }
    BEGIN {
      rank["V"] = 0; rank["D"] = 1; rank["I"] = 2; rank["W"] = 3; rank["E"] = 4; rank["F"] = 5; rank["A"] = 5
      minrank = rank[minlvl]
      n = split(seed, sp, " ")
      for (i = 1; i <= n; i++) pids[sp[i]] = 1
    }
    {
      sub(/\r$/, "")
      if (!match($0, /^[0-9][0-9]-[0-9][0-9] [0-9:.]+ +[0-9]+ +[0-9]+ [VDIWEFA] /)) next
      hdr = substr($0, 1, RLENGTH); rest = substr($0, RLENGTH + 1)
      split(hdr, h, " ")
      time = h[2]; pid = h[3]; lvl = h[5]
      i = index(rest, ": ")
      if (i > 0) { tag = substr(rest, 1, i - 1); msg = substr(rest, i + 2) }
      else       { tag = rest; sub(/:$/, "", tag); msg = "" }
      sub(/ +$/, "", tag)
      if (tag == "ActivityManager") {
        if (msg ~ /^Start proc [0-9]+:/) {
          s = substr(msg, 12); c = index(s, ":")
          p = substr(s, 1, c - 1); r = substr(s, c + 1)
          sl = index(r, "/"); pkg = (sl ? substr(r, 1, sl - 1) : r)
          if (pkg == app || index(pkg, app ":") == 1) {
            pids[p] = 1
            marker(75, "process " pkg " started (pid " p ")")
          }
        } else if (msg ~ /^Process .* \(pid [0-9]+\) has died/) {
          q = index(msg, "(pid "); p = substr(msg, q + 5) + 0
          if (p in pids) { delete pids[p]; marker(203, "process died (pid " p ")") }
        } else if (msg ~ /^Killing [0-9]+:/) {
          p = substr(msg, 9) + 0
          if (p in pids) { delete pids[p]; marker(203, "process killed (pid " p ")") }
        }
      }
      if (!(pid in pids)) next
      if (rank[lvl] < minrank) next
      print $0
      fflush()
    }'
}

_logcat_colorize() {
  awk '
    BEGIN {
      ESC = sprintf("%c", 27); RST = ESC "[0m"
      # Palette (256 colors) — tweak here
      fg["V"] = 250; fg["D"] = 75; fg["I"] = 71; fg["W"] = 178; fg["E"] = 203; fg["F"] = 196; fg["A"] = 196
      DIM = ESC "[38;5;242m"; BOLD = ESC "[1m"
    }
    /^@@ / {
      line = substr($0, 4)
      c = index(line, " "); color = substr(line, 1, c - 1); line = substr(line, c + 1)
      c = index(line, " "); mtime = substr(line, 1, c - 1); text = substr(line, c + 1)
      printf "%s%s  ── %s ──%s\n", ESC "[38;5;" color "m", mtime, text, RST
      fflush(); next
    }
    {
      sub(/\r$/, "")
      if (!match($0, /^[0-9][0-9]-[0-9][0-9] [0-9:.]+ +[0-9]+ +[0-9]+ [VDIWEFA] /)) next
      hdr = substr($0, 1, RLENGTH); rest = substr($0, RLENGTH + 1)
      split(hdr, h, " ")
      time = h[2]; pid = h[3]; tid = h[4]; lvl = h[5]
      i = index(rest, ": ")
      if (i > 0) { tag = substr(rest, 1, i - 1); msg = substr(rest, i + 2) }
      else       { tag = rest; sub(/:$/, "", tag); msg = "" }
      sub(/ +$/, "", tag)
      col = ESC "[38;5;" fg[lvl] "m"
      badge = ESC "[30;48;5;" fg[lvl] "m " lvl " " RST
      if (tag == lasttag) t = sprintf("%-23s", ""); else t = sprintf("%-23.23s", tag)
      lasttag = tag
      msgstyle = (lvl == "F" || lvl == "A") ? BOLD col : col
      printf "%s%s  %5d-%-5d%s  %s%s%s%s %s %s%s%s\n", \
        DIM, time, pid, tid, RST, BOLD, col, t, RST, badge, msgstyle, msg, RST
      fflush()
    }'
}

_apk_package() {
  local apk="$1" aapt_bin pkg
  aapt_bin=$(ls -d "$ANDROID_HOME/build-tools/"*/aapt "$HOME/Android/Sdk/build-tools/"*/aapt "$HOME/.android/Sdk/build-tools/"*/aapt 2>/dev/null | sort -V | tail -n 1)
  [[ -n "$aapt_bin" ]] || return 1
  pkg=$("$aapt_bin" dump badging "$apk" 2>/dev/null | grep -m1 -oE "^package: name='[^']+'" | cut -d"'" -f2)
  [[ -n "$pkg" ]] || return 1
  echo "$pkg"
}

function install-app() {
  _android_module "$1" || return 1
  local module="$REPLY"
  _adb_pick_device || return 1
  local serial="$REPLY"
  ./gradlew ":${module}:assembleDebug" || return 1
  local apk_path
  apk_path=$(find "${module}/build/outputs/apk/debug" -name "*.apk" -print -quit)
  [[ -z "$apk_path" ]] && { echo "Couldn't find built APK under ${module}/build/outputs/apk/debug"; return 1; }
  local app_id
  app_id=$(_apk_package "$apk_path" 2>/dev/null) || {
    _android_app_id "$module" || return 1
    app_id="$REPLY"
  }
  local user
  user=$(adb -s "$serial" shell am get-current-user 2>/dev/null | tr -d '\r')
  [[ "$user" =~ ^[0-9]+$ ]] || user=0
  echo "Installing $apk_path to '$serial' (user $user)..."
  adb -s "$serial" install -r "$apk_path" || return 1
  if ! adb -s "$serial" shell pm list packages --user "$user" 2>/dev/null | tr -d '\r' | grep -qx "package:$app_id"; then
    echo "Package not enabled for user $user — restoring (stale per-user uninstall state)..."
    adb -s "$serial" shell pm install-existing --user "$user" "$app_id" || return 1
  fi
  local target
  target=$(adb -s "$serial" shell cmd package resolve-activity --user "$user" --brief -a android.intent.action.MAIN -c android.intent.category.LAUNCHER "$app_id" | tail -n 1 | tr -d '\r')
  [[ -z "$target" || "$target" == "No activity found" ]] && {
    echo "Could not resolve launcher activity on device for $app_id (user $user)." >&2
    echo "Hint: check per-user state via 'adb -s \"$serial\" shell dumpsys package $app_id | grep -A1 \"User $user\"'." >&2
    return 1
  }
  echo "Launching $target..."
  adb -s "$serial" shell am start --user "$user" -n "$target"
}

function logcat() {
  local -A opts
  zparseopts -D -E -A opts c l:
  local level="${(U)${opts[-l]:-V}}"
  [[ "$level" == [VDIWEFA] ]] || { echo "Invalid level '$level' (use V, D, I, W, E, F)." >&2; return 1; }
  _android_module "$1" || return 1
  local module="$REPLY"
  _android_app_id "$module" || return 1
  local app_id="$REPLY"
  _adb_pick_device || return 1
  local serial="$REPLY"
  (( ${+opts[-c]} )) && adb -s "$serial" logcat -c
  echo "Logcat for $app_id on $serial  (min level: $level, Ctrl-C to stop)"
  local pids
  local -a rc extra_args
  while true; do
    pids=$(adb -s "$serial" shell pidof "$app_id" 2>/dev/null | tr -d '\r')
    adb -s "$serial" logcat -b main,system,crash -v threadtime "${extra_args[@]}" 2>/dev/null \
      | _logcat_filter "$app_id" "$level" "$pids" \
      | _logcat_colorize
    rc=("${pipestatus[@]}")
    (( ${rc[(I)130]} )) && break   # Ctrl-C
    echo "\e[38;5;178m-- device disconnected, waiting for it to come back --\e[0m"
    adb -s "$serial" wait-for-device
    sleep 2
    extra_args=(-T 1)   # don't replay the whole buffer after reconnecting
  done
}

function start-emu() {
  local emu_bin="$HOME/.android/Sdk/emulator/emulator"
  [[ ! -f "$emu_bin" ]] && { echo "Error: Emulator binary not found at $emu_bin"; return 1; }
  local avds=($("$emu_bin" -list-avds 2>/dev/null))
  local avd_count=${#avds[@]}
  local selected_avd=""
  if [[ $avd_count -eq 0 ]]; then
    echo "No Android Virtual Devices (AVDs) found."
    return 1
  elif [[ $avd_count -eq 1 ]]; then
    echo "Only one AVD found. Auto-selecting ${avds[0]}..."
    selected_avd="${avds[0]}"
  else
    command -v fzf &> /dev/null || { echo "Error: fzf is required for selection but not installed."; return 1; }
    selected_avd=$(printf "%s\n" "${avds[@]}" | fzf --prompt="Select AVD > " --layout=reverse)
  fi
  [[ -z "$selected_avd" ]] && { echo "No AVD selected. Aborting."; return 1; }
  echo "Booting $selected_avd using Android Studio default configurations..."
  QT_QPA_PLATFORM=xcb "$emu_bin" -avd "$selected_avd" \
    -no-metrics \
    -no-snapshot-load -no-boot-anim -netfast \
    > "/tmp/emu_${selected_avd}.log" 2>&1
}
