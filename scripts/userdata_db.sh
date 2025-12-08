#!/bin/bash

# Logging
exec > >(tee /var/log/userdata.log)
exec 2>&1

echo "Starting PostgreSQL database installation..."

# Setup SSH key for accessing database instance
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Add SSH public key to authorized_keys if provided
if [ -n "${ssh_public_key}" ]; then
  echo "Setting up SSH public key..."
  touch ~/.ssh/authorized_keys
  chmod 600 ~/.ssh/authorized_keys
  echo "${ssh_public_key}" >> ~/.ssh/authorized_keys
fi

echo "Updating system and installing PostgreSQL..."
sudo apt update -y
sudo DEBIAN_FRONTEND=noninteractive apt install -y postgresql postgresql-contrib

echo "Configuring PostgreSQL..."
sudo systemctl enable postgresql
sudo systemctl start postgresql

# create DB and user
sudo -u postgres psql -c "CREATE USER ${db_user} WITH PASSWORD '${db_pass}';" || true
sudo -u postgres psql -c "CREATE DATABASE ${db_name} OWNER ${db_user};" || true

# listen on all interfaces (private VPC)
PG_CONF=$(sudo ls /etc/postgresql/*/main/postgresql.conf | head -n1)
PG_HBA=$(sudo ls /etc/postgresql/*/main/pg_hba.conf | head -n1)
sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" "$PG_CONF"
echo "host    all             all             10.0.0.0/24            md5" | sudo tee -a "$PG_HBA"
sudo systemctl restart postgresql
