#!/bin/bash

# Logging
exec > >(tee /var/log/userdata.log)
exec 2>&1

echo "Starting frontend installation..."

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

# PASSO 2: Atualizar Sistema
echo "Updating system..."
sudo apt update -y
sudo apt upgrade -y
sudo apt install docker-compose -y
sudo apt install -y git curl ca-certificates gnupg lsb-release

# PASSO 3: Instalar Docker (usando repositório oficial)
echo "Installing Docker from official repository..."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update -y
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "Configuring Docker..."
sudo systemctl start docker
sudo systemctl enable docker

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

# Add ubuntu user to docker group
sudo usermod -aG docker ubuntu
newgrp docker << EOF
true
EOF

# Verify docker is accessible
echo "Verifying Docker access..."
sudo docker ps || {
  echo "Docker still not accessible after waiting"
  exit 1
}

# PASSO 4: Instalar Docker Compose Standalone (additional)
echo "Installing Docker Compose standalone..."
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# PASSO 1 (DEPLOY): Criar Diretório
echo "Creating workspace directory..."
mkdir -p /home/ubuntu/Petcolumbia
cd /home/ubuntu/Petcolumbia || {
  echo "Failed to enter workspace directory"
  exit 1
}
echo "Workspace directory: $(pwd)"

# PASSO 2 (DEPLOY): Clonar Repositório
echo "Cloning repository..."
if [ ! -d "FRONT-REFACTOR" ]; then
  git clone https://github.com/Sprint-Grupo-9/FRONT-REFACTOR.git || {
    echo "Git clone failed, waiting and retrying..."
    sleep 10
    git clone https://github.com/Sprint-Grupo-9/FRONT-REFACTOR.git || {
      echo "Git clone failed twice, exiting"
      exit 1
    }
  }
fi

# Verify FRONT-REFACTOR exists
if [ ! -d "FRONT-REFACTOR" ]; then
  echo "FRONT-REFACTOR directory does not exist after clone attempt"
  ls -la
  exit 1
fi

cd FRONT-REFACTOR/my-react-app || {
  echo "Failed to enter FRONT-REFACTOR/my-react-app directory"
  ls -la ..
  exit 1
}

echo "Successfully changed to: $(pwd)"
echo "Files in current directory:"
ls -la | head -20

# PASSO 3 (DEPLOY): Configurar .env
echo "Creating .env file..."
cat > .env <<'ENVEOF'
NODE_ENV=production
PORT=3000
HOST=0.0.0.0
RABBITMQ_URL=amqp://admin:admin@rabbitmq:5672
RABBITMQ_QUEUE=chatbot_queue
GROQ_API_KEY=${groq_api_key}
CORS_ORIGIN=http://${domain}
BACKEND_1=http://${back1_ip}:8080
BACKEND_2=http://${back2_ip}:8080
REDIS_PASSWORD=${redis_password}
ENVEOF

# PASSO 4 (DEPLOY): Subir Aplicação
echo "Starting Docker Compose..."
echo "Current working directory: $(pwd)"

# Check if docker-compose.yml exists
if [ ! -f "docker-compose.yml" ]; then
  echo "ERROR: docker-compose.yml not found in $(pwd)"
  ls -la
  exit 1
fi

# Final verification that docker is ready
echo "Final Docker verification..."
for i in {1..10}; do
  if sudo docker ps > /dev/null 2>&1; then
    echo "Docker is ready, proceeding with docker-compose"
    break
  fi
  echo "Docker still not responding, waiting..."
  sleep 2
done

echo "Found docker-compose.yml. Starting containers..."
sudo /usr/local/bin/docker-compose up -d

# Wait a bit for containers to start
sleep 5

# PASSO 5 (DEPLOY): Verificar Status
echo "Checking Docker containers status..."
sudo /usr/local/bin/docker-compose ps
echo ""
echo "Container logs (last 30 lines from each):"
sudo /usr/local/bin/docker-compose logs --tail=30

echo ""
echo "Frontend installation completed!"
