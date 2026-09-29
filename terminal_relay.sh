#!/bin/bash
# ============================================================
# Internet Relay - Terminal Side Script
# เวอร์ชัน: 1.0
# ใช้งาน: รันสคริปต์นี้บนเครื่องที่มี Internet
# ============================================================

# ========== ตั้งค่า ==========
MAILBOX_BASE="https://aisenseapi.com/services/v1/storage"
POLL_INTERVAL=8          # วินาที
TIMEOUT_DEFAULT=30       # วินาที
LAST_SEEN_FILE="/tmp/relay_last_seen.txt"
LOG_FILE="/tmp/relay.log"

# เก็บ id ที่เคยประมวลผลแล้ว
PROCESSED_IDS=()

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# สร้าง mailbox ใหม่แล้วคืนค่า storage_id
create_mailbox() {
    local payload="$1"
    local response
    response=$(curl -s -X POST "$MAILBOX_BASE" \
        -H "Content-Type: application/json" \
        -d "$payload")
    echo "$response" | grep -o '"storage_id":"[^"]*"' | cut -d'"' -f4
}

# อ่านข้อมูลจาก mailbox
read_mailbox() {
    local id="$1"
    curl -s "$MAILBOX_BASE/$id"
}

# ตรวจสอบว่าเป็น JSON หรือไม่
is_json() {
    echo "$1" | grep -q '^\s*{'
}

# ดึงคำสั่งจากข้อความ
extract_cmd() {
    local msg="$1"
    if is_json "$msg"; then
        # พยายามดึงฟิลด์ cmd
        echo "$msg" | grep -o '"cmd"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"cmd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/'
    else
        # แบบ CMD:....
        echo "$msg" | sed -n 's/^CMD://p' | sed 's/^[[:space:]]*//'
    fi
}

# ดึง id จากข้อความ
extract_id() {
    local msg="$1"
    if is_json "$msg"; then
        echo "$msg" | grep -o '"id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/'
    else
        echo "auto-$(date +%s)"
    fi
}

# รันคำสั่งแล้วคืนผลลัพธ์
run_command() {
    local cmd="$1"
    local timeout="${2:-$TIMEOUT_DEFAULT}"
    log "Running command (timeout=${timeout}s): $cmd"
    timeout "$timeout" bash -c "$cmd" 2>&1
    local exit_code=$?
    if [ $exit_code -eq 124 ]; then
        echo "[ERROR] Command timed out after ${timeout}s"
    fi
}

# ส่งผลลัพธ์กลับ
send_reply() {
    local id="$1"
    local status="$2"
    local output="$3"

    # จำกัดความยาว output ไม่ให้ยาวเกิน (ป้องกัน payload ใหญ่)
    if [ ${#output} -gt 8000 ]; then
        output="${output:0:8000}...[truncated]"
    fi

    # escape สำหรับ JSON
    local escaped_output
    escaped_output=$(echo "$output" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null || echo "\"$output\"")

    local payload
    payload=$(cat <<EOF
{
  "id": "$id",
  "type": "reply",
  "status": "$status",
  "result": $escaped_output,
  "from": "terminal",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
)

    local new_id
    new_id=$(create_mailbox "$payload")
    log "Reply sent → storage_id: $new_id"
    echo "$new_id"
}

# ========== เริ่มต้น ==========
log "=== Internet Relay Terminal started ==="
log "Polling every ${POLL_INTERVAL}s"
log "ใช้คำสั่งนี้เพื่อส่ง mailbox id ให้ AI: echo \"MAILBOX_ID=xxxx\""

# ตัวอย่าง: ถ้ามี mailbox id เริ่มต้นให้ใส่ตรงนี้
# CURRENT_INBOX="d7a3fb87-adf6-49ea-8c2a-2251e458e9e8"

if [ -z "$CURRENT_INBOX" ]; then
    log "ยังไม่มี CURRENT_INBOX"
    log "วิธีใช้:"
    log "1. AI สร้างข้อความแล้วได้ storage_id"
    log "2. รัน: CURRENT_INBOX=<storage_id> $0"
    log "หรือแก้ไขสคริปต์ใส่ CURRENT_INBOX ไว้เลย"
    exit 1
fi

log "กำลัง watch mailbox: $CURRENT_INBOX"

while true; do
    content=$(read_mailbox "$CURRENT_INBOX")
    
    if [ -z "$content" ] || echo "$content" | grep -q '"error"'; then
        sleep "$POLL_INTERVAL"
        continue
    fi

    # ตรวจว่าเคยประมวลผลหรือยัง
    msg_id=$(extract_id "$content")
    already_done=false
    for pid in "${PROCESSED_IDS[@]}"; do
        if [ "$pid" = "$msg_id" ]; then
            already_done=true
            break
        fi
    done

    if [ "$already_done" = true ]; then
        sleep "$POLL_INTERVAL"
        continue
    fi

    cmd=$(extract_cmd "$content")
    
    if [ -n "$cmd" ]; then
        log "พบคำสั่งใหม่ id=$msg_id"
        PROCESSED_IDS+=("$msg_id")
        
        output=$(run_command "$cmd")
        send_reply "$msg_id" "done" "$output"
    fi

    sleep "$POLL_INTERVAL"
done
