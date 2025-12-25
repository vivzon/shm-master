#!/bin/bash

# upgrade_v4.sh - System Hosting Manager Upgrade Script
# This script installs/updates the shm-manage utility

echo "Starting Upgrade v4..."

# Create the directory for configurations if it doesn't exist
mkdir -p /etc/shm

# Writing the management script
echo "Deploying /usr/local/bin/shm-manage..."

cat > /usr/local/bin/shm-manage << 'EOF'
#!/bin/bash
source /etc/shm/config.sh

case "$1" in
    create-account)
        # $2=username, $3=domain, $4=email, $5=pass
        useradd -m -d /var/www/clients/$2 -s /bin/bash $2
        mkdir -p /var/www/clients/$2/{public_html,logs}
        echo "<h1>Welcome to $3</h1>" > /var/www/clients/$2/public_html/index.html
        chown -R $2:$2 /var/www/clients/$2
        
        # PHP Pool
        cat > /etc/php/8.2/fpm/pool.d/$2.conf << PHP
[$2]
user = $2
group = $2
listen = /run/php/php8.2-fpm-$2.sock
listen.owner = www-data
listen.group = www-data
pm = ondemand
pm.max_children = 5
PHP
        systemctl reload php8.2-fpm

        # Nginx Vhost
        cat > /etc/nginx/sites-available/$3 << NGINX
server {
    listen 80;
    server_name $3 www.$3;
    root /var/www/clients/$2/public_html;
    index index.php index.html;
    location ~ \.php$ { include snippets/fastcgi-php.conf; fastcgi_pass unix:/run/php/php8.2-fpm-$2.sock; }
}
NGINX
        ln -sf /etc/nginx/sites-available/$3 /etc/nginx/sites-enabled/
        systemctl reload nginx

        # DB Logic
        mysql -e "INSERT INTO clients (username, email, password) VALUES ('$2', '$4', '$5');" $DB_NAME
        mysql -e "INSERT INTO domains (client_id, domain, document_root) SELECT id, '$3', '/var/www/clients/$2/public_html' FROM clients WHERE username='$2';" $DB_NAME
        ;;

    delete-account)
        # $2=username
        DOMAIN=$(mysql -N -s -e "SELECT domain FROM domains d JOIN clients c ON d.client_id=c.id WHERE c.username='$2'" $DB_NAME)
        rm -f /etc/nginx/sites-enabled/$DOMAIN
        rm -f /etc/nginx/sites-available/$DOMAIN
        rm -f /etc/php/8.2/fpm/pool.d/$2.conf
        userdel -r $2
        mysql -e "DELETE FROM clients WHERE username='$2'" $DB_NAME
        systemctl reload nginx
        systemctl reload php8.2-fpm
        ;;

    get-stats)
        CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}')
        RAM=$(free -m | awk '/Mem:/ {print int($3/$2 * 100)}')
        DISK=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
        UPTIME=$(uptime -p | sed 's/up //')
        echo "$CPU|$RAM|$DISK|$UPTIME"
        ;;

    service-status)
        systemctl is-active $2
        ;;

    service-control)
        # $2=action (restart), $3=service
        systemctl $2 $3
        ;;
esac
EOF

# Set permissions
chmod +x /usr/local/bin/shm-manage

echo "Upgrade v4 completed successfully."
echo "Utility installed at: /usr/local/bin/shm-manage"
