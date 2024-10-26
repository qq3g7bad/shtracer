#!/bin/sh

# For unit test
_SHTRACER_FUNC_SH=""

case "$0" in
*shtracer)
	: # Successfully sourced from shtracer.
	;;
*shtracer*test*)
	: # Successfully sourced from shtracer.
	;;
*)
	echo "This script should only be sourced, not executed directly."
	exit 1
	;;
esac

##
# @brief
# @param  $1 : CONFIG_MARKDOWN_PATH
# @return CONFIG_OUTPUT_DATA
# @tag    @IMP2.1@ (FROM: @ARC2.1@)
check_configfile() {
	(
		# Prepare the output directory and filenames
		_CONFIG_OUTPUT_DIR="${OUTPUT_DIR%/}/config/"
		_CONFIG_OUTPUT_LEVEL1="${_CONFIG_OUTPUT_DIR%/}/1"
		_CONFIG_OUTPUT_LEVEL2="${_CONFIG_OUTPUT_DIR%/}/2"

		mkdir -p "$_CONFIG_OUTPUT_DIR"

		# Level1: Delete comment blocks from the confiuration markdown file
		awk <"$1" \
			'
      /`.*<!--.*-->.*`/   { match($0, /`.*<!--.*-->.*`/);               # Exception for comment blocks that is surrounded by backquotes.
                            print(substr($0, 1, RSTART + RLENGTH - 1)); # Delete comments
                            next;}
                          { sub(/<!--.*-->/, "") }
      /<!--/              { in_comment=1 }
      /-->/ && in_comment { in_comment=0; next }
      /<!--/,/-->/        { if (in_comment) next }
      !in_comment         { print }
      ' |
			sed '/^[[:space:]]*$/d' |    # Delete empty lines
			sed 's/^[[:space:]]*\* //' | # Delete start spaces
			sed 's/[[:space:]]*$//' |    # Delete end spaces
			sed 's/\*\*\(.*\)\*\*:/\1:/' >"$_CONFIG_OUTPUT_LEVEL1"

		# Level2: Convert sections to lines
		sed <"$_CONFIG_OUTPUT_LEVEL1" \
			's/:/'"$SHTRACER_SEPARATOR"'/' | # Separator
			sed 's/[[:space:]]*'"$SHTRACER_SEPARATOR"'[[:space:]]*/'"$SHTRACER_SEPARATOR"'/' |
			awk -F "$SHTRACER_SEPARATOR" '\
        function print_data() {
          print \
            a["title"] '"\"$SHTRACER_SEPARATOR\""'\
            a["PATH"]  '"\"$SHTRACER_SEPARATOR\""'\
            a["EXTENSION FILTER"] '"\"$SHTRACER_SEPARATOR\""'\
            a["BRIEF"] '"\"$SHTRACER_SEPARATOR\""'\
            a["TAG FORMAT"] '"\"$SHTRACER_SEPARATOR\""'\
            a["TAG LINE FORMAT"] '"\"$SHTRACER_SEPARATOR\""'\
            a["TAG-TITLE OFFSET"];
        }

        BEGIN { precount=1; count=1; }
        /^#/ {
          match($0, /^#+/)
          gsub(/^#+ */, "", $0)
          t[RLENGTH]=$0
          title="";
          for (i=2;i<=RLENGTH;i++){ title=sprintf("%s:%s", title, t[i])}
        }

        /^PATH'"$SHTRACER_SEPARATOR"'/  {
          if (a["title"] != "") {
            print_data()
          }
          for(i in a){a[i]=""}
          a["title"]=title
        }

        {
          a[$1]=$2
        }

        END {
          print_data()
        }
      ' >"$_CONFIG_OUTPUT_LEVEL2"

		# echo the output file location
		echo "$_CONFIG_OUTPUT_LEVEL2"
	)
}

##
# @brief
# @param  $1 : CONFIG_OUTPUT_DATA
# @return TAG_OUTPUT_DATA
# @tag    @IMP2.2@ (FROM: @ARC2.2@)
make_tags() {
	(

		_TAG_OUTPUT_DIR="${OUTPUT_DIR%/}/tags/"
		_TAG_OUTPUT_LEVEL1="${_TAG_OUTPUT_DIR%/}/1"

		mkdir -p "$_TAG_OUTPUT_DIR"

		# Read config parse results (tag information are included in one line)
		_TARGET_DATA="$(cat "$1")"

		echo "$_TARGET_DATA" |
			while read -r _DATA; do
				_TITLE="$(echo "$_DATA" | awk -F "$SHTRACER_SEPARATOR" '{ print $1 }')"
				_PATH="$(echo "$_DATA" | awk -F "$SHTRACER_SEPARATOR" '{ print $2 }' | sed 's/"\(.*\)"/\1/')"
				_EXTENSION="$(echo "$_DATA" | awk -F "$SHTRACER_SEPARATOR" '{ print $3 }' | sed 's/"\(.*\)"/\1/')"
				_TAG_FORMAT="$(echo "$_DATA" | awk -F "$SHTRACER_SEPARATOR" '{ print $5 }' | sed 's/^`//' | sed 's/`$//')"
				_TAG_LINE_FORMAT="$(echo "$_DATA" | awk -F "$SHTRACER_SEPARATOR" '{ print $6 }' | sed 's/^`//' | sed 's/`$//')"
				_TAG_TITLE_OFFSET="$(echo "$_DATA" | awk -F "$SHTRACER_SEPARATOR" '{ print $7 }')"
				_TAG_TITLE_OFFSET="${_TAG_TITLE_OFFSET:-1}"

				_FROM_TAG_START="FROM:"
				_FROM_TAG_REGEX="\(""$_FROM_TAG_START"".*\)"

				cd "$CONFIG_DIR" || error_exit 1 'ERROR: cannot change directory to config path'

				_TITLE_SEPARATOR="--"
				_TAG_OUTPUT_DIR="${OUTPUT_DIR%/}/config/"

				# Check if TARGET_PATH is file or direcrory
				if [ -f "$_PATH" ]; then # File
					_FILE="$_PATH"
				else # Directory (Check extention: Multiple extensions can be set by grep argument way)
					_EXTENSION=${_EXTENSION:-*}
					_FILE="$(eval ls "${_PATH%/}/" 2>/dev/null |
						grep -E "$_EXTENSION" |
						sed "s@^@$_PATH@")"

					if [ "$(echo "$_FILE" | sed '/^$/d' | wc -l)" -eq 0 ]; then
						return # There are no files to match specified extension.
					fi
				fi

				echo "$_FILE" |
					while read -r t; do
						awk <"$t" \
							' # For title offset, extract only the offset line
              BEGIN {
                counter = -1
              }

              # 1) Print tag column
              /'"$_TAG_FORMAT"'/ && /'"$_TAG_LINE_FORMAT"'/ {
                counter='"$_TAG_TITLE_OFFSET"';
                print "'"$_TITLE"'"                      # column 1: trace target

                match($0, /'"$_TAG_FORMAT"'/)
                tag=substr($0, RSTART, RLENGTH)
                print tag;                               # column 2: tag

                match($0, /'"$_FROM_TAG_REGEX"'/)
                if (RSTART == 0) {                       # no from tag
                  from_tag="'"$NODATA_STRING"'"
                }
                else{
                  from_tag=substr($0, RSTART+1, RLENGTH-2)
                  sub(/'"$_FROM_TAG_START"'/, "", from_tag)
                  sub(/^[[:space:]]*/, "", from_tag)
                  sub(/[[:space:]]$/, "", from_tag)
                }
                print from_tag;                          # column 3: from tag
              }

              # 2) Print the offset line
              {
                if (counter == 0) {
                  sub(/^#+[[:space:]]*/, "", $0)
                  print;                                 # column 4: title
                  print "'"$t"'"                         # column 5: filename
                  print NR                               # column 6: line including title
                  print'"\"$_TITLE_SEPARATOR"\"'
                }
                if (counter >= 0) {
                  counter--;
                }
              }

              ' |
							sed 's/$/'"$SHTRACER_SEPARATOR"'/' |
							tr -d '\n' |
							sed 's/'"$_TITLE_SEPARATOR$SHTRACER_SEPARATOR"'/\n/g'
					done
			done >"$_TAG_OUTPUT_LEVEL1"

		# echo the output file location
		echo "$_TAG_OUTPUT_LEVEL1"
	)
}

##
# @brief
# @param  $1 : TAG_OUTPUT_DATA
# @return TAG_MATRIX
# @tag    @IMP2.3@ (FROM: @ARC2.2@)
make_tag_table() {
	if [ -e "$1" ]; then
		:
	else
		error_exit 1 "Can't find a tag table."
	fi

	(
		_TAG_OUTPUT_DIR="${OUTPUT_DIR%/}/tags/"
		_TAG_TABLE="${_TAG_OUTPUT_DIR%/}/tagtable"
		_TAG_TABLE_UPSTREAM="${_TAG_OUTPUT_DIR%/}/upstream"
		_TAG_TABLE_DOWNSTREAM="${_TAG_OUTPUT_DIR%/}/downstream"
		_TAG_TABLE_UNIQ="${_TAG_OUTPUT_DIR%/}/uniq"
		_TAG_TABLE_DUPLICATED="${_TAG_OUTPUT_DIR%/}/duplicated"
		_JOINED_TAG_TABLE="${_TAG_OUTPUT_DIR%/}/joined"

		mkdir -p "$_TAG_OUTPUT_DIR"

		awk <"$1" \
			-F"$SHTRACER_SEPARATOR" \
			'{
        # OFS="'"$SHTRACER_SEPARATOR"'"
        split($3, parent, /[ ]*,[ ]*/);
        for (i=1; i<=length(parent); i++){
          print(parent[i], $2);
        }
     }' >"$_TAG_TABLE"

		# [Verify] Duplicated tags
		awk <"$1" \
			-F"$SHTRACER_SEPARATOR" \
			'{
        print $2
       }' |
			sort |
			uniq -d >"$_TAG_TABLE_DUPLICATED"

		# Detect isolated items
		_TAG_TABLE_ISOLATED="$(awk <"$_TAG_TABLE" '{print $1; print $2; print $2}' |
			sort |
			uniq -u |
			sed 's/^/'"$NODATA_STRING"' /')"
		echo "$_TAG_TABLE_ISOLATED" >>"$_TAG_TABLE"
		echo "$_TAG_TABLE_ISOLATED" >"$_TAG_TABLE_UNIQ"

		# Prepare upstream table (starting point)
		grep "^$NODATA_STRING" "$_TAG_TABLE" |
			sort |
			awk '{$1=""; print $0}' |
			sed 's/^[[:space:]]*//' |
			sed '/^$/d' >"$_TAG_TABLE_UPSTREAM"

		# Prepare downstream tag table
		grep -v "^$NODATA_STRING" "$_TAG_TABLE" |
			sort |
			sed '/^$/d' >"$_TAG_TABLE_DOWNSTREAM"

		cat "$_TAG_TABLE_UPSTREAM" >"$_JOINED_TAG_TABLE"

		# [Verify] From tags that have no upstream tags.
		_UPSTREAM_UNIQ="$(awk <"$_TAG_TABLE_DOWNSTREAM" '{
       print $1;
    }' |
			sort |
			uniq -u)"

		_DOWNSTREAM_UNIQ="$(awk <"$_TAG_TABLE_DOWNSTREAM" '{
       print $2;
    }' |
			sort |
			uniq -u)"

		echo "$_UPSTREAM_UNIQ" "$_UPSTREAM_UNIQ" "$_DOWNSTREAM_UNIQ" |
			sort |
			uniq -u >"$_TAG_TABLE_UNIQ"

		# Make joined tag table (each row has a single trace tag chain)
		join_tag_table "$_JOINED_TAG_TABLE" "$_TAG_TABLE_DOWNSTREAM"

		echo "$_JOINED_TAG_TABLE$SHTRACER_SEPARATOR$_TAG_TABLE_UNIQ$SHTRACER_SEPARATOR$_TAG_TABLE_DUPLICATED"
	)
}

##
# @brief
# @param  $1 : JOINED_TAG_TABLE
# @param  $2 : TAG_TABLE
# @tag    @IMP2.4@ (FROM: @ARC2.3@)
join_tag_table() {
	(
		if [ ! -r "$1" ]; then
			error_exit 111 "JOINED_TAG_TABLE (\"$1\") is not existed"
		fi

		_JOINED_TAG_TABLE="$1"
		_TAG_TABLE_DOWNSTREAM="$2"

		_NF="$(awk <"$_JOINED_TAG_TABLE" 'BEGIN{a=0}{if(a<NF){a=NF}}END{print a}')"
		_NF_PLUS1="$((_NF + 1))"

		_JOINED_TMP="$(join -1 "$_NF" -2 1 -a 1 "$_JOINED_TAG_TABLE" "$_TAG_TABLE_DOWNSTREAM" |
			awk '{if($'"$_NF_PLUS1"'=="") $'"$_NF_PLUS1"'="'"$NODATA_STRING"'"; print}' |
			awk '{for (i=2; i<=(NF-1); i++){printf("%s ", $i)}; printf("%s %s\n", $1, $NF)}' |
			sort -k$_NF_PLUS1,$_NF_PLUS1)"

		_IS_LAST="$(echo "$_JOINED_TMP" |
			awk '{if($NF != "'"$NODATA_STRING"'"){a=1}}END{if(a==1){print 0}else{print 1}}')"

		if [ "$_IS_LAST" -eq 1 ]; then
			return
		else
			echo "$_JOINED_TMP" >"$_JOINED_TAG_TABLE"
			join_tag_table "$_JOINED_TAG_TABLE" "$_TAG_TABLE_DOWNSTREAM"
		fi
	)
}

##
# @brief
# @param  $1 : DOWNSTREAM_TAG_TABLE
# @tag    @IMP2.5@ (FROM: )
verify_tags() {
	_TAG_TABLE_UNIQ="$(echo "$1" | awk -F"$SHTRACER_SEPARATOR" '{print $1}')"
	_TAG_TABLE_DUPLICATED="$(echo "$1" | awk -F"$SHTRACER_SEPARATOR" '{print $2}')"

	if [ "$(wc <"$_TAG_TABLE_UNIQ" -l)" -ne 0 ]; then
		printf "1) Following tags are isolated.\n" 1>&2
		sed <"$_TAG_TABLE_UNIQ" \
			's/^/ /' 1>&2
	fi
	if [ "$(wc <"$_TAG_TABLE_DUPLICATED" -l)" -ne 0 ]; then
		printf "2) Following tags are duplicated.\n" 1>&2
		sed <"$_TAG_TABLE_DUPLICATED" \
			's/^/ /' 1>&2
	fi

}

##
# @brief
# @param  $1 : CONFIG_OUTPUT_DATA
# @param  $2 : BEFORE_TAG
# @param  $3 : AFTER_TAG
# @tag    @IMP2.6@ (FROM: @ARC2.4@)
swap_tags() {
	(
		# Read config parse results (tag information are included in one line)
		_TARGET_DATA="$(cat "$1")"
		_TEMP_TAG="@SHTRACER___TEMP___TAG@"
		_TEMP_TAG="$(echo "$_TEMP_TAG" | sed 's/___/_/g')" # for preventing conversion

		echo "$_TARGET_DATA" |
			while read -r _DATA; do
				_PATH="$(echo "$_DATA" | awk -F "$SHTRACER_SEPARATOR" '{ print $2 }' | sed 's/"\(.*\)"/\1/')"
				_EXTENSION="$(echo "$_DATA" | awk -F "$SHTRACER_SEPARATOR" '{ print $3 }' | sed 's/"\(.*\)"/\1/')"
				cd "$CONFIG_DIR" || error_exit 1 'ERROR: cannot change directory to config path'

				# Check if TARGET_PATH is file or direcrory
				if [ -f "$_PATH" ]; then # File
					_FILE="$_PATH"
				else # Directory (Check extention: Multiple extensions can be set by grep argument way)
					_EXTENSION=${_EXTENSION:-*}
					_FILE="$(eval ls "${_PATH%/}/" 2>/dev/null |
						grep -E "$_EXTENSION" |
						sed "s@^@$_PATH@")"

					if [ "$(echo "$_FILE" | sed '/^$/d' | wc -l)" -eq 0 ]; then
						return # There are no files to match specified extension.
					fi
				fi

				echo "$_FILE" |
					while read -r t; do
						sed -i "s/${2}/${_TEMP_TAG}/g" "$t"
						sed -i "s/${3}/${2}/g" "$t"
						sed -i "s/${_TEMP_TAG}/${3}/g" "$t"
					done
			done
	)
}
