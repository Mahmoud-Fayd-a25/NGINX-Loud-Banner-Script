#!/bin/bash

ips=("192.168.1.4" "192.168.1.5" "192.168.1.6")

# Set hostnames for remote VMs

ssh root@"${ips[0]}" hostnamectl set-hostname nginxlb
ssh root@"${ips[1]}" hostnamectl set-hostname backend1
ssh root@"${ips[2]}" hostnamectl set-hostname backend2

# Install and configure NGINX on nginxlb
ssh "${ips[0]}" sudo yum install -y nginx
ssh "${ips[0]}" sudo systemctl enable --now nginx
ssh "${ips[0]}" sudo firewall-cmd --permanent --add-service={http,https}
ssh "${ips[0]}" sudo firewall-cmd --reload

# configure Apache HTTP servers on backend VMs via SSH

for vm in "${ips[@]}"; do
    ssh $vm "sudo yum install -y httpd"
    ssh $vm "sudo systemctl enable --now httpd"
    ssh $vm "sudo firewall-cmd --permanent --add-service={http,https}"
    ssh $vm "sudo firewall-cmd --reload"
done

# Configure NGINX for load balancing
ssh "${ips[0]}" sudo bash -c 'cat <<EOL > /etc/nginx/nginx.conf
http {
    upstream itiservers {
        server 192.168.1.5;
        server 192.168.1.6;
    }

    server {
        listen 80;
        server_name nginxlb;

        location / {
            proxy_pass http://itiservers;
        }
    }
}
EOL'

# Restart NGINX
ssh "${ips[0]}" sudo systemctl restart nginx

# Enable SELinux boolean httpd_can_network_connect
ssh "${ips[0]}" sudo setsebool -P httpd_can_network_connect on

# Display success message
echo "Load balancer Installation and configuration completed successfully."
