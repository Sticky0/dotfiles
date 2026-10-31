# Oh My Zsh + Powerlevel10k Catppuccin Mocha
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

# Mantener la configuración de Catppuccin Mocha al cargar el plugin.
zstyle ':catppuccin:p10k' theme classic
zstyle ':catppuccin:p10k' flavour mocha

plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
  catppuccin-powerlevel10k-themes
)

source "$ZSH/oh-my-zsh.sh"

alias vim=nvim
alias vi=nvim



# Carga explícita del perfil para que p10k use Catppuccin Mocha.
[[ -r "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"

# Pfetch on startup
pfetch

# Pi
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.pi/agent/bin:$PATH"

[[ -r "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
