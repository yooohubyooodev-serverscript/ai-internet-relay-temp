# Internet Relay Protocol (Hybrid)

เวอร์ชัน: 1.0  
วันที่: 2026-09-29  
เป้าหมาย: ให้ AI สื่อสารกับ Internet-enabled Terminal ผ่าน Public Mailbox โดยใช้ได้ทั้ง JSON และข้อความแบบเทอร์มินัล

## ภาพรวม Flow

```
AI → (Web Access) → Public Mailbox → Terminal (polling)
Terminal → รันคำสั่ง → เขียนผลลัพธ์กลับ Mailbox → AI อ่านผล
```

## 1. รูปแบบข้อความที่ AI ส่งได้

### แบบสั้น (Termux / Shell style) — แนะนำสำหรับใช้งานส่วนตัว
```
CMD:ls -la && echo hello && whoami
```

หรือ
```
CMD:ls -la && echo "hello from AI" && curl -s ifconfig.me
```

### แบบ JSON (แนะนำสำหรับระบบจริง)
```json
{
  "id": "001",
  "type": "cmd",
  "cmd": "ls -la && echo hello && whoami",
  "timeout": 30,
  "from": "ai",
  "timestamp": "2026-09-29T12:30:00Z"
}
```

### ฟิลด์ที่รองรับ (JSON)
| ฟิลด์       | ความหมาย                          | บังคับ? |
|------------|-----------------------------------|---------|
| id         | รหัสข้อความ (กันซ้ำ)              | แนะนำ   |
| type       | cmd / message / reply / error     | ใช่     |
| cmd        | คำสั่ง shell ที่ต้องการรัน        | ใช่ (ถ้า type=cmd) |
| data       | ข้อมูลดิบ (Base64 หรือ plain)     | ไม่บังคับ |
| timeout    | เวลาสูงสุดที่รันได้ (วินาที)       | ไม่บังคับ (default 30) |
| from       | ai / terminal                     | แนะนำ   |
| status     | pending / processing / done / error | แนะนำ |
| timestamp  | เวลา                              | ไม่บังคับ |

## 2. รูปแบบข้อความที่ Terminal ตอบกลับ

### แบบ plain text
```
ID=001
STATUS=done
OUTPUT=
total 12
drwxr-xr-x 2 user user 4096 ...
hello
user
```

### แบบ JSON
```json
{
  "id": "001",
  "type": "reply",
  "status": "done",
  "result": "total 12\ndrwxr-xr-x ...\nhello\nuser",
  "from": "terminal",
  "timestamp": "2026-09-29T12:30:15Z"
}
```

## 3. สถานะ (status)
- `pending`     → รอ Terminal มารับ
- `processing`  → Terminal กำลังรัน
- `done`        → เสร็จแล้ว
- `error`       → เกิดข้อผิดพลาด

## 4. กฎสำคัญ
1. Terminal ต้องเช็ค `id` เพื่อไม่ประมวลผลซ้ำ
2. ถ้าข้อความขึ้นต้นด้วย `{` ให้ถือว่าเป็น JSON
3. ถ้าขึ้นต้นด้วย `CMD:` ให้ถือว่าเป็นคำสั่ง shell ตรง ๆ
4. ผลลัพธ์ควรเก็บทั้ง stdout และ stderr
5. ควรมี timeout กันคำสั่งค้าง

## 5. ตัวอย่างการใช้จริง

**AI ส่ง:**
```
CMD:echo "Hello from AI" && date && uname -a
```

**Terminal ตอบ:**
```
ID=auto-001
STATUS=done
OUTPUT=
Hello from AI
Tue Sep 29 12:30:15 UTC 2026
Linux hostname 6.x ...
```
