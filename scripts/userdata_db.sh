#!/bin/bash
set -e

apt update -y
DEBIAN_FRONTEND=noninteractive apt install -y postgresql postgresql-contrib

systemctl enable postgresql
systemctl start postgresql

# create DB and user
sudo -u postgres psql -c "CREATE USER ${db_user} WITH PASSWORD '${db_pass}';" || true
sudo -u postgres psql -c "CREATE DATABASE ${db_name} OWNER ${db_user};" || true

# listen on all interfaces (private VPC)
PG_CONF=\$(ls /etc/postgresql/*/main/postgresql.conf | head -n1)
PG_HBA=\$(ls /etc/postgresql/*/main/pg_hba.conf | head -n1)
sed -i \"s/#listen_addresses = 'localhost'/listen_addresses = '*'/g\" \"\$PG_CONF\"
echo \"host    all             all             10.0.0.0/24            md5\" >> \"\$PG_HBA\"
systemctl restart postgresql
