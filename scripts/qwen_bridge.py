#!/usr/bin/env python3
"""
NERV EvaCore Qwen 2.5 Bridge
Handles natural language command processing, application launching,
window focusing, and system IPC commands for the bottom command line bar.
"""

import sys
import os
import json
import re
import urllib.request
import urllib.error
import urllib.parse
import subprocess
import shutil
from pathlib import Path

OLLAMA_API = os.environ.get("OLLAMA_API", "http://localhost:11434/api")
MODEL_NAME = os.environ.get("QWEN_MODEL", "qwen2.5:0.5b")
QWEN_ASSISTANT_BIN = Path.home() / ".local/bin/qwen-assistant"

def check_status() -> dict:
    """Check if Ollama service is reachable and verify model availability."""
    try:
        req = urllib.request.Request(f"{OLLAMA_API}/tags", headers={"Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=1.5) as res:
            data = json.loads(res.read().decode("utf-8"))
            models = [m.get("name") for m in data.get("models", [])]
            has_05b = "qwen2.5:0.5b" in models or any("0.5b" in m for m in models)
            active_model = "qwen2.5:0.5b" if has_05b else (models[0] if models else MODEL_NAME)
            return {
                "online": True,
                "model": active_model,
                "has_model": has_05b,
                "available_models": models
            }
    except Exception as e:
        return {
            "online": False,
            "model": MODEL_NAME,
            "has_model": False,
            "error": str(e)
        }

def strip_ansi(text: str) -> str:
    ansi_regex = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')
    return ansi_regex.sub('', text)

def try_internal_fast_path(user_input: str) -> dict | None:
    text = user_input.strip()
    lower = text.lower()

    # Evangelion / NERV Internal Shortcuts
    ev_shortcuts = {
        "vitals": {"action": "ipc", "target": "vitals", "call": "toggle", "message": "Toggled NERV Hardware Vitals"},
        "control center": {"action": "ipc", "target": "controlcenter", "call": "toggle", "message": "Toggled NERV Control Center"},
        "controlcenter": {"action": "ipc", "target": "controlcenter", "call": "toggle", "message": "Toggled NERV Control Center"},
        "panel": {"action": "ipc", "target": "controlcenter", "call": "toggle", "message": "Toggled NERV Control Center"},
        "cc": {"action": "ipc", "target": "controlcenter", "call": "toggle", "message": "Toggled NERV Control Center"},
        "launcher": {"action": "ipc", "target": "launcher", "call": "toggle", "message": "Toggled NERV Launcher"},
        "lock": {"action": "ipc", "target": "lockscreen", "call": "lock", "message": "Locked NERV Terminal"},
        "lockscreen": {"action": "ipc", "target": "lockscreen", "call": "lock", "message": "Locked NERV Terminal"},
        "audio": {"action": "ipc", "target": "audiobri", "call": "toggle", "message": "Toggled Audio & Brightness"},
        "volume": {"action": "ipc", "target": "audiobri", "call": "toggle", "message": "Toggled Audio & Brightness"},
        "network": {"action": "ipc", "target": "network", "call": "toggle", "message": "Toggled Network Radar"},
        "wifi": {"action": "ipc", "target": "network", "call": "toggle", "message": "Toggled Network Radar"},
        "areapicker": {"action": "ipc", "target": "areapicker", "call": "open", "message": "Opened Tactical Area Picker"},
        "screenshot": {"action": "ipc", "target": "areapicker", "call": "openClip", "message": "Tactical Area Picker -> Clipboard"},
        "wallpaper": {"action": "ipc", "target": "background", "call": "openPicker", "message": "Opened Wallpaper Selector"},
        "evafile": {"action": "cmd", "cmd": ["evafile"], "message": "Launched EvaFile"},
        "evaterm": {"action": "cmd", "cmd": ["evaterm"], "message": "Launched EvaTerm"},
        # Common app synonyms (0ms instant response)
        "file manager": {"action": "cmd", "cmd": ["evafile"], "message": "Launched EvaFile", "success": True},
        "filemanager": {"action": "cmd", "cmd": ["evafile"], "message": "Launched EvaFile", "success": True},
        "files": {"action": "cmd", "cmd": ["evafile"], "message": "Launched EvaFile", "success": True},
        "browser": {"action": "cmd", "cmd": ["firefox"], "message": "Launched Firefox", "success": True},
        "editor": {"action": "cmd", "cmd": ["antigravity-ide"], "message": "Launched Antigravity IDE", "success": True},
        "code": {"action": "cmd", "cmd": ["antigravity-ide"], "message": "Launched Antigravity IDE", "success": True},
        "calculator": {"action": "cmd", "cmd": ["gnome-calculator"], "message": "Launched Calculator", "success": True},
        "calc": {"action": "cmd", "cmd": ["gnome-calculator"], "message": "Launched Calculator", "success": True},
        "htop": {"action": "cmd", "cmd": ["evaterm", "-e", "htop"], "message": "Launched HTop Terminal", "success": True}
    }
    if lower in ev_shortcuts:
        res = ev_shortcuts[lower]
        res["success"] = True
        return res

    # Common URL domains
    common_sites = {
        "youtube": "https://youtube.com",
        "github": "https://github.com",
        "google": "https://google.com",
        "reddit": "https://reddit.com",
        "twitter": "https://twitter.com",
        "x": "https://x.com",
        "wikipedia": "https://wikipedia.org"
    }
    if lower in common_sites:
        url = common_sites[lower]
        subprocess.Popen(["xdg-open", url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        return {"success": True, "message": f"Opened {url}", "target": url, "type": "url"}

    if lower.startswith("http://") or lower.startswith("https://"):
        subprocess.Popen(["xdg-open", text], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        return {"success": True, "message": f"Opened {text}", "target": text, "type": "url"}

    return None

def run_via_qwen_assistant(query: str) -> dict:
    """Execute query via qwen-assistant CLI tool."""
    env = os.environ.copy()
    env["QWEN_MODEL"] = "qwen2.5:0.5b"
    
    bin_path = str(QWEN_ASSISTANT_BIN) if QWEN_ASSISTANT_BIN.exists() else "qwen-assistant"
    try:
        res = subprocess.run(
            [bin_path, query],
            capture_output=True,
            text=True,
            timeout=12,
            env=env
        )
        raw_out = strip_ansi(res.stdout + res.stderr).strip()

        # Parse lines
        lines = [line.strip() for line in raw_out.splitlines() if line.strip()]
        
        executing_action = None
        success_message = None
        error_message = None

        for line in lines:
            if "⚡ [FastPath]" in line or "⚡ [Executing]" in line:
                executing_action = line
            elif line.startswith("✓"):
                success_message = line.lstrip("✓").strip()
            elif "Error:" in line or "error" in line.lower():
                error_message = line
            elif line.startswith("Qwen:") and not success_message:
                q_text = line.replace("Qwen:", "").strip()
                if q_text:
                    success_message = q_text

        if success_message:
            is_err = "error" in success_message.lower() or "not found" in success_message.lower()
            return {
                "success": not is_err,
                "message": success_message,
                "action": executing_action or "",
                "type": "error" if is_err else "success"
            }
        elif error_message:
            return {
                "success": False,
                "message": error_message,
                "type": "error"
            }
        elif lines:
            # Last non-empty line
            last_line = lines[-1]
            return {
                "success": True,
                "message": last_line,
                "type": "info"
            }
        return {"success": False, "message": "Command completed with no output", "type": "warning"}
    except subprocess.TimeoutExpired:
        return {"success": False, "message": "AI query timed out (12s)", "type": "timeout"}
    except Exception as e:
        return {"success": False, "message": f"Execution error: {e}", "type": "error"}

def main():
    if len(sys.argv) < 2:
        print(json.dumps({"error": "No command specified. Usage: qwen_bridge.py [--status | --exec <query>]"}))
        sys.exit(1)

    flag = sys.argv[1]
    if flag == "--status":
        print(json.dumps(check_status()))
        return
    elif flag == "--exec":
        if len(sys.argv) < 3:
            print(json.dumps({"success": False, "message": "Empty query", "type": "error"}))
            return
        query = " ".join(sys.argv[2:]).strip()
        if not query:
            print(json.dumps({"success": False, "message": "Empty query", "type": "error"}))
            return

        # 1. Internal fast path (0ms)
        fast = try_internal_fast_path(query)
        if fast:
            print(json.dumps(fast))
            return

        # 2. Delegate to qwen-assistant (with qwen2.5:0.5b)
        result = run_via_qwen_assistant(query)
        print(json.dumps(result))
        return
    else:
        query = " ".join(sys.argv[1:]).strip()
        fast = try_internal_fast_path(query)
        if fast:
            print(json.dumps(fast))
            return
        print(json.dumps(run_via_qwen_assistant(query)))

if __name__ == "__main__":
    main()
