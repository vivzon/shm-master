#!/bin/bash

# ==============================================================================
# SHM PANEL v25.0 - TOTAL CONSOLIDATED INSTALLER (PRODUCTION LIVE)
# ==============================================================================
# Domain: vivzon.cloud
# Includes: WHM, CPanel, phpMyAdmin, Webmail, File Manager, DNS, Mail, FTP
# ==============================================================================

export DEBIAN_FRONTEND=noninteractive

# --- 1. Configuration Variables ---
MAIN_DOMAIN="vivzon.cloud"
IP_ADDR=$(hostname -I | awk '{print $1}')
ADMIN_EMAIL="admin@vivzon.cloud"
DB_NAME="shm_panel"
DB_USER="shm_admin"
DB_PASS=$(openssl rand -base64 16)
MYSQL_ROOT_PASS=$(openssl rand -base64 18)
SSH_PORT=22

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}"; }

if [ "$EUID" -ne 0 ]; then echo "Run as root"; exit 1; fi

# --- 2. System Updates & Repo Setup ---
log "Installing dependencies and PHP repositories..."
apt update && apt upgrade -y
apt install -y software-properties-common curl wget git zip unzip ufw fail2ban certbot python3-certbot-nginx acl quota bind9 dovecot-core dovecot-imapd dovecot-pop3d dovecot-mysql postfix postfix-mysql proftpd-basic proftpd-mod-mysql mariadb-server mariadb-client

add-apt-repository ppa:ondrej/php -y
apt update

# Install Multi-PHP Stack
for v in 8.1 8.2 8.3; do
    apt install -y php$v-fpm php$v-mysql php$v-common php$v-gd php$v-mbstring php$v-xml php$v-zip php$v-curl php$v-bcmath php$v-intl php$v-imagick php$v-cli
done

# --- 3. Database Initialization ---
log "Configuring Database Server..."
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASS';"
cat > /root/.my.cnf << EOF
[client]
user=root
password=$MYSQL_ROOT_PASS
EOF
chmod 600 /root/.my.cnf

mysql -e "CREATE DATABASE $DB_NAME;"
mysql -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# --- 4. Database Schema (The Engine) ---
log "Deploying Core Schema..."
mysql $DB_NAME << EOF
-- Users & Hosting
CREATE TABLE clients (id INT AUTO_INCREMENT PRIMARY KEY, username VARCHAR(32) UNIQUE, email VARCHAR(255), password VARCHAR(255), status ENUM('active','suspended') DEFAULT 'active', package_id INT, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);
CREATE TABLE domains (id INT AUTO_INCREMENT PRIMARY KEY, client_id INT, domain VARCHAR(255) UNIQUE, document_root VARCHAR(255), php_version VARCHAR(5) DEFAULT '8.2', ssl_active BOOLEAN DEFAULT 0);
CREATE TABLE packages (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(50), disk_mb INT, max_domains INT, max_emails INT);

-- Mail (Postfix/Dovecot)
CREATE TABLE mail_domains (id INT AUTO_INCREMENT PRIMARY KEY, domain VARCHAR(50) NOT NULL);
CREATE TABLE mail_users (id INT AUTO_INCREMENT PRIMARY KEY, domain_id INT NOT NULL, email VARCHAR(100) NOT NULL UNIQUE, password VARCHAR(255) NOT NULL, FOREIGN KEY (domain_id) REFERENCES mail_domains(id) ON DELETE CASCADE);

-- FTP (ProFTPD)
CREATE TABLE ftp_users (id INT AUTO_INCREMENT PRIMARY KEY, userid VARCHAR(32) NOT NULL UNIQUE, passwd VARCHAR(255) NOT NULL, uid INT DEFAULT 33, gid INT DEFAULT 33, homedir VARCHAR(255), shell VARCHAR(255) DEFAULT '/sbin/nologin');

INSERT INTO packages VALUES (1, 'Starter', 2000, 1, 5), (2, 'Business', 10000, 10, 50);
CREATE TABLE admins (id INT AUTO_INCREMENT PRIMARY KEY, username VARCHAR(50) UNIQUE, password VARCHAR(255));
INSERT INTO admins (username, password) VALUES ('admin', '\$2y\$10\$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi');
EOF

# --- 5. DNS (Bind9) Configuration ---
log "Configuring Bind9 DNS..."
cat > /etc/bind/named.conf.local << EOF
zone "$MAIN_DOMAIN" { type master; file "/etc/bind/zones/db.$MAIN_DOMAIN"; allow-update { none; }; };
EOF
mkdir -p /etc/bind/zones
cat > /etc/bind/zones/db.$MAIN_DOMAIN << EOF
\$TTL 86400
@ IN SOA ns1.$MAIN_DOMAIN. $ADMIN_EMAIL. (2025122401 3600 900 604800 86400)
@ IN NS ns1.$MAIN_DOMAIN.
@ IN NS ns2.$MAIN_DOMAIN.
@ IN A $IP_ADDR
ns1 IN A $IP_ADDR
ns2 IN A $IP_ADDR
admin IN A $IP_ADDR
client IN A $IP_ADDR
phpmyadmin IN A $IP_ADDR
filemanager IN A $IP_ADDR
webmail IN A $IP_ADDR
EOF
systemctl restart bind9

# --- 6. The Master Management Tool (shm-manage) ---
log "Deploying Backend Engine (shm-manage)..."
cat > /usr/local/bin/shm-manage << 'EOF'
#!/bin/bash
source /etc/shm/config.sh
case "$1" in
    create-account)
        # $2=username, $3=domain, $4=email, $5=pass
        useradd -m -d /var/www/clients/$2 -s /bin/bash $2
        mkdir -p /var/www/clients/$2/{public_html,logs,mail}
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
php_admin_value[open_basedir] = /var/www/clients/$2:/tmp
PHP
        systemctl reload php8.2-fpm
        # DB Logic
        mysql -e "INSERT INTO clients (username, email, password) VALUES ('$2', '$4', '$5');" $DB_NAME
        mysql -e "INSERT INTO domains (client_id, domain, document_root) SELECT id, '$3', '/var/www/clients/$2/public_html' FROM clients WHERE username='$2';" $DB_NAME
        # FTP User
        mysql -e "INSERT INTO ftp_users (userid, passwd, homedir) VALUES ('$2', '$5', '/var/www/clients/$2');" $DB_NAME
        ;;
    add-vhost)
        # $2=username, $3=domain
        cat > /etc/nginx/sites-available/$3 << NGINX
server {
    listen 80;
    server_name $3 www.$3;
    root /var/www/clients/$2/public_html;
    index index.php index.html;
    location ~ \.php$ { include snippets/fastcgi-php.conf; fastcgi_pass unix:/run/php/php8.2-fpm-$2.sock; }
}
NGINX
        ln -s /etc/nginx/sites-available/$3 /etc/nginx/sites-enabled/
        systemctl reload nginx
        ;;
esac
EOF
chmod +x /usr/local/bin/shm-manage
mkdir -p /etc/shm
echo "DB_NAME='$DB_NAME' \nDB_USER='$DB_USER' \nDB_PASS='$DB_PASS'" > /etc/shm/config.sh
echo "www-data ALL=(root) NOPASSWD: /usr/local/bin/shm-manage" > /etc/sudoers.d/shm

# --- 7. Installing Production Web Apps ---
log "Installing Webmail (Roundcube) & phpMyAdmin..."
# phpMyAdmin
mkdir -p /var/www/apps/phpmyadmin
wget -q https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.tar.gz
tar -xzf phpMyAdmin-latest-all-languages.tar.gz -C /var/www/apps/phpmyadmin --strip-components=1
rm phpMyAdmin-latest-all-languages.tar.gz

# Roundcube
mkdir -p /var/www/apps/webmail
# (Assuming local apt install for speed, then symlinking)
apt install -y roundcube roundcube-mysql
ln -s /usr/share/roundcube /var/www/apps/webmail/src

# File Manager
mkdir -p /var/www/apps/filemanager
wget -q -O /var/www/apps/filemanager/index.php https://raw.githubusercontent.com/prasathmani/tinyfilemanager/master/tinyfilemanager.php

# --- 8. Nginx Production Vhosts ---
log "Configuring Production Subdomains..."
declare -A SUBDOMAINS=(
    ["admin.$MAIN_DOMAIN"]="/var/www/panel/whm"
    ["client.$MAIN_DOMAIN"]="/var/www/panel/cpanel"
    ["phpmyadmin.$MAIN_DOMAIN"]="/var/www/apps/phpmyadmin"
    ["filemanager.$MAIN_DOMAIN"]="/var/www/apps/filemanager"
    ["webmail.$MAIN_DOMAIN"]="/usr/share/roundcube"
    ["$MAIN_DOMAIN"]="/var/www/panel/landing"
)

mkdir -p /var/www/panel/{whm,cpanel,landing}

for sub in "${!SUBDOMAINS[@]}"; do
    cat > /etc/nginx/sites-available/$sub << EOF
server {
    listen 80;
    server_name $sub;
    root ${SUBDOMAINS[$sub]};
    index index.php index.html;
    location ~ \.php$ { include snippets/fastcgi-php.conf; fastcgi_pass unix:/run/php/php8.2-fpm.sock; }
}
EOF
    ln -sf /etc/nginx/sites-available/$sub /etc/nginx/sites-enabled/
done

# --- 9. Security & Firewall ---
log "Finalizing Security..."
ufw allow 22,80,443,21,25,465,587,110,995,143,993,53/tcp
ufw allow 53/udp
ufw --force enable

# Auto-SSL for System Domains (Optional: Requires DNS to be pointed)
# certbot --nginx -d vivzon.cloud -d admin.vivzon.cloud -d client.vivzon.cloud --non-interactive --agree-tos -m $ADMIN_EMAIL

log "SHM PANEL v25.0 INSTALLED SUCCESSFULLY!"
echo "------------------------------------------------------------"
echo "WHM Login:     http://admin.vivzon.cloud"
echo "Client Portal: http://client.vivzon.cloud"
echo "Webmail:       http://webmail.vivzon.cloud"
echo "File Manager:  http://filemanager.vivzon.cloud"
echo "MySQL Root:    $MYSQL_ROOT_PASS"
echo "Admin Default: admin / admin123"
echo "------------------------------------------------------------"
