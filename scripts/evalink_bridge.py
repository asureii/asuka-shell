#!/usr/bin/env python3
"""
Evalink Bridge Script for Quickshell QML Integration.
Manages aria2c daemon on-demand and executes commands using evalink library.
"""

import sys
import os
import json

# Automatically use evalink's virtual environment if present
venv_dir = os.path.expanduser("~/evalink/.venv")
venv_python = os.path.join(venv_dir, "bin", "python3")
if os.path.exists(venv_python) and sys.prefix != venv_dir:
    os.execv(venv_python, [venv_python] + sys.argv)

evalink_dir = os.path.expanduser("~/evalink")
if os.path.isdir(evalink_dir) and evalink_dir not in sys.path:
    sys.path.insert(0, evalink_dir)

try:
    from evalink.config import load_config
    from evalink.aria2 import (
        Aria2DaemonManager,
        ensure_daemon_running,
        Aria2Client
    )
except ImportError as e:
    def main():
        print(json.dumps({"error": f"Evalink module not found: {e}"}))
    if __name__ == "__main__":
        main()
    sys.exit(0)

def main():
    if len(sys.argv) < 2:
        print(json.dumps({"error": "No action specified"}))
        return

    action = sys.argv[1]
    config = load_config()

    try:
        if action == "status":
            running = Aria2DaemonManager.is_running(config)
            print(json.dumps({"running": running, "rpc_port": config.rpc_port}))

        elif action == "start":
            Aria2DaemonManager.start(config)
            print(json.dumps({"success": True, "message": "Daemon started"}))

        elif action == "stop":
            Aria2DaemonManager.stop(config)
            print(json.dumps({"success": True, "message": "Daemon stopped"}))

        elif action == "add":
            if len(sys.argv) < 3:
                print(json.dumps({"error": "No URL provided"}))
                return
            url = sys.argv[2]
            with ensure_daemon_running(config) as client:
                gid = client.add_uri([url])
                print(json.dumps({"success": True, "gid": gid}))

        elif action == "pause_all":
            with ensure_daemon_running(config) as client:
                client.pause_all()
                print(json.dumps({"success": True}))

        elif action == "resume_all":
            with ensure_daemon_running(config) as client:
                client.unpause_all()
                print(json.dumps({"success": True}))

        elif action == "purge":
            with ensure_daemon_running(config) as client:
                client.purge_download_result()
                print(json.dumps({"success": True}))

        else:
            print(json.dumps({"error": f"Unknown action: {action}"}))

    except Exception as e:
        print(json.dumps({"error": str(e)}))

if __name__ == "__main__":
    main()
