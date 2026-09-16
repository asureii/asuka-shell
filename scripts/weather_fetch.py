#!/usr/bin/env python3
import sys
import os
import json
import time
import urllib.request
import subprocess

CACHE_FILE = "/tmp/nerv_weather.json"
CACHE_TTL = 900  # 15 minutes

# Common timezone coordinates
TZ_COORDS = {
    "Asia/Jakarta": (-6.2088, 106.8456, "TOKYO-3 // JAKARTA SECTOR"),
    "Asia/Tokyo": (35.6762, 139.6503, "TOKYO-3 // GEO-FRONT HQ"),
    "America/New_York": (40.7128, -74.0060, "NERV-02 // NEW YORK SECTOR"),
    "Europe/London": (51.5074, -0.1278, "NERV-03 // LONDON SECTOR"),
    "Europe/Berlin": (52.5200, 13.4050, "NERV-04 // BERLIN SECTOR"),
    "Asia/Singapore": (1.3521, 103.8198, "NERV-05 // SINGAPORE SECTOR"),
    "Asia/Seoul": (37.5665, 126.9780, "NERV-06 // SEOUL SECTOR"),
    "America/Los_Angeles": (34.0522, -118.2437, "NERV-07 // PACIFIC SECTOR"),
}

WMO_CODES = {
    0: ("CLEAR SKY", "󰖙"),
    1: ("MAINLY CLEAR", "󰖕"),
    2: ("PARTLY CLOUDY", "󰖕"),
    3: ("OVERCAST", "󰖐"),
    45: ("FOG FORMATION", "󰖑"),
    48: ("DEPOSITING RIME FOG", "󰖑"),
    51: ("LIGHT DRIZZLE", "󰖗"),
    53: ("MODERATE DRIZZLE", "󰖗"),
    55: ("DENSE DRIZZLE", "󰖗"),
    61: ("SLIGHT RAIN", "󰖖"),
    63: ("MODERATE RAIN", "󰖖"),
    65: ("HEAVY RAIN", "󰖖"),
    71: ("SLIGHT SNOW", "󰼶"),
    73: ("MODERATE SNOW", "󰼶"),
    75: ("HEAVY SNOW", "󰼶"),
    80: ("SLIGHT RAIN SHOWERS", "󰖖"),
    81: ("MODERATE SHOWERS", "󰖖"),
    82: ("VIOLENT SHOWERS", "󰖖"),
    95: ("THUNDERSTORM", "󰖓"),
    96: ("THUNDERSTORM WITH HAIL", "󰖓"),
    99: ("SEVERE THUNDERSTORM", "󰖓"),
}

def get_system_timezone():
    try:
        out = subprocess.getoutput("timedatectl | grep 'Time zone'").strip()
        # format: Time zone: Asia/Jakarta (WIB, +0700)
        parts = out.split("Time zone:")
        if len(parts) > 1:
            tz_part = parts[1].strip().split()[0]
            return tz_part
    except Exception:
        pass
    return "Asia/Jakarta"

def get_wind_direction_label(degrees):
    dirs = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
    idx = int((degrees + 11.25) / 22.5) % 16
    return dirs[idx]

def fetch_weather(force=False):
    # Check cache unless force
    if not force and os.path.exists(CACHE_FILE):
        try:
            mtime = os.path.getmtime(CACHE_FILE)
            if time.time() - mtime < CACHE_TTL:
                with open(CACHE_FILE, "r") as f:
                    return json.load(f)
        except Exception:
            pass

    tz = get_system_timezone()
    coords = TZ_COORDS.get(tz, (-6.2088, 106.8456, f"NERV SECTOR // {tz}"))
    lat, lon, sector_name = coords

    url = (
        f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}"
        "&current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m,wind_direction_10m,surface_pressure"
        "&daily=weather_code,temperature_2m_max,temperature_2m_min&timezone=auto"
    )

    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (NERV HUD Terminal)"})
        with urllib.request.urlopen(req, timeout=5) as resp:
            raw = json.loads(resp.read().decode())

            curr = raw.get("current", {})
            daily = raw.get("daily", {})

            wcode = curr.get("weather_code", 0)
            cond_desc, cond_icon = WMO_CODES.get(wcode, ("ATMOSPHERIC DATA", "󰖙"))

            wind_deg = curr.get("wind_direction_10m", 0)
            wind_dir = get_wind_direction_label(wind_deg)

            forecast = []
            dates = daily.get("time", [])
            codes = daily.get("weather_code", [])
            maxs = daily.get("temperature_2m_max", [])
            mins = daily.get("temperature_2m_min", [])

            for i in range(min(5, len(dates))):
                d_code = codes[i] if i < len(codes) else 0
                d_desc, d_icon = WMO_CODES.get(d_code, ("CLEAR", "󰖙"))
                d_str = dates[i]
                try:
                    t_struct = time.strptime(d_str, "%Y-%m-%d")
                    day_name = time.strftime("%a", t_struct).upper()
                except Exception:
                    day_name = f"D+{i}"

                forecast.append({
                    "day": day_name,
                    "date": d_str,
                    "icon": d_icon,
                    "desc": d_desc,
                    "max": round(maxs[i]) if i < len(maxs) else 0,
                    "min": round(mins[i]) if i < len(mins) else 0
                })

            result = {
                "success": True,
                "sector": sector_name,
                "timezone": tz,
                "temp": round(curr.get("temperature_2m", 0)),
                "feels_like": round(curr.get("apparent_temperature", 0)),
                "humidity": round(curr.get("relative_humidity_2m", 0)),
                "wind_speed": round(curr.get("wind_speed_10m", 0)),
                "wind_dir": wind_dir,
                "wind_deg": wind_deg,
                "precipitation": curr.get("precipitation", 0.0),
                "pressure": round(curr.get("surface_pressure", 1013)),
                "weather_code": wcode,
                "condition": cond_desc,
                "icon": cond_icon,
                "updated": time.strftime("%H:%M:%S"),
                "forecast": forecast
            }

            # Cache to file
            try:
                with open(CACHE_FILE, "w") as f:
                    json.dump(result, f)
            except Exception:
                pass

            return result
    except Exception as e:
        # If network failed, check if we have stale cache
        if os.path.exists(CACHE_FILE):
            try:
                with open(CACHE_FILE, "r") as f:
                    cached = json.load(f)
                    cached["cached"] = True
                    return cached
            except Exception:
                pass

        # Fallback offline structure
        return {
            "success": False,
            "error": str(e),
            "sector": "TOKYO-3 // GEO-FRONT",
            "timezone": tz,
            "temp": 28,
            "feels_like": 31,
            "humidity": 68,
            "wind_speed": 10,
            "wind_dir": "NE",
            "wind_deg": 45,
            "precipitation": 0.0,
            "pressure": 1013,
            "weather_code": 0,
            "condition": "ATMOSPHERE NOMINAL",
            "icon": "󰖙",
            "updated": time.strftime("%H:%M:%S"),
            "forecast": [
                {"day": "FRI", "date": "2026-08-28", "icon": "󰖕", "desc": "PARTLY CLOUDY", "max": 33, "min": 25},
                {"day": "SAT", "date": "2026-08-29", "icon": "󰖖", "desc": "LIGHT RAIN", "max": 31, "min": 24},
                {"day": "SUN", "date": "2026-08-30", "icon": "󰖙", "desc": "CLEAR SKY", "max": 34, "min": 26},
                {"day": "MON", "date": "2026-08-31", "icon": "󰖙", "desc": "CLEAR SKY", "max": 35, "min": 26},
                {"day": "TUE", "date": "2026-09-01", "icon": "󰖐", "desc": "OVERCAST", "max": 32, "min": 25}
            ]
        }

if __name__ == "__main__":
    force_refresh = "--force" in sys.argv or "-f" in sys.argv
    data = fetch_weather(force=force_refresh)
    print(json.dumps(data))
