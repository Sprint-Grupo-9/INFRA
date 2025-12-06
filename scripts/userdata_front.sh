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

# write .env (will be used by the docker-compose in the repo)
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

# ensure nginx has no port conflict: frontend will serve on 3000, we proxy with local nginx to 3000
cat > /etc/nginx/sites-available/default <<'EOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    location /api/ {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
    }
}
EOF

nginx -t && systemctl restart nginx

# create a docker-compose if not present (use the repo's compose if exists)
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
    image: taysonmartins/pet-columbia-front:front-latest
    container_name: frontend-petcolumbia
    volumes:
      - ./build:/usr/share/nginx/html:ro
    expose:
      - "80"
    restart: unless-stopped
    depends_on:
      - rabbitmq

  backend_local:
    image: taysonmartins/pet-columbia-front:backend-latest
    container_name: backend-petcolumbia-local
    env_file:
      - .env
    expose:
      - "3000"
    restart: unless-stopped
    depends_on:
      - rabbitmq
EOF

  /usr/local/bin/docker-compose up -d --remove-orphans
fi

chown -R ubuntu:ubuntu /opt/Petcolumbia || true
