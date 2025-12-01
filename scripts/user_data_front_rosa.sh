#!/bin/bash

apt-get update -y
apt-get install -y git curl docker.io

systemctl enable --now docker
usermod -aG docker ubuntu || true

curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

APP_DIR="/home/ubuntu/PetFrontRosa"
REPO="https://github.com/Sprint-Grupo-9/FRONT-REFACTOR.git"
SUBPATH="FRONT-REFACTOR/my-react-app"

mkdir -p "$APP_DIR"
cd "$APP_DIR"

git clone "$REPO"
cd "$SUBPATH"

cat > .env <<EOF
NODE_ENV=production
PORT=3000
HOST=0.0.0.0
RABBITMQ_URL=amqp://admin:admin@rabbitmq:5672
RABBITMQ_QUEUE=chatbot_queue
GROQ_API_KEY=*
CORS_ORIGIN=*
EOF

cat > nginx.conf <<EOF
server {
    listen 80;

    location / {
        try_files \$uri /index.html;
    }

    location /api/ {
        proxy_pass http://backend_pool;
    }
}

upstream backend_pool {
    server 10.0.0.166:8080;
    server 10.0.0.191:8080;
}
EOF

docker-compose down || true
docker-compose up -d --build

cat > /etc/systemd/system/front.service <<EOF
[Unit]
Description=Front Rosa
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$APP_DIR/$SUBPATH
ExecStart=/usr/local/bin/docker-compose up -d --build
ExecStop=/usr/local/bin/docker-compose down

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now front.service
