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
    is_sway = bool(os.environ.get("SWAYSOCK"))
    parsed_clients = []
    mon_w = 1366
    mon_h = 768
    active_ws = 1

    if is_sway:
        try:
            outputs = json.loads(subprocess.check_output(["swaymsg", "-t", "get_outputs", "-r"], stderr=subprocess.DEVNULL))
            for o in outputs:
                if o.get("active") or o.get("focused"):
                    mon_w = o.get("rect", {}).get("width", 1366)
                    mon_h = o.get("rect", {}).get("height", 768)
                    try:
                        active_ws = int(o.get("current_workspace", "1"))
                    except Exception:
                        active_ws = 1
                    break
        except Exception:
            pass

        try:
            tree = json.loads(subprocess.check_output(["swaymsg", "-t", "get_tree", "-r"], stderr=subprocess.DEVNULL))
            def walk(node, ws_num):
                if not node:
                    return
                if node.get("type") == "workspace":
                    num = node.get("num")
                    name = node.get("name", "")
                    if num is not None and num > 0:
                        ws_num = num
                    else:
                        try:
                            ws_num = int(name)
                        except Exception:
                            ws_num = None

                is_window = (node.get("app_id") or node.get("window_properties") or node.get("pid")) and not node.get("nodes")
                if is_window and ws_num is not None:
                    rect = node.get("rect", {})
                    wp = node.get("window_properties", {})
                    cls = (wp and wp.get("class")) or node.get("app_id") or ""
                    parsed_clients.append({
                        "address": str(node.get("id", "")),
                        "ws": ws_num,
                        "title": node.get("name", ""),
                        "class": cls,
                        "initialClass": cls,
                        "at": [rect.get("x", 0), rect.get("y", 0)],
                        "size": [rect.get("width", 100), rect.get("height", 100)],
                        "pid": node.get("pid", 0),
                        "floating": "on" in str(node.get("floating", "")),
                        "fullscreen": bool(node.get("fullscreen_mode", 0)),
                        "focused": bool(node.get("focused", False))
                    })

                for ch in node.get("nodes", []):
                    walk(ch, ws_num)
                for ch in node.get("floating_nodes", []):
                    walk(ch, ws_num)

            walk(tree, active_ws)
        except Exception:
            pass
    else:
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

        if monitors and len(monitors) > 0:
            mon = monitors[0]
            mon_w = mon.get("width", 1366)
            mon_h = mon.get("height", 768)
            active_ws = mon.get("activeWorkspace", {}).get("id", 1)

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
