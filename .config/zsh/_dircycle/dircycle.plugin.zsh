# enables cycling through the directory stack using
# Alt+Left/Right/Up/Down
#
# left/right direction follows the order in which directories
# were visited, like left/right arrows do in a browser
#
# up switches to the parent directory (pushing the current directory
# onto the stack); down reverses that by popping back to where you were

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
	(( ${#dirstack} == 0 )) && return 1

	while ! builtin pushd -q "$1" &>/dev/null; do
		# We found a missing directory: pop it out of the dir stack
		builtin popd -q "$1"

		# Stop trying if there are no more directories in the dir stack
		(( ${#dirstack} == 0 )) && return 1
	done
}

# Runs chpwd/precmd hooks and refreshes the prompt, shared by every
# cycling widget below so the logic only lives in one place
_dircycle-refresh () {
	local fn
	for fn in chpwd $chpwd_functions precmd $precmd_functions; do
		(( $+functions[$fn] )) && "$fn"
	done
	zle reset-prompt
}

insert-cycledleft () {
	switch-to-dir +1 || return $?
	_dircycle-refresh
}
zle -N insert-cycledleft

insert-cycledright () {
	switch-to-dir -0 || return $?
	_dircycle-refresh
}
zle -N insert-cycledright

insert-cycledup () {
	switch-to-dir -- .. || return $?
	_dircycle-refresh
}
zle -N insert-cycledup

insert-cycleddown () {
	# Reverses insert-cycledup: that function does `pushd -- ..`, which
	# pushes the directory we're leaving onto the top of the dirstack
	# before cd-ing to the parent. So going back down just means popping
	# that entry back off and returning to it.
	(( ${#dirstack} == 0 )) && return 1
	builtin popd -q &>/dev/null || return $?
	_dircycle-refresh
}
zle -N insert-cycleddown

# \e[3C / \e[1;3C: Alt+Right in most terminals (xterm, iTerm, etc.)
# \e\e[C / \eO3C : Alt+Right variants seen in some terminals/tmux setups
for seq in '\e[3C' '\e[1;3C' '\e\e[C' '\eO3C'; do
	bindkey "$seq" insert-cycledright
done

# \e[3D / \e[1;3D: Alt+Left in most terminals (xterm, iTerm, etc.)
# \e\e[D / \eO3D : Alt+Left variants seen in some terminals/tmux setups
for seq in '\e[3D' '\e[1;3D' '\e\e[D' '\eO3D'; do
	bindkey "$seq" insert-cycledleft
done

# Alt+Up
for seq in '\e[3A' '\e[1;3A' '\e\e[A' '\eO3A'; do
	bindkey "$seq" insert-cycledup
done

# Alt+Down
for seq in '\e[3B' '\e[1;3B' '\e\e[B' '\eO3B'; do
	bindkey "$seq" insert-cycleddown
done
