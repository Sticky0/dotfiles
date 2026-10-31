# Waybar

### Full Dekstop
<img width="2880" height="1800" alt="full_desktop_waybar" src="https://github.com/user-attachments/assets/c9ee976f-83c0-4dfd-95c5-a5d0de4bc33c" />

### Showcase
https://github.com/user-attachments/assets/150b7b3d-9b5d-4a0f-a7a4-47977d99e9e5

---

### Structure

```
waybar/
├── config.jsonc                     # Entry point, loads all modules
├── style.css                        # Main stylesheet
├── modules/
│   ├── audio.jsonc
│   ├── backlight.jsonc             # Indicador de brillo
│   ├── battery.jsonc
│   ├── clock.jsonc
│   ├── connections.jsonc
│   ├── distro.jsonc                 < Applications embedded
│   ├── groups.jsonc                 # Drawer grouping
│   ├── idle-inhibitor.jsonc
│   ├── power-profiles-daemon.jsonc
│   ├── storage.jsonc
│   ├── system.jsonc
│   ├── tray-notif.jsonc             # Tray + SwayNC
│   └── workspace.jsonc
└── tokens/                          # CSS variables
    ├── colors.css                   < edit colors here
    ├── batt-clock.css
    ├── slider.css
    ├── state.css
    ├── widget.css
    └── workspace.css
```

---

### Dependencies

| Package | Purpose |
| --- | --- |
| [SwayNC](https://github.com/ErikReider/SwayNotificationCenter) | Notification center |
| [nm-applet](https://wiki.archlinux.org/title/NetworkManager) | Network manager |
| [blueman](https://wiki.archlinux.org/title/Blueman) | Bluetooth manager |
| [pipewire](https://wiki.archlinux.org/title/PipeWire) / [pulseaudio](https://wiki.archlinux.org/title/PulseAudio) | Audio |
| `brightnessctl` / módulo `backlight` | Indicador y barra de brillo independientes del audio |

### Instalación
Esta configuración se mantiene directamente en `~/.config/waybar` y ya no se gestiona desde `~/dotfiles`. Hyprland inicia Waybar automáticamente al arrancar.

El tema incluye botones para aplicaciones opcionales (Code, Obsidian, Spotify, Firefox, Thunar y OnlyOffice); si no están instaladas, esos botones no tendrán efecto.

### Dependencias opcionales
SwayNC y `pavucontrol` se usan para notificaciones y el control de audio. Si no están instalados, el resto de Waybar sigue funcionando.
---

>[!IMPORTANT]
>Open file `waybar/modules/clock`, and change this;

```bash
{
  "clock": {
    "timezone": "REGION/CITY",
    "format": "󰃱 <span size='11pt'>{:%H.%M }</span>",
    "format-alt": "󰃱 <span size='11pt'>{:%d %B %Y}</span>",
    "tooltip-format": "<tt><small>{calendar}</small></tt>"
  }
}
```

---

### Modules

| Module | Interaction | Action |
| --- | --- | --- |
| Network | Left click | Show `nm-applet` in tray|
| | Right click | Hide `nm-applet` in tray|
| | Scroll up | Enable Wi-Fi |
| | Scroll down | Disable Wi-Fi |
| Bluetooth | Left click | Open `blueman-manager` |
| | Right click | Toggle power on/off |
| SwayNC | Left click | Open/close panel |
| | Right click | Toggle Do Not Disturb |
| Power Profiles | Click | Toggle Saver > Balance > Performance |
| Idle Inhibitor | Click | Toggle screen dimming |

---

### Colors

La paleta activa es Catppuccin Mocha y se define en `tokens/colors.css`. Se conservaron los nombres de tokens existentes para no alterar los módulos; los estados y accesos rápidos usan colores semánticos de Mocha (`green`, `yellow`, `red`, `blue`, `peach`, `mauve`).

Para cambiar la paleta, edita `tokens/colors.css` sin modificar la estructura de los módulos.

Los módulos de batería, volumen, señal Wi-Fi, temperatura, CPU, memoria y almacenamiento usan una escala semántica: rojo para nivel bajo o crítico, naranja para nivel intermedio y verde para nivel correcto/alto. En volumen, los umbrales son 0–39% rojo, 40–69% naranja y 70–100% verde. En CPU, memoria, almacenamiento y temperatura el sentido se invierte cuando aumentar el valor indica mayor consumo o riesgo. Los umbrales se mantienen explícitos en cada módulo; volumen usa 40/75 y Wi-Fi 40/20 respectivamente. En volumen: 0–39% rojo, 40–74% naranja y 75–100% verde.

El módulo de escritorios muestra únicamente el icono de cada escritorio (`{icon}`), sin las aplicaciones abiertas (`{windows}`); se conservan los estados activo, vacío, urgente y especial.

El reloj usa la zona horaria `Europe/Madrid` y el locale `es_ES.UTF-8`, por lo que las fechas y nombres de meses se muestran en español.

La validación de carga con Waybar 0.15.0 no mostró errores de CSS/configuración; el proceso se mantuvo activo hasta finalizarlo por timeout. Los avisos observados (`swaync-client` ausente, `tray-arrow` y el icono de Blueman) pertenecen a dependencias/módulos preexistentes y no al cambio de colores.

El system tray se muestra permanentemente: `group/tray-group` ya no usa drawer. `nm-applet` y `blueman-applet` se deshabilitaron mediante overrides de autostart en `~/.config/autostart/`; esto no desactiva NetworkManager, Bluetooth ni `blueman-manager` bajo demanda. El clic de red abre `nmtui` en una ventana de Kitty y el clic derecho usa `nmcli`, evitando relanzar el applet. `blueman-manager` tiene una regla de Hyprland para abrir siempre como ventana flotante.

> [!TIP]
> For automatic color generation from your wallpaper, see `.config/matugen` and `.config/zsh`.

## Reloj + calendario con festivos (custom module)

El módulo nativo `clock` no permite dar formato a días concretos: su calendario se genera en C++ con cinco formatters fijos (`months`, `weekdays`, `days`, `today`, `weeks`). Para marcar festivos hubo que sustituirlo por `custom/clock`.

```
modules/clock.jsonc                 # custom/clock (exec del emisor, return-type json, interval 1, escape false)
scripts/clock-calendar.py           # calendario + festivos; --build cachea la plantilla
scripts/clock-calendar.sh           # tick de 1 s (bash, sin python)
tokens/batt-clock.css               # #clock, #custom-clock comparten estilo
```

Decisiones:

- **Festivos**: laborales de la Comunitat Valenciana (Decreto 100/2025 para 2026). Fijos = 1 ene, 6 ene, 19 mar, 1 may, 24 jun, 15 ago, 9 oct, 12 oct, 1 nov, 6 dic, 8 dic, 25 dic; móviles = Viernes Santo (Pascua−2) y Lunes de Pascua (Pascua+1), calculados con el algoritmo de Meeus/Jones/Butcher, así que vale cualquier año. No se incluyen los locales de Manises.
- **Formato**: replicado del calendar nativo (`src/modules/clock.cpp`): título `{:L%B %Y}` en minúscula ("octubre 2026"), celdas de 2 caracteres, columna de mes de 20 (`cldMonColLen_`) + 3 del nº de semana (`cldWnLen_`, " 40" sin prefijo), y 3 espacios entre columnas en modo año. Sin leyenda de festivos. Verificado: todas las líneas miden 23 caracteres (184 px en monospace).
- Hoy = cuadrado lavanda (`#b4befe` sobre `#1e1e2e`); festivos = cuadrado rojo (`#f38ba8`); sábado y domingo = **solo la letra** en amarillo (`#f9e2af`, sin fondo; se probó cuadrado amarillo y se descartó). Pango no permite bordes/contornos en el tooltip, solo fondo. Colores literales porque el tooltip no hereda las variables CSS; los `<span>` solo envuelven los números marcados, el resto es texto plano (no alteran el ancho).
- **Clic derecho** alterna mes ↔ año (3 columnas); **clic izquierdo** alterna hora ↔ fecha larga (equivalente al antiguo `format-alt`). El estado vive en `$XDG_RUNTIME_DIR/waybar-clock-calendar.mode` y `...alt` (se pierden al reiniciar, vuelven a mes/hora). Los clics los resuelve el emisor bash (`toggle-alt` / `toggle-mode`) y avisan a waybar con `SIGRTMIN+9` (opción `signal` del módulo) para refrescar al instante en vez de esperar al siguiente tick; `exec-on-event` va en `false` para no provocar un refresco extra con estado viejo.
- **Por qué dos scripts**: `python3 clock-calendar.py --once` cuesta ~78 ms por tick (≈8 % de un core a 1 Hz). El emisor bash hace el tick en ~14 ms: la plantilla JSON (con placeholder `TIME`) se cachea y solo se rehace al cambiar de día o de modo.
- **Nada de procesos persistentes**: con un script en bucle, cada recarga de Waybar (`SIGUSR2`) dejaba el python anterior vivo (waybar no mata los hijos al recargar). Con `interval: 1` y ejecución por tick el script muere solo, sin fugas.
- La navegación de meses por rueda se descartó: en touchpad llega como eventos *smooth* a 20–30/s y cada evento suma un mes (`smooth-scrolling-threshold` no lo doma en la práctica). Solo clic derecho.

---

## Acknowledgments
* **[Waybar](https://github.com/Alexays/Waybar)** - Created by **Alexays**. Huge thanks for this amazing and highly customizable status bar.
* All the contributors who have made Waybar what it is today.
* I personally customized this configuration to fit the **Athena** desktop.

---
Developed by Muhammad Haikal Hakim.
