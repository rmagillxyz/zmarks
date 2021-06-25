Zmarks
========

A fork of [Zshmarks (by Jocelyn Mallon)](https://github.com/jocelynmallon/zshmarks)

How to install
--------------
Make sure ZDOTDIR environment variable is set.

`git clone http://github.com/rmagillxyz/zmarks ~/.config/zsh $ZDOTDIR`
and install [fzf](https://github.com/junegunn/fzf#installation)

then add `source "$HOME/.config/zsh/zmarks/init.zsh"` to your `.zshrc`

Commands/Usage:
--------------

* zmj - used to 'jump' (cd or $EDITOR) to the given bookmark directory or file. 
        zmj 'foo'

* zm - used to create a new bookmark for your current working directory

        cd 'some_dir'
        zm 'foo'

* zmf - used to create a new file bookmark
 
* zmrm - used to delete a bookmark

        zmrm 'foo'

* zms - prints a list of all saved bookmarks, or print the information for a single, specific bookmark

        showmarks 'foo'
        $HOME/foo

Additional commands:
-------------------

* zm_jump_n_source - jump to zsh file and source on save/quit  
* _zm_dir_jump - only checks and completes with directories
* _zm_file_jump - only checks and completes with files 
* _zm_clear_all - clear all (directories and files)
* _zm_clear_all_dirs - clear all directories
* _zm_clear_all_files - clear all files

FZF bindings: 
------------
_fzf_zm_jump (directories and files)
_fzf_zm_dir_jump
_fzf_zm_file_jump





oh-my-zsh
---------
* Download the script or clone this repository in [oh-my-zsh](http://github.com/robbyrussell/oh-my-zsh) plugins directory:

        cd ~/.oh-my-zsh/custom/plugins
        git clone https://github.com/rmagillxyz/zmarks.git

* Activate the plugin in `~/.zshrc`:

        plugins=( [plugins...] zmarks [plugins...])

* Source `~/.zshrc`  to take changes into account:

        source ~/.zshrc

antigen
-------
Add `antigen bundle rmagillxyz/zmarks` to your .zshrc where you're adding your other plugins. Antigen will clone the plugin for you and add it to your antigen setup the next time you start a new shell.

prezto
------
For most people the easiest way to use zmarks with [prezto](https://github.com/sorin-ionescu/prezto) is to manually clone the zmarks repo to a directory of your choice (e.g. /usr/local or ~/bin) and symlink the zmarks folder into your zpretzo/modules folder:

        ln -s ~/bin/zmarks ~/.zprezto/modules/zmarks

Alternatively, you can add the zmarks repository as a submodule to your prezto repo by manually editing the '.gitmodules' file:

        [submodule "modules/zmarks"]
        	path = modules/zmarks
        	url = https://github.com/rmagillxyz/zmarks.git

Then make sure you activate the plugin in your .zpreztorc file:

        zstyle ':prezto:load' pmodule \
        zmarks \
        ...

zplug
-----
Add the following to your .zshrc file somewhere after you source zplug.

        zplug "rmagillxyz/zmarks"

Notes/Tips:
-----------

You can change the location of the bookmarks files (default is $HOME/.local/share/zsh) by adding the environment variable 'ZMARKS_DIR' to your shell profile or .zshrc.

        export ZMARKS_DIR="foo/bar"

If you were expecting this to be a port of similarly named [Bashmarks (by huyng)](https://github.com/huyng/bashmarks), you can setup zmarks to behave in roughly the same way by adding the following aliases to your shell setup files/dotfiles:

        alias g="zmj"
        alias s="zm"
        alias d="zmrm"
        alias p="zms"
        alias l="zms"

(You can also omit the "l" alias, and just use p without an argument to show all  bookmarks.)

