#!/usr/bin/env python3
"""
EvaCore Bridge Script for Quickshell QML Integration.
Provides JSON interface for EvaCore, EvaTerm, EvaFile, and EvaSort.
"""

import os
import sys
import json
import subprocess
import shutil
import re

EVACORE_BIN = os.path.expanduser("~/.local/bin/evacore")
EVAFILE_BIN = os.path.expanduser("~/.local/bin/evafile")
EVATERM_BIN = os.path.expanduser("~/.local/bin/evaterm")
EVASORT_BIN = os.path.expanduser("~/.local/bin/evasort")
EVALINK_BIN = os.path.expanduser("~/.local/bin/evalink")

def get_pids_by_name(process_name):
    """Find all PIDs matching an executable name."""
    try:
        out = subprocess.check_output(["pgrep", "-x", process_name], text=True).strip()
        return [int(p) for p in out.splitlines() if p.strip()]
    except (subprocess.CalledProcessError, FileNotFoundError):
        return []

def get_service_status(service_name):
    """Check status of a service via evacore or pidfile."""
    runtime_dir = os.environ.get("XDG_RUNTIME_DIR", f"/tmp/user/{os.getuid()}")
    pid_file = os.path.join(runtime_dir, "evacore", f"{service_name}.pid")
    
    if os.path.exists(pid_file):
        try:
            with open(pid_file, "r") as f:
                pid = int(f.read().strip())
            # Check if process is actually alive
            os.kill(pid, 0)
            return {"running": True, "pid": pid}
        except (ValueError, OSError):
            return {"running": False, "pid": None}
    
    # Fallback to pgrep
    pids = get_pids_by_name(service_name)
    if pids:
        return {"running": True, "pid": pids[0], "pids": pids}
    return {"running": False, "pid": None}

def get_global_status():
    """Aggregate live status of all Eva ecosystem components."""
    # 1. Quickshell
    shell_status = get_service_status("quickshell")
    if not shell_status["running"]:
        pids = get_pids_by_name("quickshell")
        if pids:
            shell_status = {"running": True, "pid": pids[0]}

    # 2. Evasort Watcher
    sort_status = get_service_status("evasort")
    
    # 3. EvaFile
    file_pids = get_pids_by_name("evafile")
    file_status = {
        "running": len(file_pids) > 0,
        "count": len(file_pids),
        "pids": file_pids,
        "pid": file_pids[0] if file_pids else None
    }
    
    # 4. EvaTerm
    term_pids = get_pids_by_name("evaterm")
    term_status = {
        "running": len(term_pids) > 0,
        "count": len(term_pids),
        "pids": term_pids,
        "pid": term_pids[0] if term_pids else None
    }
    
    # 5. Evalink / aria2
    link_pids = get_pids_by_name("aria2c")
    link_status = {
        "running": len(link_pids) > 0,
        "pid": link_pids[0] if link_pids else None
    }
    
    # 6. EvaTube
    tube_available = os.path.exists(os.path.expanduser("~/evatube")) or shutil.which("evatube") is not None

    return {
        "evacore": {
            "installed": os.path.exists(EVACORE_BIN),
            "version": "0.1.0"
        },
        "shell": shell_status,
        "sort": sort_status,
        "file": file_status,
        "term": term_status,
        "link": link_status,
        "tube": {
            "available": tube_available
        }
    }

def run_sort(path=None):
    """Run Evasort to organize a directory once."""
    target = path or os.path.expanduser("~/Downloads")
    try:
        cmd = [EVACORE_BIN, "sort"] if os.path.exists(EVACORE_BIN) else [EVASORT_BIN, target]
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
        return {
            "success": res.returncode == 0,
            "output": res.stdout.strip() or res.stderr.strip(),
            "target": target
        }
    except Exception as e:
        return {"success": False, "error": str(e)}

def toggle_sort_daemon():
    """Toggle continuous Evasort watcher daemon."""
    status = get_service_status("evasort")
    try:
        if status["running"]:
            if os.path.exists(EVACORE_BIN):
                res = subprocess.run([EVACORE_BIN, "sort", "-k"], capture_output=True, text=True)
            else:
                res = subprocess.run(["kill", str(status["pid"])], capture_output=True, text=True)
            return {"success": True, "action": "stopped", "running": False}
        else:
            if os.path.exists(EVACORE_BIN):
                res = subprocess.run([EVACORE_BIN, "sort", "-D"], capture_output=True, text=True)
            else:
                proc = subprocess.Popen([EVASORT_BIN, "-w", os.path.expanduser("~/Downloads")], start_new_session=True)
            return {"success": True, "action": "started", "running": True}
    except Exception as e:
        return {"success": False, "error": str(e)}

def launch_file(path=None):
    """Launch EvaFile graphical file manager."""
    target = path if path else os.path.expanduser("~/Downloads")
    target = os.path.expanduser(target)
    
    bin_path = EVAFILE_BIN if os.path.exists(EVAFILE_BIN) else "evafile"
    try:
        proc = subprocess.Popen([bin_path, target], start_new_session=True)
        return {"success": True, "pid": proc.pid, "path": target}
    except Exception as e:
        return {"success": False, "error": str(e)}

def launch_term(cwd=None, cmd=None):
    """Launch EvaTerm GPU terminal emulator."""
    target_dir = os.path.expanduser(cwd) if cwd else os.path.expanduser("~")
    bin_path = EVATERM_BIN if os.path.exists(EVATERM_BIN) else "evaterm"
    
    exec_args = [bin_path]
    if cmd:
        exec_args.extend(["-e", cmd])
        
    try:
        proc = subprocess.Popen(exec_args, cwd=target_dir, start_new_session=True)
        return {"success": True, "pid": proc.pid, "cwd": target_dir}
    except Exception as e:
        return {"success": False, "error": str(e)}

def shell_restart():
    """Restart Quickshell UI."""
    try:
        if os.path.exists(EVACORE_BIN):
            subprocess.Popen([EVACORE_BIN, "shell", "-r", "-d"], start_new_session=True)
        else:
            subprocess.Popen(["quickshell", "-p", os.path.expanduser("~/.config/quickshell/evangelion/shell.qml")], start_new_session=True)
        return {"success": True}
    except Exception as e:
        return {"success": False, "error": str(e)}

def get_sort_rules():
    """Fetch active sorting rules and structured routing pipeline data."""
    icons = {
        "Music": "󰝚",
        "Videos": "󰕧",
        "Pictures": "󰋩",
        "Documents": "󰈙",
        "Archives": "󰛫",
        "Installers": "󰏖",
        "Torrents": "󰇚"
    }
    try:
        raw_text = ""
        if os.path.exists(EVACORE_BIN):
            res = subprocess.run([EVACORE_BIN, "sort", "--rules"], capture_output=True, text=True)
            raw_text = res.stdout.strip()
        elif os.path.exists(EVASORT_BIN):
            res = subprocess.run([EVASORT_BIN, "--rules"], capture_output=True, text=True)
            raw_text = res.stdout.strip()

        if not raw_text:
            return {"success": False, "error": "evacore binary not found", "categories": [], "rules_text": ""}

        source_match = re.search(r"Source Directory:\s*(.*)", raw_text)
        strategy_match = re.search(r"Conflict Strategy:\s*(.*)", raw_text)
        source_dir = source_match.group(1).strip() if source_match else "~/Downloads"
        strategy = strategy_match.group(1).strip() if strategy_match else "rename"

        home_dir = os.path.expanduser("~")
        categories = []
        blocks = re.findall(r"•\s*\[(.*?)\]\s*->\s*(.*?)\n\s*Extensions:\s*(.*)", raw_text)
        for name, dest, exts in blocks:
            ext_list = [e.strip() for e in exts.split(",") if e.strip()]
            clean_dest = dest.strip()
            display_dest = clean_dest.replace(home_dir, "~")
            categories.append({
                "name": name.strip(),
                "icon": icons.get(name.strip(), "󰉋"),
                "dest": display_dest,
                "dest_full": clean_dest,
                "exts": ext_list,
                "count": len(ext_list)
            })

        return {
            "success": True,
            "source": source_dir.replace(home_dir, "~"),
            "source_full": source_dir,
            "strategy": strategy,
            "categories": categories,
            "rules_text": raw_text
        }
    except Exception as e:
        return {"success": False, "error": str(e), "categories": [], "rules_text": ""}

def execute_magi_command(cmd_text):
    """Dispatch command string from MAGI terminal."""
    cmd_text = (cmd_text or "").strip()
    if not cmd_text:
        return {"output": "NO COMMAND SPECIFIED", "success": False}
    
    parts = cmd_text.split()
    first = parts[0].lower()
    
    if first in ("status", "stat"):
        stat = get_global_status()
        out = (
            f"EVA SUITE STATUS READOUT:\n"
            f"-------------------------\n"
            f"• EVACORE:  {'ONLINE' if stat['evacore']['installed'] else 'OFFLINE'}\n"
            f"• SHELL:    {'ACTIVE (PID ' + str(stat['shell']['pid']) + ')' if stat['shell']['running'] else 'STANDBY'}\n"
            f"• EVALINK:  {'ONLINE' if stat['link']['running'] else 'STANDBY'}\n"
            f"• EVASORT:  {'DAEMON RUNNING' if stat['sort']['running'] else 'STANDBY'}\n"
            f"• EVAFILE:  {str(stat['file']['count']) + ' INSTANCE(S)' if stat['file']['running'] else 'STANDBY'}\n"
            f"• EVATERM:  {str(stat['term']['count']) + ' SESSION(S)' if stat['term']['running'] else 'STANDBY'}\n"
        )
        return {"output": out, "success": True, "data": stat}
    
    elif first in ("sort", "organize"):
        target = parts[1] if len(parts) > 1 else None
        res = run_sort(target)
        return {"output": res.get("output", res.get("error", "Sort completed")), "success": res.get("success", False)}
        
    elif first in ("sort-daemon", "watcher"):
        res = toggle_sort_daemon()
        action = res.get("action", "unknown")
        return {"output": f"EVASORT WATCHER DAEMON: {action.upper()}", "success": res.get("success", False)}
        
    elif first in ("file", "evafile", "fm"):
        target = parts[1] if len(parts) > 1 else None
        res = launch_file(target)
        return {"output": f"EVAFILE LAUNCHED (PID {res.get('pid')})", "success": res.get("success", False)}
        
    elif first in ("term", "evaterm", "sh"):
        cmd_arg = " ".join(parts[1:]) if len(parts) > 1 else None
        res = launch_term(cmd=cmd_arg)
        return {"output": f"EVATERM LAUNCHED (PID {res.get('pid')})", "success": res.get("success", False)}
        
    elif first in ("kill", "terminate"):
        if len(parts) < 2:
            return {"output": "USAGE: kill <pid>", "success": False}
        pid = parts[1]
        try:
            subprocess.run(["kill", pid], check=True)
            return {"output": f"TERMINATED PID {pid}", "success": True}
        except Exception as e:
            return {"output": f"FAILED TO KILL PID {pid}: {e}", "success": False}
            
    elif first in ("restart", "reload"):
        shell_restart()
        return {"output": "QUICKSHELL RESTART DISPATCHED", "success": True}
        
    elif first in ("help", "?"):
        help_text = (
            "MAGI COMMAND MATRIX:\n"
            "• status         - View live status of all Eva services\n"
            "• sort [path]    - Run EvaSort directory organizer\n"
            "• watcher        - Toggle EvaSort background daemon\n"
            "• file [path]    - Launch EvaFile file manager\n"
            "• term [cmd]     - Spawn EvaTerm GPU terminal\n"
            "• kill <pid>     - Terminate system process\n"
            "• restart        - Hot-restart Quickshell\n"
        )
        return {"output": help_text, "success": True}
        
    else:
        # Pass to evacore CLI directly
        try:
            res = subprocess.run([EVACORE_BIN] + parts, capture_output=True, text=True, timeout=5)
            out = res.stdout.strip() or res.stderr.strip()
            return {"output": out or "COMMAND EXECUTED", "success": res.returncode == 0}
        except Exception as e:
            return {"output": f"UNKNOWN COMMAND: {cmd_text}\nType 'help' for available commands.", "success": False}

def main():
    if len(sys.argv) < 2:
        print(json.dumps({"error": "No action specified"}))
        return

    action = sys.argv[1]

    if action == "status":
        print(json.dumps(get_global_status()))

    elif action == "sort_run":
        path = sys.argv[2] if len(sys.argv) > 2 else None
        print(json.dumps(run_sort(path)))

    elif action == "sort_toggle_daemon":
        print(json.dumps(toggle_sort_daemon()))

    elif action == "sort_rules":
        print(json.dumps(get_sort_rules()))

    elif action == "launch_file":
        path = sys.argv[2] if len(sys.argv) > 2 else None
        print(json.dumps(launch_file(path)))

    elif action == "launch_term":
        cwd = sys.argv[2] if len(sys.argv) > 2 else None
        cmd = sys.argv[3] if len(sys.argv) > 3 else None
        print(json.dumps(launch_term(cwd, cmd)))

    elif action == "shell_restart":
        print(json.dumps(shell_restart()))

    elif action == "command":
        cmd_text = " ".join(sys.argv[2:]) if len(sys.argv) > 2 else ""
        print(json.dumps(execute_magi_command(cmd_text)))

    else:
        print(json.dumps({"error": f"Unknown action: {action}"}))

if __name__ == "__main__":
    main()
