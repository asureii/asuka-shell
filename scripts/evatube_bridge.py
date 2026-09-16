#!/usr/bin/env python3
"""
EvaTube Bridge Script for Quickshell QML Integration.
Extracts media metadata as JSON and runs background downloads with EvaTube.
"""

import os
import sys
import json
import subprocess

# Add evatube src to sys.path if present
evatube_base = os.path.expanduser("~/evatube")
evatube_src = os.path.join(evatube_base, "src")
if os.path.isdir(evatube_src):
    sys.path.insert(0, evatube_src)

try:
    from evatube.core import EvaTube
    from evatube.utils.sanitize import format_duration, format_bytes
except ImportError:
    EvaTube = None
    format_duration = None
    format_bytes = None

def main():
    if len(sys.argv) < 2:
        print(json.dumps({"error": "No action specified"}))
        return

    action = sys.argv[1]

    if action == "info":
        if EvaTube is None:
            print(json.dumps({"error": "EvaTube core module not available"}))
            return
        if len(sys.argv) < 3:
            print(json.dumps({"error": "No URL provided"}))
            return
        url = sys.argv[2]
        try:
            app = EvaTube(show_progress=False)
            info = app.extract_info(url)
            
            formats = []
            for f in info.formats:
                formats.append({
                    "format_id": f.format_id,
                    "ext": f.ext,
                    "resolution": f.resolution_str or "audio only",
                    "filesize": format_bytes(f.filesize) if f.filesize else "N/A",
                    "vcodec": f.vcodec,
                    "acodec": f.acodec,
                    "note": f.format_note or ""
                })

            res = {
                "id": info.id,
                "title": info.title,
                "uploader": info.uploader or "Unknown Artist",
                "duration": format_duration(info.duration) if info.duration else "N/A",
                "duration_secs": info.duration or 0,
                "thumbnail": info.thumbnail or "",
                "extractor": info.extractor,
                "formats": formats
            }
            print(json.dumps(res))
        except Exception as e:
            print(json.dumps({"error": str(e)}))

    elif action == "download":
        if len(sys.argv) < 3:
            print(json.dumps({"error": "No URL provided"}))
            return
        url = sys.argv[2]
        mode = sys.argv[3] if len(sys.argv) > 3 else "mp3"
        quality = sys.argv[4] if len(sys.argv) > 4 else "best"
        embed_thumb = (sys.argv[5].lower() == "true") if len(sys.argv) > 5 else True
        output_dir = os.path.expanduser("~/Downloads")

        cli_path = os.path.join(evatube_base, "cli.py")
        if os.path.exists(cli_path):
            cmd = ["python3", cli_path, mode, url, "-o", output_dir]
        else:
            cmd = ["evatube", mode, url, "-o", output_dir]
        if embed_thumb:
            cmd.append("--embed-thumbnail")
        if mode == "mp4" and quality != "best":
            cmd.extend(["-q", quality])

        try:
            # Spawn download process in background
            proc = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )
            print(json.dumps({
                "success": True,
                "pid": proc.pid,
                "output_dir": output_dir,
                "mode": mode,
                "quality": quality
            }))
        except Exception as e:
            print(json.dumps({"error": str(e)}))

    else:
        print(json.dumps({"error": f"Unknown action: {action}"}))

if __name__ == "__main__":
    main()
