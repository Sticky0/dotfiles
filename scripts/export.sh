#!/usr/bin/env bash
# Regenera resources/ a partir del estado actual de este PC.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
R="$REPO/resources"
FORBIDDEN_FILE="${DOTFILES_FORBIDDEN:-$HOME/.config/dotfiles/forbidden}"
[ -s "$FORBIDDEN_FILE" ] || { echo "Falta $FORBIDDEN_FILE (patrones prohibidos, uno por línea)" >&2; exit 1; }

CONFIG_DIRS=(hypr waybar kitty nvim wofi dunst yazi Kvantum gtk-3.0 gtk-4.0 nwg-look nwg-displays autostart systemd)
CONFIG_FILES=(mimeapps.list user-dirs.dirs)
HOME_FILES=(.p10k.zsh .gtkrc-2.0)
LOCAL_BIN=(pfetch waybar-brightness-notify waybar-volume-notify)
ETC_FILES=(sddm.conf.d/theme.conf systemd/zram-generator.conf)
LOOKS=(looks.png looks_3.png)

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }

clean_tree() {
  find "$1" \( -name '*.bak*' -o -name '*.backup*' -o -name '*.orig' -o -name '__pycache__' \
    -o -name 'mimeinfo.cache' -o -name '*.wants' -o -name '.git' \) -prune -exec rm -rf {} +
}

templatize() {
  grep -rIl -- "$HOME" "$1" 2>/dev/null | while read -r f; do
    sed -i "s|$HOME|@HOME@|g" "$f"
  done
}

log "Limpiando resources/ (salvo img/wallpapers, gestionado aparte)"
mkdir -p "$R"
find "$R" -mindepth 1 -maxdepth 1 ! -name img -exec rm -rf {} +
mkdir -p "$R"/{config,home,local-bin,etc,packages,pi,omz} "$R/img/looks" "$R/img/wallpapers"

log "Configs de ~/.config"
for d in "${CONFIG_DIRS[@]}"; do [ -e "$HOME/.config/$d" ] && cp -a "$HOME/.config/$d" "$R/config/"; done
for f in "${CONFIG_FILES[@]}"; do [ -e "$HOME/.config/$f" ] && cp -a "$HOME/.config/$f" "$R/config/"; done

log "Ficheros de ~"
for f in "${HOME_FILES[@]}"; do [ -e "$HOME/$f" ] && cp -a "$HOME/$f" "$R/home/"; done
grep -vEif "$FORBIDDEN_FILE" "$HOME/.zshrc" | grep -v 'zshrc.local' > "$R/home/.zshrc"
# shellcheck disable=SC2016
printf '\n[[ -r "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"\n' >> "$R/home/.zshrc"

log "Scripts de ~/.local/bin"
for f in "${LOCAL_BIN[@]}"; do cp -a "$HOME/.local/bin/$f" "$R/local-bin/"; done

log "Ficheros de /etc"
for f in "${ETC_FILES[@]}"; do
  mkdir -p "$R/etc/$(dirname "$f")"
  cp "/etc/$f" "$R/etc/$f"
done

log "oh-my-zsh: lista de plugins/temas git + plugins locales"
: > "$R/packages/omz-repos.txt"
for p in "$HOME"/.oh-my-zsh/custom/{plugins,themes}/*; do
  name="$(basename "$p")"
  [ "$name" = example ] || [ "$name" = example.zsh-theme ] && continue
  kind="$(basename "$(dirname "$p")")"
  if [ -d "$p/.git" ]; then
    echo "$kind $name $(git -C "$p" remote get-url origin)" >> "$R/packages/omz-repos.txt"
  elif [ -d "$p" ]; then
    mkdir -p "$R/omz/$kind" && cp -a "$p" "$R/omz/$kind/"
  fi
done

log "pi: extensiones locales, temas y paquetes"
cp -a "$HOME/.pi/agent/extensions" "$HOME/.pi/agent/themes" "$R/pi/"
jq -r '.packages[] | if type=="string" then . else .source end' "$HOME/.pi/agent/settings.json" > "$R/packages/pi-packages.txt"

log "Listas de paquetes y servicios"
pacman -Qqen > "$R/packages/pacman.txt"
pacman -Qqem > "$R/packages/aur.txt"
: > "$R/packages/npm-global.txt"
for m in "$HOME"/.local/lib/node_modules/[!@]*; do [ -d "$m" ] && basename "$m" >> "$R/packages/npm-global.txt"; done
systemctl list-unit-files --state=enabled --no-legend | awk '{print $1}' | grep -v '@' > "$R/packages/services-system.txt"
systemctl --user list-unit-files --state=enabled --no-legend | awk '{print $1}' > "$R/packages/services-user.txt"
ls "$HOME/.local/share/JetBrains/Toolbox/apps" > "$R/packages/jetbrains.txt" 2>/dev/null || true

log "Imágenes"
cp -a "$HOME/Pictures/Wallpapers/." "$R/img/wallpapers/"
for f in "${LOOKS[@]}"; do cp -a "$HOME/Pictures/Screenshots/$f" "$R/img/looks/"; done

clean_tree "$R"
templatize "$R"

log "Comprobando palabras prohibidas"
if grep -rIniEf "$FORBIDDEN_FILE" "$R"; then
  echo "ERROR: hay contenido prohibido en resources/. Revisa antes de commitear." >&2
  exit 1
fi
log "Listo: $R"
