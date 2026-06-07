#!/usr/bin/env bash
set -euo pipefail

# ============================================================
#  dotfiles setup — curl -fsSL <url>/setup.sh | bash
# ============================================================
#  Idempotent. Safe to run over and over.
#  Clones dotfiles to ~/.dotfiles, sets up antigen, wires zshrc.
# ============================================================

DOTFILES="${HOME}/.dotfiles"
REPO="https://github.com/h4ckitt/dotfiles.git"

# -- colors --
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

info()  { echo -e "${BLUE}==>${NC} $*"; }
ok()    { echo -e "${GREEN}==>${NC} $*"; }
warn()  { echo -e "${YELLOW}==>${NC} $*"; }
err()   { echo -e "${RED}==>${NC} $*"; }

# -----------------------------------------------------------
# Check that the essentials are available
# -----------------------------------------------------------
check_deps() {
    info "Checking dependencies..."

    if ! command -v zsh &>/dev/null; then
        err "zsh is required but not installed. Install it first."
        exit 1
    fi

    if ! command -v git &>/dev/null; then
        err "git is required but not installed. Install it first."
        exit 1
    fi

    if ! command -v curl &>/dev/null; then
        err "curl is required but not installed. Install it first."
        exit 1
    fi

    if ! command -v bat &>/dev/null; then
        err "bat is required but not installed. Install it first."
        exit 1
    fi

    ok "Dependencies look good."
}

# -----------------------------------------------------------
# Clone (or pull) the dotfiles repo into ~/.dotfiles
# -----------------------------------------------------------
install_dotfiles() {
    if [[ -d "${DOTFILES}/.git" ]]; then
        info "~/.dotfiles already exists — pulling latest..."
        git -C "${DOTFILES}" pull --ff-only || warn "Could not pull (you may have local changes)."
    else
        if [[ -d "${DOTFILES}" ]]; then
            warn "~/.dotfiles exists but is not a git repo — backing it up."
            mv "${DOTFILES}" "${DOTFILES}.bak.$(date +%s)"
        fi
        info "Cloning dotfiles into ~/.dotfiles..."
        git clone "${REPO}" "${DOTFILES}"
    fi

    ok "Dotfiles are in ${DOTFILES}"
}

# -----------------------------------------------------------
# Install oh-my-zsh if not already present
# -----------------------------------------------------------
install_ohmyzsh() {
    if [[ -d "${HOME}/.oh-my-zsh" ]]; then
        ok "oh-my-zsh already installed."
        return
    fi

    info "Installing oh-my-zsh..."
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    ok "oh-my-zsh installed."
}

# -----------------------------------------------------------
# Install antigen and populate .antigenrc in ~/.dotfiles
# -----------------------------------------------------------
setup_antigen() {
    info "Setting up antigen..."

    # Download antigen if not already present
    if [[ ! -f "${HOME}/.antigen/antigen.zsh" ]]; then
        mkdir -p "${HOME}/.antigen"
        info "  Downloading antigen..."
        curl -fsSL git.io/antigen > "${HOME}/.antigen/antigen.zsh"
        ok "  antigen downloaded."
    else
        ok "  antigen already present."
    fi

    # Create ~/.dotfiles/antigenrc if missing
    if [[ ! -f "${DOTFILES}/antigenrc" ]]; then
        info "  Creating ~/.dotfiles/antigenrc..."
        cat > "${DOTFILES}/antigenrc" << 'EOF'
# Use Oh-My-Zsh
antigen use oh-my-zsh

antigen bundle zsh-users/zsh-completions
antigen bundle zsh-users/zsh-autosuggestions
antigen bundle zsh-users/zsh-syntax-highlighting

# Apply Configs
antigen apply
EOF
        ok "  ~/.dotfiles/antigenrc created."
    else
        ok "  ~/.dotfiles/antigenrc already exists — skipped."
    fi
}

# -----------------------------------------------------------
# Wire up ~/.zshrc to source from ~/.dotfiles
# -----------------------------------------------------------
update_zshrc() {
    local ZSHRC="${HOME}/.zshrc"
    local NEED_ANTIGEN=false
    local NEED_ALIASES=false
    local NEED_FUNCTIONS=false

    info "Wiring up ~/.zshrc..."

    # If no .zshrc at this point, oh-my-zsh install must have failed.
    # Create a bare-minimum bootstrap so the shell isn't broken.
    if [[ ! -f "${ZSHRC}" ]]; then
        info "  No ~/.zshrc found — creating bare bootstrap."
        cat > "${ZSHRC}" << 'EOF'
# Load Antigen
source ~/.antigen/antigen.zsh

# Source Aliases And Custom Functions
source ~/.dotfiles/.aliases
source ~/.dotfiles/.functions

# Load Antigen Configs
antigen init ~/.dotfiles/antigenrc
EOF
        ok "  ~/.zshrc created."
        return
    fi

    # -- oh-my-zsh already wrote the zshrc, we just layer our stuff on top --

    # Add z + extract to the plugins line if missing
    if grep -q 'plugins=(' "${ZSHRC}" 2>/dev/null; then
        if ! grep -q 'plugins=([^)]*[[:space:]]z[[:space:]])' "${ZSHRC}" 2>/dev/null && \
           ! grep -q 'plugins=([^)]*[[:space:]]z)'    "${ZSHRC}" 2>/dev/null; then
            info "  Adding 'z' to plugins..."
            sed -i '' 's/plugins=(\(.*\))/plugins=(\1 z)/' "${ZSHRC}"
        fi
        if ! grep -q 'plugins=([^)]*[[:space:]]extract[[:space:]])' "${ZSHRC}" 2>/dev/null && \
           ! grep -q 'plugins=([^)]*[[:space:]]extract)'    "${ZSHRC}" 2>/dev/null; then
            info "  Adding 'extract' to plugins..."
            sed -i '' 's/plugins=(\(.*\))/plugins=(\1 extract)/' "${ZSHRC}"
        fi
    fi

    # Check what needs updating
    if ! grep -q "antigen" "${ZSHRC}" 2>/dev/null; then
        NEED_ANTIGEN=true
    fi

    if ! grep -q 'source.*\.dotfiles/\.aliases' "${ZSHRC}" 2>/dev/null; then
        NEED_ALIASES=true
    fi

    if ! grep -q 'source.*\.dotfiles/\.functions' "${ZSHRC}" 2>/dev/null; then
        NEED_FUNCTIONS=true
    fi

    # Fix old paths (~/.aliases → ~/.dotfiles/.aliases)
    if grep -q 'source ~/\.aliases' "${ZSHRC}" 2>/dev/null; then
        info "  Updating alias source path: ~/.aliases → ~/.dotfiles/.aliases"
        sed -i '' 's|source ~/\.aliases|source ~/.dotfiles/.aliases|g' "${ZSHRC}"
        NEED_ALIASES=false
    fi

    if grep -q 'source ~/\.functions' "${ZSHRC}" 2>/dev/null; then
        info "  Updating functions source path: ~/.functions → ~/.dotfiles/.functions"
        sed -i '' 's|source ~/\.functions|source ~/.dotfiles/.functions|g' "${ZSHRC}"
        NEED_FUNCTIONS=false
    fi

    # Add antigen bootstrap if missing
    if ${NEED_ANTIGEN}; then
        info "  Adding antigen bootstrap to ~/.zshrc..."
        {
            echo ''
            echo '# >>> dotfiles: antigen bootstrap >>>'
            echo 'source ~/.antigen/antigen.zsh'
            echo 'antigen init ~/.dotfiles/antigenrc'
            echo '# <<< dotfiles: antigen bootstrap <<<'
        } >> "${ZSHRC}"
    fi

    # Add source lines if missing
    if ${NEED_ALIASES}; then
        info "  Adding aliases source to ~/.zshrc..."
        echo 'source ~/.dotfiles/.aliases' >> "${ZSHRC}"
    fi

    if ${NEED_FUNCTIONS}; then
        info "  Adding functions source to ~/.zshrc..."
        echo 'source ~/.dotfiles/.functions' >> "${ZSHRC}"
    fi

    ok "~/.zshrc is wired up."
}

# -----------------------------------------------------------
# Main
# -----------------------------------------------------------
main() {
    echo ''
    echo -e "${GREEN}══════════════════════════════════════${NC}"
    echo -e "${GREEN}   dotfiles bootstrap${NC}"
    echo -e "${GREEN}══════════════════════════════════════${NC}"
    echo ''

    check_deps
    install_dotfiles
    install_ohmyzsh
    setup_antigen
    update_zshrc

    echo ''
    echo -e "${GREEN}══════════════════════════════════════${NC}"
    echo -e "${GREEN}   All done!${NC}"
    echo ''
    echo -e "  Restart your shell:  ${BLUE}exec zsh${NC}"
    echo -e "  Or open a new terminal tab."
    echo ''
    echo -e "${GREEN}══════════════════════════════════════${NC}"
    echo ''
}

main "$@"
