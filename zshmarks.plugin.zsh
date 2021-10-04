#!/bin/zsh

# ------------------------------------------------------------------------------
#        FILE:  zsharks.plugin.zsh
#        AUTHOR: Robert Magill
#        FORKED_FROM:  Jocelyn Mallon
#        VERSION: 0.7
#        DEPENDS: fzf
# ------------------------------------------------------------------------------


 [[ -d $ZDOTDIR ]] && fpath=("$ZDOTDIR/zmarks/functions" $fpath)

# if [[ -z $ZDOTDIR ]];then
# 	 fpath=("$HOME/.config/zsh/zmarks/functions" $fpath)
# else
# 	 fpath=("$ZDOTDIR/zmarks/functions" $fpath)
# fi

# dir="${foo%%|*}"
# zm="${foo##*|}"
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

# Set ZMARKS_DIR if it doesn't exist to the default.
# Allows for a user-configured ZMARKS_DIR.
if [[ -z $ZMARKS_DIR ]] ; then
	 [[ ! -d "$HOME/.local/share/zsh" ]] && mkdir -p "$HOME/.local/share/zsh" 
	 ZMARKS_DIR="$HOME/.local/share/zsh"
fi

ZM_DIRS_FILE="$ZMARKS_DIR/zm_dirs"
ZM_FILES_FILE="$ZMARKS_DIR/zm_files"
ZM_NAMED_DIRS="$ZMARKS_DIR/zm_named_dirs"
ZM_NAMED_FILES="$ZMARKS_DIR/zm_named_files"
ZM_ZOOM_MARK="__zm_zoom__"

# TODO should i just touch these or check if they exist and touch? 
touch "$ZM_FILES_FILE"
touch "$ZM_DIRS_FILE"
touch "$ZM_NAMED_FILES"
touch "$ZM_NAMED_DIRS"



	 ## could just remove one instead of rebuilting
	 function _gen_zmarks_named_dirs(){
			if [[  -f "$ZM_NAMED_DIRS" ]]; then
				 \rm -f "$ZM_NAMED_DIRS"
			fi

				 while read line
				 do
						if [[ -n "$line" ]]; then
							 dir="${line%%|*}"
							 bm="${line##*|}"
							 echo "~$bm"
							 echo "hash -d $bm=$dir" >> "$ZM_NAMED_DIRS"
						fi
				 done < "$ZM_DIRS_FILE"
				 return 
	 }

	 function _gen_zmarks_named_files(){
			if [[  -f "$ZM_NAMED_FILES" ]]; then
				 \rm -f "$ZM_NAMED_FILES"
			fi

				 while read line
				 do
						if [[ -n "$line" ]]; then
							 dir="${line%%|*}"
							 bm="${line##*|}"
							 echo "~$bm"
							 echo "hash -d $bm=$dir" >> "$ZM_NAMED_FILES"
						fi
				 done < "$ZM_FILES_FILE"
				 return 
	 }

	 function zm_rebuild_hash_table(){
			# generate new named dir to sync with marks
			hash -d -r  # rebuild hash table
			_gen_zmarks_named_dirs 1> /dev/null
			_gen_zmarks_named_files 1> /dev/null
			# echo 'rebuild hash table'
			# echo "Deleted and synced named hashes"
	 }

	 zm_rebuild_hash_table

	 # Check if $ZMARKS_DIR is a symlink.
	 if [[ -L "$ZM_DIRS_FILE" ]]; then
			ZM_DIRS_FILE=$(readlink $ZM_DIRS_FILE)
	 fi

	 if [[ -L "$ZM_FILES_FILE" ]]; then
			ZM_FILES_FILE=$(readlink $ZM_FILES_FILE)
	 fi

	 # if [[ ! -f $ZM_DIRS_FILE  ]]; then
	 # 	 touch $ZM_DIRS_FILE
	 # else 
	 # 	 _gen_zmarks_named_dirs 1> /dev/null
	 # 	 _gen_zmarks_named_files 1> /dev/null
	 # fi

	 # _gen_zmarks_named_dirs 1> /dev/null
	 # _gen_zmarks_named_files 1> /dev/null

		[ -f $ZM_NAMED_DIRS ] && source "$ZM_NAMED_DIRS" 
		[ -f $ZM_NAMED_FILES ] && source "$ZM_NAMED_FILES" 


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

	 function zm_mark_dir() {
			local zm_name=$1
			if [[ -z $zm_name ]]; then
				 zm_name="${PWD##*/}"
			fi
			cur_dir="$(pwd)"
			# Replace /home/uname with $HOME
			if [[ "$cur_dir" =~ ^"$HOME"(/|$) ]]; then
				 cur_dir="\$HOME${cur_dir#$HOME}"
			fi

			 # Store the zmark as directory|name
			 local new_zm_line="$cur_dir|$zm_name"

		 # TODO: this could be sped up sorting and using a search algorithm
		 for line in $(cat $ZM_DIRS_FILE) 
		 do

				if [[ "$line" == "$cur_dir|$zm_name" ]]; then 
					 echo "umm, you already have this EXACT dir zmark, bro" 
					 return 
				fi 

				if [[ $(echo $line |  awk -F'|' '{print $2}') == $zm_name ]]; then

					 printf "\n${RED}zmark name is already being used:\n$(zm_show $zm_name)${NOCOLOR}\n"

					 echo -n "Remove $zm_name?  (y/n)? "
						read answer
						if  [ "$answer" != "${answer#[Yy]}" ];then 
							 zm_rm $zm_name
							 zm $zm_name
							 return 
						fi

				elif [[ $(echo $line |  awk -F'|' '{print $1}') == $cur_dir  ]]; then

					 local zm_clashed_path zm_clashed_path_name
						__zm_line_parse "$line" zm_clashed_path zm_clashed_path_name

						 printf "${RED}zmark path is already being used:\n$zm_clashed_path_name\t--  $zm_clashed_path${NOCOLOR}\n"
					 
					 __ask_to_overwrite_zm_dir $zm_clashed_path_name $zm_name
					 return 1
				fi
		 done

		 local zm_clash_fail
		 __zm_checkclash zm_clash_fail "$zm_name" "$ZM_FILES_FILE"
		 [[ -n $zm_clash_fail ]] && echo "$zm_clash_fail" && return 1

		 # no duplicates, make mark
		 echo $new_zm_line >> $ZM_DIRS_FILE
		 echo "zmark '$zm_name' saved"

		 echo "hash -d $zm_name=$cur_dir" >> "$ZM_NAMED_DIRS"
		 echo "Created named dir ~$zm_name"
		 source "$ZM_NAMED_DIRS"
	 }

	 function __zmarks_zgrep() {
			local outvar="$1"; shift
			local pattern="$1"
			local filename="$2"
			# There was a BUG here, but now files should always exist
			# [[ ! -f $filename ]] && return
			local file_contents="$(<"$filename")"
			local file_lines; file_lines=(${(f)file_contents})


			for line in "${file_lines[@]}"; do
				 if [[ "$line" =~ "$pattern" ]]; then
						eval "$outvar=\"$line\""
						return 0
				 fi
			done
			return 1
	 }

	 # jump
	 function zm_jump() {
			if [[ -z $1 ]];then
				 cd ~
				 return 
			fi

			local zm_name=$1
			local zm
			if ! __zmarks_zgrep zm "\\|$zm_name\$" "$ZM_DIRS_FILE"; then
				 if ! __zmarks_zgrep zm "\\|$zm_name\$" "$ZM_FILES_FILE"; then
						echo "Invalid name, please provide a valid zmark name. For example:"
						echo "zm_jump foo [pattern]"
						echo
						echo "To mark a directory:"
						echo "zm <name>"
						echo "To mark a file:"
						echo "zmf <name>"
						return 1
				 else
						# echo 'DEBUG zm_jump: found file'
						local filename="${zm%%|*}"
						zm_zoom "$filename" "$2"
				 fi

			else
				 # echo 'DEBUG zm_jump: found dir'
				 local dir="${zm%%|*}"
				 eval "cd \"${dir}\""
				 eval "ls \"${dir}\""
			fi
			# return 
	 }

	 # Show a list of all the zmarks
	 function zm_show() {
			# zm_file is the contents of the file stored in a var
			local zm_file=$(<"$ZM_DIRS_FILE" <"$ZM_FILES_FILE")
			local zm_array; zm_array=(${(f)zm_file});
			local zm_name zm_path zm_line

			if [[ $# -eq 1 ]]; then
				 zm_name="*\|${1}"
				 zm_line=${zm_array[(r)$zm_name*]}
				 __zm_line_printf "$zm_line"
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
			printf "%s\t\t--  %s\n" "$name" "$path"
	 }

	 # remove a zm
	 function zm_rm()  {
			local zm_name="$1"
			local file_path="${2:-$ZM_DIRS_FILE}"
			if [[ -z $zm_name ]]; then
				 printf "%s \n" "Please provide a name for your zm to delete. For example:"
				 printf "\t%s \n" "zm_rm foo"
				 return 1
			else
				 local zm_line zm_search
				 local zm_file="$(<"$file_path")"
				 local zm_array; zm_array=(${(f)zm_file});
				 zm_search="*\|${zm_name}"
				 if [[ -z ${zm_array[(r)$zm_search]} ]]; then
						if [[ $file_path == $ZM_DIRS_FILE ]]; then
							 # name not found in dirs, run again with files
							 # TODO would it be better to check the named hash for file or dir and not run through all? 
							 zm_rm "$zm_name" "$ZM_FILES_FILE"
						else
							 eval "printf '%s\n' \"'${zm_name}' not found, skipping.\""
						fi
				 else
						\cp "${file_path}" "${file_path}.bak"
						zm_line=${zm_array[(r)$zm_search]}
						zm_array=(${zm_array[@]/$zm_line})
						eval "printf '%s\n' \"\${zm_array[@]}\"" >! $file_path

						__zm_move_to_trash "${file_path}.bak" 

						zm_rebuild_hash_table
						echo "Synced named hashes"
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
			usage='usage: ${FUNCNAME[0]} to-overwrite <replacement>'
			[ ! $# -ge 1 ] && echo "$usage" && return 1 

			local overwrite="$1"
			local replacement
			[[  $# -gt 1 ]] && replacement="$2" || replacement="$1"

			echo -e "overwrite: $(zm_show $overwrite)"
			# printf "overwrite: %s\n" $overwrite
			# printf "overwrite: %s\n" $(zm_show $overwrite)
			printf "replacement: $replacement\t-- ${cur_dir/\$HOME/~}\n"

			echo -n "overwrite mark $1 (y/n)? "
			read answer
			if  [ "$answer" != "${answer#[Yy]}" ];then 
				 zm_rm $1
				 zm $2
			else
				 return 1
			fi
	 }

	 # function zm_zoom() {
	 # 	 # if [[ -z  ]]
	 # 	 if [[ -z $2 ]]; then
	 # 			has_zoom_mark = grep '__zm_zoom__' "$filename"
	 # 			if [[ -n $has_zoom_mark ]]; then
	 # 				"$EDITOR" "$filename" "$ZM_ZOOM_MARK"
	 # 			else
	 # 				"$EDITOR" "$filename"
	 # 			fi
	 # 		 else
	 # 				"$EDITOR" "$filename" "$2"
	 # 	 			"$EDITOR" +/"$2" "$1"	
	 # 	 fi

	 # 	 # if [ -z "$2" ]; then
	 # 	 # 			"$EDITOR" "$1"
	 # 	 # else
	 # 	 # 			"$EDITOR" +/"$2" "$1"	
	 # 	 # fi
	 # }


	 # jump to marked file
	 function zm_zoom() {
			local filename=$1
				 if [[ -z $2 ]]; then
						has_zoom_mark=$(grep "$ZM_ZOOM_MARK" "$filename")
						if [[ -n $has_zoom_mark ]]; then
							"$EDITOR" +/"$ZM_ZOOM_MARK" "$filename"	
						else
							"$EDITOR" "$filename"
						fi
					 else
							"$EDITOR" +/"$2" "$filename"	
				 fi
	 }

	 # TODO add command comletion 
	 # add checks to for type and file to only allow editable commands
	 # add check for path to any file or path which exists
	 function zm_vi() {
		 local cmd pattern c_path 
		 cmd="$1"
		 pattern="$2"
		 c_path=$(command -v $cmd)
		 echo "zmarks/init.zsh: 465 c_path: $c_path"
		 if [[ -z "$c_path" ]];then
				echo 'script not in path'
		 else
			 zm_zoom "$c_path" "$pattern"
		 fi
	 }

	 # TODO
	 # could just get rid of this and source any files which reside in ZDOTDIR immediately
	 function zm_jump_n_source() {
			_zm_file_jump "$1" "$2"
			source ~"$1"
	 }

	 # works, but not currently being used
	 # jump to marked file
	 function _zm_file_jump() {
			local editmark_name=$1
			local editmark
			if ! __zmarks_zgrep editmark "\\|$editmark_name\$" "$ZM_FILES_FILE"; then
				 echo "Invalid name, please provide a valid zmark name. For example:"
				 echo "zm_jump foo [pattern]"
				 echo
				 echo "To mark a directory:"
				 echo "zm <name>"
				 echo "To mark a file:"
				 echo "zmf <name>"
				 return 1
			else
				 local filename="${editmark%%|*}"
				 # _ezoom "$filename" "$2"
				 zm_zoom "$filename" "$2"
			fi
	 }

	 # works, but not currently being used
	 # jump to marked dir
	 function _zm_dir_jump() {
			local zmark_name=$1
			local zmark
			if ! __zmarks_zgrep zmark "\\|$zmark_name\$" "$ZM_DIRS_FILE"; then
				 echo "Invalid directory zmark name, please provide a valid zmark name. For example:"
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

	 function zm_mark_file() {
			local zm_name="$1"

			local zm_file_path="$2"

			if [[ -z $zm_name ]]; then
				 echo 'zmark name required'
				 return 1
			fi

			local zm_clash_fail
			# __zm_checkclash zm_clash_fail "$zm_name" "$ZM_DIRS_FILE"
			__zm_checkclash zm_clash_fail "$zm_name" "$ZM_FILES_FILE"

			[[ -n $zm_clash_fail ]] && return 2

			local exactmatchfromdir=$(\ls $(pwd) | grep -x "$zm_name")

			if [[ -z $zm_file_path && -n $exactmatchfromdir ]]; then
				 #could use find here
				 cur_dir="$(pwd)"
				 zm_file_path="$cur_dir"
				 zm_file_path+="/$zm_name"

			elif [[ -z $zm_file_path ]]; then
				 zm_file_path="$(find -L $(pwd) -maxdepth 4 -type f 2>/dev/null | fzf-tmux)"
				 if [[ -z "$zm_file_path" ]]; then
						return 1
				 fi
			fi


			 # Replace /home/uname with $HOME
			 if [[ "$zm_file_path" =~ ^"$HOME"(/|$) ]]; then
					zm_file_path="\$HOME${zm_file_path#$HOME}"
			 fi

			 # Store the zm as directory|name
			 zm="$zm_file_path|$zm_name"

			 __ask_to_overwrite_zm_file() {
					usage='usage: ${FUNCNAME[0]} to-overwrite replacement'

					local overwrite=$1
					local replacement=$1
					[[  $# == 2 ]] && replacement=$2
					echo "overwrite: $overwrite"
					echo "replacement: $replacement"

					echo -n "overwrite mark $1 (y/n)? "
					read answer
					if  [ "$answer" != "${answer#[Yy]}" ];then 
						 zm_rm "$overwrite"
						 zmf "$replacement" "$zm_file_path"
					else
						 return 1
					fi
			 }

		 # TODO: this could be sped up by sorting and using a search algorithm
		 # refactor into function to deal with files and dirs
		 # check for duplicates
		 for line in $(cat $ZM_FILES_FILE) 
		 do

				if [[ "$line" == "$zm_file_path|$zm_name" ]]; then 
					 echo "umm, you already have this EXACT edit mark, bro" 
					 return 
				fi 	

				if [[ $(echo $line |  awk -F'|' '{print $2}') == $zm_name ]]; then
					 echo "zmarks file name already existed"
					 echo "old: $line"
					 echo "new: $zm"
					 __ask_to_overwrite_zm_file $zm_name 
					 return 1

				elif [[ $(echo $line |  awk -F'|' '{print $1}') == $zm_file_path  ]]; then
					 echo "zmark dir already existed"
					 echo "old: $line"
					 echo "new: $zm"
					 local zm_to_overwrite_name="${line##*|}"
					 __ask_to_overwrite_zm_file "$zm_to_overwrite_name" "$zm_name" 
					 return 1
				fi
		 done

		 if [[ -n "$zm_name" && -n "$zm_file_path" ]]; then
				echo $zm >> "$ZM_FILES_FILE"
				echo "zmark file '$zm_name' saved"

				# echo "hash -d $zm_name=$zm_file_path" >> "$ZM_NAMED_FILES"
				# TODO zmf ZM_NAMED_FILES is empty here!!! ZM_NAMED_FILES
				echo "hash -d $zm_name=$zm_file_path" >> "$ZM_NAMED_FILES"
				echo "Created named file ~$zm_name"
				source "$ZM_NAMED_FILES"
		 else
				echo "something went wrong. Mark or path is not assigned"
		 fi
	 }



	 function __zm_checkclash(){
			# usage='usage: ${FUNCNAME[0]} zm_clash_fail  $zm_name $ZM_X_FILE'

			local clash_fail="$1"; shift
			local zm_name="$1"
			local zm_path="$2"

			local clash

			__asktodelete(){
				 local zm="${clash##*|}"
				 read answer
				 if  [ "$answer" != "${answer#[Yy]}" ];then 
						zm_rm "$zm"
				 else
						eval "$clash_fail=true"
						return 1
				 fi
			}

			__zm_checkhashclash(){
				 local hash_already_exists=$(hash -dm "$zm_name")
				 if [[ -n $hash_already_exists ]]; then
						printf "${RED} ~$zm_name clashes. Named hash: $hash_already_exists ${NOCOLOR}\n"
						echo 'If you created this, you can remove it and run again, but this could have been set by another program on your machine. If you did not create it, I would just choose another name.'
						eval "$clash_fail=true"
						return 1
						fi
			}

			# check marks for collision
			if  __zmarks_zgrep clash "\\|$zm_name\$" "$zm_path"; then
				 # TODO BUG: true when file ZM_FILES_FILE does not exist. may be fixed
				 if [[ $zm_path == $ZM_FILES_FILE ]];then
						printf "${RED}name clashes with zmark file: $clash${NOCOLOR}\n"
						echo -n "delete zmark file?: $clash (y/n)? "
						__asktodelete "$clash"
				 else
						printf "${RED}name clashes with zmark dir: $clash${NOCOLOR}\n"
						echo -n "delete zmark directory?: $clash (y/n)? "
						__asktodelete "$clash"
				 fi
				 fi
				 __zm_checkhashclash 
	 }


			# USAGE="$(basename $0) [ -j, --jump MARK ] [ -s, --show <MARK> ] [ -f, --mark-file <MARK> ] [ -d, --mark-dir <MARK> ] [ -h --help ]"
			
			# usage(){
			# 	    echo -e "\nUsage: zm [OPTION]... [MARK]...\n  -j, --jump MARK \n  -s, --show <MARK> \n  -f, --mark-file <MARK> \n  -d, --mark-dir <MARK> \n  -h --help \n"
			# }
			
			# usage(){
			# 	echo  "
			# 	 -j jump to file or dir
			# 	 -s <MARK> \t\t\t Will try to match or show all if not specified.   
			# 	"
			# }
			
			usage(){
	    echo "Usage: zm [OPTION]... [MARK]...
  -j, --jump MARK \t\t\t Jump to directory or jump into file.
  -s, --show <MARK> \t\t\t Will try to match or show all if not specified.   
  -f, --mark-file <MARK> \t\t Mark file. Will use fzf to select from files in current dir if not specified.  
  -d, --mark-dir <MARK> \t\t Mark directory. Will use current directory name if not specified. 
  -h --help \t\t\t\t Show this message.
	"
			}


function zm(){

			if [[ $# -gt 0 ]]; then
				 key="$1"

				 case $key in

						 -j|--jump)
								shift
								# [[  $# -lt 1  ]] && usage && return 
								zm_jump "$@"
								# echo "you are here: $PWD "
								return
						 ;;

						 -s|--show)
								shift
								zm_show "$@"
								return
						 ;;
						 
						 -f|--mark-file)
								shift 
								zm_mark_file "$@"
								return
						 ;;
						 
						 -d|--mark-dir)
								shift 
								zm_mark_dir "$@"
								return
						 ;;

						 -rm|--remove)
								shift 
								zm_rm "$@"
								return
						 ;;

						 -h|--help)
							 # echo "$USAGE"
							 usage
							 return
						 ;; 

				 esac

			else
				 # echo "$USAGE"
				 usage
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
			eval "zm_zoom \"$dest\""
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
		 # could use BUFFER and zm_zoom here
		eval "\"$EDITOR\" \"$file\""
	 fi
}
zle     -N    _fzf_zm_file_jump


