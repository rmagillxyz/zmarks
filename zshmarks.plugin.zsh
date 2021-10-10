#!/bin/zsh

# ------------------------------------------------------------------------------
#        FILE:  zsharks.plugin.zsh
#        AUTHOR: Robert Magill
#        FORKED_FROM:  Jocelyn Mallon
#        VERSION: 0.7
#        DEPENDS: fzf
# ------------------------------------------------------------------------------

# zm_path="${foo%%|*}"
# zm_name="${foo##*|}"

[[ -d $ZDOTDIR ]] && fpath=("$ZDOTDIR/zmarks/functions" $fpath)

RED='\033[0;31m'
NOCOLOR='\033[0m'

# echo "zmarks/zmarks.plugin.zsh: 16 EDITOR : $EDITOR "
if [[ -z $EDITOR ]]; then
	 echo "set \$EDITOR environment variable to choose editor"
	 echo "defaulting to nvim or vim"
	 if [[ -n $(command -v nvim) ]]; then 
			EDITOR="$(command -v nvim)"
	 else
			EDITOR="$(command -v vim)"
	 fi
fi

# Allows for a user to configure ZMARKS_DIR location.
[[ -z "$ZMARKS_DIR" ]] \
	 && export ZMARKS_DIR="$HOME/.local/share/zsh"

[[ ! -d "$ZMARKS_DIR" ]] \
	 && mkdir -p "$ZMARKS_DIR" && echo "created ZMARKS_DIR: $ZMARKS_DIR " 

[[ -z "$ZM_ZOOM_MARK" ]] \
	 && export ZM_ZOOM_MARK="__zm_zoom__"

export ZM_DIRS_FILE="$ZMARKS_DIR/zm_dirs"
export ZM_FILES_FILE="$ZMARKS_DIR/zm_files"
export ZM_NAMED_DIRS="$ZMARKS_DIR/zm_named_dirs"
export ZM_NAMED_FILES="$ZMARKS_DIR/zm_named_files" 

touch "$ZM_FILES_FILE"
touch "$ZM_DIRS_FILE"
touch "$ZM_NAMED_FILES"
touch "$ZM_NAMED_DIRS"

[[ -L "$ZM_DIRS_FILE" ]] \
	&& ZM_DIRS_FILE=$(eval "readlink -e $ZM_DIRS_FILE")
[[ -L "$ZM_FILES_FILE" ]] \
	&& ZM_FILES_FILE=$(eval "readlink -e $ZM_FILES_FILE")

# TODO could have options to rebuild one or the other or even most recent line and source
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
	 hash -d -r 
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

function _zm_mark_dir() {
	 local new_zm_name new_zm_path new_zm_line
	 new_zm_name="$1"
	 new_zm_path="$2"

	 if [[ -z $new_zm_name ]]; then
			new_zm_name="${PWD##*/}"
	 fi
	 
	 [[ -z "$new_zm_path" ]] \
			&& new_zm_path=$(eval "readlink -e $PWD") \
			|| new_zm_path=$(eval "readlink -e $2")


	 if [[ ! "$new_zm_name" =~ '^[[:alnum:]]+[a-zA-Z0-9]?' ]]; then
			echo 'Mark names must start with an alphanumeric and must only contain alphanumerics, dashes or underscores'
			return 1
	 fi

	 [[ -z "$new_zm_path" ]] \
			&& echo "path does not exist" && return 1

	 if [[ ! "${new_zm_path//[0-9A-Za-z-_.\/]/}" = "" ]]; then
			echo 'Path must only contain alphanumeric characters'
			return 1
	 fi


	 # Store the zmark as directory|name
	 if [[ "$new_zm_path" =~ ^"$HOME"(/|$) ]]; then
			new_zm_line="\$HOME${new_zm_path#$HOME}|$new_zm_name"
	 else
			new_zm_line="$new_zm_path|$new_zm_name"
	 fi

# 	 # Store the zmark as directory|name
# 	 [[ "$new_zm_path" =~ ^"$HOME"(/|$) ]] \
# 			&& new_zm_line="\$HOME${new_zm_path#$HOME}|$new_zm_name" \
# 			|| new_zm_line="$new_zm_path|$new_zm_name"

	 echo "zmarks/init.zsh: 125 new_zm_line: $new_zm_line"

	 for line in $(cat $ZM_DIRS_FILE) 
	 do
			if [[ "$line" == "$new_zm_line" ]]; then 
				 echo "umm, like, you already have this EXACT dir zmark." 
				 return 

			elif [[ $(eval "readlink -f ${line%%|*}") == $(eval "readlink -e $new_zm_path") ]]; then


				local zm_clashed_path zm_clash_name
				__zm_line_parse "$line" zm_clashed_path zm_clash_name

				printf "${RED}zmark path is already being used:\n$zm_clash_name\t--  $zm_clashed_path${NOCOLOR}\n"

				__ask_to_overwrite_zm_dir "$zm_clash_name" "$new_zm_name" "$new_zm_path"
				return 
		 fi
	done

	! __zm_check_name_clash "$new_zm_name" && return
	! __zm_check_hash_clash && return

	# no duplicates, make mark
	echo "$new_zm_line" >> $ZM_DIRS_FILE
	echo "directory mark '$new_zm_name' saved"

	# echo "hash -d $new_zm_name=$zm_path" >> "$new_zm_nameD_DIRS"
	# echo "Created named dir ~$new_zm_name"
	# source "$new_zm_nameD_DIRS"
	_zm_rebuild_hash_table
	# echo 'named dir sourced'
	return 
}

function __zmarks_zgrep() {
	 local outvar="$1"; shift
	 local pattern="$1"
	 local filename="$2"
	 local file_contents="$(<"$filename")"
	 local contents_array; contents_array=(${(f)file_contents})


	 for line in "${contents_array[@]}"; do
			if [[ "$line" =~ "$pattern" ]]; then
				 echo "zmarks/init.zsh: 187 line: $line"
				 eval "$outvar=\"$line\""
				 # eval "$outvar=\"$HOME/slate|sla\""
				 return 
			fi
	 done
	 return 1
}

function _zm_jump() {
	 if [[ -z $1 ]];then
			cd ~
			return 
	 fi

	 local zm_name=$1
	 local zm
	 if ! __zmarks_zgrep zm "\\|$zm_name\$" "$ZM_DIRS_FILE"; then
			if ! __zmarks_zgrep zm "\\|$zm_name\$" "$ZM_FILES_FILE"; then
				 echo "Invalid name, please provide a valid file or directory mark name. For example:"
				 echo "zm -j <MARK> [PATTERN]"
				 echo
				 echo "To mark a directory:"
				 echo "zm -m <NAME>"
				 echo "To mark a file:"
				 echo "zm -d  <NAME>"
				 return 1
			else
				 # File mark found
				 local zm_path="${zm%%|*}"
				 _zm_zoom "$zm_path" "$2"
			fi

	 else
			# Directory mark found
			local dir="${zm%%|*}"
			eval "cd \"${dir}\""
			eval "ls \"${dir}\""
	 fi
}

function _zm_show() {
	 local zm_file=$(<"$ZM_DIRS_FILE" <"$ZM_FILES_FILE")
	 local zm_array; zm_array=(${(f)zm_file});
	 local zm_name zm_path zm_line
	 zmarks=()

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
				 # echo 'printing formatted line'
				 __zm_line_printf "$zm_line"
			done
	 fi
}

# TODO write format function for hash -d from line

__zm_line_parse(){
	 USAGE="
	 ${FUNCNAME[0]}  zm_line path_variable_to_set name_variable_to_set 
	 "
	 local zm_line="$1"
	 local outpath outname
	 local outpath="${zm_line%%|*}"
	 local outpath="${outpath/\$HOME/~}"
	 local outname="${zm_line#*|}"

	 if [[ "$#" -eq 3 ]]; then
			eval "$2=\"$outpath\""
			eval "$3=\"$outname\""
	 else
			echo "$USAGE"
	 fi
}

__zm_line_printf() {
	 USAGE="${FUNCNAME[0]} zm_line"
	 if [[ ! "$#" -eq 1 ]]; then
			echo "$USAGE"
	 fi

	 local zm_line="$1"
	 local path name
	 __zm_line_parse "$zm_line" path name

	 if [[ ${#name} -gt 7 ]]; then
			# echo "${#name} is greater than 7"
	 	 printf "%s\t-- %s\n" "$name" "$path"
	 else
			# echo "${#name} is not greater than 7"
	  printf "%s\t\t-- %s\n" "$name" "$path"
	 fi
}

# function __zm_line_printf() {
# 	 USAGE="${FUNCNAME[0]} zm_line"
# 	 if [[ ! "$#" -eq 1 ]]; then
# 			echo "$USAGE"
# 	 fi
# 	 local zm_line="$1"
# 	 local path name
# 	 __zm_line_parse "$zm_line" path name
# 	 printf "%s\t\t--  %s\n" "$name" "$path"
# }

function _zm_remove()  {
	 local zm_name="$1"
	 local zm_file="${2:-$ZM_DIRS_FILE}"
	 if [[ -z $zm_name ]]; then
			printf "%s \n" "Please provide a mark name to remove. For example:"
			printf "\t%s \n" "zm -r foo"
			return 1
	 else
			local zm_line zm_search
			local file_contents="$(<"$zm_file")"
			local zm_array; zm_array=(${(f)file_contents});
			zm_search="*\|${zm_name}"
			if [[ -z ${zm_array[(r)$zm_search]} ]]; then
				 if [[ $zm_file == $ZM_DIRS_FILE ]]; then
						# name not found in dirs, run again with files
						_zm_remove "$zm_name" "$ZM_FILES_FILE"
				 else
						eval "printf '%s\n' \"'${zm_name}' not found.\""
						return 1
				 fi
			else
				 \cp "${zm_file}" "${zm_file}.bak"
				 zm_line=${zm_array[(r)$zm_search]}
				 zm_array=(${zm_array[@]/$zm_line})

				 [[ ${#zm_array[@]} -gt 0 ]] \
						&& eval "printf '%s\n' \"\${zm_array[@]}\"" > "$zm_file" \
						|| echo -n > "$zm_file"

				 __zm_move_to_trash "${zm_file}.bak" 
				 echo "$zm_name removed"

				 _zm_rebuild_hash_table
				 return 
			fi
	 fi
}

function __zm_clear_all(){
	 __zm_move_to_trash "$ZM_DIRS_FILE"
	 __zm_move_to_trash "$ZM_FILES_FILE"
}

function __zm_clear_all_dirs(){
	 __zm_move_to_trash "$ZM_DIRS_FILE"
}

function __zm_clear_all_files(){
	 __zm_move_to_trash "$ZM_FILES_FILE"
}

function __ask_to_overwrite_zm_dir() {
	 usage='usage: ${FUNCNAME[0]} to-overwrite <replacement> [dir-path]'
	 [ ! $# -ge 2 ] && echo "$usage" && return 1 

	 local zm_clash zm_new_name zm_path
	 zm_clash="$1"
	 zm_new_name="$2"


	 # [[ -n "$3" ]] && zm_path=$(eval "readlink -e $3") || zm_path=$(eval "readlink -e $PWD")
	 [[ -n "$3" ]] && zm_path=$(eval "readlink -e $3") || zm_path="$PWD"
	 # echo "zmarks/init.zsh: 396 zm_path: $zm_path"

	 echo -e "overwrite: $(_zm_show $zm_clash)"
	 # printf "replacement: $zm_new_name\t-- $zm_path\n"
	 printf "replacement: $zm_new_name\t-- ${zm_path/#$HOME/~}\n"

	 echo -n "overwrite mark $1 (y/n)? "
	 read answer
	 if  [ "$answer" != "${answer#[Yy]}" ];then 
			
		_zm_remove "$zm_clash" && _zm_mark_dir "$zm_new_name" "$zm_path" 
			
	 else
			echo 'abort'
	 fi
	 return
}

# jump to ZM_ZOOM_MARK in marked file
function _zm_zoom() {
	 local file_path=$1
	 if [[ -z $2 ]]; then
			has_zoom_mark=$(grep "$ZM_ZOOM_MARK" "$file_path")
			if [[ -n $has_zoom_mark ]]; then
				 "$EDITOR" +/"$ZM_ZOOM_MARK" "$file_path"	
			else
				 "$EDITOR" "$file_path"
			fi
	 else
			"$EDITOR" +/"$2" "$file_path"	
	 fi
}

# TODO add command comletion 
# add checks to for type and file to only allow editable commands
function _zm_vi() {
	 local cmd pattern c_path 
	 cmd="$1"
	 pattern="$2"
	 c_path=$(command -v $cmd)
	 echo "zmarks/init.zsh: 465 c_path: $c_path"
	 if [[ -z "$c_path" ]];then
			echo 'script not in path'
	 else
			_zm_zoom "$c_path" "$pattern"
	 fi
}

# TODO
# could just get rid of this and source any files which reside in ZDOTDIR immediately
function _zm_jump_n_source() {
	 _zm_file_jump "$1" "$2"
	 source ~"$1"
}

# jump to file mark
function _zm_file_jump() {
	 local editmark_name=$1
	 local editmark
	 if ! __zmarks_zgrep editmark "\\|$editmark_name\$" "$ZM_FILES_FILE"; then
			echo "Invalid name, please provide a valid mark name. For example:"
			echo "_zm_jump foo [pattern]"
			echo
			echo "To mark a directory:"
			echo "zm <name>"
			echo "To mark a file:"
			echo "zmf <name>"
			return 1
	 else
			local filename="${editmark%%|*}"
			# _ezoom "$filename" "$2"
			_zm_zoom "$filename" "$2"
	 fi
}

# jump to dir mark
function _zm_dir_jump() {
	 local zmark_name=$1
	 local zmark
	 if ! __zmarks_zgrep zmark "\\|$zmark_name\$" "$ZM_DIRS_FILE"; then
			echo "Invalid directory mark name, please provide a valid mark name. For example:"
			echo "_zm_dir_jump foo [pattern]"
			echo
			echo "To mark a directory:"
			echo "zm <name>"
			echo "To mark a file:"
			echo "zmf <name>"
			return 1
	 else
			local dir="${zmark%%|*}"
			eval "cd \"${dir}\""
			eval "ls \"${dir}\""
	 fi
}

function _zm_mark_file() {
	 local new_zm_name new_zm_path new_zm_line
	 new_zm_name="$1"
	 new_zm_path="$2"

	 if [[ -z $new_zm_name ]]; then
			echo 'mark name required'
			return 1
	 fi

	 if [[ ! "$new_zm_name" =~ '^[[:alnum:]]+[a-zA-Z0-9]?' ]]; then
			echo 'Mark names must start with an alphanumeric and must only contain alphanumerics, dashes or underscores'
			return 1
	 fi

	 echo "zmarks/init.zsh: 530 new_zm_path: $new_zm_path"
	 [[ -n $(eval "readlink -e  $new_zm_path") ]] \
	 && echo "zmarks/init.zsh: 530 new_zm_path: $new_zm_path"
	 # if mark name matches file from cwd, automatically use that file path
	 local exactmatchfromcwd=$(\ls $(pwd) | grep -x "$new_zm_name")
	 if [[ -z "$new_zm_path" && -n "$exactmatchfromcwd" ]]; then
			#could use find here
			cur_dir="$(pwd)"
			new_zm_path="$cur_dir"
			new_zm_path+="/$new_zm_name"

	 elif [[ -n "$new_zm_path" ]] && [[ -n $(eval "readlink -e  $new_zm_path") ]]; then
			# echo "zmarks/init.zsh: 540 new_zm_path: $new_zm_path"
			new_zm_path=$(eval "readlink -e $new_zm_path")
			# echo "zmarks/init.zsh: 499 new_zm_path: $new_zm_path"

	 else
			new_zm_path="$(find -L $(pwd) -maxdepth 4 -type f 2>/dev/null | fzf-tmux)"
			if [[ -z "$new_zm_path" ]]; then
				 echo 'abort'
				 return 1
			fi

	 fi

	 if [[ ! "${new_zm_path//[0-9A-Za-z-_.\/]/}" = "" ]]; then
			echo 'Path must only contain alphanumeric characters'
			return 1
	 fi

		# Replace /home/$USER with $HOME
	 if [[ "$new_zm_path" =~ ^"$HOME"(/|$) ]]; then
			new_zm_path="\$HOME${new_zm_path#$HOME}"
	 fi

	 echo "zmarks/init.zsh: 565 new_zm_name: $new_zm_name"
	 echo "zmarks/init.zsh: 565 new_zm_path: $new_zm_path"
	 # Store the zm as directory|name
	 new_zm_line="$new_zm_path|$new_zm_name"
	 echo "zmarks/init.zsh: 565 new_zm_line: $new_zm_line"

	 ! __zm_check_path_clash  "$new_zm_line" && return
	 ! __zm_check_name_clash "$new_zm_name" && return
	 ! __zm_check_hash_clash && return

	 if [[ -n "$new_zm_name" && -n "$new_zm_path" ]]; then
		 echo "$new_zm_line" >> "$ZM_FILES_FILE"
		 echo "zmark file '$new_zm_name' saved"

		 # echo "hash -d $new_zm_name=$new_zm_path" >> "$ZM_NAMED_FILES"
		 # TODO zmf ZM_NAMED_FILES is empty here!!! ZM_NAMED_FILES
		 echo "hash -d $new_zm_name=$new_zm_path" >> "$ZM_NAMED_FILES"
		 echo "Created named file ~$new_zm_name"
		 source "$ZM_NAMED_FILES"
	 else
		 echo "something went wrong. Mark or path is not assigned"
	 fi
}

function __zm_check_hash_clash(){
	 # check there are no named hash collisions set by something other than this program
	 local hash_already_exists=$(hash -dm "$zm_name")
	 if [[ -n $hash_already_exists ]]; then
			printf "${RED} ~$zm_name named hash clashes: $hash_already_exists ${NOCOLOR}\n"
			echo 'If you created this, you can remove it and run again, but this could have been set by another program. If you did not create it, I would just choose another name.'
			# eval "$clash_fail=true"
			return 1 
	 fi
}

function __zm_check_name_clash(){
	 # usage='usage: ${FUNCNAME[0]} zm_clash $zm_name $zm_file'

	 # local clash_fail="$1"; shift
	 local zm_name="$1"
	 # local zm_file="$ZM_FILES_FILE" # ZM_FILES_FILE or ZM_DIRS_FILE

	 local clash

	 __checktoremove(){
			local zm_name="${clash##*|}"
			read answer
			if  [ "$answer" != "${answer#[Yy]}" ];then 
				 _zm_remove "$zm_name"
			else
				 # eval "$clash_fail=true"
				 echo 'abort'
				 return  1
			fi
	 }

	 # check file and dir marks for name collision
	 if  __zmarks_zgrep clash "\\|$zm_name\$" "$ZM_FILES_FILE"; then
			printf "${RED}name clashes with marked file: $clash${NOCOLOR}\n"
			echo -n "Remove '$zm_name' file mark? (y/n)?"
			__checktoremove "$clash"
	 elif  __zmarks_zgrep clash "\\|$zm_name\$" "$ZM_DIRS_FILE"; then
			printf "${RED}name clashes with directory mark : $clash${NOCOLOR}\n"
			echo -n "delete directory mark?: $clash (y/n)? "
			__checktoremove "$clash"
	 fi

}

function __ask_to_overwrite_zm_file() {
	 local overwrite replacement zm_path
	 overwrite="$1"
	 replacement="$2"
	 zm_path="$3"
	 echo "overwrite: $overwrite"
	 echo "replacement: $replacement"

	 echo -n "overwrite mark $1 (y/n)? "
	 read answer
	 if  [ "$answer" != "${answer#[Yy]}" ];then 
		_zm_remove "$overwrite"
		_zm_mark_file "$replacement" "$zm_path"
	 else
		return 1
	 fi
}

function __zm_check_path_clash(){
	 echo "zmarks/init.zsh: 688 __zm_check_path_clash"
	 local new_zm_line zm_clashed_path zm_clash_name
	 new_zm_line="$1"
	 echo "zmarks/init.zsh: 645 new_zm_line: $new_zm_line"

# while read -r line 
# do
# 	echo "$line"
# done < $ZM_DIRS_FILE

	 for line in $(cat $ZM_DIRS_FILE) 
	 # while read -r line 
	 do
			if [[ "$line" == "$new_zm_line" ]]; then 
				 echo "umm, like, you already have this EXACT dir zmark." 
				 return 1 

			elif [[ $(eval "readlink -f ${line%%|*}") == $(eval "readlink -e $new_zm_path") ]]; then
				__zm_line_parse "$line" zm_clashed_path zm_clash_name

				printf "${RED}mark path is already being used on directory:\n$zm_clash_name\t--  $zm_clashed_path${NOCOLOR}\n"

				__ask_to_overwrite_zm_dir "$zm_clash_name" "$new_zm_name" "$new_zm_path"
				return 1 
		 fi
	# done < "$ZM_DIRS_FILE"
	 done

	 for line in $(cat $ZM_FILES_FILE) 
	 # while read -r line 
			do
				 if [[ "$line" == "$new_zm_line" ]]; then 
						echo "umm, like, you already have this EXACT dir zmark." 
						return 1 

				 elif [[ $(eval "readlink -f ${line%%|*}") == $(eval "readlink -f ${new_zm_line%%|*}") ]]; then
					 __zm_line_parse "$line" zm_clashed_path zm_clash_name

					 printf "${RED}mark path is already being used on file:\n$zm_clash_name\t--  $zm_clashed_path${NOCOLOR}\n"

					 echo "zmarks/init.zsh: 679 zm_clashed_path: $zm_clashed_path"
					 __ask_to_overwrite_zm_file "$zm_clash_name" "$new_zm_name" "$zm_clashed_path" 
					 return 1
				fi
		 # done < "$ZM_FILES_FILE"
		 done
} 


function zm(){
	 local USAGE="Usage: zm <OPTION> <MARK>
	 -d, --dir-jump <DIR-MARK> \t\t Jump to directory mark. 
	 -D, --mark-dir [MARK-NAME] \t\t Mark directory. Will use current directory name if not specified. 
	 -f, --file-jump <FILE-MARK> [PATTERN] \t Jump to file mark and search for optional pattern. 
	 -F, --mark-file <MARK-NAME> [FILE] \t Mark file. Will use fzf to select from files in current dir if not specified.  
	 -j, --jump MARK \t\t\t Jump to directory or jump into file.
	 -s, --show <MARK> \t\t\t Will try to match or show all if not specified.   
	 -h, --help \t\t\t\t Show this message.
	 "

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
						# [[  $# -lt 1  ]] && usage && return 
						_zm_jump "$@"
						# echo "you are here: $PWD "
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

				 -h|--help)
						echo $USAGE
						return
						;; 

				 esac

			else
				 echo $USAGE
				 return
	 fi

}

# FZF bindings 

# zsh fzf jump binding (all)
_fzf_zm_jump(){
	 local zm=$(<"$ZM_DIRS_FILE" <"$ZM_FILES_FILE" | fzf-tmux)
	 local dest="${zm%%|*}"
	 [[ -z "$dest" ]] && zle reset-prompt && return 1

	 # could also use zgrep here
	 # if ! __zmarks_zgrep zm "\\|$zm_name\$" "$ZM_DIRS_FILE"; then
	 # TODO why do I need eval here?
	 if [ -d $(eval "echo $dest") ]; then
			echo "we gotta dir"
			eval "cd \"$dest\""
			ls
			echo -e "\n"
	 else
			echo "we gotta file"
			eval "_zm_zoom \"$dest\""
	 fi
	 zle reset-prompt
}
zle     -N    _fzf_zm_jump

# zsh fzf jump binding (dirs)
_fzf_zm_dir_jump(){
	 local zm=$(< $ZM_DIRS_FILE | fzf-tmux)
	 if [[ -n $zm ]];then 
			local dir="${zm%%|*}"
			eval "cd ${dir}"
			ls
			echo -e "\n"
			zle reset-prompt
	 fi
}
zle     -N    _fzf_zm_dir_jump

# zsh fzf jump binding (files)
_fzf_zm_file_jump(){
	 local zm=$(cat $ZM_FILES_FILE | fzf-tmux)
	 if [[ -n $zm ]];then 
			local file="${zm%%|*}"
			# could use BUFFER and _zm_zoom here
			# eval "\"$EDITOR\" \"$file\""
			eval "_zm_zoom \"$file\""
	 fi
}
zle     -N    _fzf_zm_file_jump


