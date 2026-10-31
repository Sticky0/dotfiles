#!/usr/bin/env bash
# Monta el escritorio en un Arch Linux recién instalado a partir de resources/.
# Uso: scripts/install.sh [--dry-run] [--no-packages] [--no-aur] [--no-services]
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
R="$REPO/resources"
BACKUP="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
DRY=0 PKGS=1 AUR=1 SERVICES=1

for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    --no-packages) PKGS=0 ;;
    --no-aur) AUR=0 ;;
    --no-services) SERVICES=0 ;;
    -h|--help) sed -n '2,3p' "$0"; exit 0 ;;
    *) echo "Opción desconocida: $a" >&2; exit 1 ;;
  esac
done

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
run() { if [ "$DRY" = 1 ]; then echo "  [dry-run] $*"; else "$@"; fi; }
list() { grep -vE '^\s*(#|$)' "$1"; }

[ -f /etc/arch-release ] || { echo "Este script es solo para Arch Linux." >&2; exit 1; }
[ "$(id -u)" != 0 ] || { echo "Ejecútalo como tu usuario, no como root (usa sudo cuando hace falta)." >&2; exit 1; }

install_pacman() {
  log "Paquetes oficiales ($(list "$R/packages/pacman.txt" | wc -l))"
  if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
    run sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
  fi
  run sudo pacman -Syu --needed --noconfirm git git-lfs base-devel nodejs npm
  # shellcheck disable=SC2046
  run sudo pacman -S --needed --noconfirm $(list "$R/packages/pacman.txt")
}

install_aur() {
  if ! command -v yay >/dev/null; then
    log "Instalando yay"
    local tmp; tmp="$(mktemp -d)"
    run git clone https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
    if [ "$DRY" = 0 ]; then (cd "$tmp/yay-bin" && makepkg -si --noconfirm); fi
    rm -rf "$tmp"
  fi
  log "Paquetes AUR ($(list "$R/packages/aur.txt" | wc -l))"
  # shellcheck disable=SC2046
  run yay -S --needed --noconfirm --answerdiff None --answerclean None $(list "$R/packages/aur.txt" | grep -vx 'yay-bin')
}

backup_and_copy() {
  local src="$1" dst="$2"
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    run mkdir -p "$BACKUP/$(dirname "${dst#"$HOME"/}")"
    run cp -a "$dst" "$BACKUP/${dst#"$HOME"/}"
  fi
  if [ -d "$src" ]; then
    run mkdir -p "$dst"
    run cp -a "$src/." "$dst/"
  else
    run mkdir -p "$(dirname "$dst")"
    run cp -a "$src" "$dst"
  fi
  if [ "$DRY" = 0 ]; then
    if [ -d "$dst" ]; then
      { grep -rIl '@HOME@' "$dst" 2>/dev/null || true; } | xargs -r sed -i "s|@HOME@|$HOME|g"
    elif grep -qI '@HOME@' "$dst" 2>/dev/null; then
      sed -i "s|@HOME@|$HOME|g" "$dst"
    fi
  fi
}

install_shell() {
  log "oh-my-zsh, powerlevel10k y plugins"
  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    run git clone --depth 1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
  fi
  while read -r kind name url; do
    local dst="$HOME/.oh-my-zsh/custom/$kind/$name"
    [ -d "$dst" ] || run git clone --depth 1 "$url" "$dst"
  done < <(list "$R/packages/omz-repos.txt")
  if [ -d "$R/omz" ]; then
    for kind in "$R"/omz/*; do
      for p in "$kind"/*; do backup_and_copy "$p" "$HOME/.oh-my-zsh/custom/$(basename "$kind")/$(basename "$p")"; done
    done
  fi
  if [ "$(getent passwd "$USER" | cut -d: -f7)" != "/usr/bin/zsh" ]; then
    run sudo chsh -s /usr/bin/zsh "$USER"
  fi
}

install_dotfiles() {
  log "Configs en ~/.config"
  for p in "$R"/config/*; do backup_and_copy "$p" "$HOME/.config/$(basename "$p")"; done
  log "Ficheros en ~"
  for p in "$R"/home/.[!.]*; do backup_and_copy "$p" "$HOME/$(basename "$p")"; done
  log "Scripts en ~/.local/bin"
  for p in "$R"/local-bin/*; do backup_and_copy "$p" "$HOME/.local/bin/$(basename "$p")"; done
  log "Wallpapers en ~/Pictures/Wallpapers"
  run mkdir -p "$HOME/Pictures/Wallpapers" "$HOME/Pictures/Screenshots"
  run cp -a "$R/img/wallpapers/." "$HOME/Pictures/Wallpapers/"
  log "Ficheros de sistema en /etc"
  (cd "$R/etc" && find . -type f) | while read -r f; do
    run sudo install -Dm644 "$R/etc/$f" "/etc/${f#./}"
  done
}

install_git_identity() {
  if [ -z "$(git config --global user.email || true)" ] && [ "$DRY" = 0 ] && [ -t 0 ]; then
    log "Identidad de git (global)"
    read -rp "  Nombre: " gname
    read -rp "  Email: " gmail
    git config --global user.name "$gname"
    git config --global user.email "$gmail"
  fi
}

install_pi() {
  log "pi (agente) y sus extensiones"
  if ! command -v pi >/dev/null && [ ! -x "$HOME/.pi/agent/bin/pi" ]; then
    if [ "$DRY" = 1 ]; then echo "  [dry-run] curl -fsSL https://pi.dev/install.sh | sh"
    else curl -fsSL https://pi.dev/install.sh | sh; fi
  fi
  local pi_bin; pi_bin="$(command -v pi || echo "$HOME/.pi/agent/bin/pi")"
  while read -r pkg; do run "$pi_bin" install "$pkg" || echo "  aviso: no se pudo instalar $pkg"; done < <(list "$R/packages/pi-packages.txt")
  run mkdir -p "$HOME/.pi/agent"
  for p in "$R"/pi/*; do backup_and_copy "$p" "$HOME/.pi/agent/$(basename "$p")"; done
  if [ -s "$R/packages/npm-global.txt" ]; then
    log "Paquetes npm globales (prefijo ~/.local)"
    # shellcheck disable=SC2046
    run npm install -g --prefix "$HOME/.local" $(list "$R/packages/npm-global.txt")
  fi
}

enable_services() {
  log "Servicios del sistema"
  while read -r s; do
    systemctl cat "$s" >/dev/null 2>&1 && run sudo systemctl enable "$s" || echo "  aviso: $s no existe, se omite"
  done < <(list "$R/packages/services-system.txt")
  log "Servicios de usuario"
  run systemctl --user daemon-reload || true
  while read -r s; do run systemctl --user enable "$s" || echo "  aviso: $s no se pudo habilitar"; done < <(list "$R/packages/services-user.txt")
  getent group docker >/dev/null && ! id -nG | grep -qw docker && run sudo usermod -aG docker "$USER"
  return 0
}

[ "$PKGS" = 1 ] && install_pacman
[ "$PKGS" = 1 ] && [ "$AUR" = 1 ] && install_aur
install_shell
install_dotfiles
install_git_identity
install_pi
[ "$SERVICES" = 1 ] && enable_services

log "Hecho."
if [ -d "$BACKUP" ]; then echo "    Backup de lo que había antes: $BACKUP"; fi
cat <<EOF
    Pasos manuales: claves SSH/GPG, iniciar sesión en las apps,
    IDEs de JetBrains Toolbox ($(tr '\n' ' ' < "$R/packages/jetbrains.txt")),
    credenciales de pi (pi auth) y reiniciar para entrar en Hyprland con SDDM.
EOF
