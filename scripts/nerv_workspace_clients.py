#!/usr/bin/env python3
import subprocess
import json
import os
import sys

SHM_DIR = "/dev/shm/quickshell_evangelion"

def ensure_shm():
    os.makedirs(SHM_DIR, exist_ok=True)

def capture_snapshot(ws_id):
    ensure_shm()
    target_file = os.path.join(SHM_DIR, f"ws_{ws_id}.jpg")
    try:
        subprocess.run(["grim", "-t", "jpeg", "-q", "70", target_file], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
        return target_file
    except Exception:
        return None

def get_workspace_telemetry():
    ensure_shm()
    try:
        clients_raw = subprocess.check_output(["hyprctl", "clients", "-j"], stderr=subprocess.DEVNULL)
        clients = json.loads(clients_raw.decode("utf-8"))
    except Exception:
        clients = []

    try:
        monitors_raw = subprocess.check_output(["hyprctl", "monitors", "-j"], stderr=subprocess.DEVNULL)
        monitors = json.loads(monitors_raw.decode("utf-8"))
    except Exception:
        monitors = []

    active_ws = 1
    mon_w = 1366
    mon_h = 768

    if monitors and len(monitors) > 0:
        mon = monitors[0]
        mon_w = mon.get("width", 1366)
        mon_h = mon.get("height", 768)
        active_ws = mon.get("activeWorkspace", {}).get("id", 1)

    parsed_clients = []
    for c in clients:
        ws_id = c.get("workspace", {}).get("id", 1)
        parsed_clients.append({
            "address": c.get("address", ""),
            "ws": ws_id,
            "title": c.get("title", ""),
            "class": c.get("class", ""),
            "initialClass": c.get("initialClass", ""),
            "at": c.get("at", [0, 0]),
            "size": c.get("size", [100, 100]),
            "pid": c.get("pid", 0),
            "floating": c.get("floating", False),
            "fullscreen": bool(c.get("fullscreen", 0)),
            "focused": c.get("focusHistoryID", 99) == 0
        })

    snapshots = {}
    for i in range(1, 9):
        path = os.path.join(SHM_DIR, f"ws_{i}.jpg")
        snapshots[str(i)] = os.path.exists(path)

    data = {
        "monitor": {
            "width": mon_w,
            "height": mon_h,
            "activeWs": active_ws
        },
        "clients": parsed_clients,
        "snapshots": snapshots,
        "shmDir": SHM_DIR
    }

    return json.dumps(data)

if __name__ == "__main__":
    if len(sys.argv) > 2 and sys.argv[1] == "--snapshot":
        try:
            ws = int(sys.argv[2])
            capture_snapshot(ws)
        except Exception:
            pass
    print(get_workspace_telemetry())
