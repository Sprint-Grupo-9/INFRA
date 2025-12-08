#!/bin/bash

# Logging
exec > >(tee /var/log/userdata.log)
exec 2>&1

echo "Starting nginx LB installation..."

# Setup SSH key for accessing private instances
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Add SSH public key to authorized_keys if provided
if [ -n "${ssh_public_key}" ]; then
  echo "Setting up SSH public key..."
  touch ~/.ssh/authorized_keys
  chmod 600 ~/.ssh/authorized_keys
  echo "${ssh_public_key}" >> ~/.ssh/authorized_keys
fi

echo "Updating system and installing nginx..."
sudo apt update -y
sudo apt install -y nginx

sudo cat > /etc/nginx/sites-available/default <<'EOF'
upstream frontend_cluster {
    server ${front1_ip}:80 weight=1 max_fails=3 fail_timeout=30s;
    server ${front2_ip}:80 weight=1 max_fails=3 fail_timeout=30s;
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

sudo nginx -t
sudo systemctl restart nginx
sudo systemctl enable nginx

# Wait for frontends to be ready (with retries)
echo "Waiting for frontends to be ready..."
for i in {1..60}; do
  if curl -sf http://${front1_ip}:80 > /dev/null 2>&1 || curl -sf http://${front2_ip}:80 > /dev/null 2>&1; then
    echo "Frontend is ready!"
    break
  fi
  echo "Attempt $i/60: Frontends not ready yet, retrying in 10s..."
  sleep 10
done

echo "Nginx configuration complete"

