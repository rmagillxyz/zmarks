# ------------------------------------------------------------------------------
#          FILE:  zshmarks.plugin.zsh
#        AUTHOR: Robert Magill
#        FORKED_FROM:  Jocelyn Mallon
#       VERSION:  1.7.1
#       DEPENDS: fzf
# ------------------------------------------------------------------------------


# dir="${foo%%|*}"
# bm="${foo##*|}"

# Set ZMARKS_DIR if it doesn't exist to the default.
# Allows for a user-configured ZMARKS_DIR.
if [[ -z $ZMARKS_DIR ]] ; then
    [[ ! -d "$HOME/.local/share/zsh" ]] && mkdir -p "$HOME/.local/share/zsh" 
		export ZMARKS_DIR="$HOME/.local/share/zsh"
fi

NAMED_DIRS="$ZMARKS_DIR/zmarks_named_dirs"
ZMARKS_FILE="$ZMARKS_DIR/zmarks"
ZEDITS_FILE="$ZMARKS_DIR/zedits"


# Check if $ZMARKS_DIR is a symlink.
if [[ -L "$ZMARKS_FILE" ]]; then
 ZMARKS_FILE=$(readlink $ZMARKS_FILE)
fi

_gen_zshmarks_named_dirs(){
   rm "$NAMED_DIRS"
   while read line
   do
      dir="${line%%|*}"
      bm="${line##*|}"
      echo "~$bm"
			echo "hash -d $bm=$dir" >> "$NAMED_DIRS"
	 done < "$ZMARKS_FILE"
	 return 
}

if [[ ! -f $ZMARKS_FILE ]]; then
		touch $ZMARKS_FILE
 else 
   _gen_zshmarks_named_dirs 1> /dev/null
fi


fpath=($fpath "$ZDOTDIR/zshmarks/functions")

[ -f "$NAMED_DIRS" ] && source "$NAMED_DIRS" 

_zshmarks_move_to_trash(){
	 local FILE_PATH="$1"
	 echo "zshmarks/init.zsh: 77 FILE_PATH: $FILE_PATH"
		if [[ $(uname) == "Linux"* || $(uname) == "FreeBSD"*  ]]; then
				label=`date +%s`
				mkdir -p ~/.local/share/Trash/info ~/.local/share/Trash/files
				\mv "$FILE_PATH" ~/.local/share/Trash/files/$(basename "$FILE_PATH")-$label
				echo "[Trash Info]
				Path="$FILE_PATH"
				DeletionDate="`date +"%Y-%m-%dT%H:%M:%S"`"
				">~/.local/share/Trash/info/$(basename "$FILE_PATH")-$label.trashinfo
		elif [[ $(uname) = "Darwin" ]]; then
				\mv "$FILE_PATH" ~/.Trash/$(basename "$FILE_PATH")$(date +%H-%M-%S) 
		else
				\rm -f "$FILE_PATH"
		fi
}

function bookmark() {
		local bookmark_name=$1
		if [[ -z $bookmark_name ]]; then
				bookmark_name="${PWD##*/}"
		fi
		cur_dir="$(pwd)"
		# Replace /home/uname with $HOME
		if [[ "$cur_dir" =~ ^"$HOME"(/|$) ]]; then
				cur_dir="\$HOME${cur_dir#$HOME}"
		fi
		# Store the bookmark as folder|name
		bookmark="$cur_dir|$bookmark_name"

	# TODO: this could be sped up sorting and using a search algorithm
	for line in $(cat $ZMARKS_FILE) 
	do

		 if [[ "$line" == "$cur_dir|$bookmark_name" ]]; then 
				echo "umm, you already have this EXACT bm, bro" 
				return 
		 fi 

			if [[ $(echo $line |  awk -F'|' '{print $2}') == $bookmark_name ]]; then
					echo "Bookmark name already existed"
					echo "old: $line"
					echo "new: $bookmark"
					_ask_to_overwrite $bookmark_name 
					return 1

			elif [[ $(echo $line |  awk -F'|' '{print $1}') == $cur_dir  ]]; then
					echo "Bookmark dir already existed"
					echo "old: $line"
					echo "new: $bookmark"
					local bm="${line##*|}"
					_ask_to_overwrite $bm $bookmark_name 
					return 1
			fi
	done

	# no duplicates, make bookmark
	echo $bookmark >> $ZMARKS_FILE
	echo "Bookmark '$bookmark_name' saved"

	echo "hash -d $bookmark_name=$cur_dir" >> "$NAMED_DIRS"
	echo "Created named dir ~$bookmark_name"
  source "$NAMED_DIRS"
}

__zshmarks_zgrep() {
		local outvar="$1"; shift
		local pattern="$1"
		local filename="$2"
		local file_contents="$(<"$filename")"
		local file_lines; file_lines=(${(f)file_contents})

		# echo "zshmarks/init.zsh: 101 file_lines: $file_lines"
		for line in "${file_lines[@]}"; do
				if [[ "$line" =~ "$pattern" ]]; then
						eval "$outvar=\"$line\""
						return 0
				fi
		done
		return 1
}

function jump() {
		local bookmark_name=$1
		local bookmark
		if ! __zshmarks_zgrep bookmark "\\|$bookmark_name\$" "$ZMARKS_FILE"; then
				echo "Invalid name, please provide a valid bookmark name. For example:"
				echo "  jump foo"
				echo
				echo "To bookmark a folder, go to the folder then do this (naming the bookmark 'foo'):"
				echo "  bookmark foo"
				return 1
		else
				# echo "zshmarks/init.zsh: 124 bookmark : $bookmark "
				local dir="${bookmark%%|*}"
				eval "cd \"${dir}\""
				eval "ls \"${dir}\""
        # echo "dir: $dir"
        # echo "$dir"
		fi
}

# Show a list of the bookmarks
function showmarks() {
		local bookmark_file="$(<"$ZMARKS_FILE")"
		local bookmark_array; bookmark_array=(${(f)bookmark_file});
		local bookmark_name bookmark_path bookmark_line
		if [[ $# -eq 1 ]]; then
				bookmark_name="*\|${1}"
				bookmark_line=${bookmark_array[(r)$bookmark_name]}
				bookmark_path="${bookmark_line%%|*}"
				bookmark_path="${bookmark_path/\$HOME/~}"
				printf "%s \n" $bookmark_path
		else
				for bookmark_line in $bookmark_array; do
						bookmark_path="${bookmark_line%%|*}"
						bookmark_path="${bookmark_path/\$HOME/~}"
						bookmark_name="${bookmark_line#*|}"
						printf "%s\t\t%s\n" "$bookmark_name" "$bookmark_path"
				done
		fi
}

# Delete a bookmark
function deletemark()  {
		local bookmark_name=$1
		if [[ -z $bookmark_name ]]; then
				printf "%s \n" "Please provide a name for your bookmark to delete. For example:"
				printf "\t%s \n" "deletemark foo"
				return 1
		else
				local bookmark_line bookmark_search
				local bookmark_file="$(<"$ZMARKS_FILE")"
				local bookmark_array; bookmark_array=(${(f)bookmark_file});
				bookmark_search="*\|${bookmark_name}"
				if [[ -z ${bookmark_array[(r)$bookmark_search]} ]]; then
						eval "printf '%s\n' \"'${bookmark_name}' not found, skipping.\""
				else
						\cp "${ZMARKS_FILE}" "${ZMARKS_FILE}.bak"
						bookmark_line=${bookmark_array[(r)$bookmark_search]}
						bookmark_array=(${bookmark_array[@]/$bookmark_line})
						eval "printf '%s\n' \"\${bookmark_array[@]}\"" >! $ZMARKS_FILE

						 _zshmarks_move_to_trash "${ZMARKS_FILE}.bak" 
             
            # generate new named dir to sync with bookmarks
            _gen_zshmarks_named_dirs 1> /dev/null
            echo "Deleted and synced named dirs"
				fi
		fi
}

_zshmarks_clear_all(){
		_zshmarks_move_to_trash "$ZMARKS_FILE"
}


_ask_to_overwrite() {
		usage='usage: ${FUNCNAME[0]} to-overwrite <replacement>'
		[ ! $# -ge 1 ] && echo "$usage" && return 1 

		local overwrite=$1
		local replacement=$1
		[[  $# == 2 ]] && replacement=$2
		echo "overwrite: $overwrite"
		echo "replacement: $replacement"

		echo -n "overwrite mark $1 (y/n)? "
		read answer
		if  [ "$answer" != "${answer#[Yy]}" ];then 
				deletemark $1
				bookmark $2
		else
				return 1
		fi
}

fzf_zmark_jump(){
   local bookmark=$(cat $ZMARKS_DIR/zmarks | fzf-tmux)
	 local dir="${bookmark%%|*}"
   # echo "zshmarks/init.zsh: 237 dir: $dir"
	 eval "cd ${dir}"
	 # eval "ls ${dir}"
	 ls
   echo -e "\n"
   zle reset-prompt
}

zle     -N    fzf_zmark_jump


# dir="${foo%%|*}"
# bm="${foo##*|}"


# -- zedit functions -- 

if [[ -z $EDITOR ]] ; then
			echo "set \$EDITOR environment variable to choose editor"
			echo "defaulting to nvim or vim"
	 if [[ ! -z $(command -v nvim) ]]; then 
			export EDITOR="$(command -v nvim)"
	 else
			export EDITOR="$(command -v vim)"
	 fi
fi




_ezoom() {
# echo "zsh/functions.sh: 1: 76 $1"
# echo "zsh/functions.sh: 2: 77 $2"
	if [ -z "$2" ]; then
		"$EDITOR" "$1"
     # "$EDITOR" +/"--end--" "$1"	
	else
     "$EDITOR" +/"$2" "$1"	
  fi
}

_ezoomzsh() {
	ezoom "$1" "$2"
	source "$SHELLRC"
}


function zedit() {
		local editmark_name=$1
		local editmark
		if ! __zshmarks_zgrep editmark "\\|$editmark_name\$" "$ZEDITS_FILE"; then
				echo "Invalid name, please provide a valid editmark name. For example:"
				echo "  jump foo"
				echo
				echo "To editmark a folder, go to the folder then do this (naming the editmark 'foo'):"
				echo "  editmark foo"
				return 1
		else
				# echo "zshmarks/init.zsh: 124 editmark : $editmark "
				local filename="${editmark%%|*}"
				echo "zshmarks/init.zsh: 169 filename: $filename"
				# eval "_ezoom \"${filename}\" \"$2\""
				# eval "_ezoom \"$filename\" \"$2\""
				# eval "_ezoom $filename $2"
				_ezoom "$filename" "$2"
		fi
}

_ask_to_overwrite_zedit() {
		usage='usage: ${FUNCNAME[0]} to-overwrite <replacement>'
		[ ! $# -ge 1 ] && echo "$usage" && return 1 

		local overwrite=$1
		local replacement=$1
		[[  $# == 2 ]] && replacement=$2
		echo "overwrite: $overwrite"
		echo "replacement: $replacement"

		echo -n "overwrite mark $1 (y/n)? "
		read answer
		if  [ "$answer" != "${answer#[Yy]}" ];then 
				deleteeditmark $1
				zeditmark$2
		else
				return 1
		fi
}

function zeditmark() {
		local bookmark_name=$1
		if [[ -z $bookmark_name ]]; then
				echo 'zmark file required'
				return 1
		fi
		zedit_file="$( find $(pwd) -type f | fzf)"

				
		# Replace /home/uname with $HOME
		if [[ "$zedit_file" =~ ^"$HOME"(/|$) ]]; then
				zedit_file="\$HOME${zedit_file#$HOME}"
		fi
		# Store the bookmark as folder|name
		bookmark="$zedit_file|$bookmark_name"

	# TODO: this could be sped up sorting and using a search algorithm
	for line in $(cat $ZEDITS_FILE) 
	do

		 if [[ "$line" == "$zedit_file|$bookmark_name" ]]; then 
				echo "umm, you already have this EXACT edit mark, bro" 
				return 
		 fi 

			if [[ $(echo $line |  awk -F'|' '{print $2}') == $bookmark_name ]]; then
					echo "Bookmark name already existed"
					echo "old: $line"
					echo "new: $bookmark"
					_ask_to_overwrite_zedit $bookmark_name 
					return 1

			elif [[ $(echo $line |  awk -F'|' '{print $1}') == $zedit_file  ]]; then
					echo "Bookmark dir already existed"
					echo "old: $line"
					echo "new: $bookmark"
					local bm="${line##*|}"
					_ask_to_overwrite_zedit $bm $bookmark_name 
					return 1
			fi
	done

	# no duplicates, make bookmark
	echo $bookmark >> "$ZEDITS_FILE"
	echo "zeditmark '$bookmark_name' saved"

	# echo "hash -d $bookmark_name=$zedit_file" >> "$NAMED_DIRS"
	# echo "Created named dir ~$bookmark_name"
  # source "$NAMED_DIRS"
}

# function bookmark() {

# 	 function usage {
# 					 echo "$(basename $0) [mark name] \n
# 					 -e, --edit\n
# 							 use edit marks
# 						-h, --help
# 							 show this 
# 					 "
# 	 }

# 	 isZedit=false

# 	 POSITIONAL=()
# 	 while [[ $# -gt 0 ]]
# 	 do
# 	 key="$1"

# 	 case $key in
# 			 e|-e|--edit)
# 			 # DAYS_AGO="$2"
# 			 shift # past argument
# 			 isZedit=true
# 			 # shift # past value
# 			 ;;
# 			 h|-h|--help)
# 			 usage
# 			 exit
# 	 esac
# 	 done

# 	 # set -- "${POSITIONAL[@]}" # restore positional parameters

# 		local bookmark_name=$1
# 		if [[ -z $bookmark_name ]]; then
# 				bookmark_name="${PWD##*/}"
# 		fi
# 		cur_dir="$(pwd)"
# 		# Replace /home/uname with $HOME
# 		if [[ "$cur_dir" =~ ^"$HOME"(/|$) ]]; then
# 				cur_dir="\$HOME${cur_dir#$HOME}"
# 		fi
# 		# Store the bookmark as folder|name
# 		bookmark="$cur_dir|$bookmark_name"

# 	# TODO: this could be sped up sorting and using a search algorithm
# 	for line in $(cat $(isZedit && $ZEDITS_FILE || $ZMARKS_FILE)) 
# 	do

# 		 if [[ "$line" == "$cur_dir|$bookmark_name" ]]; then 
# 				echo "umm, you already have this EXACT bm, bro" 
# 				return 
# 		 fi 

# 			if [[ $(echo $line |  awk -F'|' '{print $2}') == $bookmark_name ]]; then
# 					echo "Bookmark name already existed"
# 					echo "old: $line"
# 					echo "new: $bookmark"
# 					_ask_to_overwrite $bookmark_name 
# 					return 1

# 			elif [[ $(echo $line |  awk -F'|' '{print $1}') == $cur_dir  ]]; then
# 					echo "Bookmark dir already existed"
# 					echo "old: $line"
# 					echo "new: $bookmark"
# 					local bm="${line##*|}"
# 					_ask_to_overwrite $bm $bookmark_name 
# 					return 1
# 			fi
# 	done

# 	# no duplicates, make bookmark
# 	echo $bookmark >> $ZMARKS_FILE
# 	echo "Bookmark '$bookmark_name' saved"

# 	echo "hash -d $bookmark_name=$cur_dir" >> "$NAMED_DIRS"
# 	echo "Created named dir ~$bookmark_name"
#   source "$NAMED_DIRS"
# }


