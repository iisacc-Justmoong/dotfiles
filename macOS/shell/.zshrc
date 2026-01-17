export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="jonathan"
plugins=(git)

source $ZSH/oh-my-zsh.sh
#source ~/CraftRoot/craft/craftenv.sh

source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh

alias python=python3
alias pip=pip3
alias brew-up='brew update && brew upgrade && brew cleanup'

b() {
    brew cleanup
    brew update
    brew upgrade
    brew cleanup
    echo "Check Complete at $(date)." >> ~/checkbrew.log
}

dot() {
    cd .dotfiles/
    wait 2
    echo "start sync .dotfiles on git"
    sudo git add .
    sudo git commit -m "Fixed at: $(date '+%Y-%m-%d %H:%M:%S')"
    sudo git push
    echo "Fixed at: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Done"
    cd
}

eval "$(rbenv init - zsh)"

export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

export CMAKE_PREFIX_PATH=$HOME/Qt/6.8.3/macos:$CMAKE_PREFIX_PATH
export PATH="$HOME/Qt/6.8.3/macos/bin:$PATH"
export DIST_CERT_SHA=<SHA1_PLACEHOLDER>
export DIST_CERT_SHA=<SHA1_PLACEHOLDER>
# Added by Antigravity
export PATH="/Users/ymy/.antigravity/antigravity/bin:$PATH"
