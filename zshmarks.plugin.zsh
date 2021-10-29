#!/bin/zsh

# ------------------------------------------------------------------------------
#        FILE:  zmarks/init.zsh
#        AUTHOR: Robert Magill
#        FORKED_FROM:  Jocelyn Mallon
#        VERSION: 1.0
#        DEPENDS: fzf
# ------------------------------------------------------------------------------

_ZM_USAGE="USAGE: zm <OPTION> <MARK> [PATH|PATTERN]
  -d, --dir-jump <MARK> \t\t\tJump to directory mark. 
  -D, --mark-dir <MARK> [PATH] \t\t\tMark directory. Will use current 
\t\t\t\t\t\tdirectory name if not specified. 
  -f, --file-jump <MARK> [PATTERN] \t\tJump to file mark and search for
\t\t\t\t\t\toptional pattern. 
  -F, --mark-file <MARK> [PATH]\t\t\tMark file. Will use fuzzy selector
\t\t\t\t\t\t for file if path not specified.  
  -j, --jump <MARK> [PATTERN]\t\t\tJump to directory or jump into file.
\t\t\t\t\t\tMarked files accept a search pattern.
  -s, --show [PATTERN] \t\t\t\tShow Marks. 
  -i, --into-cmd <CMD> [PATTERN] \t\t\tJump into command which resides in path.
  --clear-all \t\t\t\t\tClear all directory and file marks.
  --clear-all-dirs \t\t\t\tClear all directory marks.
  --clear-all-files \t\t\t\tClear all file marks.
  -h, --help \t\t\t\t\tShow this message.
\t "

[[ -d $ZDOTDIR ]] && fpath=("$ZDOTDIR/zmarks/functions" $fpath)

_ZM_RED='\033[0;31m'
_ZM_NOCOLOR='\033[0m'
# _ZM_MARK_RE='[0-9A-Za-z_\.]' # TODO: zsh regex behaves differently than bash. Figure this out.
_ZM_PATH_RE='^\/[0-9A-Za-z\-_\.\/]+' 


if [[ -z $EDITOR ]]; then
	 echo "set \$EDITOR environment variable to choose editor"
	 echo "defaulting to nvim or vim"
	 if [[ -n $(command -v nvim) ]]; then 
			EDITOR="$(command -v nvim)"
	 else
			EDITOR="$(command -v vim)"
	 fi
fi

# build commands cache for _zm_vi
function buildcmdcache(){
	 local cachedir="${XDG_CACHE_HOME:-"$HOME/.cache"}"
	 local cache="$cachedir/zm_vi"
	 print -rlo -- $commands:t > "$cache"
}; 
buildcmdcache

# Allows for a user to change default config
export _ZM_ZOOM=${_ZM_ZOOM:-"__zm_zoom__"}
export _ZM_MARK_FILE_SEARCH_DEPTH=${_ZM_MARK_FILE_SEARCH_DEPTH:-3}
export ZMARKS_DIR=${ZMARKS_DIR:-"$HOME/.local/share/zsh/zmarks"}
export FUZZY_CMD=${FUZZY_CMD:-fzf}
# export FUZZY_CMD='fzf-tmux'
# export FUZZY_CMD='fzy'

[[ ! -d "$ZMARKS_DIR" ]] \
	 && mkdir -p "$ZMARKS_DIR" && echo "created ZMARKS_DIR: $ZMARKS_DIR " 

export ZM_DIRS_FILE="$ZMARKS_DIR/zm_dirs" \
	 && touch "$ZM_DIRS_FILE"

export ZM_FILES_FILE="$ZMARKS_DIR/zm_files" \
	 && touch "$ZM_FILES_FILE"

export ZM_NAMED_DIRS="$ZMARKS_DIR/zm_named_dirs" \
	 && touch "$ZM_NAMED_DIRS"

export ZM_NAMED_FILES="$ZMARKS_DIR/zm_named_files" \
	 && touch "$ZM_NAMED_FILES"

[[ -L "$ZM_DIRS_FILE" ]] \
	 && ZM_DIRS_FILE=$(eval "readlink -e $ZM_DIRS_FILE")

[[ -L "$ZM_FILES_FILE" ]] \
	 && ZM_FILES_FILE=$(eval "readlink -e $ZM_FILES_FILE")

function _zm_rebuild_hash_table(){
	 gen_named_hashes(){
			local zm_file zm_path zm_name named_hash_file
			zm_file="$1"
			named_hash_file="$2"

			echo -n >  "$named_hash_file"

			while read line
			do
				 if [[ -n "$line" ]]; then
						zm_path="${line%%|*}"
						zm_name="${line##*|}"
						echo "hash -d $zm_name=$zm_path" >> "$named_hash_file"
				 fi
			done < "$zm_file"
			return 
	 }

	 # empty and rebuild hash table immediately
	 hash -rfd
	 gen_named_hashes "$ZM_DIRS_FILE" "$ZM_NAMED_DIRS" 1> /dev/null
	 gen_named_hashes "$ZM_FILES_FILE" "$ZM_NAMED_FILES" 1> /dev/null
	 source "$ZM_NAMED_DIRS" 
	 source "$ZM_NAMED_FILES" 
}

_zm_rebuild_hash_table

function __zm_move_to_trash(){
	 local file_path="$1"
	 if [[ $(uname) == "Linux"* || $(uname) == "FreeBSD"*  ]]; then
			label=`date +%s`
			mkdir -p ~/.local/share/Trash/info ~/.local/share/Trash/files
			\mv "$file_path" ~/.local/share/Trash/files/$(basename "$file_path")-$label
			echo "[Trash Info]
			Path="$file_path"
			DeletionDate="`date +"%Y-%m-%dT%H:%M:%S"`"
			">~/.local/share/Trash/info/$(basename "$file_path")-$label.trashinfo
	 elif [[ $(uname) = "Darwin" ]]; then
			\mv "$file_path" ~/.Trash/$(basename "$file_path")$(date +%H-%M-%S) 
	 else
			\rm -f "$file_path"
	 fi
}

function __zm_find() {
	 local outvar="$1"; shift
	 local pattern="$1"
	 local zm_file="$2"
	 local file_contents="$(<"$zm_file")"
	 local contents_array; contents_array=(${(f)file_contents})
	 local zm_line=${contents_array[(r)$pattern]}

	 [[ -n "$zm_line" ]] && eval "$outvar=\"$zm_line\"" \
			&& return \
			|| return 1
}

function _zm_jump() {
	 if [[ -z $1 ]];then
			cd ~
			ls
			return 
	 fi

	 local zm_name=$1
	 local matched_line
	 if ! __zm_find matched_line "*\|$zm_name" "$ZM_DIRS_FILE"; then
			if ! __zm_find matched_line "*\|$zm_name" "$ZM_FILES_FILE"; then
				  echo '
 Invalid mark,
 Please provide a valid file or directory mark name.
 For example:\n
 Jump to mark:
 zm -j <MARK> [PATTERN]\n
 To mark a directory:
 zm -D <NAME> \n
 To mark a file:
 zm -F  <NAME> \n
 zm --help
					'
				 return 1
			else
				 # File mark found
				 local zm_file_path="${matched_line%%|*}"
				 _zm_zoom "$zm_file_path" "$2"
			fi

	 else
			# Directory mark found
			local zm_dir_path="${matched_line%%|*}"
			eval "cd \"${zm_dir_path}\""
			eval "ls \"${zm_dir_path}\""
	 fi
}

function _zm_show() {
	 local zm_file=$(<"$ZM_DIRS_FILE" <"$ZM_FILES_FILE")
	 local zm_array; zm_array=(${(f)zm_file});
	 local zm_name zm_path zm_line
	 zmarks=()
				 [[ ${#zm_array[@]} -eq 0 ]] \
					&& echo '
 You do not have any marks set yet. \n
 To mark a directory:
 zm -D <name> \n
 To mark a file:
 zm -F <name> \n
 zm --help
				 '

	 if [[ $# -eq 1 ]]; then
			for zm_line in $zm_array; do
				 zm_name="${zm_line#*|}"
				 if [[ $zm_name =~ ^$1 ]]; then
						zmarks+="$zm_line"
				 fi

			done

			IFS=$'\n' 
			sorted=($(sort -t '|' -k 2 <<<"${zmarks[*]}"))
			unset IFS

			for zm_line in $sorted; do
				 __zm_line_printf "$zm_line"
			done

	 else
			for zm_line in $zm_array; do
				 __zm_line_printf "$zm_line"
			done
	 fi
}

__zm_line_parse(){
	 local USAGE="
	 ${FUNCNAME[0]}  zm_line path_variable_to_set name_variable_to_set 
	 "
	 local zm_line="$1"
	 local outpath outname
	 local outpath="${zm_line%%|*}"
	 local outname="${zm_line#*|}"

	 if [[ "$#" -eq 3 ]]; then
			eval "$2=\"$outpath\""
			eval "$3=\"$outname\""
	 else
			echo "$USAGE"
	 fi
}

__zm_line_printf() {
	 local USAGE="${FUNCNAME[0]} zm_line"
	 if [[ ! "$#" -eq 1 ]]; then
			echo "$USAGE"
	 fi

	 local zm_line="$1"
	 local path name
	 __zm_line_parse "$zm_line" path name

	 if [[ ${#name} -gt 7 ]]; then
			# echo "${#name} length is greater than 7"
			printf "%s\t-- %s\n" "$name" "$path"
	 else
			# echo "${#name} length is less than 7"
			printf "%s\t\t-- %s\n" "$name" "$path"
	 fi
}

function _zm_remove()  {
	 local zm_name="$1"
	 local zm_file="${2:-$ZM_DIRS_FILE}"
	 [[ -z $zm_name ]] && printf "%s \n" "Provide a mark name to remove" \
			&& return 1

	 local file_contents="$(<"$zm_file")"
	 local zm_array; zm_array=(${(f)file_contents});

	 local matched_line pattern
	 pattern="*\|${zm_name}"
	 matched_line=${zm_array[(r)$pattern]}

	 if [[ -z "$matched_line"  ]]; then

			# name not found in dirs, run again with files
			[[ "$zm_file" == "$ZM_DIRS_FILE" ]] \
				 && _zm_remove "$zm_name" "$ZM_FILES_FILE" \
				 || eval "printf '%s\n' \"'${zm_name}' not found.\"" && return 1 

	 else
			\cp "${zm_file}" "${zm_file}.zm_bak"
			local new_array=(${zm_array[@]/$matched_line})

			[[ ${#new_array} -gt 0 ]] \
				 && eval "printf '%s\n' \"\${new_array[@]}\"" > "$zm_file" \
				 || echo -n > "$zm_file"

			__zm_move_to_trash "${zm_file}.zm_bak" 
			echo "$zm_name removed"

			_zm_rebuild_hash_table
			return 
	 fi
}

function __zm_ask_to_clear(){
	 local i msg
	 msg="${@: -1}"
	 printf "${_ZM_RED}$msg (y/n)? ${_ZM_NOCOLOR}"
	 read answer
	 if  [ "$answer" != "${answer#[Yy]}" ];then 
			i=1
			for file in "$@" 
			do
				 [[ $i -lt $# ]] \
						&& __zm_move_to_trash "$file" && touch "$file"

				((i++))
			done
			_zm_rebuild_hash_table
	 else
			echo 'abort'
	 fi
}

function __zm_clear_all(){
	 __zm_ask_to_clear "$ZM_FILES_FILE" "$ZM_DIRS_FILE" "Clear all directory and file marks?"
}

function __zm_clear_all_dirs(){
	 __zm_ask_to_clear "$ZM_DIRS_FILE" "Clear all directory marks?"
}

function __zm_clear_all_files(){
	 __zm_ask_to_clear "$ZM_FILES_FILE" "Clear all file marks?"
}

# open marked file and jump to pattern or $_ZM_ZOOM if it exists in file
function _zm_zoom() {
	 local file_path=$1
	 if [[ -z $2 ]]; then
			has_zoom_mark=$(grep "$_ZM_ZOOM" "$file_path")
			if [[ -n $has_zoom_mark ]]; then
				 "$EDITOR" +/"$_ZM_ZOOM" "$file_path"	
			else
				 "$EDITOR" "$file_path"
			fi
	 else
			"$EDITOR" +/"$2" "$file_path"	
	 fi
}

function _zm_file_jump() {
	 local zm_name="$1"
	 local matched_line
	 if ! __zm_find matched_line "*\|$zm_name" "$ZM_FILES_FILE"; then
			echo '
Invalid file mark,
Please provide a valid file mark name. \n
For more info:
 zm --help
			'
			return 1
	 else
			local zm_file_path="${matched_line%%|*}"
			_zm_zoom "$zm_file_path" "$2"
	 fi
}

function _zm_dir_jump() {
	 local zm_name=$1
	 local matched_line
	 if ! __zm_find matched_line "*\|$zm_name" "$ZM_DIRS_FILE"; then
			echo '
Invalid directory mark,
Please provide a valid directory mark name. \n
For more info:
 zm --help
			'
			return 1
	 else
			local zm_dir_path="${matched_line%%|*}"
			eval "cd \"${zm_dir_path}\""
			eval "ls \"${zm_dir_path}\""
	 fi
}

function _zm_mark_dir() {
	 local new_zm_name new_zm_path new_zm_line
	 new_zm_name="$1"

	 if [[ -z $new_zm_name ]]; then
			new_zm_name="${PWD##*/}"
	 fi

	 # if [[ ! "${new_zm_name//$_ZM_MARK_RE/}" = "" ]]; then
	 if [[ ! "${new_zm_name//[0-9A-Za-z_\.]/}" = "" ]]; then
			echo 'Mark name must only contain alphanumerics and underscores'
			echo 'Example: zm -D MARK [PATH]'
			return 1
	 fi

	 [[ -z "$2" ]] \
			&& new_zm_path=$(eval "readlink -e $PWD") \

	 [[ -z "$new_zm_path" ]] \
			&& new_zm_path=$(eval "readlink -e $2")

	 if [[ -z "$new_zm_path" && -n "$2" ]]; then

			[[ ! $(readlink -f "$2") =~ $_ZM_PATH_RE ]] \
				 && echo 'Path must only contain alphanumerics, dashes and underscores' && return 1 \
				 || echo "Path '$(readlink -f "$2")' does not exist" 

			echo 'Would you like to create it? (y/n) '
			read answer
			if  [ "$answer" != "${answer#[Yy]}" ]; then 
				 mkdir -p "$2"
				 new_zm_path=$(eval "readlink -e $2")

				 [[ -z "$new_zm_path" ]] \
						&& echo 'invalid path' \
						&& return 1

				 echo "path created: $new_zm_path"
			else
				 echo 'abort'
				 return 1
			fi
	 elif [[ -z "$new_zm_path" ]]; then
			echo 'Invalid path:'
			echo 'Path must only contain alphanumerics, dashes and underscores'
			return 1
	 fi


	 if [[ ! "$new_zm_path" =~ $_ZM_PATH_RE ]]; then
			echo 'Path must only contain alphanumerics, dashes and underscores'
			return 1
	 fi

	 new_zm_line="$new_zm_path|$new_zm_name"

	 ! __zm_check_path_clash "$new_zm_line" && return
	 ! __zm_check_name_clash "$new_zm_line" && return
	 ! __zm_check_hash_clash "$new_zm_name"  && return

	# no duplicates, make mark
	echo "$new_zm_line" >> $ZM_DIRS_FILE
	echo "directory mark '$new_zm_name' saved"

	_zm_rebuild_hash_table
	return 
}

function _zm_mark_file() {
	 local new_zm_name new_zm_path new_zm_line
	 new_zm_name="$1"
	 new_zm_path="$2"

	 if [[ -z $new_zm_name ]]; then
			echo 'mark name required'
			return 1
	 fi

	 # if [[ ! "${new_zm_name//$_ZM_MARK_RE/}" = "" ]]; then
	 if [[ ! "${new_zm_name//[0-9A-Za-z_\.]/}" = "" ]]; then
			echo 'Invalid mark name.'
			echo 'Mark name must only contain alphanumerics and underscores'
			return 1
	 fi

	 if [[ -n "$new_zm_path" ]]; then
			if [[ -n $(eval "readlink -e  $new_zm_path") ]]; then
				 new_zm_path=$(eval "readlink -e $new_zm_path")
			else
				 [[ ! $(readlink -f "$new_zm_path") =~ $_ZM_PATH_RE ]] \
						&& echo 'Path must only contain alphanumerics, dashes and underscores' && return 1 \
						|| echo "Path '$(readlink -f "$new_zm_path")' does not exist" 

				 echo 'Would you like to create it? (y/n) '
				 read answer
				 if  [ "$answer" != "${answer#[Yy]}" ]; then 
						touch "$new_zm_path"
						new_zm_path=$(eval "readlink -e $new_zm_path")

						[[ -z "$new_zm_path" ]] \
							 && echo 'invalid path' \
							 && return 1

						echo "path created: $new_zm_path"
				 else
						echo 'abort'
						return 1
				 fi
			fi


	 elif [[ -z "$new_zm_path" && -n $(\ls $(pwd) | grep -x "$new_zm_name") ]]; then
			new_zm_path=$(readlink -e "$PWD/$new_zm_name")

	 else
			new_zm_path="$(find -L $(pwd) -maxdepth $_ZM_MARK_FILE_SEARCH_DEPTH -type f 2>/dev/null | "$FUZZY_CMD")"
			if [[ -z "$new_zm_path" ]]; then
				 echo 'abort'
				 return 1
			fi

	 fi


	 if [[ ! "$new_zm_path" =~ $_ZM_PATH_RE ]]; then
			echo 'Path must only contain alphanumerics, dashes and underscores'
			return 1
	 fi

		new_zm_line="$new_zm_path|$new_zm_name"

		! __zm_check_path_clash "$new_zm_line" && return
		! __zm_check_name_clash "$new_zm_line" && return
		! __zm_check_hash_clash "$new_zm_name"  && return

		if [[ -n "$new_zm_name" && -n "$new_zm_path" ]]; then
			 echo "$new_zm_line" >> "$ZM_FILES_FILE"
			 echo "zmark file '$new_zm_name' saved"

			 echo "hash -d $new_zm_name=$new_zm_path" >> "$ZM_NAMED_FILES"
			 echo "Created named file ~$new_zm_name"
			 source "$ZM_NAMED_FILES"
		else
			 echo "Something went wrong. Mark or path is not assigned."
		fi
 }

function __zm_check_hash_clash(){
	 local zm_name="$1"; [[ -z "$zm_name" ]] && return 1 

	 local hash_name_exists=$(hash -md "$zm_name")

	 if [[ -n "$hash_name_exists" ]]; then
			printf "${_ZM_RED} ~$zm_name named hash clashes: $hash_name_exists ${_ZM_NOCOLOR}\n"
			echo 'If you created hash, you can remove it and run again, but this could have been set by another program. If you did not create it, I would just choose another name.'
			return 1 
			fi
	 }

function __zm_check_name_clash(){
	 # lcoal USAGE='USAGE: ${FUNCNAME[0]} <ZMARK_LINE>'
	 local new_zm_line zm_name clash_line clash_name clash_path
	 new_zm_line="$1"
	 zm_name="${new_zm_line##*|}"

	 if  __zm_find clash_line "*\|$zm_name" "$ZM_FILES_FILE"; then

			[[ "$clash_line" == "$new_zm_line" ]] \
				 && echo "umm, like, you already have this EXACT mark." && return 1

			clash_name=${clash_line##*|}
			clash_path=${clash_line%%|*}

			printf "${_ZM_RED}Name clashes with marked file:\n $clash_name\t -- $clash_path${_ZM_NOCOLOR}\n"
			echo -n "Remove '$clash_name' file mark? (y/n)? "

			__zm_checktoremove "$clash_line"

	 elif  __zm_find clash_line "*\|$zm_name" "$ZM_DIRS_FILE"; then

			[[ "$clash_line" == "$new_zm_line" ]] \
				 && echo "umm, like, you already have this EXACT mark." && return 1

			clash_name=${clash_line##*|}
			clash_path=${clash_line%%|*}

			printf "${_ZM_RED}Name clashes with marked directory:\n $clash_name\t -- $clash_path${_ZM_NOCOLOR}\n"
			echo -n "Remove '$clash_name' directory mark? (y/n)? "
			__zm_checktoremove "$clash_line"
	 fi
}

function __zm_check_path_clash(){
	 local new_zm_line zm_path zm_name clash_path clash_name
	 new_zm_line="$1"
	 zm_path="${new_zm_line%%|*}"
	 zm_name="${new_zm_line##*|}"

	 if  __zm_find clash_line "$zmark_path\|*" "$ZM_FILES_FILE"; then

			[[ "$clash_line" == "$new_zm_line" ]] \
				 && echo "umm, like, you already have this EXACT mark." && return 1

			clash_name=${clash_line##*|}
			clash_path=${clash_line%%|*}

			printf "${_ZM_RED}Path clashes with marked file: \n $clash_name\t -- $clash_path${_ZM_NOCOLOR}\n"
			echo -n "Remove '$clash_name' file mark? (y/n)? "
			__zm_checktoremove "$clash_line"

	 elif  __zm_find clash_line "$zmark_path\|*" "$ZM_DIRS_FILE"; then

			[[ "$clash_line" == "$new_zm_line" ]] \
				 && echo "umm, like, you already have this EXACT mark." && return 1

			clash_name=${clash_line##*|}
			clash_path=${clash_line%%|*}

			printf "${_ZM_RED}Path clashes with marked directory: \n $clash_name\t -- $clash_path${_ZM_NOCOLOR}\n"

			echo -n "Remove '$clash_name' directory mark? (y/n)? "
			__zm_checktoremove "$clash_line"

	 fi
} 

function __zm_checktoremove(){
	 local clash_name clash_line
	 clash_line="$1"
	 clash_name="${clash_line##*|}"
	 read answer
	 if  [ "$answer" != "${answer#[Yy]}" ];then 
			_zm_remove "$clash_name"
	 else
			echo 'abort'
			return  1
	 fi
}

# TODO add command comletion or maybe just remove this
# add checks to for type and file to only allow editable commands
function _zm_vi() {
	 local cmd pattern c_path 
	 cmd="$1"
	 [[ -z "$cmd" ]] && echo 'command required' && return
	 pattern="$2"
	 c_path=$(command -v $cmd)
	 # echo "zmarks/init.zsh: 465 c_path: $c_path"
	 if [[ -z "$c_path" ]];then
			echo 'script not in path'
	 else
			
			# if [ $? -eq 0 ];then
			# if file "$c_path" | grep executable &> /dev/null; then
			if file "$c_path" | grep 'binary'; then
				 echo "$c_path is a binary"
			else
					
					if file "$c_path" |egrep "ascii|text";then
							# echo "File is ascii"   
						 _zm_zoom "$c_path" "$pattern"
					else
						 # echo "$cmd is not ascii text"
							printf "${_ZM_RED}$cmd is not ascii text${_ZM_NOCOLOR}\n\n"
						 file "$c_path"
					fi
			fi
	 fi
}

# TODO
# could just get rid of this and source any files which reside in ZDOTDIR immediately
function _zm_jump_n_source() {
	 _zm_file_jump "$1" "$2"
	 source ~"$1"
}

function zm(){

	 if [[ $# -gt 0 ]]; then
			key="$1"

			case $key in

				 -d|--dir-jump)
						shift 
						_zm_dir_jump "$@"
						return
						;;

				 -D|--mark-dir)
						shift 
						_zm_mark_dir "$@"
						return
						;; 

				 -F|--mark-file)
						shift 
						_zm_mark_file "$@"
						return
						;;

				 -f|--file-jump)
						shift 
						_zm_file_jump "$@"
						return
						;;

				 -j|--jump)
						shift
						_zm_jump "$@"
						return
						;; 

				 -s|--show)
						shift
						_zm_show "$@"
						return
						;;

				 -r|--remove)
						shift 
						_zm_remove "$@"
						return
						;;

				 -i|--into-cmd)
						shift
						_zm_vi "$@"
						return
						;; 

				 --clear-all)
						shift 
						__zm_clear_all
						return
						;;

				 --clear-all-files)
						shift 
						__zm_clear_all_files
						return
						;;

				 --clear-all-dirs)
						shift 
						__zm_clear_all_dirs
						return
						;;

				 -h|--help)
						echo "$_ZM_USAGE"
						return
						;; 

				 esac

			else
				 echo "$_ZM_USAGE"
				 return
	 fi

}

# fuzzy bindings 

# zsh fuzzy jump binding (all)
_zm_fuzzy_jump(){
	 local zm_line=$("$FUZZY_CMD" <"$ZM_DIRS_FILE" <"$ZM_FILES_FILE")
	 local zm_path="${zm_line%%|*}"
	 [[ -z "$zm_path" ]] && zle reset-prompt && return 1

	 # TODO could also use zgrep here, this would allow new marks without sourcing
	 # if ! __zm_find zm_line "\\|$zm_name\$" "$ZM_DIRS_FILE"; then
	 if [ -d $(eval "echo $zm_path") ]; then
			# echo "we gotta dir"
			eval "cd \"$zm_path\""
			ls
			echo -e "\n"
	 else
			# echo "we gotta file"
			eval "_zm_zoom \"$zm_path\""
	 fi
	 zle reset-prompt
}
zle     -N    _zm_fuzzy_jump

# zsh fuzzy jump binding (dirs)
_zm_fuzzy_dir_jump(){
	 local zm_line=$("$FUZZY_CMD" <"$ZM_DIRS_FILE" )
	 if [[ -n $zm_line ]];then 
			local zm_dir_path="${zm_line%%|*}"
			eval "cd ${zm_dir_path}"
			ls
			echo -e "\n"
			zle reset-prompt
	 fi
}
zle     -N    _zm_fuzzy_dir_jump

_zm_fuzzy_dir_jump_increment(){
		 setopt localoptions pipefail no_aliases 2> /dev/null
		 filesel () {
				# fzf is used regardless of FUZZY_CMD setting
				local filecmd="command find -L . -mindepth 1 \\( -path '*/\\.*' -o -fstype 'sysfs' -o -fstype 'devfs' -o -fstype 'devtmpfs' -o -fstype 'proc' \\) -prune -o -type f -print -o -print 2> /dev/null" 
				local item
				eval "$filecmd | fzf -m $@" | while read item
				do
					echo -n "${(q)item} "
				done
				local ret=$? 
				echo
				return $ret
			}

   # get marked dir
	 local zm_line=$("$FUZZY_CMD" <"$ZM_DIRS_FILE" )
	 if [[ -n $zm_line ]];then 
			local zm_dir_path="${zm_line%%|*}"

	 local cmd="command find -L $zm_dir_path -mindepth 1 \\( -path '*/\\.*' -o -fstype 'sysfs' -o -fstype 'devfs' -o -fstype 'devtmpfs' -o -fstype 'proc' \\) -prune \
			-o -type d -print 2> /dev/null"
			# local dir="$(eval "$cmd" | FZF_DEFAULT_OPTS="--height ${FZF_TMUX_HEIGHT:-40%} --reverse --bind=ctrl-z:ignore $FZF_DEFAULT_OPTS $FZF_ALT_C_OPTS" $(__fzfcmd) +m)"
			local dir="$(eval "$cmd | $FUZZY_CMD")"

			[[ -z "$dir" ]] \
				 && zle redisplay && return 0
    

			if [[ -d "$dir" ]]; then
	 				 # zle push-line # Clear buffer. Auto-restored on next prompt.
					 cd ${(q)dir}
					 # zle accept-line

					 # local sel="$(__fsel)"
					 local sel="$(filesel)"
					 echo "zmarks/init.zsh: 815 sel: $sel"
					 [[ -n "$sel" ]] && LBUFFER="$EDITOR $sel"

					 local ret=$?
					 unset dir # ensure this doesn't end up appearing in prompt expansion
					 zle reset-prompt
					 return $ret

			fi
			# if [[ -f "$dir" ]]; then
			# 			LBUFFER="vi ${(q)dir}"
			# 			return 0
			# fi
			# # unset dir # ensure this doesn't end up appearing in prompt expansion
			# # zle reset-prompt
			local ret=$?
			return $ret
	 fi
}; zle     -N    _zm_fuzzy_dir_jump_increment

_zm_fuzzy_dir_jump_increment_edit(){
		 setopt localoptions pipefail no_aliases 2> /dev/null
		 filesel () {
				# fzf is used regardless of FUZZY_CMD setting
				local filecmd="command find -L . -mindepth 1 \\( -path '*/\\.*' -o -fstype 'sysfs' -o -fstype 'devfs' -o -fstype 'devtmpfs' -o -fstype 'proc' \\) -prune -o -type f -print -o -print 2> /dev/null" 
				local item
				eval "$filecmd | fzf -m $@" | while read item
				do
					echo -n "${(q)item} "
				done
				local ret=$? 
				echo
				return $ret
			}

   # get marked dir
	 local zm_line=$("$FUZZY_CMD" <"$ZM_DIRS_FILE" )
	 if [[ -n $zm_line ]];then 
			local zm_dir_path="${zm_line%%|*}"

	 local cmd="command find -L $zm_dir_path -mindepth 1 \\( -path '*/\\.*' -o -fstype 'sysfs' -o -fstype 'devfs' -o -fstype 'devtmpfs' -o -fstype 'proc' \\) -prune \
			-o -type d -print 2> /dev/null"
			# local dir="$(eval "$cmd" | FZF_DEFAULT_OPTS="--height ${FZF_TMUX_HEIGHT:-40%} --reverse --bind=ctrl-z:ignore $FZF_DEFAULT_OPTS $FZF_ALT_C_OPTS" $(__fzfcmd) +m)"
			local dir="$(eval "$cmd | $FUZZY_CMD")"

			[[ -z "$dir" ]] \
				 && zle redisplay && return 0
    

			if [[ -d "$dir" ]]; then
	 				 # zle push-line # Clear buffer. Auto-restored on next prompt.
					 cd ${(q)dir}
					 # zle accept-line

					 # local sel="$(__fsel)"
					 local sel="$(filesel)"
					 echo "zmarks/init.zsh: 815 sel: $sel"
					 [[ -n "$sel" ]] && LBUFFER="$EDITOR $sel"

					 local ret=$?
					 unset dir # ensure this doesn't end up appearing in prompt expansion
					 zle reset-prompt
					 return $ret

			fi
			# if [[ -f "$dir" ]]; then
			# 			LBUFFER="vi ${(q)dir}"
			# 			return 0
			# fi
			# # unset dir # ensure this doesn't end up appearing in prompt expansion
			# # zle reset-prompt
			local ret=$?
			return $ret
	 fi
}
zle     -N    _zm_fuzzy_dir_jump_increment_edit


# zsh fuzzy jump binding (files)
_zm_fuzzy_file_jump(){
	 local zm_line=$("$FUZZY_CMD" <"$ZM_FILES_FILE")
	 if [[ -n $zm_line ]];then 
			local zm_file_path="${zm_line%%|*}"
			eval "_zm_zoom \"$zm_file_path\""
	 fi
}
zle     -N    _zm_fuzzy_file_jump

_zm_quick_man(){
	 local currbuff=${BUFFER}
	 local cmd=$(echo "$currbuff"|cut -f1 -d' ')
	 [ -n "$cmd" ] && man "$cmd"
	 zle reset-prompt
	 LBUFFER="$currbuff"
}
zle     -N   _zm_quick_man

# function buildcache(){
# 	 local cachedir="${XDG_CACHE_HOME:-"$HOME/.cache"}"
# 	 local cache="$cachedir/dmenu_run"

# 	 [ ! -e "$cachedir" ] && mkdir -p "$cachedir"

# 	 IFS=:
# 	 if stest -dqr -n "$cache" $PATH; then
# 		 stest -flx $PATH | sort -u > "$cache"
# 	 else
# 		 cat "$cache"
# 	 fi
# }

# function buildcache(){
# 	 echo $PATH
# 	 cachedir="${XDG_CACHE_HOME:-"$HOME/.cache"}"
# 	 cache="$cachedir/dmenu_run"

# 	 [ ! -e "$cachedir" ] && mkdir -p "$cachedir"

# 	 IFS=:
# 	 if stest -dqr -n "$cache" $PATH; then
# 			echo 'true'
# 		 stest -flx $PATH | sort -u | tee "$cache"
# 	 else
# 			echo 'not true'
# 		 stest -flx $PATH | sort -u | tee "$cache"
# 		 # cat "$cache"
# 	 fi
# }


# # Good stuff but not being used

# # function __ask_to_overwrite_zm_dir() {
# # 	 usage='usage: ${FUNCNAME[0]} to-overwrite <replacement> [dir-path]'
# # 	 [ ! $# -ge 2 ] && echo "$usage" && return 1 

# # 	 local zm_clash zm_new_name zm_path
# # 	 zm_clash="$1"
# # 	 zm_new_name="$2"


# # 	 # [[ -n "$3" ]] && zm_path=$(eval "readlink -e $3") || zm_path=$(eval "readlink -e $PWD")
# # 	 [[ -n "$3" ]] && zm_path=$(eval "readlink -e $3") || zm_path="$PWD"
# # 	 # echo "zmarks/init.zsh: 396 zm_path: $zm_path"

# # 	 echo -e "overwrite: $(_zm_show $zm_clash)"
# # 	 # printf "replacement: $zm_new_name\t-- $zm_path\n"
# # 	 printf "replacement: $zm_new_name\t-- ${zm_path/#$HOME/~}\n"

# # 	 echo -n "overwrite mark $1 (y/n)? "
# # 	 read answer
# # 	 if  [ "$answer" != "${answer#[Yy]}" ];then 

# # 		_zm_remove "$zm_clash" && _zm_mark_dir "$zm_new_name" "$zm_path" 

# # 	 else
# # 			echo 'abort'
# # 	 fi
# # 	 return
# # }

# # function __ask_to_overwrite_zm_file() {
# # 	 local overwrite replacement zm_path
# # 	 overwrite="$1"
# # 	 replacement="$2"
# # 	 zm_path="$3"
# # 	 echo "overwrite: $overwrite"
# # 	 echo "replacement: $replacement"

# # 	 echo -n "overwrite mark $1 (y/n)? "
# # 	 read answer
# # 	 if  [ "$answer" != "${answer#[Yy]}" ];then 
# # 		_zm_remove "$overwrite"
# # 		_zm_mark_file "$replacement" "$zm_path"
# # 	 else
# # 		return 1
# # 	 fi
# # }

# # zm_path="${foo%%|*}"
# # zm_name="${foo##*|}"
