#!/bin/bash
sudo apt update -y
sudo apt install -y nginx
echo "yo this is nginx" > /var/www/html/index.html
sudo systemctl enable nginx
sudo systemctl start nginx