# ตัวอย่างการใช้งานฝั่ง AI

## วิธีส่งคำสั่ง (ใช้ Web Access / curl / open_page)

### 1. ส่งแบบสั้น (Termux style)
สร้าง mailbox ด้วย payload:
```json
{"message":"CMD:ls -la && echo hello && whoami","type":"cmd"}
```

หรือสั้นสุด:
```
CMD:ls -la && date
```

### 2. ส่งแบบ JSON เต็ม
```json
{
  "id": "test-001",
  "type": "cmd",
  "cmd": "ls -la && echo 'Hello from AI' && uname -a",
  "timeout": 20,
  "from": "ai"
}
```

## คำสั่งที่ใช้บ่อย (คัดลอกไปใช้ได้เลย)

```
CMD:echo "Hello from AI Relay" && date && whoami && pwd
```

```
CMD:uname -a && cat /etc/os-release | head -5
```

```
CMD:curl -s ifconfig.me && echo && curl -s https://httpbin.org/ip
```

```
CMD:ls -la /tmp && df -h | head -5
```

```
CMD:python3 -c "print('Python works!'); import sys; print(sys.version)"
```

## วิธีอ่านผลลัพธ์
หลังจาก Terminal ตอบกลับ จะได้ storage_id ใหม่  
ใช้ Web Access หรือ curl ไปที่:
```
https://aisenseapi.com/services/v1/storage/<storage_id ที่ Terminal ส่งกลับ>
```

## ตัวอย่างผลลัพธ์ที่คาดหวัง
```json
{
  "id": "test-001",
  "type": "reply",
  "status": "done",
  "result": "Hello from AI Relay\nTue Sep 29 ...\nuser\n/home/...",
  "from": "terminal"
}
```
