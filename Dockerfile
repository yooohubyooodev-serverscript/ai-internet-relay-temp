# Internet Relay - Dockerfile for Render
FROM python:3.12-slim

WORKDIR /app

# ติดตั้ง dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# คัดลอกโค้ด
COPY . .

# Render จะตั้ง PORT ให้เอง
ENV PORT=10000
EXPOSE 10000

# รันด้วย gunicorn
CMD ["gunicorn", "--bind", "0.0.0.0:10000", "--workers", "1", "--threads", "4", "app:app"]
