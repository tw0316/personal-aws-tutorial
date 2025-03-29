#! /bin/bash

#INSTALL GIT AND NGINX
dnf install git nginx -y

#INSTALL NODE v20
curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
dnf install nodejs -y
npm -v
node -v
npm install -g pm2
pm2 --version

#MOUNT EFS
dnf install amazon-efs-utils -y
mkdir -p /mnt/efs/uploads
mount -t efs fs-03cf8a465bda57902:/ /mnt/efs/uploads

#CLONE CODE
mkdir -p /home/ec2-user/apps
cd /home/ec2-user/apps/
git clone https://github.com/tw0316/personal-aws-tutorial.git

#SETUP BACKEND
cd /home/ec2-user/apps/personal-aws-tutorial/efs-ec2-asg/backend
npm install
pm2 start server.js --name "backend"

#SETUP FRONTEND
cd /home/ec2-user/apps/personal-aws-tutorial/efs-ec2-asg/citizenscoop
npm install
npm run build
pm2 start npm --name "frontend" -- run start

#CONFIGURE NGINX AS A REVERSE PROXY
sudo tee /etc/nginx/nginx.conf > /dev/null <<EOL
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;
events {
    worker_connections 1024;
}
http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    sendfile on;
    keepalive_timeout 65;
    server {
        listen 80;
        location /api/ {
            proxy_pass http://localhost:4000/;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host \$host;
            proxy_cache_bypass \$http_upgrade;
        }
 
        location / {
            proxy_pass http://localhost:3000/;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host \$host;
            proxy_cache_bypass \$http_upgrade;
        }
    }
}
EOL
 
# Restart Nginx
sudo systemctl restart nginx
sudo systemctl enable nginx