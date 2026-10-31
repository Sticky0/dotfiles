#!/usr/bin/env bash
# Reloj + calendario (festivos Comunitat Valenciana) para waybar.
#
# Uso:
#   clock-calendar.sh              tick de 1 s: imprime el JSON del módulo
#   clock-calendar.sh toggle-alt   alterna hora <-> fecha y refresca waybar
#   clock-calendar.sh toggle-mode  alterna mes <-> año y refresca waybar
#
# El tick no usa python: la plantilla JSON con el calendario la cachea
# clock-calendar.py --build (se rehace al cambiar de día o de modo). El flag
# de hora/fecha usa template-alt, ya renderizado (la fecha solo cambia a
# medianoche).
#
# Los toggles flipan el estado y avisan a waybar con SIGRTMIN+9 (opción
# "signal" del módulo): así el refresco es inmediato y no depende de esperar
# al siguiente tick.
set -uo pipefail

runtime="${XDG_RUNTIME_DIR:-/tmp}"
dir="$runtime/waybar-clock-calendar"
modef="$runtime/waybar-clock-calendar.mode"
altf="$runtime/waybar-clock-calendar.alt"
py="$HOME/.config/waybar/scripts/clock-calendar.py"
signal="RTMIN+9"

refresh_waybar() {
  local pid
  pid=$(pgrep -x waybar | head -1)
  [[ -n "$pid" ]] && kill -s "$signal" "$pid" 2>/dev/null
}

read_flag() { cat "$1" 2>/dev/null || true; }

case "${1:-}" in
  toggle-alt)
    if [[ "$(read_flag "$altf")" == "1" ]]; then
      echo 0 > "$altf"
    else
      echo 1 > "$altf"
    fi
    refresh_waybar
    exit 0
    ;;
  toggle-mode)
    if [[ "$(read_flag "$modef")" == "year" ]]; then
      echo month > "$modef"
    else
      echo year > "$modef"
    fi
    refresh_waybar
    exit 0
    ;;
esac

mode=$(read_flag "$modef")
mode=${mode:-month}

printf -v today '%(%F)T' -1
stamp=$(read_flag "$dir/stamp")

if [[ "$stamp" != "$today|$mode" ]]; then
  python3 "$py" --build || exit 1
fi

if [[ "$(read_flag "$altf")" == "1" ]]; then
  [[ -r "$dir/template-alt" ]] || python3 "$py" --build || exit 1
  cat "$dir/template-alt"
  exit 0
fi

template=$(read_flag "$dir/template") || exit 1
printf -v now '%(%H:%M:%S)T' -1
printf '%s\n' "${template//TIME/$now}"
