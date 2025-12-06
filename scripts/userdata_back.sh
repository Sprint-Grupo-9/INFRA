#!/bin/bash
set -e

apt update -y
apt upgrade -y
apt install -y docker.io curl git

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

# create docker-compose (backend runs on port 8080)
cat > docker-compose.yml <<'EOF'
version: '3.8'
services:
  api:
    image: samuelpazz/api-pet-columbia:2.1.3
    container_name: api-petcolumbia-java
    env_file:
      - .env
    ports:
      - "8080:8080"
    restart: unless-stopped
    environment:
      - SPRING_JPA_HIBERNATE_DDL_AUTO=update
      - SPRING_JPA_PROPERTIES_HIBERNATE_DIALECT=org.hibernate.dialect.PostgreSQLDialect
EOF

# start services
/usr/local/bin/docker-compose up -d --remove-orphans

chown -R ubuntu:ubuntu /opt/Petcolumbia-back || true

