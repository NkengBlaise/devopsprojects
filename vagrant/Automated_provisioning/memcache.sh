#!/bin/bash
set -euo pipefail

sudo dnf update -y
sudo dnf install -y memcached firewalld

sudo sed -i 's/^OPTIONS=.*/OPTIONS="-l 0.0.0.0,::"/' /etc/sysconfig/memcached

sudo systemctl enable --now memcached
sudo systemctl enable --now firewalld

sudo firewall-cmd --permanent --add-port=11211/tcp
sudo firewall-cmd --permanent --add-port=11111/udp
sudo firewall-cmd --reload

sudo systemctl restart memcached
sudo systemctl status memcached --no-pager
