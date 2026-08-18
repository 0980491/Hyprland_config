#!/usr/bin/env bash
# Prints one JSON line with the system state every N seconds (3 by default).
# A single streaming process: the bar just reads stdout, it never spawns anything.
#
# Fields: cpu (%), cpuTemp (°C), mem (%), memUsed/memTotal (GiB),
#         gpu (%), gpuTemp (°C), vram (%), vramUsed/vramTotal (GiB), disk (%)
set -u
INTERVAL="${1:-3}"

# Resolve hwmon by name: the numbers change between boots.
hwmon_by_name() {
    local want="$1" h
    for h in /sys/class/hwmon/hwmon*; do
        [[ -r "$h/name" ]] || continue
        [[ "$(<"$h/name")" == "$want" ]] && { echo "$h"; return; }
    done
}

CPU_HW="$(hwmon_by_name k10temp)"; [[ -z "$CPU_HW" ]] && CPU_HW="$(hwmon_by_name coretemp)"
GPU_HW="$(hwmon_by_name amdgpu)"
GPU_CARD=$(ls -d /sys/class/drm/card*/device 2>/dev/null | while read -r d; do
    [[ -r "$d/gpu_busy_percent" ]] && { echo "$d"; break; }; done)

read_int() { [[ -r "$1" ]] && cat "$1" 2>/dev/null || echo 0; }

prev_total=0; prev_idle=0
declare -A prev_ctotal prev_cidle

# Default route interface, for the network speed counters
net_iface() { ip route show default 2>/dev/null | awk '{print $5; exit}'; }
IFACE="$(net_iface)"
prev_rx=0; prev_tx=0; first_net=1

while :; do
    # ── CPU (aggregate + per core) ──
    read -r _ u n s i io irq soft steal _ < /proc/stat
    total=$((u+n+s+i+io+irq+soft+steal))
    idle=$((i+io))
    if (( prev_total > 0 && total > prev_total )); then
        cpu=$(( 100 * ( (total-prev_total) - (idle-prev_idle) ) / (total-prev_total) ))
    else
        cpu=0
    fi
    prev_total=$total; prev_idle=$idle

    cores="["
    while read -r name cu cn cs ci cio cirq csoft csteal _; do
        [[ "$name" == cpu[0-9]* ]] || continue
        ctot=$((cu+cn+cs+ci+cio+cirq+csoft+csteal))
        cidl=$((ci+cio))
        pt=${prev_ctotal[$name]:-0}; pi=${prev_cidle[$name]:-0}
        if (( pt > 0 && ctot > pt )); then
            cval=$(( 100 * ( (ctot-pt) - (cidl-pi) ) / (ctot-pt) ))
        else
            cval=0
        fi
        prev_ctotal[$name]=$ctot; prev_cidle[$name]=$cidl
        [[ "$cores" == "[" ]] && cores="$cores$cval" || cores="$cores,$cval"
    done < /proc/stat
    cores="$cores]"

    # ── Memory ──
    mem_total_kb=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
    mem_avail_kb=$(awk '/^MemAvailable:/{print $2}' /proc/meminfo)
    mem_used_kb=$((mem_total_kb - mem_avail_kb))
    mem=$(( 100 * mem_used_kb / mem_total_kb ))

    # ── Temperatures ──
    cpu_temp=$(( $(read_int "$CPU_HW/temp1_input") / 1000 ))
    gpu_temp=$(( $(read_int "$GPU_HW/temp1_input") / 1000 ))

    # ── GPU and VRAM ──
    gpu=$(read_int "$GPU_CARD/gpu_busy_percent")
    vram_total=$(read_int "$GPU_CARD/mem_info_vram_total")
    vram_used=$(read_int "$GPU_CARD/mem_info_vram_used")
    vram=0
    (( vram_total > 0 )) && vram=$(( 100 * vram_used / vram_total ))

    # ── Network throughput ──
    # An empty IFACE would make the -d test pass on /sys/class/net itself,
    # freezing the counters at zero when the shell starts before the network.
    [[ -n "$IFACE" && -d "/sys/class/net/$IFACE" ]] || IFACE="$(net_iface)"
    rx=$(read_int "/sys/class/net/$IFACE/statistics/rx_bytes")
    tx=$(read_int "/sys/class/net/$IFACE/statistics/tx_bytes")
    if (( first_net )); then
        rx_rate=0; tx_rate=0; first_net=0
    else
        rx_rate=$(( (rx - prev_rx) / INTERVAL ))
        tx_rate=$(( (tx - prev_tx) / INTERVAL ))
        (( rx_rate < 0 )) && rx_rate=0
        (( tx_rate < 0 )) && tx_rate=0
    fi
    prev_rx=$rx; prev_tx=$tx

    # ── Root filesystem ──
    disk=$(df --output=pcent / 2>/dev/null | tail -1 | tr -dc '0-9')

    printf '{"cpu":%d,"cpuTemp":%d,"cores":%s,"mem":%d,"memUsed":%.1f,"memTotal":%.1f,"gpu":%d,"gpuTemp":%d,"vram":%d,"vramUsed":%.1f,"vramTotal":%.1f,"disk":%d,"rx":%d,"tx":%d,"iface":"%s"}\n' \
        "$cpu" "$cpu_temp" "$cores" "$mem" \
        "$(awk -v k="$mem_used_kb" 'BEGIN{printf "%.1f", k/1048576}')" \
        "$(awk -v k="$mem_total_kb" 'BEGIN{printf "%.1f", k/1048576}')" \
        "$gpu" "$gpu_temp" "$vram" \
        "$(awk -v b="$vram_used" 'BEGIN{printf "%.1f", b/1073741824}')" \
        "$(awk -v b="$vram_total" 'BEGIN{printf "%.1f", b/1073741824}')" \
        "${disk:-0}" "$rx_rate" "$tx_rate" "$IFACE"

    sleep "$INTERVAL"
done
