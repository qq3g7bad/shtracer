#!/bin/sh

SHTRACER_TRUE="${SHTRACER_TRUE:=1}"
SHTRACER_FALSE="${SHTRACER_FALSE:=0}"
SHTRACER_IS_PROFILE_ENABLE="${SHTRACER_IS_PROFILE_ENABLE:=$SHTRACER_TRUE}"

##
# @brief  Initialize environment
# @tag    @IMP4.1@ (FROM: @ARC1.2@)
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
# @tag    @IMP4.2@ (FROM: @ARC1.2@)
error_exit() {
	if [ $# -ge 3 ]; then
		echo "[${0##*/}][$2]: $3" 1>&2
	fi
	exit "$1"
}

##
# @brief For profiling
# @param $1 : PROCESS_NAME
profile_start() {
	if [ "$SHTRACER_IS_PROFILE_ENABLE" -ne "$SHTRACER_TRUE" ]; then
		return
	fi
	PROCESS_NAME="$1"
	if [ -z "$PROCESS_NAME" ]; then
		echo "Error: process name is required." >&2
		return 1
	fi

	eval "PROFILE_START_TIME_$PROCESS_NAME=\$(date +%s.%N)"
}

##
# @brief For profiling
# @param $1 : PROCESS_NAME
profile_end() {
	if [ "$SHTRACER_IS_PROFILE_ENABLE" -ne "$SHTRACER_TRUE" ]; then
		return
	fi
	PROCESS_NAME="$1"
	if [ -z "$PROCESS_NAME" ]; then
		echo "Error: process name is required." >&2
		return 1
	fi

	eval "START_TIME=\$PROFILE_START_TIME_$PROCESS_NAME"
	if [ -z "$START_TIME" ]; then
		echo "Error: process '$PROCESS_NAME' was not started." >&2
		return 1
	fi

	END_TIME=$(date +%s.%N)
	ELAPSED=$(awk -v end="$END_TIME" -v start="$START_TIME" 'BEGIN{printf "%.2f\n", end-start}')

	echo "Process '$PROCESS_NAME' took ${ELAPSED} seconds." >&2

	eval "unset PROFILE_START_TIME_$PROCESS_NAME"
}
