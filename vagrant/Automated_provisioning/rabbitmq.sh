#!/bin/bash
set -euo pipefail

sudo dnf update -y
sudo dnf install -y curl gnupg2 socat logrotate firewalld

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

sudo systemctl enable --now rabbitmq-server
sudo rabbitmq-plugins enable rabbitmq_management

sudo systemctl enable --now firewalld
sudo firewall-cmd --permanent --add-port=5672/tcp
sudo firewall-cmd --permanent --add-port=15672/tcp
sudo firewall-cmd --reload

sudo rabbitmqctl add_user test test || true
sudo rabbitmqctl set_user_tags test administrator
sudo rabbitmqctl set_permissions -p / test '.*' '.*' '.*'

sudo systemctl restart rabbitmq-server
sudo systemctl status rabbitmq-server --no-pager
