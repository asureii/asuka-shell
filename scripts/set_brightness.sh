#!/bin/bash
pct=$1
[ -z "$pct" ] && exit 0

# Bound between 1 and 100
if [ "$pct" -lt 1 ]; then pct=1; fi
if [ "$pct" -gt 100 ]; then pct=100; fi

if which brightnessctl >/dev/null 2>&1; then
    brightnessctl set "${pct}%" 2>/dev/null || true
elif which light >/dev/null 2>&1; then
    light -S "$pct" 2>/dev/null || true
else
    # Try writing to sysfs if permissions allow
    for b in /sys/class/backlight/*; do
        [ -d "$b" ] || continue
        max=$(cat "$b/max_brightness" 2>/dev/null || echo 100)
        val=$(( (max * pct) / 100 ))
        [ "$val" -lt 1 ] && val=1
        echo "$val" > "$b/brightness" 2>/dev/null || true
    done
fi
