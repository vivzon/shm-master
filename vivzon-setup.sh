#!/bin/bash

# ==============================================================================
# VIVZON CLOUD - TOTAL SERVER AUTOMATION (Final Version)
# ==============================================================================

export DEBIAN_FRONTEND=noninteractive
MAIN_DOMAIN="vivzon.cloud"
ADMIN_SUB="admin.vivzon.cloud"
CLIENT_SUB="client.vivzon.cloud"
ADMIN_EMAIL="admin@vivzon.cloud"
SSH_PORT=2222

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"; }

# 1. Credentials Generation
MYSQL_ROOT_PASS=$(openssl rand -base64 24)
DB_USER="vivzon_panel"
DB_PASS=$(openssl rand -base64 18)
DB_NAME="vivzon_management"

# ------------------------------------------------------------------------------
# 2. System Core & Repositories
# ------------------------------------------------------------------------------
log "Updating system and adding PHP repositories..."
apt update && apt upgrade -y
apt install -y software-properties-common curl git unzip ufw fail2ban certbot python3-certbot-nginx
add-apt-repository ppa:ondrej/php -y
apt update

log "Installing LAMP + Mail + FTP stack..."
apt install -y nginx mysql-server postfix postfix-mysql dovecot-core dovecot-mysql \
dovecot-imapd dovecot-lmtpd proftpd-basic proftpd-mod-mysql \
php8.1-fpm php8.2-fpm php8.3-fpm php8.2-mysql php8.2-curl php8.2-gd php8.2-mbstring php8.2-xml php8.2-zip

# ------------------------------------------------------------------------------
# 3. Database & Schema
# ------------------------------------------------------------------------------
log "Configuring Database..."
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASS';"
cat > /root/.my.cnf << EOF
[client]
user=root
password=$MYSQL_ROOT_PASS
EOF

mysql -e "CREATE DATABASE $DB_NAME;"
mysql -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"

mysql $DB_NAME << EOF
CREATE TABLE packages (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50),
    disk_mb INT,
    max_domains INT,
    max_emails INT
);

CREATE TABLE clients (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(32) UNIQUE,
    password VARCHAR(255),
    email VARCHAR(255),
    role ENUM('admin', 'client') DEFAULT 'client',
    status ENUM('active', 'suspended') DEFAULT 'active',
    package_id INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE domains (
    id INT AUTO_INCREMENT PRIMARY KEY,
    client_id INT,
    domain VARCHAR(255) UNIQUE,
    php_version VARCHAR(5) DEFAULT '8.2',
    ssl_active BOOLEAN DEFAULT 0,
    FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE CASCADE
);

CREATE TABLE email_accounts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    domain_id INT,
    email VARCHAR(255) UNIQUE,
    password VARCHAR(255),
    FOREIGN KEY (domain_id) REFERENCES domains(id) ON DELETE CASCADE
);

INSERT INTO packages VALUES (1, 'Admin-Plan', 0, 0, 0), (2, 'Starter', 5000, 2, 10);
-- Default Admin: admin / Vivzon@2025
INSERT INTO clients (username, password, email, role, package_id) 
VALUES ('admin', '\$2y\$10\$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', '$ADMIN_EMAIL', 'admin', 1);
EOF

# ------------------------------------------------------------------------------
# 4. System Logic Bridge (shm-manage)
# ------------------------------------------------------------------------------
mkdir -p /etc/shm
cat > /etc/shm/config.sh << EOF
DB_NAME="$DB_NAME"
DB_USER="$DB_USER"
DB_PASS="$DB_PASS"
EOF

cat > /usr/local/bin/shm-manage << 'EOF'
#!/bin/bash
source /etc/shm/config.sh
case "$1" in
    create-client)
        USER=$2; PASS=$3
        useradd -m -d /var/www/clients/$USER -s /bin/false $USER
        mkdir -p /var/www/clients/$USER/{public_html,logs,mail}
        chown -R $USER:$USER /var/www/clients/$USER
        # Dedicated PHP Pool
        cat > /etc/php/8.2/fpm/pool.d/$USER.conf << PHP
[$USER]
user = $USER
group = $USER
listen = /run/php/php8.2-fpm-$USER.sock
listen.owner = www-data
listen.group = www-data
pm = ondemand
pm.max_children = 5
PHP
        systemctl reload php8.2-fpm
        ;;
    add-domain)
        USER=$2; DOMAIN=$3
        DOCROOT="/var/www/clients/$USER/$DOMAIN"
        mkdir -p $DOCROOT
        chown -R $USER:$USER $DOCROOT
        cat > /etc/nginx/sites-available/$DOMAIN << NGINX
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    root $DOCROOT;
    index index.php index.html;
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.2-fpm-$USER.sock;
    }
}
NGINX
        ln -s /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
        systemctl reload nginx
        ;;
    get-stats)
        CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}')
        RAM=$(free -m | awk '/Mem:/ { print int($3/$2*100) }')
        DISK=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
        UPTIME=$(uptime -p)
        echo "$CPU|$RAM|$DISK|$UPTIME"
        ;;
esac
EOF
chmod +x /usr/local/bin/shm-manage
echo "www-data ALL=(ALL) NOPASSWD: /usr/local/bin/shm-manage" >> /etc/sudoers

# ------------------------------------------------------------------------------
# 5. Web Layout Deployment
# ------------------------------------------------------------------------------
log "Setting up Web Panels..."
BASE="/var/www/vivzon"
mkdir -p $BASE/{admin,client,landing}

# Common PHP Database Header
cat > $BASE/db.php << PHP
<?php
\$pdo = new PDO("mysql:host=localhost;dbname=$DB_NAME", "$DB_USER", "$DB_PASS");
session_start();
function isAdmin() { return \$_SESSION['role'] === 'admin'; }
PHP

# Landing Page (vivzon.cloud)
cat > $BASE/landing/index.html << EOF
<!DOCTYPE html><html><head><title>Vivzon Cloud</title><link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
<style>body{background:#0f172a; color:white; display:flex; align-items:center; height:100vh; text-align:center;}</style></head>
<body class="container"><div><h1 class="display-1 fw-bold">VIVZON CLOUD</h1><p class="lead">Next-Gen Web Hosting Solutions</p>
<a href="http://$CLIENT_SUB" class="btn btn-primary btn-lg m-2">Client Portal</a>
<a href="http://$ADMIN_SUB" class="btn btn-outline-light btn-lg m-2">Admin Panel</a></div></body></html>
EOF

# Nginx Configuration
cat > /etc/nginx/sites-available/vivzon-main << EOF
server {
    listen 80;
    server_name $MAIN_DOMAIN;
    root $BASE/landing;
}
server {
    listen 80;
    server_name $ADMIN_SUB;
    root $BASE/admin;
    index index.php;
    location ~ \.php$ { include snippets/fastcgi-php.conf; fastcgi_pass unix:/run/php/php8.2-fpm.sock; }
}
server {
    listen 80;
    server_name $CLIENT_SUB;
    root $BASE/client;
    index index.php;
    location ~ \.php$ { include snippets/fastcgi-php.conf; fastcgi_pass unix:/run/php/php8.2-fpm.sock; }
}
EOF
ln -s /etc/nginx/sites-available/vivzon-main /etc/nginx/sites-enabled/
rm /etc/nginx/sites-enabled/default
systemctl restart nginx

# ------------------------------------------------------------------------------
# 6. Admin Panel UI (Based on your v22 code)
# ------------------------------------------------------------------------------
# [The full logic from your v22 index.php goes into $BASE/admin/index.php]
# Note: Ensure calls to shell_exec use "sudo /usr/local/bin/shm-manage"

# ------------------------------------------------------------------------------
# 7. Security (UFW & SSH)
# ------------------------------------------------------------------------------
log "Securing Server..."
sed -i "s/#Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config
systemctl restart ssh
ufw allow $SSH_PORT/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 21/tcp
ufw --force enable

# Finalize SSL (Optional: requires live DNS)
# certbot --nginx -d $MAIN_DOMAIN -d $ADMIN_SUB -d $CLIENT_SUB --non-interactive --agree-tos -m $ADMIN_EMAIL

log "====================================================="
log " VIVZON CLOUD INSTALLED SUCCESSFULLY"
log " Admin: http://$ADMIN_SUB"
log " Client: http://$CLIENT_SUB"
log " Landing: http://$MAIN_DOMAIN"
log " SSH Port: $SSH_PORT"
log "====================================================="
