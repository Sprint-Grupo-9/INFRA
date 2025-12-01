#!/bin/bash
set -e

# Atualizar sistema
apt update -y
apt upgrade -y

# Instalar nginx
apt install -y nginx

# Criar configuração Nginx para balanceamento
cat <<EOF >/etc/nginx/sites-available/default
upstream frontend_cluster {
    server 10.0.0.93:80;   # front 1
    server 10.0.0.120:80;   # front 2
}

upstream backend_cluster {
    server 10.0.0.166:8080;   # back 1
    server 10.0.0.191:8080;   # back 2
}

server {
    listen 80;
    server_name _;

    # Health-check
    location /health {
        return 200 "OK\n";
        add_header Content-Type text/plain;
    }

    # Proxy reverso p/ FRONT
    location / {
        proxy_pass http://frontend_cluster;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_http_version 1.1;
        proxy_set_header Connection "";

        proxy_read_timeout 90;
    }

    location /api/ {
        proxy_pass http://backend_cluster;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_http_version 1.1;
        proxy_set_header Connection "";

        proxy_read_timeout 90;
    }

}
EOF

# Testar e reiniciar nginx
nginx -t && systemctl restart nginx

# Habilitar no boot
systemctl enable nginx
