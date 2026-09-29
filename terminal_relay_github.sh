#!/bin/bash
# ============================================================
# Internet Relay - Terminal Side (GitHub version)
# ใช้ GitHub repo เป็น Public Mailbox ถาวร
# ============================================================

TOKEN="${GITHUB_TOKEN:?Please set GITHUB_TOKEN environment variable}"
REPO="yooohubyooodev-serverscript/ai-internet-relay-temp"
API="https://api.github.com/repos/$REPO/contents"
POLL_INTERVAL=10
TIMEOUT_DEFAULT=30
PROCESSED_FILE="/tmp/relay_processed_ids.txt"

touch "$PROCESSED_FILE"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# อ่านไฟล์จาก GitHub (raw)
get_file() {
    local path="$1"
    curl -s -H "Authorization: token $TOKEN" \
         -H "Accept: application/vnd.github.raw" \
         "$API/$path"
}

# อัปเดตไฟล์บน GitHub
update_file() {
    local path="$1"
    local content="$2"
    local message="$3"
    
    local sha
    sha=$(curl -s -H "Authorization: token $TOKEN" "$API/$path" | grep -o '"sha": "[^"]*"' | head -1 | cut -d'"' -f4)
    
    local b64
    b64=$(echo -n "$content" | base64 -w 0)
    
    curl -s -X PUT \
        -H "Authorization: token $TOKEN" \
        -H "Accept: application/vnd.github+json" \
        "$API/$path" \
        -d "{
            \"message\": \"$message\",
            \"content\": \"$b64\",
            \"sha\": \"$sha\"
        }" > /dev/null
}

# รันคำสั่ง
run_cmd() {
    local cmd="$1"
    timeout "${TIMEOUT_DEFAULT}" bash -c "$cmd" 2>&1
}

log "=== Internet Relay (GitHub) started ==="
log "Watching: mailbox/inbox.json"
log "Repo: https://github.com/$REPO"

while true; do
    inbox=$(get_file "mailbox/inbox.json")
    
    # ดึง messages array แบบง่าย (ใช้ python ช่วย)
    cmds=$(echo "$inbox" | python3 -c '
import sys, json
try:
    data = json.load(sys.stdin)
    for m in data.get("messages", []):
        if m.get("status") == "pending":
            print(m.get("id",""), "|", m.get("cmd") or m.get("data",""))
except: pass
' 2>/dev/null)

    if [ -n "$cmds" ]; then
        while IFS= read -r line; do
            id=$(echo "$line" | cut -d'|' -f1 | xargs)
            cmd=$(echo "$line" | cut -d'|' -f2- | xargs)
            
            if grep -q "^$id$" "$PROCESSED_FILE" 2>/dev/null; then
                continue
            fi
            
            if [ -n "$cmd" ]; then
                log "Found pending command id=$id"
                echo "$id" >> "$PROCESSED_FILE"
                
                output=$(run_cmd "$cmd")
                log "Command finished"
                
                # สร้าง reply
                reply=$(python3 -c "
import json, datetime
print(json.dumps({
    'id': '$id',
    'type': 'reply',
    'status': 'done',
    'result': '''$output''',
    'from': 'terminal',
    'timestamp': datetime.datetime.utcnow().isoformat() + 'Z'
}, ensure_ascii=False))
")
                
                # อ่าน outbox ปัจจุบันแล้วเพิ่ม
                outbox=$(get_file "mailbox/outbox.json")
                new_outbox=$(echo "$outbox" | python3 -c "
import sys, json, datetime
data = json.load(sys.stdin)
data.setdefault('messages', []).append(json.loads('''$reply'''))
data['last_updated'] = datetime.datetime.utcnow().isoformat() + 'Z'
print(json.dumps(data, ensure_ascii=False, indent=2))
")
                
                update_file "mailbox/outbox.json" "$new_outbox" "Reply for command $id"
                log "Reply written to outbox.json"
                
                # อัปเดต status ใน inbox เป็น done
                new_inbox=$(echo "$inbox" | python3 -c "
import sys, json, datetime
data = json.load(sys.stdin)
for m in data.get('messages', []):
    if m.get('id') == '$id':
        m['status'] = 'done'
data['last_updated'] = datetime.datetime.utcnow().isoformat() + 'Z'
print(json.dumps(data, ensure_ascii=False, indent=2))
")
                update_file "mailbox/inbox.json" "$new_inbox" "Mark $id as done"
            fi
        done <<< "$cmds"
    fi
    
    sleep "$POLL_INTERVAL"
done
