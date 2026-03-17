#!/bin/bash
set -euo pipefail

DATABASE_PASS='admin123'
APP_DB='accounts'
APP_USER='admin'
REPO_DIR='/tmp/vprofile-project'

sudo dnf update -y
sudo dnf install -y git zip unzip mariadb-server firewalld

sudo systemctl enable --now mariadb
sudo systemctl enable --now firewalld

# Allow remote connections for the application tier
sudo tee /etc/my.cnf.d/vprofile.cnf > /dev/null <<EOCNF
[mysqld]
bind-address=0.0.0.0
EOCNF
sudo systemctl restart mariadb

if [ ! -d "$REPO_DIR" ]; then
  git clone -b main https://github.com/hkhcoder/vprofile-project.git "$REPO_DIR"
fi

sudo mysql <<EOSQL
CREATE DATABASE IF NOT EXISTS ${APP_DB};
CREATE USER IF NOT EXISTS '${APP_USER}'@'localhost' IDENTIFIED BY '${DATABASE_PASS}';
CREATE USER IF NOT EXISTS '${APP_USER}'@'%' IDENTIFIED BY '${DATABASE_PASS}';
GRANT ALL PRIVILEGES ON ${APP_DB}.* TO '${APP_USER}'@'localhost';
GRANT ALL PRIVILEGES ON ${APP_DB}.* TO '${APP_USER}'@'%';
FLUSH PRIVILEGES;
EOSQL

sudo mysql "${APP_DB}" < "${REPO_DIR}/src/main/resources/db_backup.sql"

sudo firewall-cmd --permanent --add-port=3306/tcp
sudo firewall-cmd --reload

sudo systemctl restart mariadb
sudo systemctl status mariadb --no-pager
