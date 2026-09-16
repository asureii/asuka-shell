#!/bin/bash
# set_hyprsunset.sh: Controls hyprsunset temperature or turns it off
# Usage: ./set_hyprsunset.sh <temp_kelvin> | off

ARG=$1

if [ -z "$ARG" ] || [ "$ARG" = "off" ] || [ "$ARG" = "OFF" ] || [ "$ARG" = "identity" ] || [ "$ARG" = "0" ]; then
    killall -9 hyprsunset 2>/dev/null || true
else
    TEMP=$ARG
    # Ensure numeric
    if ! [[ "$TEMP" =~ ^[0-9]+$ ]]; then
        TEMP=6000
    fi
    # Bound between 1500 and 10000
    if [ "$TEMP" -lt 1500 ]; then TEMP=1500; fi
    if [ "$TEMP" -gt 10000 ]; then TEMP=10000; fi

    killall -9 hyprsunset 2>/dev/null || true
    sleep 0.05
    hyprsunset -t "$TEMP" >/dev/null 2>&1 &
fi
