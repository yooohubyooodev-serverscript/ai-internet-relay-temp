# Internet Relay for AI

ระบบสื่อสารระหว่าง AI (sandbox ที่ outbound ถูกจำกัด) กับ Internet-enabled Terminal  
ผ่าน Public Mailbox บนเว็บ โดยไม่ต้องมี socket ตรงจากฝั่ง AI

## ไฟล์ในโฟลเดอร์นี้

| ไฟล์                  | คำอธิบาย                                      |
|-----------------------|-----------------------------------------------|
| PROTOCOL.md           | นิยาม protocol แบบ Hybrid (JSON + Termux)    |
| terminal_relay.sh     | สคริปต์ฝั่ง Terminal (polling + รันคำสั่ง)   |
| ai_examples.md        | ตัวอย่างคำสั่งและวิธีใช้งานฝั่ง AI           |
| README.md             | ไฟล์นี้                                       |

## วิธีใช้แบบรวดเร็ว (POC)

### ฝั่ง AI
1. สร้างข้อความ (JSON หรือ CMD:...)
2. POST ไปที่ `https://aisenseapi.com/services/v1/storage`
3. ได้ `storage_id` มา
4. บอก Terminal ให้ watch id นั้น

### ฝั่ง Terminal
```bash
chmod +x terminal_relay.sh
CURRENT_INBOX=<storage_id> ./terminal_relay.sh
```

### ผลลัพธ์
Terminal จะรันคำสั่งแล้วสร้าง mailbox ใหม่สำหรับคำตอบ  
AI ใช้ Web Access ไปอ่าน storage_id ของคำตอบ

## ข้อจำกัดของเวอร์ชันปัจจุบัน
- ใช้ temporary storage (หมดอายุประมาณ 24 ชั่วโมง)
- ยังไม่มี persistent queue
- ยังไม่มี UI

## แผนต่อไป (เมื่อมี GitHub Token)
1. ย้ายไปใช้ GitHub Gist / Repository เป็น mailbox ถาวร
2. สร้าง HTML Web App
3. Deploy บน Render
4. เพิ่ม UI ดู log, status, request/response
5. รองรับการรัน Python และ automation ที่ซับซ้อนกว่านี้

## Protocol สรุปสั้น ๆ
- AI ส่ง: `CMD:คำสั่ง` หรือ JSON ที่มี `"cmd": "..."`
- Terminal ตอบ: JSON ที่มี `"status": "done"` และ `"result": "..."`
- ใช้ `id` เพื่อกันซ้ำ
