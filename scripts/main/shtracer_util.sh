#!/bin/sh

##
# @brief  Initialize environment
# @tag    @IMP1.1@ (FROM: @ARC1.2@)
init_environment() {
	set -u
	umask 0022
	export LC_ALL=C

	PATH="$(command -p getconf PATH 2>/dev/null)${PATH+:}${PATH-}"
	export PATH
	case $PATH in :*) PATH=${PATH#?} ;; esac
	IFS='
'
}

##
# @brief  Echo error message and exit
# @param  $1 : Error code
# @param  $2 : Error message
# @tag    @IMP1.4@ (FROM: @ARC1.2@)
error_exit() {
	if [ -n "$2" ]; then
		echo "${0##*/}: $2" 1>&2
	fi
	exit "$1"
}

