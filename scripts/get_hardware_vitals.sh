#!/usr/bin/env bash
# ==============================================================================
# NERV Hardware Telemetry Backend Script
# Gathers accurate, real-time Linux hardware metrics from /proc, /sys, and df
# ==============================================================================

# 1. CPU Identification & Topology
cpu_model=$(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2 | xargs)
[ -z "$cpu_model" ] && cpu_model="Generic x86_64 Processor"

# 2. Hostname, Kernel, Board Identification
hostname=$(uname -n)
kernel=$(uname -r)
board_vendor=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null | xargs)
board_product=$(cat /sys/class/dmi/id/product_name 2>/dev/null | xargs)
board="$board_vendor $board_product"
[ -z "$board_vendor" ] && board="NERV Tactical Motherboard"

# 3. CPU Total & Per-Core Loads (100ms delta)
readarray -t s1 < <(grep "^cpu[0-9]" /proc/stat)
c1_tot=($(grep "^cpu " /proc/stat))
sleep 0.1
readarray -t s2 < <(grep "^cpu[0-9]" /proc/stat)
c2_tot=($(grep "^cpu " /proc/stat))

cores=()
for i in "${!s1[@]}"; do
  c1=(${s1[i]})
  c2=(${s2[i]})
  t1=0; t2=0
  for v in "${c1[@]:1}"; do ((t1+=v)); done
  for v in "${c2[@]:1}"; do ((t2+=v)); done
  id1=$((c1[4]+c1[5])); id2=$((c2[4]+c2[5]))
  dt=$((t2-t1)); did=$((id2-id1))
  pct=$(( (dt-did)*100 / (dt > 0 ? dt : 1) ))
  [ "$pct" -lt 0 ] && pct=0
  [ "$pct" -gt 100 ] && pct=100
  cores+=($pct)
done

t1=0; t2=0
for v in "${c1_tot[@]:1}"; do ((t1+=v)); done
for v in "${c2_tot[@]:1}"; do ((t2+=v)); done
id1=$((c1_tot[4]+c1_tot[5])); id2=$((c2_tot[4]+c2_tot[5]))
dt=$((t2-t1)); did=$((id2-id1))
cpu_tot=$(( (dt-did)*100 / (dt > 0 ? dt : 1) ))
[ "$cpu_tot" -lt 0 ] && cpu_tot=0
[ "$cpu_tot" -gt 100 ] && cpu_tot=100

# 4. CPU Temperature
temp=0
for t in /sys/class/hwmon/hwmon*/temp*_input /sys/class/thermal/thermal_zone*/temp; do
  if [ -f "$t" ]; then
    v=$(cat "$t" 2>/dev/null)
    if [ -n "$v" ] && [ "$v" -gt 10000 ] && [ "$v" -lt 120000 ]; then
      temp=$((v / 1000))
      break
    fi
  fi
done
[ "$temp" -le 0 ] && temp=45

# 5. Battery Status & Capacity
bat_cap=100
bat_stat="AC POWER"
for b in /sys/class/power_supply/BAT*; do
  if [ -d "$b" ]; then
    v_cap=$(cat "$b/capacity" 2>/dev/null)
    v_stat=$(cat "$b/status" 2>/dev/null)
    [ -n "$v_cap" ] && bat_cap=$v_cap
    [ -n "$v_stat" ] && bat_stat="$v_stat"
    break
  fi
done

# 6. Memory & Swap from /proc/meminfo
m_tot=$(grep MemTotal /proc/meminfo | awk '{print $2}')
m_avail=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
m_used=$((m_tot - m_avail))
ram_used_gb=$(awk "BEGIN {printf \"%.1f\", $m_used / 1048576}")
ram_tot_gb=$(awk "BEGIN {printf \"%.1f\", $m_tot / 1048576}")
ram_pct=$((m_used * 100 / (m_tot > 0 ? m_tot : 1)))

s_tot=$(grep SwapTotal /proc/meminfo | awk '{print $2}')
s_free=$(grep SwapFree /proc/meminfo | awk '{print $2}')
s_used=$((s_tot - s_free))
swap_used_gb=$(awk "BEGIN {printf \"%.1f\", $s_used / 1048576}")
swap_tot_gb=$(awk "BEGIN {printf \"%.1f\", $s_tot / 1048576}")
swap_pct=$((s_tot > 0 ? (s_used * 100 / s_tot) : 0))

# 7. Filesystem Partitions (Root & User /home)
read -r r_size r_used r_pct < <(df -h / | awk 'NR==2 {print $2, $3, $5}')
read -r h_size h_used h_pct < <(df -h /home 2>/dev/null | awk 'NR==2 {print $2, $3, $5}' || df -h / | awk 'NR==2 {print $2, $3, $5}')
r_pct_num=${r_pct%\%}
h_pct_num=${h_pct%\%}
[ -z "$r_pct_num" ] && r_pct_num=0
[ -z "$h_pct_num" ] && h_pct_num=0

cores_json=$(IFS=,; echo "${cores[*]}")

# Output standardized JSON
cat <<EOF
{
  "cpuModel": "$cpu_model",
  "cpuLoad": $cpu_tot,
  "coreLoads": [$cores_json],
  "cpuTemp": $temp,
  "hostName": "$hostname",
  "kernelVer": "$kernel",
  "boardName": "$board",
  "batteryCap": $bat_cap,
  "batteryStatus": "$bat_stat",
  "ramUsedGb": "$ram_used_gb",
  "ramTotalGb": "$ram_tot_gb",
  "ramPct": $ram_pct,
  "swapUsedGb": "$swap_used_gb",
  "swapTotalGb": "$swap_tot_gb",
  "swapPct": $swap_pct,
  "rootUsed": "$r_used",
  "rootTotal": "$r_size",
  "rootPct": $r_pct_num,
  "homeUsed": "$h_used",
  "homeTotal": "$h_size",
  "homePct": $h_pct_num
}
EOF
