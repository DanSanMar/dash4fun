# dash4fun

Monitor de recursos de terminal, en un único script Bash, con vocación de
**pasar el rato mirándolo**: temperatura y carga de trabajo en **barras
verticales** y un bicho rebotón que se pone feliz, serio o entra en pánico (y
suda) según cómo esté el equipo.

![versión](https://img.shields.io/badge/versión-1.1-blue)
![licencia](https://img.shields.io/badge/licencia-GPL--3.0--or--later-green)

## Características

- **Seis barras verticales**: uso de CPU, temperatura de CPU, RAM, carga del
  sistema (`load avg` relativa a los núcleos), uso de GPU y temperatura de GPU.
- **Color por estado**: verde por debajo del 60 % / 70 °C, naranja en el tramo
  medio y rojo a partir del 85 % / 85 °C. Cada barra se colorea de forma
  independiente; el bicho usa el peor estado global.
- **Bicho animado**: cuatro poses de rebote (normal, estirado, parpadeo y
  aplastado). En verde sonríe y rebota tranquilo; en naranja se concentra y
  acelera; en rojo entra en pánico y suda.
- **Cabecera viva**: el color del título va cambiando solo con los segundos, y
  los separadores son cortos. Sin contador de hilos.
- **Números claros** encima de cada barra y etiqueta debajo, con redondeo
  continuo en la cima de la barra (bloques parciales `▁▂▃▄▅▆▇`).
- **Dos modos**: `full` (pantalla alternativa y animación fluida) y `simple`
  (texto plano, una línea por métrica, ideal para tuberías o pruebas).
- **Sin parpadeo**: cada frame se compone en memoria y se imprime de una vez.
- **Sin dependencias obligatorias**: las lecturas base salen de `/proc` y
  `/sys`. Si falta un dato, la barra se apaga y muestra `n/d`.

## Vista rápida

```text
────────────────────────────────────────
 DASH4FUN | MODO DIVERSIÓN | V 1.1 | 12:34:56 | up 3h 12m
────────────────────────────────────────
 AUTO-REFRESCO: 1s  |  CTRL+C: Salir

                4%    25°C    23%   0.95    0%    35°C
               ░░░░░  ░░░░░  ░░░░░  ░░░░░  ░░░░░  ░░░░░
               ░░░░░  ░░░░░  ░░░░░  ░░░░░  ░░░░░  ░░░░░
               ░░░░░  ░░░░░  ░░░░░  ░░░░░  ░░░░░  ░░░░░
      ▄▄▄▄▄    ░░░░░  ░░░░░  ░░░░░  ░░░░░  ░░░░░  ░░░░░
     █ o o █   ░░░░░  ░░░░░  ░░░░░  ░░░░░  ░░░░░  ░░░░░
     █  w  █   ░░░░░  ░░░░░  ░░░░░  ░░░░░  ░░░░░  ▆▆▆▆▆
      ▀▀▀▀▀    ░░░░░  █████  ▆▆▆▆▆  ░░░░░  ░░░░░  █████
      ▁▁▁▁▁    ▂▂▂▂▂  █████  █████  ▄▄▄▄▄  ░░░░░  █████
                CPU   TEMP    RAM   LOAD    GPU   GTMP
                OK     OK     OK     OK     OK     OK
  > Todo tranquilo, el bicho rebota feliz

 Ctrl+C para salir  |  dash4fun v1.1 — mira cómo rebota
────────────────────────────────────────
```

Con el equipo cargado, el bicho cambia de color, acelera el rebote y, en rojo,
entra en pánico: ojos `> <`, boca `O`, gotas de sudor (`'` y `,`) y líneas de
velocidad (`»»`). La cara también cambia con el estado: `o o` / `w` en verde,
`O O` / `-` en naranja y `> <` / `O` en rojo.

## Estados

| Estado | Uso | Temperatura | Carga (load) | Bicho |
| --- | --- | --- | --- | --- |
| Verde | < 60 % | < 70 °C | < 70 % de núcleos | Rebota tranquilo |
| Naranja | 60–84 % | 70–84 °C | 70–89 % | Rebota más rápido |
| Rojo | ≥ 85 % | ≥ 85 °C | ≥ 90 % | Rebota en pánico y suda |

La barra de `LOAD` muestra la media de 1 minuto como número y se llena respecto
al número de núcleos (100 % = todos los núcleos ocupados).

## Requisitos

- Linux con Bash 4.2 o superior.
- Las lecturas base salen de `/proc` (`stat`, `meminfo`, `loadavg`, `uptime`).
- **Opcionales** (se usan si están disponibles):
  - `nvidia-smi` — uso y temperatura de GPUs NVIDIA.
  - `lspci` — nombre del modelo de GPU AMD/Intel.
  - `sensors` — temperatura de CPU cuando `/sys` no la expone.

La GPU AMD se lee vía `sysfs` (`gpu_busy_percent` y `hwmon/temp1_input`). Si
`nvidia-smi` existe pero el driver no responde, se ignora y se continúa con la
detección por `sysfs`.

## Instalación

```bash
git clone <url-del-repo> dash4fun
cd dash4fun
chmod +x dash4fun.sh
```

Opcionalmente, para lanzarlo desde cualquier sitio:

```bash
ln -s "$PWD/dash4fun.sh" ~/.local/bin/dash4fun
```

## Uso

```bash
./dash4fun.sh              # bucle con refresco de muestras cada segundo
./dash4fun.sh -i 2         # muestrear cada 2 s
./dash4fun.sh -1           # una sola muestra y salir
./dash4fun.sh -1 -s        # una muestra en texto plano (pruebas / tuberías)
./dash4fun.sh -V           # versión
./dash4fun.sh -h           # ayuda
```

En modo `full` se entra en la pantalla alternativa y se restaura la terminal al
salir. Para terminar el bucle pulsa **Ctrl+C**.

### Opciones

| Opción | Descripción |
| --- | --- |
| `-i, --interval SEG` | Segundos entre muestras de hardware (por defecto `1`, mínimo `0.5`). |
| `-s, --simple` | Texto plano: sin animación, una línea por métrica. |
| `-1, --once` | Dibuja un único frame y sale. |
| `-V, --version` | Muestra la versión y sale. |
| `-h, --help` | Muestra la ayuda y sale. |

### Variables de entorno

| Variable | Valores | Descripción |
| --- | --- | --- |
| `DASH4FUN_INTERVAL` | número ≥ 0.5 | Intervalo de muestreo por defecto (segundos). |
| `DASH4FUN_MODE` | `full` \| `simple` | Modo de salida por defecto. |
| `NO_COLOR` | cualquier valor | Desactiva los colores ANSI. |

Los flags de línea de comandos tienen prioridad sobre las variables de entorno.

## Cómo funciona

- La animación se redibuja cada **0,25 s**, pero el hardware se muestrea cada
  `INTERVAL` segundos (1 s por defecto). Así el bicho se mueve fino sin leer
  sensores caros cuatro veces por segundo.
- Los colores de la cabecera se recalculan cuando cambia el segundo, con
  desplazamientos distintos para logo, modo y versión.
- El uso de CPU se calcula con los deltas de `/proc/stat` entre ticks y una
  media móvil suave.
- La temperatura, la RAM, la carga y la GPU se actualizan en cada muestreo; la
  GPU y `sensors` se consultan una sola vez por muestra.
- El ancho de barra y la altura son fijos; si la terminal es más estrecha de
  58 columnas se oculta el bicho, y por debajo de 44×20 se muestra un aviso.

## Notas

- `n/d` significa que el dato no está disponible (sin GPU, sin sensor o driver
  que no lo expone); esa barra no cuenta para el estado global.
- La detección de GPU es heurística y de mejor esfuerzo, igual que en
  `dash4ia`.
- En modo `simple` sin TTY no se emiten colores ni códigos de cursor, de modo
  que la salida queda limpia para tuberías.

## Licencia

Este proyecto se distribuye bajo la **GNU General Public License v3.0 o
posterior** (GPL-3.0-or-later). Copyright (C) 2026 **DanSanMar**.

Consulta el archivo [LICENSE](LICENSE) para el texto completo.
