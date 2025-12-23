#!/bin/bash

# ==============================================================================
# SHM PANEL v2025 - FULL SUITE AUTO-INSTALLER
# ==============================================================================
# Target: Production Multi-User Shared Hosting
# ==============================================================================

export DEBIAN_FRONTEND=noninteractive

# 1. Configuration & Variables
MAIN_IP=$(hostname -I | awk '{print $1}')
DB_PANEL_PASS=$(openssl rand -base64 18)
MYSQL_ROOT_PASS=$(openssl rand -base64 20)

# Subdomains
DOMAIN_ADMIN="admin.vivzon.cloud"
DOMAIN_CLIENT="client.vivzon.cloud"
DOMAIN_PMA="phpmyadmin.vivzon.cloud"
DOMAIN_MAIL="webmail.vivzon.cloud"
DOMAIN_FILES="filemanager.vivzon.cloud"

# Directories
WEB_ROOT="/var/www/panel"
APPS_DIR="/var/www/apps"

echo "🚀 Starting Installation of SHM Panel on $MAIN_IP..."

# ------------------------------------------------------------------------------
# 2. System Dependencies & Repositories
# ------------------------------------------------------------------------------
apt update && apt upgrade -y
apt install -y software-properties-common curl wget git zip unzip acl quota ufw fail2ban certbot python3-certbot-nginx lsb-release

# Add PHP Repository
add-apt-repository ppa:ondrej/php -y
apt update

# Install Stack (Nginx, MySQL, Multi-PHP, Mail, FTP)
apt install -y nginx mysql-server mysql-client \
    postfix postfix-mysql dovecot-core dovecot-imapd dovecot-mysql dovecot-lmtpd \
    proftpd-basic proftpd-mod-mysql bind9 \
    php8.2-fpm php8.2-mysql php8.2-common php8.2-gd php8.2-mbstring php8.2-xml php8.2-zip php8.2-curl php8.2-bcmath php8.2-intl php8.2-imagick

# ------------------------------------------------------------------------------
# 3. Database & Schema Setup
# ------------------------------------------------------------------------------
echo "init MySQL..."
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASS';"
cat > /root/.my.cnf << EOF
[client]
user=root
password=$MYSQL_ROOT_PASS
EOF
chmod 600 /root/.my.cnf

# Create Databases
mysql -e "CREATE DATABASE shm_panel;"
mysql -e "CREATE USER 'shm_admin'@'localhost' IDENTIFIED BY '$DB_PANEL_PASS';"
mysql -e "GRANT ALL PRIVILEGES ON shm_panel.* TO 'shm_admin'@'localhost';"

# Import Master Schema
mysql shm_panel << EOF
CREATE TABLE packages (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(50), disk_quota_mb INT, max_domains INT, max_dbs INT, max_emails INT);
INSERT INTO packages VALUES (1, 'Starter', 2000, 1, 1, 5), (2, 'Business', 10000, 10, 10, 50), (3, 'Unlimited', 50000, 100, 100, 500);

CREATE TABLE clients (id INT AUTO_INCREMENT PRIMARY KEY, username VARCHAR(32) UNIQUE, email VARCHAR(255), status ENUM('active', 'suspended') DEFAULT 'active', package_id INT DEFAULT 1, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);
CREATE TABLE domains (id INT AUTO_INCREMENT PRIMARY KEY, client_id INT, domain VARCHAR(255) UNIQUE, document_root VARCHAR(255), php_version VARCHAR(5) DEFAULT '8.2', ssl_active BOOLEAN DEFAULT 0, FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE CASCADE);
CREATE TABLE email_accounts (id INT AUTO_INCREMENT PRIMARY KEY, domain_id INT, email VARCHAR(255) UNIQUE, password VARCHAR(255), FOREIGN KEY (domain_id) REFERENCES domains(id) ON DELETE CASCADE);
CREATE TABLE ftp_accounts (id INT AUTO_INCREMENT PRIMARY KEY, client_id INT, userid VARCHAR(32) UNIQUE, passwd VARCHAR(255), homedir VARCHAR(255), uid INT, gid INT, FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE CASCADE);
CREATE TABLE admins (id INT AUTO_INCREMENT PRIMARY KEY, username VARCHAR(50) UNIQUE, password VARCHAR(255));
INSERT INTO admins (username, password) VALUES ('admin', '\$2y\$10\$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi'); -- pass: admin123
EOF

# ------------------------------------------------------------------------------
# 4. Core Management Logic (shm-manage)
# ------------------------------------------------------------------------------
mkdir -p /etc/shm
echo "DB_NAME=\"shm_panel\"" > /etc/shm/config.sh
echo "DB_USER=\"shm_admin\"" >> /etc/shm/config.sh
echo "DB_PASS=\"$DB_PANEL_PASS\"" >> /etc/shm/config.sh

cat > /usr/local/bin/shm-manage << 'EOF'
#!/bin/bash
source /etc/shm/config.sh
case "$1" in
    get-system-stats)
        CPU=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
        RAM_USED=$(free -m | awk '/Mem:/ {print $3}'); RAM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
        DISK_USED=$(df -h / | awk 'NR==2 {print $3}' | sed 's/G//'); DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}' | sed 's/G//')
        LOAD=$(uptime | awk -F'load average:' '{ print $2 }' | cut -d, -f1 | xargs)
        UPTIME=$(uptime -p | sed 's/up //'); OS=$(lsb_release -ds); KERNEL=$(uname -r); DISK_PERC=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
        echo "$CPU|$RAM_USED|$RAM_TOTAL|$DISK_USED|$DISK_TOTAL|$LOAD|$UPTIME|$OS|$KERNEL|$DISK_PERC" ;;
    check-services)
        echo "$(systemctl is-active nginx)|$(systemctl is-active mysql)|$(systemctl is-active php8.2-fpm)|$(systemctl is-active postfix)" ;;
    create-client)
        useradd -m -d /var/www/clients/$2 -s /bin/bash $2
        mysql -e "INSERT INTO clients (username, email) VALUES ('$2', '$3');" $DB_NAME
        mkdir -p /var/www/clients/$2/{logs,tmp,mail} && chown -R $2:$2 /var/www/clients/$2
        cat > /etc/php/8.2/fpm/pool.d/$2.conf << PHP
[$2]
user = $2; group = $2; listen = /run/php/php8.2-fpm-$2.sock; listen.owner = www-data; listen.group = www-data; pm = ondemand; pm.max_children = 10
php_admin_value[open_basedir] = /var/www/clients/$2:/tmp
PHP
        systemctl reload php8.2-fpm ;;
    add-domain)
        CLIENT=$2; DOM=$3; ROOT="/var/www/clients/$CLIENT/$DOM"; mkdir -p $ROOT
        mysql -e "INSERT INTO domains (client_id, domain, document_root) SELECT id, '$DOM', '$ROOT' FROM clients WHERE username='$CLIENT';" $DB_NAME
        cat > /etc/nginx/sites-available/$DOM << NGINX
server { listen 80; server_name $DOM www.$DOM; root $ROOT; index index.php; location ~ \.php$ { include snippets/fastcgi-php.conf; fastcgi_pass unix:/run/php/php8.2-fpm-$CLIENT.sock; } }
NGINX
        ln -s /etc/nginx/sites-available/$DOM /etc/nginx/sites-enabled/ && systemctl reload nginx ;;
    get-disk-usage) du -ms /var/www/clients/$2 | awk '{print $1}' ;;
    check-limit) echo "OK" ;; # Simplified for installer
esac
EOF
chmod +x /usr/local/bin/shm-manage

# ------------------------------------------------------------------------------
# 5. External Web Apps (Roundcube, PMA, TinyFileManager)
# ------------------------------------------------------------------------------
mkdir -p $APPS_DIR/{roundcube,phpmyadmin,filemanager}

# TinyFileManager
wget -q -O $APPS_DIR/filemanager/tfm_core.php https://raw.githubusercontent.com/prasathmani/tinyfilemanager/master/tinyfilemanager.php

# phpMyAdmin
wget -q https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.tar.gz
tar -xzf phpMyAdmin-latest-all-languages.tar.gz -C $APPS_DIR/phpmyadmin --strip-components=1
rm phpMyAdmin-latest-all-languages.tar.gz

# Roundcube
wget -q https://github.com/roundcube/roundcubemail/releases/download/1.6.2/roundcubemail-1.6.2-complete.tar.gz
tar -xzf roundcubemail-1.6.2-complete.tar.gz -C $APPS_DIR/roundcube --strip-components=1
rm roundcubemail-1.6.2-complete.tar.gz

# ------------------------------------------------------------------------------
# 6. Nginx Virtual Hosts for Vivzon Subdomains
# ------------------------------------------------------------------------------
VHOSTS=($DOMAIN_ADMIN $DOMAIN_CLIENT $DOMAIN_PMA $DOMAIN_MAIL $DOMAIN_FILES)
ROOTS=("$WEB_ROOT/admin" "$WEB_ROOT/client" "$APPS_DIR/phpmyadmin" "$APPS_DIR/roundcube" "$APPS_DIR/filemanager")

for i in "${!VHOSTS[@]}"; do
    cat > /etc/nginx/sites-available/${VHOSTS[$i]} << EOF
server {
    listen 80;
    server_name ${VHOSTS[$i]};
    root ${ROOTS[$i]};
    index index.php index.html;
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
    }
}
EOF
    ln -sf /etc/nginx/sites-available/${VHOSTS[$i]} /etc/nginx/sites-enabled/
done

# ------------------------------------------------------------------------------
# 7. Deployment of Panel PHP Files
# ------------------------------------------------------------------------------
mkdir -p $WEB_ROOT/{admin,client}

# PHP Config Link
cat > $WEB_ROOT/config.php << EOF
<?php
define('DB_HOST', 'localhost'); define('DB_NAME', 'shm_panel'); define('DB_USER', 'shm_admin'); define('DB_PASS', '$DB_PANEL_PASS');
try { \$pdo = new PDO("mysql:host=".DB_HOST.";dbname=".DB_NAME, DB_USER, DB_PASS); } catch(Exception \$e) { die(\$e->getMessage()); }
function system_call(\$cmd) { return shell_exec("sudo /usr/local/bin/shm-manage " . \$cmd); }
EOF

# Deploy Admin v22 (Simplified snippet)
cat > $WEB_ROOT/admin/index.php << 'EOF'
<?php include "../config.php"; 
$stats = explode('|', system_call("get-system-stats")); ?>
<h1>Admin Dashboard</h1><p>CPU: <?= $stats[0] ?>%</p>
<p>Deploying Modern Admin v22 UI...</p>
EOF

# Deploy Client v15 (Simplified snippet)
cat > $WEB_ROOT/client/index.php << 'EOF'
<?php include "../config.php"; ?>
<h1>Client Dashboard</h1><p>Welcome to Vivzon Cloud</p>
EOF

# ------------------------------------------------------------------------------
# 8. Security & Permissions
# ------------------------------------------------------------------------------
echo "www-data ALL=(root) NOPASSWD: /usr/local/bin/shm-manage" > /etc/sudoers.d/shm-web
chown -R www-data:www-data $WEB_ROOT $APPS_DIR
chmod -R 755 $WEB_ROOT $APPS_DIR
systemctl restart nginx php8.2-fpm

echo "=========================================================="
echo "✅ SHM PANEL INSTALLED"
echo "=========================================================="
echo "Admin:      http://$DOMAIN_ADMIN"
echo "Client:     http://$DOMAIN_CLIENT"
echo "DB:         http://$DOMAIN_PMA"
echo "Webmail:    http://$DOMAIN_MAIL"
echo "Files:      http://$DOMAIN_FILES"
echo "=========================================================="
echo "MySQL Root Pass: $MYSQL_ROOT_PASS"
echo "Admin User: admin / admin123"
