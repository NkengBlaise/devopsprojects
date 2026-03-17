#!/bin/bash
set -euo pipefail

# Legacy all-in-one backend provisioning script.
# This provisions Memcached, RabbitMQ, and MariaDB on a single VM.
# Prefer the dedicated scripts (memcache.sh, rabbitmq.sh, mysql.sh)
# when you want one service per VM.

DATABASE_PASS='admin123'
APP_DB='accounts'
APP_USER='admin'
REPO_DIR='/tmp/vprofile-project'

sudo dnf update -y
sudo dnf install -y git zip unzip memcached mariadb-server firewalld curl gnupg2 socat logrotate

# RabbitMQ repositories and keys
sudo rpm --import 'https://github.com/rabbitmq/signing-keys/releases/download/3.0/rabbitmq-release-signing-key.asc'
sudo rpm --import 'https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-erlang.E495BB49CC4BBE5B.key'
sudo rpm --import 'https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-server.9F4587F226208342.key'

sudo tee /etc/yum.repos.d/rabbitmq.repo > /dev/null <<'EOREPO'
[modern-erlang]
name=modern-erlang-el9
baseurl=https://yum1.rabbitmq.com/erlang/el/9/$basearch
        https://yum2.rabbitmq.com/erlang/el/9/$basearch
repo_gpgcheck=1
enabled=1
gpgkey=https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-erlang.E495BB49CC4BBE5B.key
gpgcheck=1
sslverify=1

[modern-erlang-noarch]
name=modern-erlang-el9-noarch
baseurl=https://yum1.rabbitmq.com/erlang/el/9/noarch
        https://yum2.rabbitmq.com/erlang/el/9/noarch
repo_gpgcheck=1
enabled=1
gpgkey=https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-erlang.E495BB49CC4BBE5B.key
gpgcheck=1
sslverify=1

[rabbitmq-el9]
name=rabbitmq-el9
baseurl=https://yum1.rabbitmq.com/rabbitmq/el/9/$basearch
        https://yum2.rabbitmq.com/rabbitmq/el/9/$basearch
repo_gpgcheck=1
enabled=1
gpgkey=https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-server.9F4587F226208342.key
gpgcheck=1
sslverify=1

[rabbitmq-el9-noarch]
name=rabbitmq-el9-noarch
baseurl=https://yum1.rabbitmq.com/rabbitmq/el/9/noarch
        https://yum2.rabbitmq.com/rabbitmq/el/9/noarch
repo_gpgcheck=1
enabled=1
gpgkey=https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-server.9F4587F226208342.key
gpgcheck=1
sslverify=1
EOREPO

sudo dnf clean all
sudo dnf makecache
sudo dnf install -y erlang rabbitmq-server

# Memcached
sudo sed -i 's/^OPTIONS=.*/OPTIONS="-l 0.0.0.0,::"/' /etc/sysconfig/memcached
sudo systemctl enable --now memcached

# RabbitMQ
sudo systemctl enable --now rabbitmq-server
sudo rabbitmqctl add_user rabbit bunny || true
sudo rabbitmqctl set_user_tags rabbit administrator
sudo rabbitmqctl set_permissions -p / rabbit '.*' '.*' '.*'

# MariaDB
sudo systemctl enable --now mariadb
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

sudo systemctl enable --now firewalld
sudo firewall-cmd --permanent --add-port=11211/tcp
sudo firewall-cmd --permanent --add-port=11111/udp
sudo firewall-cmd --permanent --add-port=3306/tcp
sudo firewall-cmd --permanent --add-port=5672/tcp
sudo firewall-cmd --permanent --add-port=15672/tcp
sudo firewall-cmd --reload

sudo systemctl restart memcached
sudo systemctl restart rabbitmq-server
sudo systemctl restart mariadb
