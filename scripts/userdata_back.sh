#!/bin/bash
set -e

apt update -y
apt upgrade -y
apt install -y docker.io curl git nginx

systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu

# docker-compose (standalone)
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# build structure
mkdir -p /opt/Petcolumbia-back
cd /opt/Petcolumbia-back

# create .env for backend service
cat > .env <<EOF
SPRING_PROFILES_ACTIVE=prod
DB_URL=jdbc:postgresql://${db_private_ip}:5432/${db_name}
DB_USERNAME=${db_user}
DB_PASSWORD=${db_pass}
EOF

# create nginx conf to proxy 8080
mkdir -p Docker/Nginx
cat > Docker/Nginx/nginx.conf <<'EOF'
worker_processes 1;
events { worker_connections 1024; }

http {
  upstream app_up {
    server 127.0.0.1:8080;
  }

  server {
    listen 8080;

    location / {
      proxy_pass http://app_up;
      proxy_set_header Host $host;
      proxy_set_header X-Real-IP $remote_addr;
    }
  }
}
EOF

# create docker-compose (backend + optional redis client not needed)
cat > docker-compose.yml <<EOF
version: '3.8'
services:
  api:
    image: ${backend_image}
    container_name: api-petcolumbia-java
    env_file:
      - .env
    ports:
      - "8080:8080"
    restart: unless-stopped
EOF

# start
/usr/local/bin/docker-compose up -d --remove-orphans

# ensure nginx is running as proxy (nginx installed earlier); restart if needed
systemctl restart nginx || true
chown -R ubuntu:ubuntu /opt/Petcolumbia-back || true

