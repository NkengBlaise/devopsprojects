#!/bin/bash
set -euo pipefail

sudo apt-get update -y
sudo apt-get install -y nginx

sudo tee /etc/nginx/sites-available/vproapp > /dev/null <<'EONGINX'
upstream vproapp {
    server app01:8080;
}

server {
    listen 80 default_server;
    server_name _;

    location / {
        proxy_pass http://vproapp;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EONGINX

sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -sf /etc/nginx/sites-available/vproapp /etc/nginx/sites-enabled/vproapp
sudo nginx -t
sudo systemctl enable --now nginx
sudo systemctl restart nginx
