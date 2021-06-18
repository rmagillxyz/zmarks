#!/bin/zsh

# ------------------------------------------------------------------------------
#        FILE:  zsharks.plugin.zsh
#        AUTHOR: Robert Magill
#        FORKED_FROM:  Jocelyn Mallon
#        VERSION: 0.6
#        DEPENDS: fzf
# ------------------------------------------------------------------------------
fpath=("$ZDOTDIR/zshmarks/functions" $fpath)

# dir="${foo%%|*}"
# zm="${foo##*|}"
RED='\033[0;31m'
NOCOLOR='\033[0m'

# echo "zshmarks/zshmarks.plugin.zsh: 16 EDITOR : $EDITOR "
if [[ -z $EDITOR ]]; then
	 echo "set \$EDITOR environment variable to choose editor"
	 echo "defaulting to nvim or vim"
	 if [[ -n $(command -v nvim) ]]; then 
			export EDITOR="$(command -v nvim)"
	 else
			export EDITOR="$(command -v vim)"
	 fi
fi

# Set ZMARKS_DIR if it doesn't exist to the default.
# Allows for a user-configured ZMARKS_DIR.
if [[ -z $ZMARKS_DIR ]] ; then
	 [[ ! -d "$HOME/.local/share/zsh" ]] && mkdir -p "$HOME/.local/share/zsh" 
	 export ZMARKS_DIR="$HOME/.local/share/zsh"
fi

ZM_DIRS_FILE="$ZMARKS_DIR/zm_dirs"
ZM_FILES_FILE="$ZMARKS_DIR/zm_files"
ZM_NAMED_DIRS="$ZMARKS_DIR/zm_named_dirs"
ZM_NAMED_FIlES="$ZMARKS_DIR/zm_named_files"


## could just remove one instead of rebuilting
_gen_zshmarks_named_dirs(){
	 if [[  -f "$ZM_NAMED_DIRS" ]]; then
			rm "$ZM_NAMED_DIRS"
	 fi
	 while read line
	 do
			dir="${line%%|*}"
			bm="${line##*|}"
			echo "~$bm"
			echo "hash -d $bm=$dir" >> "$ZM_NAMED_DIRS"
	 done < "$ZM_DIRS_FILE"
	 return 
}

_gen_zshmarks_named_files(){
	 if [[  -f "$ZM_NAMED_FIlES" ]]; then
			rm "$ZM_NAMED_FIlES"
	 fi
	 while read line
	 do
			dir="${line%%|*}"
			bm="${line##*|}"
			echo "~$bm"
			echo "hash -d $bm=$dir" >> "$ZM_NAMED_FIlES"
	 done < "$ZM_FILES_FILE"
	 return 
}



# Check if $ZMARKS_DIR is a symlink.
if [[ -L "$ZM_DIRS_FILE" ]]; then
	 ZM_DIRS_FILE=$(readlink $ZM_DIRS_FILE)
fi

if [[ ! -f $ZM_DIRS_FILE ]]; then
	 touch $ZM_DIRS_FILE
else 
	 _gen_zshmarks_named_dirs 1> /dev/null
	 _gen_zshmarks_named_files 1> /dev/null
fi

[ -f "$ZM_NAMED_DIRS" ] && source "$ZM_NAMED_DIRS" 
[ -f "$ZM_NAMED_FIlES" ] && source "$ZM_NAMED_FIlES" 


_zshmarks_move_to_trash(){
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


	 # local zm_clash_fail=false
	 local zm_clash_fail
	 echo "zshmarks/init.zsh: 119 zm_clash_fail: $zm_clash_fail"
	 __zm_checkclash zm_clash_fail "$zm_name" "$ZM_FILES_FILE"
	 echo "zshmarks/init.zsh: 121 zm_clash_fail: $zm_clash_fail"

	 echo "zshmarks/init.zsh: 115 zm_clash_fail : $zm_clash_fail "
	[[ -n $zm_clash_fail ]] && return 1

		# Store the zmark as directory|name
		zm="$cur_dir|$zm_name"


	# TODO: this could be sped up sorting and using a search algorithm
	for line in $(cat $ZM_DIRS_FILE) 
	do

		 if [[ "$line" == "$cur_dir|$zm_name" ]]; then 
				echo "umm, you already have this EXACT dir zmark, bro" 
				return 
		 fi 

		 if [[ $(echo $line |  awk -F'|' '{print $2}') == $zm_name ]]; then
				echo "zmark name already existed"
				echo "old: $line"
				echo "new: $zm"
				__ask_to_overwrite_zm_dir $zm_name 
				return 1

		 elif [[ $(echo $line |  awk -F'|' '{print $1}') == $cur_dir  ]]; then
				echo "zmark dir already existed"
				echo "old: $line"
				echo "new: $zm"
				local bm="${line##*|}"
				__ask_to_overwrite_zm_dir $bm $zm_name 
				return 1
		 fi
	done

	# no duplicates, make mark
	echo $zm >> $ZM_DIRS_FILE
	echo "zm '$zm_name' saved"

	echo "hash -d $zm_name=$cur_dir" >> "$ZM_NAMED_DIRS"
	echo "Created named dir ~$zm_name"
	source "$ZM_NAMED_DIRS"
}

__zshmarks_zgrep() {
	 local outvar="$1"; shift
	 local pattern="$1"
	 local filename="$2"
	 # echo "zshmarks/init.zsh: 161 filename: $filename"
	 # echo "zshmarks/init.zsh: 162 pattern: $pattern"
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
	 if ! __zshmarks_zgrep zm "\\|$zm_name\$" "$ZM_DIRS_FILE"; then
			if ! __zshmarks_zgrep zm "\\|$zm_name\$" "$ZM_FILES_FILE"; then
				 echo "Invalid name, please provide a valid zmark name. For example:"
				 echo "zmj foo [pattern]"
				 echo
				 echo "To mark a directory:"
				 echo "zm <name>"
				 echo "To mark a file:"
				 echo "zmf <name>"
				 return 1
			else
				 local filename="${zm%%|*}"
				 _ezoom "$filename" "$2"
			fi

			# __zmfj "$zm_name" "$2"
			# if [ -f  "~$zm" ];then 
			
			# echo "zshmarks/init.zsh: 188 zm_name: $zm_name"
			# if [ -f $(eval "echo ~$zm_name") ]; then
			# 	 echo 'we have a file'
			# 	 # eval "echo \"name: ~$zm_name\""
			# 	 eval "echo ~$zm_name"
			# 	 eval "echo \"name: ~$zm_name\""
			# 	 # $EDITOR "~$zm"
			# fi

			# # if [ -d $(eval "echo $dest") ]; then
			# if [ -d $(eval "echo $dest") ]; then
			# echo "Invalid name, please provide a valid zmark name. For example:"
			# echo "zmj foo"
			# echo
			# echo "To zm a directory, go to the directory then do this (naming the zm 'foo'):"
			# echo "  zm foo"
			# return 1
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
	 # is zm_file is the contents of the file stored in a var
	 # local zm_file="$(<${2:-$ZM_DIRS_FILE})"
	 # local zm_file="$(<$ZM_DIRS_FILE <$ZM_FILES_FILE)"
	 local zm_file=$(<"$ZM_DIRS_FILE" <"$ZM_FILES_FILE")
	 local zm_array; zm_array=(${(f)zm_file});
	 # echo "zshmarks/init.zsh: 226 zm_array: $zm_array"
	 local zm_name zm_path zm_line
	 if [[ $# -eq 1 ]]; then
			zm_name="*\|${1}"
			zm_line=${zm_array[(r)$zm_name]}
			echo "zshmarks/zshmarks.plugin.zsh: 226 zm_line: $zm_line"
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
function zmrm()  {
	 local zm_name="$1"
	 local file_path="${2:-$ZM_DIRS_FILE}"
	 if [[ -z $zm_name ]]; then
			printf "%s \n" "Please provide a name for your zm to delete. For example:"
			printf "\t%s \n" "zmrm foo"
			return 1
	 else
			local zm_line zm_search
			local zm_file="$(<"$file_path")"
			local zm_array; zm_array=(${(f)zm_file});
			zm_search="*\|${zm_name}"
			if [[ -z ${zm_array[(r)$zm_search]} ]]; then
				 if [[ $file_path == $ZM_DIRS_FILE ]]; then
						# name not found in dirs, run again with try files
						# zmfd "$zm_name" 
						zmrm "$zm_name" "$ZM_FILES_FILE"
						# zmrm "$1" "$ZM_FILES_FILE"
				 else
						eval "printf '%s\n' \"'${zm_name}' not found, skipping.\""
				 fi
			else
				 \cp "${file_path}" "${file_path}.bak"
				 zm_line=${zm_array[(r)$zm_search]}
				 zm_array=(${zm_array[@]/$zm_line})
				 eval "printf '%s\n' \"\${zm_array[@]}\"" >! $file_path

				 _zshmarks_move_to_trash "${file_path}.bak" 

						# generate new named dir to sync with marks
						hash -d -r  # rebuild hash table
						_gen_zshmarks_named_dirs 1> /dev/null
						_gen_zshmarks_named_files 1> /dev/null
						echo "Deleted and synced named dirs"
			fi
			fi
	 }

_zshmarks_clear_all(){
	 _zshmarks_move_to_trash "$ZM_DIRS_FILE"
}


__ask_to_overwrite_zm_dir() {
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
			zmrm $1
			zm $2
	 else
			return 1
	 fi
}

# _fzf_zmj(){
# 	local zm=$(< $ZM_DIRS_FILE | fzf-tmux)
#		 local dir="${zm%%|*}"
#    # echo "zshmarks/init.zsh: 237 dir: $dir"
#		 eval "cd ${dir}"
#		 # eval "ls ${dir}"
#		 ls
#    echo -e "\n"
#    zle reset-prompt
# }

_fzf_zmj(){
	 local zm=$(<"$ZM_DIRS_FILE" <"$ZM_FILES_FILE" | fzf-tmux)
	 local dest="${zm%%|*}"
	 [[ -z "$dest" ]] && zle reset-prompt && return 1

	 # could also use zgrep here
	 # if ! __zshmarks_zgrep zm "\\|$zm_name\$" "$ZM_DIRS_FILE"; then
	 # TODO why do I need eval here?
	 if [ -d $(eval "echo $dest") ]; then
			echo "we gotta dir"
			eval "cd \"$dest\""
			ls
			echo -e "\n"
	 else
			echo "we gotta file"
			eval "_ezoom \"$dest\""
	 fi
	 zle reset-prompt
}
zle     -N    _fzf_zmj

# dir="${foo%%|*}"
# bm="${foo##*|}"


# -- zm edit functions -- 

# works but _fzf_zmj now deals with both. may add back in the future if could be useful
# _fzf_zmfj(){
#    local zm=$(cat $ZM_FILES_FILE| fzf-tmux)
#		 # local file="${zm%%|*}"
#		 local bm_name="${zm##*|}"
#		 echo "zshmarks/init.zsh: 281 bm: $bm"
#		 zmfj "$bm_name"
#    # echo "zshmarks/init.zsh: 237 dir: $dir"
#		 # eval "cd ${dir}"
#		 # eval "ls ${dir}"
#		 ls
#    echo -e "\n"
#    zle reset-prompt
# }
# zle     -N    _fzf_zmfj




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

# zmjz() {
zm_jump_n_source() {
	 zmj "$1" "$2"
	 # source "$SHELLRC"
	 source ~"$1"
}

# _ezoomzsh() {
#		ezoom "$1" "$2"
#		source "$SHELLRC"
# }

# jump to maked file
# function __zmfj() {
# 	 local editmark_name=$1
# 	 local editmark
# 	 if ! __zshmarks_zgrep editmark "\\|$editmark_name\$" "$ZM_FILES_FILE"; then
# 			echo "Invalid name, please provide a valid zmark name. For example:"
# 			echo "zmj foo [pattern]"
# 			echo
# 			echo "To mark a directory:"
# 			echo "zm <name>"
# 			echo "To mark a file:"
# 			echo "zmf <name>"
# 			return 1
# 	 else
# 			local filename="${editmark%%|*}"
# 			_ezoom "$filename" "$2"
# 	 fi
# }


function zmf() {
	 local zm_name="$1"
	 echo "zshmarks/init.zsh: 427 zm_name: $zm_name"
	 
	 local zm_file_path="$2"

	 if [[ -z $zm_name ]]; then
			echo 'zmark name required'
			return 1
	 fi

	 local zm_clash_fail
	 echo "zshmarks/init.zsh: 431 zm_clash_fail: $zm_clash_fail"
	 __zm_checkclash zm_clash_fail "$zm_name" "$ZM_DIRS_FILE"
	 echo "zshmarks/init.zsh: 431 zm_clash_fail: $zm_clash_fail"

	 # "$zm_clash_fail" && return 1
	[[ -n $zm_clash_fail ]] && return 1

	 local exactmatchfromdir=$(\ls $(pwd) | grep -x "$zm_name")
	 echo "zshmarks/init.zsh: 374 exactmatchfromdir: $exactmatchfromdir"

		if [[ -z $zm_file_path && -n $exactmatchfromdir ]]; then
			 #could use find here
			 cur_dir="$(pwd)"
			 zm_file_path="$cur_dir"
			 zm_file_path+="/$zm_name"
			 echo "zshmarks/init.zsh: 385 zm_file_path: $zm_file_path"

		elif [[ -z $zm_file_path ]]; then
			 zm_file_path="$(find -L $(pwd) -maxdepth 4 -type f 2>/dev/null | fzf-tmux)"
			 echo "zshmarks/init.zsh: 409 zm_file_path: $zm_file_path"
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
						zmrm "$overwrite"
						echo "zshmarks/init.zsh: 494 zm_file_path: $zm_file_path"
						zmf "$replacement" "$zm_file_path"
				 else
						return 1
				 fi
			}

	# TODO: this could be sped up sorting and using a search algorithm
	# refactor into function to deal with fils and dirs
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

	# no duplicates, make zm
	echo $zm >> "$ZM_FILES_FILE"
	echo "zmark file '$zm_name' saved"

	echo "hash -d $zm_name=$zm_file_path" >> "$ZM_NAMED_DIRS"
	echo "Created named file ~$zm_name"
	source "$ZM_NAMED_FIlES"
}



__zm_checkclash(){

# 	 if [[ $1 == "-f" ]];then
# 			zm_path="$ZM_FILES_FILE"
# 	 fi

	 local clash_fail="$1"; shift
				 eval "$clash_fail='something'"
	 echo "zshmarks/init.zsh: 526 clash_fail: $clash_fail"
	 local zm_name="$1"
	 # local zm_path="${3:-$ZM_DIRS_FILE}"
	 local zm_path="$2"

	 local clash


	 __asktodelete(){
			# local cmd="$1"
			local zm="${clash##*|}"
			read answer
			if  [ "$answer" != "${answer#[Yy]}" ];then 
				 # eval "$cmd \"$zm\""
				 zmrm "$zm"
			else
				 # clash_fail=true
				 # eval "$clash_fail=true"
				 eval "$clash_fail='something'"
				 echo "zshmarks/init.zsh: 544 clash_fail: $clash_fail"
				 return 1
			fi
	 }

	 __zm_checkhashclash(){
			# local zm_name="$1"
			local hash_already_exists=$(echo ~"$zm_name")
			if [[ -n $hash_already_exists ]]; then
				 printf "${RED}Named hash clash: $hash_already_exists ${NOCOLOR}\n"
				 echo 'If you created this, you can remove it and run again, but this could potentially be set by another program on your machine. If you did not create it, I would just choose another name.'
				 # clash_fail=true
				 # eval "$clash_fail=true"
				 eval "$clash_fail='something'"
				 echo "zshmarks/init.zsh: 557 clash_fail: $clash_fail"
				 return 1
				 fi
			}

	 # check dir marks for collision
	 if  __zshmarks_zgrep clash "\\|$zm_name\$" "$zm_path"; then
			# if [[ $1 == "-f" ]];then
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
			# __zm_checkhashclash "$zm_name"
			__zm_checkhashclash 
}



