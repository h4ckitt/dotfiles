# Anigen Source
source ~/.files/antigen.zsh
antigen init ~/.antigenrc

# Themes.
ZSH_THEME="bubblified"

# Case-sensitive completion.
CASE_SENSITIVE="false"

# Disable bi-weekly auto-update checks.
DISABLE_AUTO_UPDATE="true"

# Disable auto-setting terminal title.
DISABLE_AUTO_TITLE="true"

# Disable marking untracked files under VCS as dirty.
DISABLE_UNTRACKED_FILES_DIRTY="true"

# History.
HIST_STAMPS="yyyy-mm-dd"

# Plugins.
plugins=(
    torrent
    archive
    extract
    git
    ssh-agent
    z
)

# Environment variables.
source ~/.exports

# Oh My Zsh.
source ~/.oh-my-zsh/oh-my-zsh.sh

# User config.
source ~/.zsh/setopt.zsh

# Aliases.
source ~/.aliases
#source ~/.aliases_private

# Functions.
source ~/.functions
#source ~/.functions_private

# Tracks your most used directories, based on frecency with z.
#source ~/.oh-my-zsh/plugins/z/z.sh

# dircolors.
if [ -x "$(command -v dircolors)" ]; then
    eval "$(dircolors -b ~/.dircolors)"
fi

# fzf key bindings.
if [ -x "$(command -v fzf)" ]; then
#    source ~/.fzf/shell/key-bindings.zsh
fi

# Manage SSH with Keychain.
if [ -x "$(command -v keychain)" ]; then
    eval "$(keychain --eval --quiet id_rsa_github id_rsa_gitlab)"
fi

# Base16 Shell.
if [ -f ~/.local/bin/base16-oxide ]; then
    source ~/.local/bin/base16-oxide
fi
export PATH=/home/dharmy/Documents/Tools/Postman/app:/home/dharmy/go/bin:/usr/local/go/bin:/usr/pgadmin4/bin/:/usr/pgadmin4/bin/pgadmin4:$PATH
