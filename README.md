# dash4fun

Monitor de recursos de terminal, en un único script Bash, con vocación de
**pasar el rato mirándolo**: temperatura y carga de trabajo en **barras
verticales** y **Dashy**, un bicho rebotón que descansa en azul, trota en verde,
se concentra en naranja o entra en pánico (y suda) en rojo según cómo esté el
equipo.

![versión](https://img.shields.io/badge/versión-1.4-blue)
![licencia](https://img.shields.io/badge/licencia-GPL--3.0--or--later-green)

## Características

- **Seis barras verticales** de altura adaptable (8-16 celdas según la
  terminal): uso de CPU, temperatura de CPU, RAM, carga del sistema (`load avg`
  relativa a los núcleos), uso de GPU y temperatura de GPU.
- **Gradiente vertical por barra**: la base es **azul de reposo** y, a medida
  que sube el llenado, aparecen verdes, ámbar, naranjas y rojos. Cada celda
  tiene su color según la altura; la barra no se vuelve de un único tono.
- **Paleta suave**: verdes, naranjas y rojos apagados, sin colores fosforitos,
  para que la subida de temperatura y carga se lea mejor.
- **Porcentaje bien visible**: el valor de cada barra se muestra en negrita
  encima; `LOAD` ahora también se expresa como % de núcleos ocupados.
- **Dashy, el bicho animado**: seis poses (reposo, agachado, ladeado a ambos
  lados, salto y aterrizaje aplastado). En azul duerme con sus `Zzz` y abre un
  ojo de vez en cuando; en verde pasea y silba; en naranja se concentra, suda y
  se pregunta qué pasa; en rojo entra en pánico y corre con líneas de
  velocidad.
- **Frases con humor**: Dashy va contando qué tal va el PC en gerundio
  (“Dashy está durmiendo una tranquila siesta”, “Dashy está rezando todas sus
  oraciones al kernel Linux”…). Cambian cada 8 segundos.
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
 DASH4FUN | DASHY EN ACCIÓN | V 1.4 | 12:34:57 | up 2h 44m
────────────────────────────────────────
 AUTO-REFRESCO: 1s  |  CTRL+C: Salir

                5%    26°C    23%    19%    2%    47°C
               ░░░░░  ░░░░░  ░░░░░  ░░░░░  ░░░░░  ░░░░░
               ░░░░░  ░░░░░  ░░░░░  ░░░░░  ░░░░░  ░░░░░
               ░░░░░  ░░░░░  ░░░░░  ░░░░░  ░░░░░  ░░░░░
               ░░░░░  ░░░░░  ░░░░░  ░░░░░  ░░░░░  ░░░░░
               ░░░░░  ░░░░░  ░░░░░  ░░░░░  ░░░░░  ░░░░░
               ░░░░░  ░░░░░  ░░░░░  ░░░░░  ░░░░░  ░░░░░
        ▄      ░░░░░  ░░░░░  ░░░░░  ░░░░░  ░░░░░  ░░░░░
       ▄▄▄     ░░░░░  ░░░░░  ░░░░░  ░░░░░  ░░░░░  ▃▃▃▃▃
      █o o█    ░░░░░  ░░░░░  ░░░░░  ░░░░░  ░░░░░  █████
     ▐█ w █▌   ░░░░░  █████  ▅▅▅▅▅  █████  ░░░░░  █████
       ▀▀▀     ░░░░░  █████  █████  █████  ░░░░░  █████
      ▁▁▁▁▁    ▂▂▂▂▂  █████  █████  █████  ░░░░░  █████
                CPU   TEMP    RAM   LOAD    GPU   GTMP
                CALMA  CALMA  CALMA  CALMA  CALMA  CALMA
  > Dashy está durmiendo una tranquila siesta

 Ctrl+C para salir  |  dash4fun v1.4 — Dashy en acción
────────────────────────────────────────
```

Con el equipo en reposo, Dashy es azul y descansa; al cargarse pasa a verde,
naranja y rojo, acelera el rebote y, en rojo, entra en pánico: ojos `> <`, boca
`O`, gotas de sudor (`'` y `,`) y líneas de velocidad (`»»`). La cara también
cambia con el estado: `o o` / `w` en azul y verde, `O O` / `-` en naranja y
`> <` / `O` en rojo.

## Estados

| Estado | Uso | Temperatura | Carga (load) | Dashy |
| --- | --- | --- | --- | --- |
| Azul (reposo) | < 30 % | < 50 °C | < 40 % de núcleos | Descansa al sol |
| Verde | 30–59 % | 50–69 °C | 40–69 % | Trota tranquilo |
| Naranja | 60–84 % | 70–84 °C | 70–89 % | Se abanica y acelera |
| Rojo | ≥ 85 % | ≥ 85 °C | ≥ 90 % | Entra en pánico y suda |

Cada barra es un gradiente vertical: la base es azul y, según sube el llenado,
va pasando por verde, ámbar, naranja y rojo. Una barra alta muestra varios
colores a la vez; no se colorea entera de un solo tono. El estado global (y el
color de Dashy) se decide con los umbrales de la tabla.

La barra de `LOAD` muestra el porcentaje de núcleos ocupados según la media de
1 minuto. En modo `simple` se añaden además las medias de 1, 5 y 15 minutos.

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
| `DASH4FUN_WIDTH` | número | Fuerza el ancho de terminal (útil sin TTY). |
| `DASH4FUN_HEIGHT` | número | Fuerza el alto de terminal (útil sin TTY). |
| `NO_COLOR` | cualquier valor | Desactiva los colores ANSI. |

Los flags de línea de comandos tienen prioridad sobre las variables de entorno.

## Cómo funciona

- La animación se redibuja cada **0,25 s**, pero el hardware se muestrea cada
  `INTERVAL` segundos (1 s por defecto). Así Dashy se mueve fino sin leer
  sensores caros cuatro veces por segundo.
- Los colores de la cabecera se recalculan cuando cambia el segundo, con
  desplazamientos distintos para logo, modo y versión.
- Cada celda de una barra toma su color según la altura que ocupa: azul en la
  base, luego verde, ámbar, naranja y rojo. Dashy y el mensaje usan el color del
  peor estado (azul/verde/naranja/rojo).
- El uso de CPU se calcula con los deltas de `/proc/stat` entre ticks y una
  media móvil suave.
- La temperatura, la RAM, la carga y la GPU se actualizan en cada muestreo; la
  GPU y `sensors` se consultan una sola vez por muestra.
- La altura de las barras se adapta al alto de la terminal (8-16 celdas). Si hay
  menos de 58 columnas o menos de 20 filas se oculta Dashy; por debajo de 44×20
  se muestra un aviso.
- Las frases de Dashy rotan cada 8 segundos según el estado global.

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
