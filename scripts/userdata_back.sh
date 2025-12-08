#!/bin/bash

# Logging
exec > >(tee /var/log/userdata.log)
exec 2>&1

echo "Starting backend installation..."

# Setup SSH key for accessing from other instances
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Add SSH public key to authorized_keys if provided
if [ -n "${ssh_public_key}" ]; then
  echo "Setting up SSH public key..."
  touch ~/.ssh/authorized_keys
  chmod 600 ~/.ssh/authorized_keys
  echo "${ssh_public_key}" >> ~/.ssh/authorized_keys
fi

echo "Updating system and installing Docker..."
sudo apt update -y
sudo apt upgrade -y
sudo apt install -y git curl ca-certificates gnupg lsb-release
sudo apt install docker-compose -y

# Install Docker from official repository
echo "Installing Docker from official repository..."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update -y
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "Configuring Docker..."
sudo systemctl enable docker
sudo systemctl start docker

# Wait for Docker daemon to be ready
echo "Waiting for Docker daemon to be ready..."
for i in {1..30}; do
  if sudo docker info > /dev/null 2>&1; then
    echo "Docker daemon is ready!"
    break
  fi
  echo "Attempt $i/30: Docker daemon not ready, waiting..."
  sleep 2
done

sudo usermod -aG docker ubuntu

# Verify docker is accessible
echo "Verifying Docker access..."
sudo docker ps || {
  echo "Docker still not accessible after waiting"
  exit 1
}
echo "Installing Docker Compose standalone..."
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# build structure
sudo mkdir -p /opt/Petcolumbia-back
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
echo "Starting Docker Compose for backend..."
sudo /usr/local/bin/docker-compose up -d --remove-orphans || {
  echo "Docker Compose failed, checking logs..."
  sudo /usr/local/bin/docker-compose logs
  exit 1
}

echo "Backend services started successfully!"
sudo /usr/local/bin/docker-compose ps

sudo chown -R ubuntu:ubuntu /opt/Petcolumbia-back || true

