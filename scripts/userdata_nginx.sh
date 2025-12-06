#!/bin/bash
set -e

apt update -y
apt install -y nginx

cat > /etc/nginx/sites-available/default <<EOF
upstream frontend_cluster {
    server ${front1_ip}:3000;
    server ${front2_ip}:3000;
}

server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://frontend_cluster;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    location /health {
        return 200 'ok';
    }
}
EOF

nginx -t && systemctl restart nginx
systemctl enable nginx

