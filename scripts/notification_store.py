#!/usr/bin/env python3
import sys
import os
import json
import time

STORE_FILE = os.path.expanduser("~/.local/state/evacore/notification_history.json")
os.makedirs(os.path.dirname(STORE_FILE), exist_ok=True)

def load_store():
    if not os.path.exists(STORE_FILE):
        return []
    try:
        with open(STORE_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return []

def save_store(data):
    try:
        temp_file = STORE_FILE + ".tmp"
        with open(temp_file, "w", encoding="utf-8") as f:
            json.dump(data[:100], f, indent=2) # Keep max 100
        os.replace(temp_file, STORE_FILE)
        return True
    except Exception as e:
        sys.stderr.write(f"Error saving notification store: {e}\n")
        return False

def format_relative_time(timestamp):
    diff = int(time.time() - timestamp)
    if diff < 60:
        return "JUST NOW"
    elif diff < 3600:
        mins = diff // 60
        return f"{mins}m AGO"
    elif diff < 86400:
        hours = diff // 3600
        return f"{hours}h AGO"
    else:
        days = diff // 86400
        return f"{days}d AGO"

if __name__ == "__main__":
    action = sys.argv[1] if len(sys.argv) > 1 else "load"

    if action == "load":
        items = load_store()
        # Refresh relative times
        for item in items:
            ts = item.get("timestamp", time.time())
            item["time"] = format_relative_time(ts)
        print(json.dumps(items))

    elif action == "add":
        import argparse
        parser = argparse.ArgumentParser()
        parser.add_argument("--app", default="SYSTEM")
        parser.add_argument("--summary", default="ALERT")
        parser.add_argument("--body", default="")
        parser.add_argument("--urgency", default="normal")
        parser.add_argument("--icon", default="")
        parser.add_argument("--image", default="")
        args = parser.parse_args(sys.argv[2:])

        items = load_store()
        new_item = {
            "id": str(int(time.time() * 1000)),
            "app": args.app.upper(),
            "summary": args.summary,
            "body": args.body,
            "urgency": args.urgency,
            "appIcon": args.icon,
            "image": args.image,
            "timestamp": time.time(),
            "time": "JUST NOW"
        }
        items.insert(0, new_item)
        save_store(items)
        print(json.dumps(new_item))

    elif action == "remove":
        target_id = sys.argv[2] if len(sys.argv) > 2 else ""
        items = load_store()
        items = [x for x in items if str(x.get("id")) != str(target_id)]
        save_store(items)
        print(json.dumps({"success": True}))

    elif action == "clear":
        save_store([])
        print(json.dumps({"success": True}))

    elif action == "save":
        payload = sys.argv[2] if len(sys.argv) > 2 else "[]"
        try:
            data = json.loads(payload)
            save_store(data)
            print(json.dumps({"success": True}))
        except Exception as e:
            print(json.dumps({"success": False, "error": str(e)}))
