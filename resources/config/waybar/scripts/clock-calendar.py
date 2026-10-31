#!/usr/bin/env python3
"""Reloj + calendario con festivos de la Comunitat Valenciana para waybar.

Replica el formato del calendar nativo de waybar 0.15 (src/modules/clock.cpp):
título en minúscula del locale, celdas de 2 caracteres, columna de mes de 20
caracteres, 3 espacios entre columnas de meses y nº de semana a la derecha.
Lo único añadido: cuadrado lavanda en el día de hoy y cuadrado rojo en festivos.

Salida: JSON de una línea (custom module de waybar):
    {"text": "<markup>", "tooltip": "<markup>", "class": "clock"}

Modos:
    --build         cachea la plantilla (placeholder TIME) para el emisor bash
    --toggle-mode   alterna mes <-> año (on-click-right)
    --once          imprime una vez y sale (tests)
    --date YYYY-MM-DD  renderiza como si hoy fuese esa fecha (tests)
"""

import calendar
import datetime
import json
import os
import sys
import time

ICON = "\U000f00f1"  # nerd font: reloj
MONTHS = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio",
          "agosto", "septiembre", "octubre", "noviembre", "diciembre"]
WEEKDAYS = ["lu", "ma", "mi", "ju", "vi", "sá", "do"]

MONTH_COL = 20               # cldMonColLen_ del nativo
WEEKS_COL = 3                # cldWnLen_ del nativo (espacio + 2 dígitos)
YEAR_COLS = 3                # mode-mon-col
SEP = "   "                  # separador entre meses en modo año

TODAY_BG = "#b4befe"         # lavanda (Catppuccin Mocha) sobre base
TODAY_FG = "#1e1e2e"
HOLIDAY_BG = "#f38ba8"       # rojo Catppuccin Mocha
HOLIDAY_FG = "#1e1e2e"
WEEKEND_FG = "#f9e2af"       # amarillo Catppuccin Mocha (sábado y domingo)

CACHE_ROOT = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
CACHE_DIR = os.path.join(CACHE_ROOT, "waybar-clock-calendar")
STATE_FILE = os.path.join(CACHE_ROOT, "waybar-clock-calendar.mode")
ALT_FILE = os.path.join(CACHE_ROOT, "waybar-clock-calendar.alt")


def easter(year: int) -> datetime.date:
    """Domingo de Resurrección (algoritmo de Meeus/Jones/Butcher)."""
    a = year % 19
    b, c = divmod(year, 100)
    d, e = divmod(b, 4)
    f = (b + 8) // 25
    g = (b - f + 1) // 3
    h = (19 * a + b - d - g + 15) % 30
    i, k = divmod(c, 4)
    l = (32 + 2 * e + 2 * i - h - k) % 7
    m = (a + 11 * h + 22 * l) // 451
    month, day = divmod(h + l - 7 * m + 114, 31)
    return datetime.date(year, month, day + 1)


def holidays(year: int) -> set:
    """Festivos laborales de la Comunitat Valenciana (sin los locales)."""
    pascua = easter(year)
    fijos = [(1, 1), (1, 6), (3, 19), (5, 1), (6, 24), (8, 15),
             (10, 9), (10, 12), (11, 1), (12, 6), (12, 8), (12, 25)]
    dias = {datetime.date(year, m, d) for m, d in fijos}
    dias.add(pascua - datetime.timedelta(days=2))   # Viernes Santo
    dias.add(pascua + datetime.timedelta(days=1))   # Lunes de Pascua
    return dias


def cell(day: datetime.date, today: datetime.date, fests: set) -> str:
    """Celda de un día: 2 caracteres; cuadrado si es hoy o festivo, letra amarilla en finde."""
    label = f"{day.day:2d}"
    if day == today:
        return (f"<span background='{TODAY_BG}' foreground='{TODAY_FG}'>"
                f"<b>{label}</b></span>")
    if day in fests:
        return (f"<span background='{HOLIDAY_BG}' foreground='{HOLIDAY_FG}'>"
                f"<b>{label}</b></span>")
    if day.weekday() >= 5:
        return f"<span foreground='{WEEKEND_FG}'>{label}</span>"
    return label


def week_rows(year: int, month: int) -> list:
    """Filas de semanas del mes, cada una con 7 posiciones (None si vacío)."""
    first = datetime.date(year, month, 1)
    ndays = calendar.monthrange(year, month)[1]
    days = [None] * first.weekday() + [datetime.date(year, month, d)
                                       for d in range(1, ndays + 1)]
    while len(days) % 7:
        days.append(None)
    return [days[i:i + 7] for i in range(0, len(days), 7)]


def month_lines(year: int, month: int, today: datetime.date, fests: set,
                weeks: bool) -> list:
    """Un mes con el formato nativo: título, cabecera y filas de semanas."""
    first = datetime.date(year, month, 1)
    col = MONTH_COL + (WEEKS_COL if weeks else 0)
    rows = week_rows(year, month)

    title = f"{MONTHS[month - 1]} {year}"
    out = [title.ljust(col)]
    out.append(" ".join(WEEKDAYS).ljust(col))

    for idx, row in enumerate(rows):
        line = " ".join(cell(d, today, fests) if d else "  " for d in row)
        if weeks:
            if idx < len(rows) - 1:
                monday = first - datetime.timedelta(days=first.weekday())
                ref = first if idx == 0 else monday + datetime.timedelta(days=7 * idx)
                line += f" {ref.isocalendar()[1]:2d}"
            else:
                line += " " * WEEKS_COL
        out.append(line)
    return out


def calendar_text(today: datetime.date, mode: str) -> str:
    fests = holidays(today.year)

    if mode == "year":
        blocks = [month_lines(today.year, m, today, fests, weeks=True)
                  for m in range(1, 13)]
        width = MONTH_COL + WEEKS_COL
        lines = []
        for i in range(0, 12, YEAR_COLS):
            group = blocks[i:i + YEAR_COLS]
            for row in range(max(len(b) for b in group)):
                lines.append(SEP.join((b[row] if row < len(b) else "").ljust(width)
                                      for b in group).rstrip())
            lines.append("")
        return "\n".join(lines).rstrip()

    return "\n".join(month_lines(today.year, today.month, today, fests, weeks=True))


def render(now: datetime.datetime, mode: str, alt: bool = False) -> dict:
    return {
        "text": text_for(now, alt),
        "tooltip": f"<tt><small>{calendar_text(now.date(), mode)}</small></tt>",
        "class": "clock",
    }


def text_for(now: datetime.datetime, alt: bool) -> str:
    """Hora con segundos o fecha larga (equivalente a format / format-alt)."""
    if alt:
        fecha = f"{now.day:02d} {MONTHS[now.month - 1]} {now.year}"
        return f"{ICON} <span size='11pt'>{fecha}</span>"
    return f"{ICON} <span size='11pt'>{now:%H:%M:%S}</span>"


def read_flag(path: str) -> bool:
    try:
        with open(path) as fh:
            return fh.read().strip() == "1"
    except OSError:
        return False


def write_flag(path: str, value: bool) -> None:
    try:
        with open(path, "w") as fh:
            fh.write("1" if value else "0")
    except OSError as err:
        print(f"no se pudo guardar {path}: {err}", file=sys.stderr)


def read_mode() -> str:
    try:
        with open(STATE_FILE) as fh:
            mode = fh.read().strip()
    except OSError:
        return "month"
    return "year" if mode == "year" else "month"


def write_mode(mode: str) -> None:
    try:
        with open(STATE_FILE, "w") as fh:
            fh.write(mode)
    except OSError as err:
        print(f"no se pudo guardar el modo: {err}", file=sys.stderr)


def build() -> None:
    """Cachea la plantilla JSON (con placeholder TIME) para el emisor bash."""
    now = datetime.datetime.now()
    body = render(now, read_mode())
    base = {"tooltip": body["tooltip"], "class": "clock"}
    template = json.dumps(
        {**base, "text": f"{ICON} <span size='11pt'>TIME</span>"}, ensure_ascii=False
    )
    template_alt = json.dumps(
        {**base, "text": text_for(now, True)}, ensure_ascii=False
    )
    os.makedirs(CACHE_DIR, exist_ok=True)
    writes = {
        os.path.join(CACHE_DIR, "template"): template,
        os.path.join(CACHE_DIR, "template-alt"): template_alt,
        os.path.join(CACHE_DIR, "stamp"):
            f"{datetime.date.today().isoformat()}|{read_mode()}",
    }
    for path, data in writes.items():
        tmp = f"{path}.tmp"
        with open(tmp, "w") as fh:
            fh.write(data)
        os.replace(tmp, path)


def main() -> int:
    args = sys.argv[1:]

    if "--toggle-mode" in args:
        write_mode("month" if read_mode() == "year" else "year")
        return 0

    if "--toggle-alt" in args:
        write_flag(ALT_FILE, not read_flag(ALT_FILE))
        return 0

    if "--build" in args:
        build()
        return 0

    today = None
    if "--date" in args:
        today = datetime.date.fromisoformat(args[args.index("--date") + 1])

    now = datetime.datetime.now()
    if today is not None:
        now = now.replace(year=today.year, month=today.month, day=today.day)

    if "--once" in args:
        print(json.dumps(render(now, read_mode(), read_flag(ALT_FILE)),
                         ensure_ascii=False), flush=True)
        return 0

    while True:
        now = datetime.datetime.now()
        print(json.dumps(render(now, read_mode()), ensure_ascii=False), flush=True)
        time.sleep(max(0.05, 1 - time.time() % 1))


if __name__ == "__main__":
    sys.exit(main())
