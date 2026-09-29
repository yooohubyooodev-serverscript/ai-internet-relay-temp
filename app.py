"""
AI Internet Relay - Web App
รันบน Render ได้เลย
รองรับการรับคำสั่งจาก AI และส่งต่อไปยัง Terminal ผ่าน GitHub Mailbox
"""

import os
import json
import time
import uuid
from datetime import datetime, timezone
from flask import Flask, request, jsonify, render_template_string, redirect

app = Flask(__name__)

# ========== Config ==========
GITHUB_TOKEN = os.environ.get("GITHUB_TOKEN", "")
GITHUB_REPO = os.environ.get("GITHUB_REPO", "yooohubyooodev-serverscript/ai-internet-relay-temp")
API_BASE = f"https://api.github.com/repos/{GITHUB_REPO}/contents"

# ========== Helpers ==========
def github_headers():
    return {
        "Authorization": f"token {GITHUB_TOKEN}",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28"
    }

def get_file(path: str) -> dict:
    """อ่านไฟล์จาก GitHub แล้วคืนเป็น dict"""
    import requests
    url = f"{API_BASE}/{path}"
    r = requests.get(url, headers=github_headers(), timeout=15)
    if r.status_code != 200:
        return {"messages": [], "error": r.text}
    data = r.json()
    import base64
    content = base64.b64decode(data["content"]).decode("utf-8")
    return json.loads(content)

def update_file(path: str, content: dict, message: str) -> bool:
    """อัปเดตไฟล์บน GitHub"""
    import requests, base64
    url = f"{API_BASE}/{path}"
    
    # หา sha ปัจจุบัน
    r = requests.get(url, headers=github_headers(), timeout=15)
    if r.status_code != 200:
        return False
    sha = r.json()["sha"]
    
    payload = {
        "message": message,
        "content": base64.b64encode(json.dumps(content, ensure_ascii=False, indent=2).encode()).decode(),
        "sha": sha
    }
    r = requests.put(url, headers=github_headers(), json=payload, timeout=15)
    return r.status_code in (200, 201)

def now_iso():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

# ========== Routes ==========
@app.route("/")
def index():
    return render_template_string(DASHBOARD_HTML)

@app.route("/api/inbox", methods=["GET"])
def api_inbox():
    data = get_file("mailbox/inbox.json")
    return jsonify(data)

@app.route("/api/outbox", methods=["GET"])
def api_outbox():
    data = get_file("mailbox/outbox.json")
    return jsonify(data)

@app.route("/api/send", methods=["POST"])
def api_send():
    """AI หรือคนส่งคำสั่งเข้า inbox"""
    body = request.get_json(force=True, silent=True) or {}
    
    cmd = body.get("cmd") or body.get("command") or body.get("data")
    if not cmd:
        # รองรับ plain text
        cmd = request.data.decode("utf-8").strip()
        if cmd.startswith("CMD:"):
            cmd = cmd[4:].strip()
    
    if not cmd:
        return jsonify({"error": "ไม่มีคำสั่ง"}), 400
    
    msg_id = body.get("id") or str(uuid.uuid4())[:8]
    
    new_msg = {
        "id": msg_id,
        "type": "cmd",
        "cmd": cmd,
        "status": "pending",
        "from": body.get("from", "ai"),
        "timestamp": now_iso()
    }
    
    inbox = get_file("mailbox/inbox.json")
    if "messages" not in inbox:
        inbox = {"messages": [], "last_updated": now_iso()}
    
    inbox["messages"].append(new_msg)
    inbox["last_updated"] = now_iso()
    
    ok = update_file("mailbox/inbox.json", inbox, f"AI sent command {msg_id}")
    
    if ok:
        return jsonify({"ok": True, "id": msg_id, "message": "ส่งคำสั่งเรียบร้อย"})
    return jsonify({"error": "เขียนลง GitHub ไม่สำเร็จ (เช็ค GITHUB_TOKEN)"}), 500

@app.route("/api/health")
def health():
    return jsonify({
        "status": "ok",
        "time": now_iso(),
        "has_token": bool(GITHUB_TOKEN),
        "repo": GITHUB_REPO
    })

# ========== Simple Dashboard HTML ==========
DASHBOARD_HTML = """
<!DOCTYPE html>
<html lang="th">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>AI Internet Relay</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: system-ui, sans-serif; background: #0f172a; color: #e2e8f0; padding: 20px; }
    h1 { margin-bottom: 4px; }
    .sub { color: #94a3b8; margin-bottom: 24px; font-size: 0.9rem; }
    .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; }
    @media (max-width: 768px) { .grid { grid-template-columns: 1fr; } }
    .card { background: #1e293b; border-radius: 12px; padding: 16px; border: 1px solid #334155; }
    .card h2 { font-size: 1rem; color: #38bdf8; margin-bottom: 10px; }
    pre { background: #020617; padding: 12px; border-radius: 8px; overflow: auto; font-size: 0.8rem; max-height: 320px; white-space: pre-wrap; }
    button { background: #0ea5e9; color: #fff; border: none; padding: 10px 16px; border-radius: 8px; cursor: pointer; margin-top: 10px; margin-right: 8px; }
    button:hover { background: #0284c7; }
    textarea { width: 100%; background: #020617; border: 1px solid #334155; color: #e2e8f0; padding: 10px; border-radius: 8px; min-height: 70px; font-family: monospace; margin-top: 8px; }
    .ok { color: #4ade80; }
    .err { color: #f87171; }
  </style>
</head>
<body>
  <h1>AI Internet Relay</h1>
  <p class="sub">Web App · URL-based · รันบน Render ได้</p>

  <div class="grid">
    <div class="card">
      <h2>📥 Inbox (AI → Terminal)</h2>
      <pre id="inbox">Loading...</pre>
      <button onclick="load('inbox')">Refresh</button>
    </div>
    <div class="card">
      <h2>📤 Outbox (Terminal → AI)</h2>
      <pre id="outbox">Loading...</pre>
      <button onclick="load('outbox')">Refresh</button>
    </div>
  </div>

  <div class="card" style="margin-top:16px">
    <h2>ส่งคำสั่ง</h2>
    <textarea id="cmd" placeholder="echo hello && date && whoami"></textarea>
    <button onclick="sendCmd()">Send Command</button>
    <span id="status"></span>
  </div>

  <script>
    async function load(which) {
      const el = document.getElementById(which);
      try {
        const r = await fetch('/api/' + which + '?t=' + Date.now());
        const d = await r.json();
        el.textContent = JSON.stringify(d, null, 2);
      } catch(e) {
        el.textContent = 'Error: ' + e.message;
      }
    }
    async function sendCmd() {
      const cmd = document.getElementById('cmd').value.trim();
      if (!cmd) return;
      const st = document.getElementById('status');
      st.textContent = 'Sending...';
      st.className = '';
      try {
        const r = await fetch('/api/send', {
          method: 'POST',
          headers: {'Content-Type': 'application/json'},
          body: JSON.stringify({cmd})
        });
        const d = await r.json();
        if (d.ok) {
          st.textContent = '✓ ส่งแล้ว id=' + d.id;
          st.className = 'ok';
          load('inbox');
        } else {
          st.textContent = '✗ ' + (d.error || 'failed');
          st.className = 'err';
        }
      } catch(e) {
        st.textContent = '✗ ' + e.message;
        st.className = 'err';
      }
    }
    load('inbox'); load('outbox');
    setInterval(() => { load('inbox'); load('outbox'); }, 12000);
  </script>
</body>
</html>
"""

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 10000))
    app.run(host="0.0.0.0", port=port, debug=False)
