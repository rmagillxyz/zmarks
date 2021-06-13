# ------------------------------------------------------------------------------
#        FILE:  zshmarks.plugin.zsh
#        AUTHOR: Robert Magill
#        FORKED_FROM:  Jocelyn Mallon
#        VERSION: 0.5
#        DEPENDS: fzf, fzf-tmux
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
NAMED_FILES="$ZMARKS_DIR/zmarks_named_files"
ZMARKS_FILE="$ZMARKS_DIR/zmarks"
ZEDITS_FILE="$ZMARKS_DIR/zedits"


# Check if $ZMARKS_DIR is a symlink.
if [[ -L "$ZMARKS_FILE" ]]; then
 ZMARKS_FILE=$(readlink $ZMARKS_FILE)
fi

_gen_zshmarks_named_dirs(){
	 if [[  -f "$NAMED_DIRS" ]]; then
			rm "$NAMED_DIRS"
	 fi
   # rm "$NAMED_DIRS"
   while read line
   do
      dir="${line%%|*}"
      bm="${line##*|}"
      echo "~$bm"
			echo "hash -d $bm=$dir" >> "$NAMED_DIRS"
	 done < "$ZMARKS_FILE"
	 return 
}

_gen_zshmarks_named_files(){
   # rm "$NAMED_FILES"

	 if [[  -f "$NAMED_FILES" ]]; then
			rm "$NAMED_FILES"
	 fi

   while read line
   do
      dir="${line%%|*}"
      bm="${line##*|}"
      echo "~$bm"
			echo "hash -d $bm=$dir" >> "$NAMED_FILES"
	 done < "$ZEDITS_FILE"
	 return 
}

if [[ ! -f $ZMARKS_FILE ]]; then
		touch $ZMARKS_FILE
 else 
   _gen_zshmarks_named_dirs 1> /dev/null
	 _gen_zshmarks_named_files 1> /dev/null
fi


fpath=($fpath "$ZDOTDIR/zshmarks/functions")

[ -f "$NAMED_DIRS" ] && source "$NAMED_DIRS" 
[ -f "$NAMED_FILES" ] && source "$NAMED_FILES" 

_zshmarks_move_to_trash(){
	 local file_path="$1"
	 echo "zshmarks/init.zsh: 77 file_path: $file_path"
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

function zm() {
		local zm_name=$1
		if [[ -z $zm_name ]]; then
				zm_name="${PWD##*/}"
		fi
		cur_dir="$(pwd)"
		# Replace /home/uname with $HOME
		if [[ "$cur_dir" =~ ^"$HOME"(/|$) ]]; then
				cur_dir="\$HOME${cur_dir#$HOME}"
		fi
		# Store the zm as folder|name
		zm="$cur_dir|$zm_name"

	# TODO: this could be sped up sorting and using a search algorithm
	for line in $(cat $ZMARKS_FILE) 
	do

		 if [[ "$line" == "$cur_dir|$zm_name" ]]; then 
				echo "umm, you already have this EXACT bm, bro" 
				return 
		 fi 

			if [[ $(echo $line |  awk -F'|' '{print $2}') == $zm_name ]]; then
					echo "zm name already existed"
					echo "old: $line"
					echo "new: $zm"
					_ask_to_overwrite $zm_name 
					return 1

			elif [[ $(echo $line |  awk -F'|' '{print $1}') == $cur_dir  ]]; then
					echo "zm dir already existed"
					echo "old: $line"
					echo "new: $zm"
					local bm="${line##*|}"
					_ask_to_overwrite $bm $zm_name 
					return 1
			fi
	done

	# no duplicates, make zm
	echo $zm >> $ZMARKS_FILE
	echo "zm '$zm_name' saved"

	echo "hash -d $zm_name=$cur_dir" >> "$NAMED_DIRS"
	echo "Created named dir ~$zm_name"
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

function zmj() {
		local zm_name=$1
		local zm
		if ! __zshmarks_zgrep zm "\\|$zm_name\$" "$ZMARKS_FILE"; then
				echo "Invalid name, please provide a valid zm name. For example:"
				echo "zmj foo"
				echo
				echo "To zm a folder, go to the folder then do this (naming the zm 'foo'):"
				echo "  zm foo"
				return 1
		else
				# echo "zshmarks/init.zsh: 124 zm : $zm "
				local dir="${zm%%|*}"
				eval "cd \"${dir}\""
				eval "ls \"${dir}\""
        # echo "dir: $dir"
        # echo "$dir"
		fi
}

# Show a list of the zms
function zms() {
	 local zm_file="$(<${2:-$ZMARKS_FILE})"
		# local zm_file="$(<"$ZMARKS_FILE")"
		local zm_array; zm_array=(${(f)zm_file});
		local zm_name zm_path zm_line
		if [[ $# -eq 1 ]]; then
				zm_name="*\|${1}"
				zm_line=${zm_array[(r)$zm_name]}
				zm_path="${zm_line%%|*}"
				zm_path="${zm_path/\$HOME/~}"
				printf "%s \n" $zm_path
		else
				for zm_line in $zm_array; do
						zm_path="${zm_line%%|*}"
						zm_path="${zm_path/\$HOME/~}"
						zm_name="${zm_line#*|}"
						printf "%s\t\t%s\n" "$zm_name" "$zm_path"
				done
		fi
}

# Delete a zm
function zmd()  {
		local zm_name="$1"
		local file_path="${2:-$ZMARKS_FILE}"
		# echo "zshmarks/init.zsh: 204 file_path: $file_path"
		if [[ -z $zm_name ]]; then
				printf "%s \n" "Please provide a name for your zm to delete. For example:"
				printf "\t%s \n" "zmd foo"
				return 1
		else
				local zm_line zm_search
				# local zm_file="$(<${2:-$ZMARKS_FILE})"
				# local zm_file="$(<${2:-$ZMARKS_FILE})"
				local zm_file="$(<"$file_path")"
				echo "zshmarks/init.zsh: 213 zm_file: $zm_file"
				local zm_array; zm_array=(${(f)zm_file});
				zm_search="*\|${zm_name}"
				if [[ -z ${zm_array[(r)$zm_search]} ]]; then
						eval "printf '%s\n' \"'${zm_name}' not found, skipping.\""
				else
						\cp "${file_path}" "${file_path}.bak"
						zm_line=${zm_array[(r)$zm_search]}
						zm_array=(${zm_array[@]/$zm_line})
						eval "printf '%s\n' \"\${zm_array[@]}\"" >! $file_path

						 _zshmarks_move_to_trash "${file_path}.bak" 
             
            # generate new named dir to sync with marks
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
				zmd $1
				zm $2
		else
				return 1
		fi
}

_fzf_zmj(){
   local zm=$(cat $ZMARKS_DIR/zmarks | fzf-tmux)
	 local dir="${zm%%|*}"
   # echo "zshmarks/init.zsh: 237 dir: $dir"
	 eval "cd ${dir}"
	 # eval "ls ${dir}"
	 ls
   echo -e "\n"
   zle reset-prompt
}
zle     -N    _fzf_zmj

# dir="${foo%%|*}"
# bm="${foo##*|}"


# -- zm edit functions -- 

_fzf_zmej(){
   local zm=$(cat $ZMARKS_DIR/zedits | fzf-tmux)
	 # local file="${zm%%|*}"
	 local bm_name="${zm##*|}"
	 echo "zshmarks/init.zsh: 281 bm: $bm"
	 zmej "$bm_name"
   # echo "zshmarks/init.zsh: 237 dir: $dir"
	 # eval "cd ${dir}"
	 # eval "ls ${dir}"
	 ls
   echo -e "\n"
   zle reset-prompt
}
zle     -N    _fzf_zmej


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

function zmej() {
		local editmark_name=$1
		local editmark
		if ! __zshmarks_zgrep editmark "\\|$editmark_name\$" "$ZEDITS_FILE"; then
				echo "Invalid name, please provide a valid editmark name. For example:"
				echo "  zmej foo"
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
				zmed "$1"
				# echo "zshmarks/init.zsh: 317 zedit_path: $zedit_path"
				zme "$2" "$zedit_path"
		else
				return 1
		fi
}

function zme() {
		local zm_name="$1"
		local zedit_path="$2"

		if [[ -z $zm_name ]]; then
				echo 'zmark file required'
				return 1
		fi

		local exactmatchfromdir=$(\ls $(pwd) | grep -x "$zm_name")
		echo "zshmarks/init.zsh: 374 exactmatchfromdir: $exactmatchfromdir"

		if [[ -z $zedit_path && -z $exactmatchfromdir ]]; then
	 		zedit_path="$(find $(pwd) -type f | fzf-tmux)"
			 if [[ -z "$zedit_path" ]]; then
					return 1
			 fi
		else
			 cur_dir="$(pwd)"
			 zedit_path="$cur_dir"
			 zedit_path+="/$zm_name"
			echo "zshmarks/init.zsh: 385 zedit_path: $zedit_path"
		fi

				
		# Replace /home/uname with $HOME
		if [[ "$zedit_path" =~ ^"$HOME"(/|$) ]]; then
				zedit_path="\$HOME${zedit_path#$HOME}"
		fi
		# Store the zm as folder|name
		zm="$zedit_path|$zm_name"

	# TODO: this could be sped up sorting and using a search algorithm
	# refactor into function to deal with edits and marks
	for line in $(cat $ZEDITS_FILE) 
	do

		 if [[ "$line" == "$zedit_path|$zm_name" ]]; then 
				echo "umm, you already have this EXACT edit mark, bro" 
				return 
		 fi 

			if [[ $(echo $line |  awk -F'|' '{print $2}') == $zm_name ]]; then
					echo "zm name already existed"
					echo "old: $line"
					echo "new: $zm"
					_ask_to_overwrite_zedit $zm_name 
					return 1

			elif [[ $(echo $line |  awk -F'|' '{print $1}') == $zedit_path  ]]; then
					echo "zm dir already existed"
					echo "old: $line"
					echo "new: $zm"
					local bm="${line##*|}"
					_ask_to_overwrite_zedit $bm $zm_name 
					return 1
			fi
	done

	# no duplicates, make zm
	echo $zm >> "$ZEDITS_FILE"
	echo "zm file '$zm_name' saved"

	echo "hash -d $zm_name=$zedit_path" >> "$NAMED_DIRS"
	echo "Created named file ~$zm_name"
  source "$NAMED_FILES"
}


# Delete a edit mark
function zmed()  {
 zmd "$1" "$ZEDITS_FILE"
}

# Show edit marks
function zmes()  {
 zms "$1" "$ZEDITS_FILE"
}
