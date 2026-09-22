#!/usr/bin/env python3
"""
MAGI System Deliberation Bridge for Quickshell
Concurrently queries local Ollama (qwen2.5:0.5b) with the 3 canonical Evangelion personas:
- MELCHIOR-01 (Scientist): Technical logic, computational efficiency, algorithm validity.
- BALTHASAR-02 (Mother): System stability, data protection, preventing destructive actions.
- CASPER-03 (Woman / Pragmatist): User intent, necessity, practical trade-offs.

Returns structured JSON for Quickshell consumption.
"""

import sys
import json
import time
import argparse
import urllib.request
import urllib.error
import concurrent.futures

OLLAMA_URL = "http://127.0.0.1:11434/api/chat"
DEFAULT_MODEL = "qwen2.5:0.5b"
TIMEOUT_SECONDS = 3.5

PERSONAS = {
    "melchior": {
        "name": "MELCHIOR • 01",
        "role": "SCIENTIST // 科学者",
        "prompt": (
            "You are MAGI-01 MELCHIOR (Scientist). Evaluate the given user query or process action purely on "
            "technical logic, system performance, memory efficiency, and algorithmic consistency. "
            "Reply strictly in this format without markdown:\n"
            "[THOUGHT] <one short sentence analysis>\n"
            "[VOTE] AGREE or DENY"
        )
    },
    "balthasar": {
        "name": "BALTHASAR • 02",
        "role": "MOTHER // 母親",
        "prompt": (
            "You are MAGI-02 BALTHASAR (Mother). Evaluate the given user query or process action purely on "
            "system safety, preventing data loss, protecting critical daemons, and system stability. "
            "Reply strictly in this format without markdown:\n"
            "[THOUGHT] <one short sentence analysis>\n"
            "[VOTE] AGREE or DENY"
        )
    },
    "casper": {
        "name": "CASPER • 03",
        "role": "WOMAN // 女性",
        "prompt": (
            "You are MAGI-03 CASPER (Woman / Pragmatist). Evaluate the given user query or process action on "
            "user intent, necessity, productivity, and practical risk/reward trade-offs. "
            "Reply strictly in this format without markdown:\n"
            "[THOUGHT] <one short sentence analysis>\n"
            "[VOTE] AGREE or DENY"
        )
    }
}

def query_ollama_node(node_key, node_info, query_text):
    payload = {
        "model": DEFAULT_MODEL,
        "messages": [
            {"role": "system", "content": node_info["prompt"]},
            {"role": "user", "content": query_text}
        ],
        "options": {
            "temperature": 0.2,
            "num_predict": 45,
            "top_p": 0.9
        },
        "stream": False
    }

    req = urllib.request.Request(
        OLLAMA_URL,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"}
    )

    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT_SECONDS) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            content = data.get("message", {}).get("content", "").strip()

            thought = "Analysis completed."
            vote = "AGREE"

            # Normalize delimiters
            norm = content.replace("[VOTE]", "VOTE:").replace("[THOUGHT]", "THOUGHT:")
            if "THOUGHT:" in norm:
                parts = norm.split("THOUGHT:")
                if len(parts) > 1:
                    rest = parts[1]
                    if "VOTE:" in rest:
                        sub = rest.split("VOTE:")
                        thought = sub[0].strip()
                        vote_raw = sub[1].strip().upper()
                        vote = "DENY" if ("DENY" in vote_raw or "REJECT" in vote_raw) else "AGREE"
                    else:
                        thought = rest.strip()
            elif "VOTE:" in norm:
                sub = norm.split("VOTE:")
                thought = sub[0].strip()
                vote_raw = sub[1].strip().upper()
                vote = "DENY" if ("DENY" in vote_raw or "REJECT" in vote_raw) else "AGREE"
            else:
                thought = content.replace("\n", " ").strip()
                if any(w in content.upper() for w in ["DENY", "REJECT", "UNSAFE", "DANGEROUS"]):
                    vote = "DENY"

            # Check if thought ends with VOTE mention
            if "VOTE:" in thought:
                v_split = thought.split("VOTE:")
                thought = v_split[0].strip()
                if "DENY" in v_split[1].upper():
                    vote = "DENY"

            # Clean thought formatting
            thought = thought.split("\n")[0].strip()
            if "[" in thought and not thought.endswith("]"):
                thought = thought.split("[")[0].strip()
            thought = thought.strip(" .[]\n\r")
            if not thought:
                thought = "Nominal system state confirmed."

            # Canonical Evangelion MAGI safety safeguard on critical system processes
            q_lower = query_text.lower()
            if any(c in q_lower for c in ["systemd", "dbus", "hyprland", "xorg", "wireplumber", "pipewire", "kworker", "init", "pid: 1", "quickshell"]):
                if node_key == "balthasar":
                    vote = "DENY"
                    thought = "Critical system core service protected. Action prohibited."
                elif node_key == "melchior" and any(k in q_lower for k in ["pid: 1", "init", "systemd"]):
                    vote = "DENY"
                    thought = "Fatal process dependency detected. Action will induce kernel panic."

            return node_key, {
                "name": node_info["name"],
                "role": node_info["role"],
                "vote": vote,
                "thought": thought
            }
    except Exception as e:
        # Node fallback
        return node_key, fallback_node(node_key, node_info, query_text)

def fallback_node(node_key, node_info, query_text):
    q = query_text.lower()
    is_kill = "kill" in q or "terminate" in q
    is_critical = any(c in q for c in ["systemd", "dbus", "hyprland", "xorg", "wireplumber", "pipewire", "kworker", "init", "pid: 1"])

    if node_key == "balthasar":
        if is_critical:
            return {"name": node_info["name"], "role": node_info["role"], "vote": "DENY", "thought": "Critical core service protected. Action prohibited."}
        return {"name": node_info["name"], "role": node_info["role"], "vote": "AGREE", "thought": "No core system files threatened. Safety verified."}
    elif node_key == "melchior":
        if is_critical:
            return {"name": node_info["name"], "role": node_info["role"], "vote": "DENY", "thought": "Fatal thread dependency detected. Computation aborted."}
        return {"name": node_info["name"], "role": node_info["role"], "vote": "AGREE", "thought": "Resource consumption is nominal. Execution logic valid."}
    else: # casper
        if is_critical:
            return {"name": node_info["name"], "role": node_info["role"], "vote": "DENY", "thought": "Disruptive action outweighs operational necessity."}
        return {"name": node_info["name"], "role": node_info["role"], "vote": "AGREE", "thought": "User directive validated. Operation authorized."}

def run_deliberation(query_text):
    t0 = time.time()
    results = {}

    try:
        # Check if Ollama is reachable
        req = urllib.request.Request(OLLAMA_URL.replace("/chat", "/tags"), headers={"Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=1.0) as resp:
            pass # Ollama is alive
        use_ollama = True
    except Exception:
        use_ollama = False

    if use_ollama:
        with concurrent.futures.ThreadPoolExecutor(max_workers=3) as executor:
            future_to_node = {
                executor.submit(query_ollama_node, k, v, query_text): k
                for k, v in PERSONAS.items()
            }
            for future in concurrent.futures.as_completed(future_to_node):
                k, res = future.result()
                results[k] = res
    else:
        for k, v in PERSONAS.items():
            results[k] = fallback_node(k, v, query_text)

    elapsed_ms = int((time.time() - t0) * 1000)

    # Tally votes
    agree_count = sum(1 for v in results.values() if v["vote"] == "AGREE")
    deny_count = 3 - agree_count

    if agree_count == 3:
        consensus_text = "3-0 UNANIMOUS PASS"
        passed = True
        status = "APPROVED // 承認"
    elif agree_count == 2:
        consensus_text = "2-1 MAJORITY PASS"
        passed = True
        status = "APPROVED // 承認"
    elif agree_count == 1:
        consensus_text = "1-2 MOTION REJECTED"
        passed = False
        status = "REJECTED // 否決"
    else:
        consensus_text = "0-3 UNANIMOUS REJECT"
        passed = False
        status = "REJECTED // 否決"

    output = {
        "query": query_text,
        "melchior": results.get("melchior", {}),
        "balthasar": results.get("balthasar", {}),
        "casper": results.get("casper", {}),
        "agree_count": agree_count,
        "deny_count": deny_count,
        "consensus": consensus_text,
        "passed": passed,
        "status": status,
        "engine": "OLLAMA_QWEN_0.5B" if use_ollama else "HEURISTIC_FALLBACK",
        "elapsed_ms": elapsed_ms
    }

    return output

def main():
    parser = argparse.ArgumentParser(description="MAGI System Tri-Core Deliberation Engine")
    parser.add_argument("--query", "-q", type=str, default="", help="General query or command text")
    parser.add_argument("--type", "-t", type=str, default="query", choices=["query", "process"], help="Query type")
    parser.add_argument("--name", "-n", type=str, default="", help="Process name")
    parser.add_argument("--pid", "-p", type=str, default="", help="Process PID")
    args = parser.parse_args()

    if args.type == "process" and (args.pid or args.name):
        query_text = f"Evaluate termination of process '{args.name or 'unknown'}' (PID: {args.pid or '?'}). Is it safe to kill?"
    elif args.query:
        query_text = args.query.strip()
    else:
        query_text = "Check system operational state and MAGI protocol consistency."

    res = run_deliberation(query_text)
    print(json.dumps(res, ensure_ascii=False))

if __name__ == "__main__":
    main()
