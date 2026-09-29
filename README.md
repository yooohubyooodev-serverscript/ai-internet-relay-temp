# AI Internet Relay (Disposable)

ระบบสื่อสารระหว่าง AI กับ Internet-enabled Terminal ผ่าน **URL ล้วน**  
ใช้ GitHub repo นี้เป็น Public Mailbox

**Repo:** https://github.com/yooohubyooodev-serverscript/ai-internet-relay-temp  
**สร้างเมื่อ:** 2026-09-29 (ใช้ครั้งเดียวทิ้ง)

## โครงสร้าง

```
mailbox/
  inbox.json   ← AI เขียนคำสั่งมาที่นี่
  outbox.json  ← Terminal เขียนผลลัพธ์มาที่นี่
PROTOCOL.md
terminal_relay.sh          (เวอร์ชัน temporary storage)
terminal_relay_github.sh   (เวอร์ชัน GitHub - แนะนำ)
index.html                 (Dashboard อ่านอย่างเดียว)
ai_examples.md
```

## วิธีใช้แบบเร็ว

### 1. ฝั่ง Terminal
```bash
export GITHUB_TOKEN=your_token_here
chmod +x terminal_relay_github.sh
./terminal_relay_github.sh
```

### 2. ฝั่ง AI ส่งคำสั่ง
เขียนลง `mailbox/inbox.json` ในรูปแบบ:

```json
{
  "messages": [
    {
      "id": "001",
      "type": "cmd",
      "cmd": "echo hello && date && whoami",
      "status": "pending",
      "from": "ai"
    }
  ],
  "last_updated": "..."
}
```

หรือใช้ raw URL อ่านผลจาก:
- Inbox: https://raw.githubusercontent.com/yooohubyooodev-serverscript/ai-internet-relay-temp/main/mailbox/inbox.json
- Outbox: https://raw.githubusercontent.com/yooohubyooodev-serverscript/ai-internet-relay-temp/main/mailbox/outbox.json

## Protocol
รองรับทั้ง:
- `CMD:ls -la && echo hello` (แบบเทอร์มินัล)
- JSON เต็มรูปแบบ

ดูรายละเอียดใน `PROTOCOL.md`

## ข้อควรระวัง
- นี่เป็น repo แบบใช้ครั้งเดียวทิ้ง
- Token ที่ใช้สร้างควรถูก revoke หลังใช้งานเสร็จ
- อย่า commit token ลงในไฟล์
