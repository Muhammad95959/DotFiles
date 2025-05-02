# enables cycling through the directory stack using
# Alt+Left/Right
#
# left/right direction follows the order in which directories
# were visited, like left/right arrows do in a browser

# NO_PUSHD_MINUS syntax:
#  pushd +N: start counting from left of `dirs' output
#  pushd -N: start counting from right of `dirs' output

# Either switch to a directory from dirstack, using +N or -N syntax
# or switch to a directory by path, using `switch-to-dir -- <path>`
switch-to-dir () {
	# If $1 is --, then treat $2 as a directory path
	if [[ $1 == -- ]]; then
		# We use `-q` because we don't want chpwd to run, we'll do it manually
		[[ -d "$2" ]] && builtin pushd -q "$2" &>/dev/null
		return $?
	fi

	setopt localoptions nopushdminus
	[[ ${#dirstack} -eq 0 ]] && return 1

	while ! builtin pushd -q $1 &>/dev/null; do
		# We found a missing directory: pop it out of the dir stack
		builtin popd -q $1

		# Stop trying if there are no more directories in the dir stack
		[[ ${#dirstack} -eq 0 ]] && return 1
	done
}

insert-cycledleft () {
	switch-to-dir +1 || return $?

	local fn
	for fn in chpwd $chpwd_functions precmd $precmd_functions; do
		(( $+functions[$fn] )) && $fn
	done
	zle reset-prompt
}
zle -N insert-cycledleft

insert-cycledright () {
	switch-to-dir -0 || return $?

	local fn
	for fn in chpwd $chpwd_functions precmd $precmd_functions; do
		(( $+functions[$fn] )) && $fn
	done
	zle reset-prompt
}
zle -N insert-cycledright

insert-cycledup () {
	switch-to-dir -- .. || return $?

	local fn
	for fn in chpwd $chpwd_functions precmd $precmd_functions; do
		(( $+functions[$fn] )) && $fn
	done
	zle reset-prompt
}
zle -N insert-cycledup

insert-cycleddown () {
	switch-to-dir -- "$(find . -mindepth 1 -maxdepth 1 -type d | sort -n | head -n 1)" || return $?

	local fn
	for fn in chpwd $chpwd_functions precmd $precmd_functions; do
		(( $+functions[$fn] )) && $fn
	done
	zle reset-prompt
}
zle -N insert-cycleddown

bindkey "\e[3C"   insert-cycledright  # Alt+Left
bindkey "\e[1;3C" insert-cycledright  # Alt+Left
bindkey "\e\e[C"  insert-cycledright  # Alt+Left
bindkey "\eO3C"   insert-cycledright  # Alt+Left

bindkey "\e[3D"   insert-cycledleft   # Alt+Right
bindkey "\e[1;3D" insert-cycledleft   # Alt+Right
bindkey "\e\e[D"  insert-cycledleft   # Alt+Right
bindkey "\eO3D"   insert-cycledleft   # Alt+Right

bindkey "\e[3A"   insert-cycledup     # Alt+Up
bindkey "\e[1;3A" insert-cycledup     # Alt+Up
bindkey "\e\e[A"  insert-cycledup     # Alt+Up
bindkey "\eO3A"   insert-cycledup     # Alt+Up

# bindkey "\e[3B"   insert-cycleddown   # Alt+Down
# bindkey "\e[1;3B" insert-cycleddown   # Alt+Down
# bindkey "\e\e[B"  insert-cycleddown   # Alt+Down
# bindkey "\eO3B"   insert-cycleddown   # Alt+Down
