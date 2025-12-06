#!/bin/bash
set -e

apt update -y
apt install -y nginx

cat > /etc/nginx/sites-available/default <<'EOF'
upstream frontend_cluster {
    server ${front1_ip}:3000 weight=1 max_fails=3 fail_timeout=30s;
    server ${front2_ip}:3000 weight=1 max_fails=3 fail_timeout=30s;
}

server {
    listen 80 default_server;
    server_name _;

    # Health check endpoint
    location /health {
        return 200 'OK';
        add_header Content-Type text/plain;
    }

    # Main proxy to frontend cluster
    location / {
        proxy_pass http://frontend_cluster;
        proxy_http_version 1.1;
        
        # Headers for proper proxying
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Connection "upgrade";
        proxy_set_header Upgrade $http_upgrade;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Buffering
        proxy_buffering off;
    }
}
EOF

nginx -t
systemctl restart nginx
systemctl enable nginx

