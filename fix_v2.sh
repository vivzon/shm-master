#!/bin/bash

# Load Config
source /etc/shm/config.sh
MAIN_DOMAIN="vivzon.cloud"

echo "Fixing SHM Panel Configurations..."

# 1. FIX DIRECTORY PERMISSIONS
# Nginx needs execution (+x) permission on all parent folders to reach the files
chmod +x /var/www
chmod +x /var/www/apps
chmod +x /var/www/panel
chown -R www-data:www-data /var/www/apps
chown -R www-data:www-data /var/www/panel

# 2. CREATE MISSING INDEX/LOGIN FILES
# Move login.php to index.php so admin.vivzon.cloud works immediately
if [ -f /var/www/panel/public_html/login.php ]; then
    mv /var/www/panel/public_html/login.php /var/www/panel/public_html/index.php
fi

# Create a basic client index if it doesn't exist
mkdir -p /var/www/panel/public_html/client
cat > /var/www/panel/public_html/client/index.php << 'PHP'
<?php session_start(); echo "<h1>Client Dashboard</h1><p>Welcome, " . ($_SESSION['client_user'] ?? 'Guest') . "</p>"; ?>
PHP

# 3. RECONFIGURE NGINX VHOSTS (Correcting Roots)
# We will define specific roots for each subdomain to avoid 403s
declare -A roots
roots=( 
    ["vivzon.cloud"]="/var/www/panel/public_html"
    ["admin.vivzon.cloud"]="/var/www/panel/public_html"
    ["client.vivzon.cloud"]="/var/www/panel/public_html/client"
    ["phpmyadmin.vivzon.cloud"]="/var/www/apps/phpmyadmin"
    ["webmail.vivzon.cloud"]="/usr/share/roundcube"
    ["filemanager.vivzon.cloud"]="/var/www/apps/filemanager"
)

for sub in "${!roots[@]}"; do
    cat > /etc/nginx/sites-available/$sub << EOF
server {
    listen 80;
    server_name $sub;
    root ${roots[$sub]};
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF
    # Ensure link exists
    ln -sf /etc/nginx/sites-available/$sub /etc/nginx/sites-enabled/
done

# 4. FIX ROUNDCUBE (Webmail) CONFIG
# Roundcube often needs specific permissions
chown -R www-data:www-data /var/lib/roundcube/temp /var/lib/roundcube/logs

# 5. RESTART SERVICES
echo "Restarting Nginx and PHP..."
systemctl restart nginx
systemctl restart php8.2-fpm

echo "DONE. Please refresh your browser."
