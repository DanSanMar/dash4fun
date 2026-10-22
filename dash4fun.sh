#!/usr/bin/env bash
###############################################################################
# dash4fun — Monitor de recursos, versión divertida
#
# Datos básicos de temperatura y carga de trabajo en barras verticales, con un
# muñeco que trota, corre o esprinta (y suda) según el estado del equipo.
#
# Copyright (C) 2026 DanSanMar
#
# Este programa es software libre: puedes redistribuirlo y/o modificarlo bajo
# los términos de la GNU General Public License tal como la publica la Free
# Software Foundation, ya sea la versión 3 de la Licencia o (a tu elección)
# cualquier versión posterior.
#
# Se distribuye con la esperanza de que sea útil, pero SIN NINGUNA GARANTÍA;
# ni siquiera la garantía implícita de COMERCIABILIDAD o IDONEIDAD PARA UN
# PROPÓSITO PARTICULAR. Consulta la GNU General Public License para más
# detalles. Deberías haber recibido una copia junto con este programa; si no,
# consulta <https://www.gnu.org/licenses/>.
###############################################################################
set -u

# ---------------------------------------------------------------------------
# Configuración por defecto (sobrescribible por variables de entorno)
# ---------------------------------------------------------------------------
VERSION="1.0"
INTERVAL="${DASH4FUN_INTERVAL:-1}"   # segundos entre muestras de hardware
MODE="${DASH4FUN_MODE:-full}"        # full | simple
ONCE=0

TICK="0.25"        # refresco de la animación (segundos)
BAR_H=8            # altura de las barras verticales (celdas)
BAR_W=5            # ancho de cada barra
COL_W=7            # ancho de columna (barra + hueco)
NOMBRE_HOST="$(hostname 2>/dev/null || echo 'localhost')"

# ---------------------------------------------------------------------------
# Parseo de argumentos
# ---------------------------------------------------------------------------
while [ $# -gt 0 ]; do
    case "$1" in
        -i|--interval)
            if [ $# -lt 2 ]; then
                echo "Falta el valor de $1" >&2; exit 1
            fi
            INTERVAL="$2"; shift 2 ;;
        -s|--simple)
            MODE="simple"; shift ;;
        -1|--once)
            ONCE=1; shift ;;
        -V|--version)
            echo "dash4fun v${VERSION}"; exit 0 ;;
        -h|--help)
            echo "dash4fun v${VERSION} - Monitor divertido de temperatura y carga"
            echo "Uso: $0 [-i SEG] [-s|--simple] [-1|--once] [-V|--version] [-h|--help]"
            echo ""
            echo "  -i, --interval SEG   Segundos entre muestras (por defecto ${INTERVAL})"
            echo "  -s, --simple         Modo texto plano: una línea por métrica"
            echo "  -1, --once           Un solo frame y sale (no entra en bucle)"
            echo "  -V, --version        Muestra la versión y sale"
            echo "  -h, --help           Muestra esta ayuda y sale"
            exit 0 ;;
        *)
            echo "Opción desconocida: $1" >&2
            exit 1 ;;
    esac
done

case "$MODE" in
    full|simple) ;;
    *) echo "Modo desconocido: $MODE (usa full o simple)" >&2; exit 1 ;;
esac

# Validación suave del intervalo: número (entero o decimal) >= 0.5
if ! printf '%s' "$INTERVAL" | grep -qE '^[0-9]+([.][0-9]+)?$' \
   || ! awk -v i="$INTERVAL" 'BEGIN{ exit !(i >= 0.5) }'; then
    echo "Intervalo no válido: $INTERVAL (mínimo 0.5 s)" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Colores y estilos (ANSI)
# ---------------------------------------------------------------------------
RESET=$'\033[0m'
BOLD=$'\033[1m'
DIM=$'\033[2m'
VERDE=$'\033[92m'
NARANJA=$'\033[38;5;208m'
ROJO=$'\033[91m'
AZUL=$'\033[94m'
CIAN=$'\033[96m'
AMARILLO=$'\033[93m'
BLANCO=$'\033[97m'
GRIS=$'\033[90m'

COLORES_ESTADO=("$VERDE" "$NARANJA" "$ROJO")
TEXTOS_ESTADO=("OK" "MEDIO" "ALTO")

# Paleta para la cabecera: los colores cambian solos con los segundos
PALETA_LOGO=("$AZUL" "$VERDE" "$AMARILLO" "$CIAN" "$ROJO" \
             "$NARANJA" "$BLANCO" "$AZUL")

COLOR_LOGO=""
COLOR_MODO=""
COLOR_VER=""
COLOR_DASH=""
COLOR_RAYO=""
SEG_COLORES=""

# Elige los colores de la cabecera a partir del segundo actual. Solo recalcula
# cuando cambia el segundo, así no parpadea a 4 fps ni se queda fijo al arrancar.
actualizar_colores_hora() {
    local seg n
    printf -v seg '%(%S)T' -1
    seg=$((10#$seg))
    [ "$seg" = "$SEG_COLORES" ] && return
    SEG_COLORES=$seg
    n=${#PALETA_LOGO[@]}
    COLOR_LOGO=${PALETA_LOGO[$(( seg % n ))]}
    COLOR_MODO=${PALETA_LOGO[$(( (seg + 2) % n ))]}
    COLOR_VER=${PALETA_LOGO[$(( (seg + 4) % n ))]}
    COLOR_DASH=${PALETA_LOGO[$(( (seg + 1) % n ))]}
    COLOR_RAYO=${PALETA_LOGO[$(( (seg + 6) % n ))]}
}

# En modo simple sin TTY (tuberías) no se emiten colores; tampoco con NO_COLOR
USE_COLOR=1
if [ -n "${NO_COLOR:-}" ]; then
    USE_COLOR=0
elif [ "$MODE" = "simple" ] && [ ! -t 1 ]; then
    USE_COLOR=0
fi
if [ "$USE_COLOR" -eq 0 ]; then
    RESET=''; BOLD=''; DIM=''
    VERDE=''; NARANJA=''; ROJO=''; AZUL=''; CIAN=''; AMARILLO=''; BLANCO=''; GRIS=''
    COLORES_ESTADO=("" "" "")
    PALETA_LOGO=("" "" "" "" "" "" "" "")
fi

# ---------------------------------------------------------------------------
# Utilidades
# ---------------------------------------------------------------------------
have() { command -v "$1" >/dev/null 2>&1; }

# Ancho visible de un texto (caracteres, no bytes)
pad_r() {
    local t="$1" w="$2" n relleno
    n=$(( w - ${#t} ))
    [ "$n" -lt 0 ] && n=0
    printf -v relleno '%*s' "$n" ''
    printf '%s%s' "$t" "$relleno"
}

# Versión sin subproceso: deja el texto centrado en CENTRADA
centrar_var() {
    local t="$1" w="$2" l r izq der
    l=$(( (w - ${#t}) / 2 ))
    [ "$l" -lt 0 ] && l=0
    r=$(( w - ${#t} - l ))
    [ "$r" -lt 0 ] && r=0
    printf -v izq '%*s' "$l" ''
    printf -v der '%*s' "$r" ''
    CENTRADA="${izq}${t}${der}"
}

# Deja una línea de '─' de ancho N en SEPARADOR (sin subproceso)
sep_var() {
    local s
    printf -v s '%*s' "$1" ''
    SEPARADOR=${s// /─}
}

term_width() {
    if [ -n "${DASH4FUN_WIDTH:-}" ]; then
        printf '%s' "$DASH4FUN_WIDTH"
    elif [ -t 1 ] && have tput; then
        tput cols 2>/dev/null || echo 80
    else
        echo 80
    fi
}

term_height() {
    if [ -n "${DASH4FUN_HEIGHT:-}" ]; then
        printf '%s' "$DASH4FUN_HEIGHT"
    elif [ -t 1 ] && have tput; then
        tput lines 2>/dev/null || echo 24
    else
        echo 24
    fi
}

human_bytes() {
    local b="${1:-0}"
    awk -v b="$b" 'BEGIN{
        split("B KB MB GB TB PB", u, " ");
        s=1; v=b+0;
        while (v>=1024 && s<7) { v/=1024; s++ }
        printf "%.1f %s", v, u[s]
    }'
}

# ---------------------------------------------------------------------------
# Lecturas de hardware
# ---------------------------------------------------------------------------

# --- CPU: deltas de /proc/stat entre ticks, suavizado con media móvil ---
CPU_PCT=0
PREV_TOTAL=0
PREV_IDLE=0
CPU_INIT=0

read_cpu_total() {
    # Sin subprocesos: se lee /proc/stat directamente en la shell
    local cpu user nice system idle iowait irq softirq steal resto
    read -r cpu user nice system idle iowait irq softirq steal resto < /proc/stat
    CTOTAL=$(( user + nice + system + idle + iowait + irq + softirq ))
    CIDLE=$(( idle + iowait ))
}

cpu_baseline() {
    read_cpu_total
    PREV_TOTAL=${CTOTAL:-0}
    PREV_IDLE=${CIDLE:-0}
}

cpu_tick() {
    local dt di inst
    read_cpu_total
    dt=$(( CTOTAL - PREV_TOTAL ))
    di=$(( CIDLE - PREV_IDLE ))
    if [ "$dt" -gt 0 ]; then
        inst=$(( (dt - di) * 100 / dt ))
        [ "$inst" -lt 0 ] && inst=0
        [ "$inst" -gt 100 ] && inst=100
        # Media móvil: evita que la barra salte con cada tick de 0,25 s
        if [ "$CPU_INIT" -eq 0 ]; then
            CPU_PCT=$inst
            CPU_INIT=1
        else
            CPU_PCT=$(( (CPU_PCT * 45 + inst * 55) / 100 ))
        fi
    fi
    PREV_TOTAL=$CTOTAL
    PREV_IDLE=$CIDLE
}

# --- RAM (kB) ---
RAM_TOTAL_KB=0
RAM_USED_KB=0
RAM_PCT=0

read_ram() {
    local key val total=0 avail=0 free=0 buffers=0 cached=0 used
    while read -r key val _; do
        case "$key" in
            MemTotal:) total=$val ;;
            MemAvailable:) avail=$val ;;
            MemFree:) free=$val ;;
            Buffers:) buffers=$val ;;
            Cached:) cached=$val ;;
        esac
        if [ "$total" -gt 0 ] && [ "$avail" -gt 0 ]; then break; fi
    done < /proc/meminfo
    total=${total:-0}
    avail=${avail:-0}
    if [ "$total" -le 0 ]; then
        RAM_TOTAL_KB=0; RAM_USED_KB=0; RAM_PCT=0
        return
    fi
    # Núcleos antiguos sin MemAvailable: aproximación clásica
    [ "$avail" -le 0 ] && avail=$(( free + buffers + cached ))
    used=$(( total - avail ))
    [ "$used" -lt 0 ] && used=0
    RAM_TOTAL_KB=$total
    RAM_USED_KB=$used
    RAM_PCT=$(( used * 100 / total ))
}

# --- Carga del sistema y núcleos ---
CPUS=$(nproc 2>/dev/null || echo 0)
LOAD_L1="0.00"
LOAD_L5="0.00"
LOAD_L15="0.00"
LOAD_PCT=0

read_load() {
    read -r LOAD_L1 LOAD_L5 LOAD_L15 _ < /proc/loadavg
    LOAD_L1=${LOAD_L1:-0.00}
    LOAD_L5=${LOAD_L5:-0.00}
    LOAD_L15=${LOAD_L15:-0.00}
    if [ "${CPUS:-0}" -gt 0 ] 2>/dev/null; then
        LOAD_PCT=$(awk -v l="$LOAD_L1" -v c="$CPUS" 'BEGIN{
            p=(l/c)*100
            if (p<0) p=0; if (p>100) p=100
            printf "%d", p
        }')
    else
        LOAD_PCT=0
    fi
}

# --- Temperatura CPU (sysfs + sensors) ---
obtener_temp_cpu() {
    local temp=0 zone type raw
    for zone in /sys/class/thermal/thermal_zone*; do
        [ -f "$zone/type" ] && [ -f "$zone/temp" ] || continue
        type=$(cat "$zone/type" 2>/dev/null)
        if [[ "$type" =~ x86_pkg_temp|cpu-thermal|cpu_thermal|k10temp|coretemp ]]; then
            raw=$(cat "$zone/temp" 2>/dev/null)
            [ -n "$raw" ] && [ "$raw" -gt 0 ] 2>/dev/null && { temp=$(( raw / 1000 )); break; }
        fi
    done
    if [ "$temp" -eq 0 ] && [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        raw=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
        [ -n "$raw" ] && [ "$raw" -gt 0 ] 2>/dev/null && temp=$(( raw / 1000 ))
    fi
    if [ "$temp" -eq 0 ] && have sensors; then
        local s_temp
        s_temp=$(sensors 2>/dev/null | grep -m1 -E 'Package id 0:|CPU:|Core 0:' \
            | awk '{print $3}' | tr -dc '0-9.')
        [ -n "$s_temp" ] && temp=$(awk -v s="$s_temp" 'BEGIN{ printf "%d", s+0.5 }')
    fi
    echo "${temp:-0}"
}

# --- GPU: detección única y muestreo periódico ---
GPU_TYPE="NONE"
GPU_MODEL="No detectada"
GPU_CARD=""
GPU_HWMON=""
GPU_UTIL=""
GPU_TEMP=0
NVIDIA_OK=0

detectar_gpu() {
    local out rc card vendor model

    if have nvidia-smi; then
        out=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>&1) || rc=$?
        rc=${rc:-0}
        if [ "$rc" -eq 0 ] && [ -n "$out" ] \
           && ! printf '%s' "$out" | grep -qiE 'failed|could not|unable|not found|error'; then
            GPU_TYPE="NVIDIA"
            GPU_MODEL=$(printf '%s\n' "$out" | head -n1 | xargs)
            NVIDIA_OK=1
            return
        fi
    fi

    for card in /sys/class/drm/card[0-9]*; do
        [ -f "$card/device/vendor" ] || continue
        vendor=$(cat "$card/device/vendor" 2>/dev/null)
        case "$vendor" in
            0x1002)
                GPU_TYPE="AMD"
                GPU_CARD="$card"
                GPU_HWMON=$(ls -d "$card/device/hwmon/hwmon"* 2>/dev/null | head -n1)
                model=""
                if have lspci; then
                    model=$(lspci -d 1002: 2>/dev/null | grep -iE 'vga|3d|display' | head -n1 \
                        | sed -E 's/^[0-9a-f:.]+ [^:]*: //; s/^Advanced Micro Devices, Inc\. \[AMD\/ATI\] //; s/^AMD\/ATI //; s/ *\(rev .*\)$//' \
                        | xargs)
                fi
                GPU_MODEL=${model:-"AMD Radeon Graphics"}
                return ;;
            0x8086)
                GPU_TYPE="INTEL"
                GPU_CARD="$card"
                GPU_HWMON=$(ls -d "$card/device/hwmon/hwmon"* 2>/dev/null | head -n1)
                model=""
                if have lspci; then
                    model=$(lspci -d 8086: 2>/dev/null | grep -iE 'vga|3d|display' | head -n1 \
                        | sed -E 's/.*: Intel Corporation //' | cut -d'(' -f1 | xargs)
                fi
                GPU_MODEL=${model:-"Intel Graphics"}
                return ;;
        esac
    done
}

muestrear_gpu() {
    GPU_UTIL=""
    GPU_TEMP=0

    case "$GPU_TYPE" in
        NVIDIA)
            [ "$NVIDIA_OK" -eq 1 ] || return
            local out u t
            out=$(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu \
                --format=csv,noheader,nounits 2>/dev/null) || return
            IFS=',' read -r u t <<< "$out"
            GPU_UTIL=$(printf '%s' "$u" | tr -dc '0-9')
            GPU_TEMP=$(printf '%s' "$t" | tr -dc '0-9')
            GPU_TEMP=${GPU_TEMP:-0}
            ;;
        AMD|INTEL)
            [ -n "$GPU_CARD" ] || return
            if [ -f "$GPU_CARD/device/gpu_busy_percent" ]; then
                GPU_UTIL=$(tr -dc '0-9' < "$GPU_CARD/device/gpu_busy_percent" 2>/dev/null)
            fi
            if [ -n "$GPU_HWMON" ] && [ -f "$GPU_HWMON/temp1_input" ]; then
                local raw
                raw=$(tr -dc '0-9' < "$GPU_HWMON/temp1_input" 2>/dev/null)
                [ -n "$raw" ] && GPU_TEMP=$(( raw / 1000 ))
            fi
            ;;
    esac
}

# --- Muestreo lento: todo lo que no cambia a 4 Hz ---
TEMP_CPU=0

muestrear_lento() {
    read_ram
    read_load
    TEMP_CPU=$(obtener_temp_cpu)
    muestrear_gpu
}

# ---------------------------------------------------------------------------
# Estado y umbrales
# ---------------------------------------------------------------------------
# Arrays del panel: 6 métricas en orden CPU, TEMP, RAM, LOAD, GPU, GTMP
NOMBRES=(CPU TEMP RAM LOAD GPU GTMP)
declare -a PCT=(0 0 0 0 0 0)
declare -a VAL=("0%" "--°C" "0%" "0.00" "n/d" "--°C")
declare -a COLBAR=("" "" "" "" "" "")
declare -a ETIQ=("OK" "n/d" "OK" "OK" "n/d" "n/d")
declare -a SEV=(0 -1 0 0 -1 -1)

ESTADO_GLOBAL=0
COLOR_ESTADO="$VERDE"
MENSAJE_ESTADO=""
PEOR_METRICA=""

# Rellena los arrays de dibujo a partir de las lecturas actuales
# (sin subprocesos: se llama 4 veces por segundo)
preparar_barras() {
    local sev i

    # CPU
    PCT[0]=$CPU_PCT
    VAL[0]="${CPU_PCT}%"
    if [ "$CPU_PCT" -ge 85 ]; then sev=2
    elif [ "$CPU_PCT" -ge 60 ]; then sev=1
    else sev=0; fi
    SEV[0]=$sev; COLBAR[0]=${COLORES_ESTADO[$sev]}; ETIQ[0]=${TEXTOS_ESTADO[$sev]}

    # Temperatura CPU
    if [ "${TEMP_CPU:-0}" -gt 0 ] 2>/dev/null; then
        PCT[1]=$TEMP_CPU
        VAL[1]="${TEMP_CPU}°C"
        if [ "$TEMP_CPU" -ge 85 ]; then sev=2
        elif [ "$TEMP_CPU" -ge 70 ]; then sev=1
        else sev=0; fi
        SEV[1]=$sev; COLBAR[1]=${COLORES_ESTADO[$sev]}; ETIQ[1]=${TEXTOS_ESTADO[$sev]}
    else
        PCT[1]=0; VAL[1]="--°C"; SEV[1]=-1
        COLBAR[1]="$GRIS"; ETIQ[1]="n/d"
    fi

    # RAM
    PCT[2]=$RAM_PCT
    VAL[2]="${RAM_PCT}%"
    if [ "$RAM_PCT" -ge 85 ]; then sev=2
    elif [ "$RAM_PCT" -ge 60 ]; then sev=1
    else sev=0; fi
    SEV[2]=$sev; COLBAR[2]=${COLORES_ESTADO[$sev]}; ETIQ[2]=${TEXTOS_ESTADO[$sev]}

    # LOAD (media de 1 min relativa a los núcleos)
    PCT[3]=$LOAD_PCT
    VAL[3]=${LOAD_L1:0:5}
    if [ "$LOAD_PCT" -ge 90 ]; then sev=2
    elif [ "$LOAD_PCT" -ge 70 ]; then sev=1
    else sev=0; fi
    SEV[3]=$sev; COLBAR[3]=${COLORES_ESTADO[$sev]}; ETIQ[3]=${TEXTOS_ESTADO[$sev]}

    # GPU uso
    if [ -n "$GPU_UTIL" ]; then
        PCT[4]=$GPU_UTIL
        VAL[4]="${GPU_UTIL}%"
        if [ "$GPU_UTIL" -ge 85 ]; then sev=2
        elif [ "$GPU_UTIL" -ge 60 ]; then sev=1
        else sev=0; fi
        SEV[4]=$sev; COLBAR[4]=${COLORES_ESTADO[$sev]}; ETIQ[4]=${TEXTOS_ESTADO[$sev]}
    else
        PCT[4]=0; VAL[4]="n/d"; SEV[4]=-1
        COLBAR[4]="$GRIS"; ETIQ[4]="n/d"
    fi

    # GPU temperatura
    if [ "${GPU_TEMP:-0}" -gt 0 ] 2>/dev/null; then
        PCT[5]=$GPU_TEMP
        VAL[5]="${GPU_TEMP}°C"
        if [ "$GPU_TEMP" -ge 85 ]; then sev=2
        elif [ "$GPU_TEMP" -ge 70 ]; then sev=1
        else sev=0; fi
        SEV[5]=$sev; COLBAR[5]=${COLORES_ESTADO[$sev]}; ETIQ[5]=${TEXTOS_ESTADO[$sev]}
    else
        PCT[5]=0; VAL[5]="--°C"; SEV[5]=-1
        COLBAR[5]="$GRIS"; ETIQ[5]="n/d"
    fi

    # Estado global: el peor de todos (los n/d no cuentan)
    ESTADO_GLOBAL=0
    PEOR_METRICA=""
    for (( i=0; i<6; i++ )); do
        if [ "${SEV[i]}" -gt "$ESTADO_GLOBAL" ]; then
            ESTADO_GLOBAL=${SEV[i]}
            PEOR_METRICA=${NOMBRES[i]}
        fi
    done

    COLOR_ESTADO=${COLORES_ESTADO[$ESTADO_GLOBAL]}
    case "$ESTADO_GLOBAL" in
        0) MENSAJE_ESTADO="Todo tranquilo, el muñeco trota feliz" ;;
        1) MENSAJE_ESTADO="Se está poniendo serio... ¡acelera!" ;;
        2) MENSAJE_ESTADO="¡A TOPE! Sudando la gota gorda" ;;
    esac
}

# ---------------------------------------------------------------------------
# Dibujo: barras y muñeco
# ---------------------------------------------------------------------------
PARCIAL=(▁ ▂ ▃ ▄ ▅ ▆ ▇)

# bar_cell_var <pct> <fila 0=abajo> <color> -> deja la celda en CELDA
bar_cell_var() {
    local pct="$1" fila="$2" col="$3" eighths c g s i
    eighths=$(( pct * BAR_H * 8 / 100 ))
    [ "$eighths" -lt 0 ] && eighths=0
    c=$(( eighths - fila * 8 ))
    if [ "$c" -le 0 ]; then
        CELDA="${GRIS}░░░░░${RESET}"
    elif [ "$c" -ge 8 ]; then
        CELDA="${col}█████${RESET}"
    else
        g=${PARCIAL[$((c-1))]}
        s=""
        for (( i=0; i<BAR_W; i++ )); do s+="$g"; done
        CELDA="${col}${s}${RESET}"
    fi
}

# Fotogramas del bicho rebotón: 4 poses x 6 líneas (cuerpo de 9 columnas)
BICHO=(
"         "
"  ▄▄▄▄▄  "
" █ o o █ "
" █  w  █ "
"  ▀▀▀▀▀  "
"  ▁▁▁▁▁  "

"  ▄▄▄▄▄  "
" █ o o █ "
" █  w  █ "
" █     █ "
"  ▀▀▀▀▀  "
"   ▁▁▁   "

"         "
"  ▄▄▄▄▄  "
" █ - - █ "
" █  w  █ "
"  ▀▀▀▀▀  "
"   ▁▁▁   "

"         "
"         "
" ▄▄▄▄▄▄▄ "
" █ ^ ^ █ "
" ▀▀▀▀▀▀▀ "
" ▁▁▁▁▁▁▁ "
)

BICHO_FRAME=0
ANIM_TICK=0

actualizar_paso() {
    local cada=4
    [ "$ESTADO_GLOBAL" -eq 1 ] && cada=2
    [ "$ESTADO_GLOBAL" -eq 2 ] && cada=1
    ANIM_TICK=$(( ANIM_TICK + 1 ))
    if [ $(( ANIM_TICK % cada )) -eq 0 ]; then
        BICHO_FRAME=$(( (BICHO_FRAME + 1) % 4 ))
    fi
}

# bicho_line_var <linea 0..5> -> bloque de 12 columnas en LINEA_BICHO
bicho_line_var() {
    local idx="$1" art speed="" sweat=" " pos ojos="o o" boca="w"
    art="${BICHO[$((BICHO_FRAME * 6 + idx))]}"

    # La cara cuenta el estado: feliz, concentrado o entrando en pánico
    [ "$ESTADO_GLOBAL" -eq 1 ] && { ojos="O O"; boca="-"; }
    [ "$ESTADO_GLOBAL" -eq 2 ] && { ojos="> <"; boca="O"; }
    art="${art/o o/$ojos}"
    art="${art/w/$boca}"

    if [ "$ESTADO_GLOBAL" -ge 1 ]; then
        case "$idx" in
            2|3) speed="»" ;;
        esac
        [ "$ESTADO_GLOBAL" -eq 2 ] && speed="»»"
    fi
    printf -v speed '%-2s' "$speed"

    if [ "$ESTADO_GLOBAL" -eq 2 ]; then
        pos=$(( (ANIM_TICK / 2) % 4 ))
        if [ "$idx" -eq "$pos" ]; then
            sweat="'"
        elif [ "$idx" -eq $((pos + 1)) ]; then
            sweat=","
        fi
    fi

    LINEA_BICHO="${COLOR_ESTADO}${speed}${RESET}${COLOR_ESTADO}${BOLD}${art}${RESET}${CIAN}${sweat}${RESET}"
}

# ---------------------------------------------------------------------------
# Dibujo del frame completo
# ---------------------------------------------------------------------------
draw_header() {
    local w up now largo
    w=$WIDTH
    printf -v now '%(%H:%M:%S)T' -1
    up=$(read_uptime)
    actualizar_colores_hora

    # Separadores cortos: no hacen falta 80 columnas de raya
    largo=$(( w - 1 ))
    [ "$largo" -gt 40 ] && largo=40

    sep_var "$largo"
    printf '%s%s%s\n' "$COLOR_DASH" "$SEPARADOR" "$RESET"
    if [ "$w" -ge 70 ]; then
        printf ' %s%sDASH4FUN%s %s| %sMODO DIVERSIÓN%s %s| %sV %s%s %s| %s%s%s %s| %sup %s%s\n' \
            "$COLOR_LOGO" "$BOLD" "$RESET" \
            "$COLOR_DASH" "$COLOR_MODO" "$RESET" \
            "$COLOR_DASH" "$COLOR_VER" "$VERSION" "$RESET" \
            "$COLOR_DASH" "$BLANCO" "$now" "$RESET" \
            "$COLOR_DASH" "$DIM" "$up" "$RESET"
    elif [ "$w" -ge 52 ]; then
        printf ' %s%sDASH4FUN%s %s| %sV %s%s %s| %s%s%s %s| %sup %s%s\n' \
            "$COLOR_LOGO" "$BOLD" "$RESET" \
            "$COLOR_DASH" "$COLOR_VER" "$VERSION" "$RESET" \
            "$COLOR_DASH" "$BLANCO" "$now" "$RESET" \
            "$COLOR_DASH" "$DIM" "$up" "$RESET"
    else
        printf ' %s%sDASH4FUN%s %s| %s%s%s %s| %sup %s%s\n' \
            "$COLOR_LOGO" "$BOLD" "$RESET" \
            "$COLOR_DASH" "$BLANCO" "$now" "$RESET" \
            "$COLOR_DASH" "$DIM" "$up" "$RESET"
    fi
    sep_var "$largo"
    printf '%s%s%s\n' "$COLOR_DASH" "$SEPARADOR" "$RESET"
    printf ' %sAUTO-REFRESCO:%s %s%ss%s  %s|%s  %sCTRL+C:%s Salir%s\n\n' \
        "$DIM" "$RESET" "$CIAN" "$INTERVAL" "$RESET" "$DIM" "$RESET" "$CIAN" "$RESET" "$RESET"
}

read_uptime() {
    local up d h m
    read -r up _ < /proc/uptime
    up=${up%%.*}
    up=${up:-0}
    d=$(( up / 86400 ))
    h=$(( (up % 86400) / 3600 ))
    m=$(( (up % 3600) / 60 ))
    if [ "$d" -gt 0 ]; then printf '%dd %dh' "$d" "$h"
    elif [ "$h" -gt 0 ]; then printf '%dh %dm' "$h" "$m"
    else printf '%dm' "$m"; fi
}

draw_panel() {
    local area_rows=$(( BAR_H + 3 )) bicho_top i r linea celda
    local show_bicho=0
    bicho_top=$(( BAR_H - 5 ))   # el bicho apoya la sombra en la base de las barras
    if [ "$WIDTH" -ge 58 ] && [ "$HEIGHT" -ge 20 ]; then
        show_bicho=1
    fi

    for (( r=0; r<area_rows; r++ )); do
        linea="  "
        if [ "$show_bicho" -eq 1 ]; then
            if [ "$r" -ge "$bicho_top" ] && [ "$r" -lt $((bicho_top + 6)) ]; then
                bicho_line_var $((r - bicho_top))
                linea+="$LINEA_BICHO"
            else
                linea+="            "
            fi
        fi

        for (( i=0; i<6; i++ )); do
            if [ "$r" -eq 0 ]; then
                centrar_var "${VAL[i]}" "$BAR_W"
                celda="${COLBAR[i]}${CENTRADA}${RESET}"
            elif [ "$r" -le "$BAR_H" ]; then
                bar_cell_var "${PCT[i]}" $((BAR_H - r)) "${COLBAR[i]}"
                celda=$CELDA
            elif [ "$r" -eq $((BAR_H + 1)) ]; then
                centrar_var "${NOMBRES[i]}" "$BAR_W"
                celda="${DIM}${CENTRADA}${RESET}"
            else
                centrar_var "${ETIQ[i]}" "$BAR_W"
                celda="${COLBAR[i]}${CENTRADA}${RESET}"
            fi
            linea+=" ${celda} "
        done
        printf '%s\n' "$linea"
    done
}

draw_status() {
    local extra=""
    [ -n "$PEOR_METRICA" ] && extra=" ($PEOR_METRICA)"
    printf '  %s%s> %s%s%s\n' "$COLOR_ESTADO" "$BOLD" "$MENSAJE_ESTADO" "$extra" "$RESET"
}

draw_footer() {
    printf '\n'
    if [ "${WIDTH:-80}" -ge 60 ]; then
        printf ' %sCtrl+C para salir  |  dash4fun v%s — mira cómo corre%s\n' \
            "$DIM" "$VERSION" "$RESET"
    else
        printf ' %sCtrl+C salir  |  v%s%s\n' "$DIM" "$VERSION" "$RESET"
    fi
    sep_var $(( ${WIDTH:-80} - 1 ))
    printf '%s%s%s\n' "$COLOR_DASH" "$SEPARADOR" "$RESET"
}

draw_full() {
    if [ "$WIDTH" -lt 44 ] || [ "$HEIGHT" -lt 20 ]; then
        printf '\n  %sTerminal demasiado pequeña%s\n' "$BOLD" "$RESET"
        printf '  Necesito al menos 44x20 (tienes %sx%s).\n' "$WIDTH" "$HEIGHT"
        return
    fi
    draw_header
    draw_panel
    draw_status
    draw_footer
}

# Barra horizontal para el modo simple
barra_h() {
    local pct="$1" ancho="$2" llenos vacios i s=""
    [ "$pct" -lt 0 ] && pct=0
    [ "$pct" -gt 100 ] && pct=100
    llenos=$(( pct * ancho / 100 ))
    vacios=$(( ancho - llenos ))
    for (( i=0; i<llenos; i++ )); do s+="#"; done
    for (( i=0; i<vacios; i++ )); do s+="-"; done
    printf '%s' "$s"
}

draw_simple() {
    local now i extra barra
    printf -v now '%(%H:%M:%S)T' -1

    printf '=== dash4fun v%s | %s | host: %s | up %s | intervalo %ss ===\n' \
        "$VERSION" "$now" "$NOMBRE_HOST" "$(read_uptime)" "$INTERVAL"

    for (( i=0; i<6; i++ )); do
        extra=""
        case "${NOMBRES[i]}" in
            RAM)
                extra="$(human_bytes $((RAM_USED_KB * 1024))) / $(human_bytes $((RAM_TOTAL_KB * 1024)))" ;;
            LOAD)
                extra="${CPUS} hilos  ($LOAD_L5 / $LOAD_L15)" ;;
            GPU)
                [ "$GPU_TYPE" = "NONE" ] && extra="sin GPU detectada" \
                    || extra="$GPU_MODEL" ;;
            GTMP)
                [ "$GPU_TYPE" = "NONE" ] && extra="sin GPU detectada" || extra="$GPU_TYPE" ;;
        esac
        barra=$(barra_h "${PCT[i]}" 20)
        printf '%s %s [%s%s%s] %s %s\n' \
            "$(pad_r "${NOMBRES[i]}" 5)" \
            "$(pad_r "${VAL[i]}" 5)" \
            "${COLBAR[i]}" "$barra" "$RESET" \
            "$(pad_r "${ETIQ[i]}" 5)" "$extra"
    done

    printf '=== fin ===\n'
}

# ---------------------------------------------------------------------------
# Renderizado de un frame completo (una sola impresión, sin parpadeo)
# ---------------------------------------------------------------------------
render_frame() {
    local frame clear=''

    # Dimensiones cacheadas: se refrescan al muestrear, no 4 veces por segundo
    [ -z "${WIDTH:-}" ] && WIDTH=$(term_width)
    [ -z "${HEIGHT:-}" ] && HEIGHT=$(term_height)

    if [ "$MODE" = "simple" ]; then
        frame=$(draw_simple)
        if [ -t 1 ]; then clear=$'\033[H\033[J'; fi
        printf '%s%s\n' "$clear" "$frame"
    else
        frame=$(draw_full)
        # Sin salto final en el bucle: evita scroll si la terminal tiene justo
        # la altura necesaria. En -1 sí se añade para devolver el prompt limpio.
        if [ "$ONCE" -eq 1 ]; then
            printf '%s%s\n' $'\033[H\033[J' "$frame"
        else
            printf '%s%s' $'\033[H\033[J' "$frame"
        fi
    fi
}

# ---------------------------------------------------------------------------
# Bucle principal
# ---------------------------------------------------------------------------
TICKS_POR_MUESTRA=$(awk -v i="$INTERVAL" 'BEGIN{ n=i/0.25; if (n<1) n=1; printf "%d", n+0.5 }')

run_once() {
    cpu_baseline
    sleep 0.3
    cpu_tick
    muestrear_lento
    preparar_barras
    ANIM_TICK=1
    RUNNER_FRAME=0
    render_frame
}

run_loop() {
    if [ "$MODE" = "simple" ]; then
        cpu_baseline
        sleep 0.3
        cpu_tick
        muestrear_lento
        while :; do
            preparar_barras
            render_frame
            sleep "$INTERVAL"
            cpu_tick
            muestrear_lento
        done
    fi

    if have tput && [ -t 1 ]; then
        tput smcup 2>/dev/null
        tput civis 2>/dev/null
        ALT_ACTIVA=1
    fi
    trap 'exit 0' SIGINT SIGTERM

    cpu_baseline
    sleep 0.3
    cpu_tick
    muestrear_lento

    local tick=0
    while :; do
        preparar_barras
        actualizar_paso
        render_frame

        tick=$(( tick + 1 ))
        sleep "$TICK"
        cpu_tick
        if [ $(( tick % TICKS_POR_MUESTRA )) -eq 0 ]; then
            muestrear_lento
            WIDTH=$(term_width)
            HEIGHT=$(term_height)
        fi
    done
}

# Restaura la terminal al salir (pantalla alternativa y cursor)
ALT_ACTIVA=0
cleanup() {
    if [ "$ALT_ACTIVA" -eq 1 ]; then
        tput rmcup 2>/dev/null
        tput cnorm 2>/dev/null
    fi
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Punto de entrada
# ---------------------------------------------------------------------------
colores_aleatorios
detectar_gpu

if [ "$ONCE" -eq 1 ]; then
    run_once
else
    run_loop
fi
