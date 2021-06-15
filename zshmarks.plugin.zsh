#!/bin/zsh

# ------------------------------------------------------------------------------
#        FILE:  zshmarks.plugin.zsh
#        AUTHOR: Robert Magill
#        FORKED_FROM:  Jocelyn Mallon
#        VERSION: 0.5
#        DEPENDS: fzf, fzf-tmux
# ------------------------------------------------------------------------------

# dir="${foo%%|*}"
# bm="${foo##*|}"
RED='\033[0;31m'
NOCOLOR='\033[0m' # No Color

# echo "zshmarks/zshmarks.plugin.zsh: 16 EDITOR : $EDITOR "
if [[ -z $EDITOR ]]; then
			echo "set \$EDITOR environment variable to choose editor"
			echo "defaulting to nvim or vim"
	 if [[ ! -z $(command -v nvim) ]]; then 
			export EDITOR="$(command -v nvim)"
	 else
			export EDITOR="$(command -v vim)"
	 fi
fi

if [[ -z $SHELLRC ]]; then
	 if [[ ! -f "$HOME/.zshrc" ]]; then 
			export SHELLRC="$HOME/.zshrc"
	 elif [[ ! -f "$HOME/config/.zshrc" ]]; then 
			export SHELLRC="$HOME/config/.zshrc"
	 elif [[ ! -f "$HOME/config/zshrc" ]]; then 
			export SHELLRC="$HOME/config/zshrc"
	 else
			printf "${RED}No $SHELLRC (.zshrc) found. Please set SHELLRC env var.${NOCOLOR}\n"
	 fi
fi

# Set ZMARKS_DIR if it doesn't exist to the default.
# Allows for a user-configured ZMARKS_DIR.
if [[ -z $ZMARKS_DIR ]] ; then
    [[ ! -d "$HOME/.local/share/zsh" ]] && mkdir -p "$HOME/.local/share/zsh" 
		export ZMARKS_DIR="$HOME/.local/share/zsh"
fi

NAMED_DIRS="$ZMARKS_DIR/zm_named_dirs"
NAMED_FILES="$ZMARKS_DIR/zm_named_files"
ZM_DIRS_FILE="$ZMARKS_DIR/zm_dirs"
ZM_FILES_FILE="$ZMARKS_DIR/zm_files"


# Check if $ZMARKS_DIR is a symlink.
if [[ -L "$ZM_DIRS_FILE" ]]; then
 ZM_DIRS_FILE=$(readlink $ZM_DIRS_FILE)
fi

## could just remove one instead of rebuilting
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
	 done < "$ZM_DIRS_FILE"
	 return 
}

_gen_zshmarks_named_files(){

	 if [[  -f "$NAMED_FILES" ]]; then
			rm "$NAMED_FILES"
	 fi

   while read line
   do
      dir="${line%%|*}"
      bm="${line##*|}"
      echo "~$bm"
			echo "hash -d $bm=$dir" >> "$NAMED_FILES"
	 done < "$ZM_FILES_FILE"
	 return 
}

if [[ ! -f $ZM_DIRS_FILE ]]; then
		touch $ZM_DIRS_FILE
 else 
   _gen_zshmarks_named_dirs 1> /dev/null
	 _gen_zshmarks_named_files 1> /dev/null
fi

[ -f "$NAMED_DIRS" ] && source "$NAMED_DIRS" 
[ -f "$NAMED_FILES" ] && source "$NAMED_FILES" 

fpath=($fpath "$ZDOTDIR/zshmarks/functions")

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


			clashfail=false
			__zm_checkclash -e "$zm_name" "$ZM_FILES_FILE"

			echo "zshmarks/init.zsh: 115 clashfail : $clashfail "
			"$clashfail" && return 1
						
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
					__ask_to_overwrite $zm_name 
					return 1

			elif [[ $(echo $line |  awk -F'|' '{print $1}') == $cur_dir  ]]; then
					echo "zmark dir already existed"
					echo "old: $line"
					echo "new: $zm"
					local bm="${line##*|}"
					__ask_to_overwrite $bm $zm_name 
					return 1
			fi
	done

	# no duplicates, make mark
	echo $zm >> $ZM_DIRS_FILE
	echo "zm '$zm_name' saved"

	echo "hash -d $zm_name=$cur_dir" >> "$NAMED_DIRS"
	echo "Created named dir ~$zm_name"
  source "$NAMED_DIRS"
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
			 __zmfj "$zm_name" "$2"
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
		# elif ! __zshmarks_zgrep zm "\\|$zm_name\$" "$ZM_DIRS_FILE"; then
		# 	 zmfd "$zm_name" 
		else
				local zm_line zm_search
				local zm_file="$(<"$file_path")"
				local zm_array; zm_array=(${(f)zm_file});
				zm_search="*\|${zm_name}"
				# if [[ -z ${zm_array[(r)$zm_search]} ]]; then
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


__ask_to_overwrite() {
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
#    local zm=$(< $ZM_DIRS_FILE | fzf-tmux)
# 	 local dir="${zm%%|*}"
#    # echo "zshmarks/init.zsh: 237 dir: $dir"
# 	 eval "cd ${dir}"
# 	 # eval "ls ${dir}"
# 	 ls
#    echo -e "\n"
#    zle reset-prompt
# }

_fzf_zmj(){
   local zm=$(<"$ZM_DIRS_FILE" <"$ZM_FILES_FILE" | fzf-tmux)
	 local dest="${zm%%|*}"
	 [[ -z "$dest" ]] && zle reset-prompt && return 1

	 # could also use zgrep here
	 # if ! __zshmarks_zgrep zm "\\|$zm_name\$" "$ZM_DIRS_FILE"; then
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

_fzf_zmfj(){
   local zm=$(cat $ZMARKS_DIR/zedits | fzf-tmux)
	 # local file="${zm%%|*}"
	 local bm_name="${zm##*|}"
	 echo "zshmarks/init.zsh: 281 bm: $bm"
	 zmfj "$bm_name"
   # echo "zshmarks/init.zsh: 237 dir: $dir"
	 # eval "cd ${dir}"
	 # eval "ls ${dir}"
	 ls
   echo -e "\n"
   zle reset-prompt
}
zle     -N    _fzf_zmfj




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
__zm_jump_source_zsh() {
	zmj "$1" "$2"
	source "$SHELLRC"
}

# _ezoomzsh() {
# 	ezoom "$1" "$2"
# 	source "$SHELLRC"
# }

# jump to maked file
function __zmfj() {
		local editmark_name=$1
		local editmark
		if ! __zshmarks_zgrep editmark "\\|$editmark_name\$" "$ZM_FILES_FILE"; then
				echo "Invalid name, please provide a valid zmark name. For example:"
				echo "zmj foo [pattern]"
				echo
				echo "To mark a directory:"
				echo "zm <name>"
				echo "To mark a file:"
				echo "zmf <name>"
				return 1
		else
				local filename="${editmark%%|*}"
				_ezoom "$filename" "$2"
		fi
}

__ask_to_overwrite_zedit() {
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
				zmrm "$overwrite"
				echo "zshmarks/init.zsh: 418 zedit_path: $zedit_path"
				zmf "$replacement" "$zedit_path"
		else
				return 1
		fi
}

function zmf() {
		local zm_name="$1"
		echo "zshmarks/init.zsh: 427 zm_name: $zm_name"
		# removed local from zedit_path to use in __ask_to_overwrite_zedit. make sure this is okay.
		zedit_path="$2"
		echo "zshmarks/init.zsh: 429 zedit_path: $zedit_path"

		if [[ -z $zm_name ]]; then
				echo 'zmark name required'
				return 1
		fi


			clashfail=false
	 __zm_checkclash -d "$zm_name"
	 # __zm_checkhashclash "$zm_name"

			echo "zshmarks/init.zsh: 115 clashfail : $clashfail "
			"$clashfail" && return 1

		local exactmatchfromdir=$(\ls $(pwd) | grep -x "$zm_name")
		echo "zshmarks/init.zsh: 374 exactmatchfromdir: $exactmatchfromdir"


		# if [[ -z $zedit_path && -z $exactmatchfromdir ]]; then
		if [[ -z $zedit_path && -n $exactmatchfromdir ]]; then
			 #could use find here
			 cur_dir="$(pwd)"
			 zedit_path="$cur_dir"
			 zedit_path+="/$zm_name"
			echo "zshmarks/init.zsh: 385 zedit_path: $zedit_path"

	 elif [[ -z $zedit_path ]]; then
			zedit_path="$(find -L $(pwd) -maxdepth 4 -type f 2>/dev/null | fzf-tmux)"
			echo "zshmarks/init.zsh: 409 zedit_path: $zedit_path"
			 if [[ -z "$zedit_path" ]]; then
					return 1
			 fi
	 fi

				
		# Replace /home/uname with $HOME
		if [[ "$zedit_path" =~ ^"$HOME"(/|$) ]]; then
				zedit_path="\$HOME${zedit_path#$HOME}"
		fi
		# Store the zm as directory|name
		zm="$zedit_path|$zm_name"

	# TODO: this could be sped up sorting and using a search algorithm
	# refactor into function to deal with edits and marks
	for line in $(cat $ZM_FILES_FILE) 
	do

		 if [[ "$line" == "$zedit_path|$zm_name" ]]; then 
				echo "umm, you already have this EXACT edit mark, bro" 
				return 
		 fi 

			if [[ $(echo $line |  awk -F'|' '{print $2}') == $zm_name ]]; then
					echo "zmarks file name already existed"
					echo "old: $line"
					echo "new: $zm"
					__ask_to_overwrite_zedit $zm_name 
					return 1

			elif [[ $(echo $line |  awk -F'|' '{print $1}') == $zedit_path  ]]; then
					echo "zmark dir already existed"
					echo "old: $line"
					echo "new: $zm"
					local zm_to_overwrite_name="${line##*|}"
					__ask_to_overwrite_zedit "$zm_to_overwrite_name" "$zm_name" 
					return 1
			fi
	done

	# no duplicates, make zm
	echo $zm >> "$ZM_FILES_FILE"
	echo "zmark file '$zm_name' saved"

	echo "hash -d $zm_name=$zedit_path" >> "$NAMED_DIRS"
	echo "Created named file ~$zm_name"
  source "$NAMED_FILES"
}


# Delete a edit mark
# function zmfd()  {
# 	 # echo '-----zmfd'
#  zmrm "$1" "$ZM_FILES_FILE"
# }

# TODO this has a bug. It does not show an individual mark with argument. compare with zms. also check zmfd
# Show edit marks
# function zmfs()  {
#  zms "$1" "$ZM_FILES_FILE"
# }

# TODO
# cmd no longer needed as zmrm deal with files and dirs
# can this be made local?
__asktodelete(){
	 local cmd="$1"
	 local zm="${2##*|}"
				 read answer
				 if  [ "$answer" != "${answer#[Yy]}" ];then 
						eval "$cmd \"$zm\""
				 else
						clashfail=true
						return 1
				 fi
}


__zm_checkclash(){
			local zm_name="$2"
			local zm_path="${3:-$ZM_DIRS_FILE}"
			 if [[ $1 == "-e" ]];then
				 zm_path="$ZM_FILES_FILE"
			 fi

		local clash
		# check dir marks for collision
		if  __zshmarks_zgrep clash "\\|$zm_name\$" "$zm_path"; then
			 if [[ $1 == "-e" ]];then
				 printf "${RED}name clashes with zmark file: $clash${NOCOLOR}\n"
				 echo -n "delete zmark file?: $clash (y/n)? "
				 # __asktodelete zmfd "$clash"
				 __asktodelete zmrm "$clash"
			else
				 printf "${RED}name clashes with zmark dir: $clash${NOCOLOR}\n"
				 echo -n "delete zmark directory?: $clash (y/n)? "
				 __asktodelete zmrm "$clash"
			fi
			__zm_checkhashclash "$zm_name"
	 fi
		}



	 __zm_checkhashclash(){
	  local zm_name="$1"
		local hashexists=$(echo ~"$zm_name")
		# echo "zshmarks/init.zsh: 535 zm_name: $zm_name"
		# echo "zshmarks/init.zsh: 401 hashexists: $hashexists"
		if [[ ! -z $hashexists ]]; then
				printf "${RED}Named hash clash${NOCOLOR}\n"
				echo 'If you created this, you can remove it and try again, but this could potentially be set by a program running on your machine. If you did not create it, I would just choose another name.'
				clashfail=true
				return 1
		fi
	 }
