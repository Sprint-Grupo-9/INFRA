#!/bin/bash
set -e

# === system update / deps ===
apt update -y
apt upgrade -y
apt install -y nginx docker.io git curl

systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu

# docker compose standalone
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# workspace
mkdir -p /opt/Petcolumbia
cd /opt/Petcolumbia

# clone UX repo
if [ ! -d "FRONT-REFACTOR" ]; then
  git clone https://github.com/Sprint-Grupo-9/FRONT-REFACTOR.git
fi
cd FRONT-REFACTOR/my-react-app || exit 0

# ensure docker-compose can use the env vars
cat > .env <<EOF
NODE_ENV=production
PORT=3000
HOST=0.0.0.0
RABBITMQ_URL=amqp://admin:admin@rabbitmq:5672
RABBITMQ_QUEUE=chatbot_queue
GROQ_API_KEY=${groq_api_key}
CORS_ORIGIN=http://${domain}
# Backend routing (two Java backends)
BACKEND_1=http://${back1_ip}:8080
BACKEND_2=http://${back2_ip}:8080
REDIS_PASSWORD=${redis_password}
EOF

# remove local nginx (LB will proxy instead)
systemctl stop nginx || true
systemctl disable nginx || true

# create docker-compose if not present
if [ -f docker-compose.yml ]; then
  /usr/local/bin/docker-compose up -d --remove-orphans
else
  cat > docker-compose.yml <<'EOF'
version: '3.8'
services:
  rabbitmq:
    image: rabbitmq:3-management-alpine
    container_name: rabbitmq-petcolumbia
    ports:
      - "5672:5672"
      - "15672:15672"
    environment:
      - RABBITMQ_DEFAULT_USER=admin
      - RABBITMQ_DEFAULT_PASS=admin
    restart: unless-stopped

  frontend:
    image: node:18-alpine
    container_name: frontend-petcolumbia
    working_dir: /app
    volumes:
      - .:/app
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - PORT=3000
      - HOST=0.0.0.0
    restart: unless-stopped
    depends_on:
      - rabbitmq
    entrypoint: sh -c "npm install && npm run build && npm start"
EOF

  /usr/local/bin/docker-compose up -d --remove-orphans
fi

chown -R ubuntu:ubuntu /opt/Petcolumbia || true
