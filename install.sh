#!/bin/bash

# ==============================================================================
# SHM PANEL v25.5 - PRODUCTION CONSOLIDATED INSTALLER
# ==============================================================================
# WHM: admin.vivzon.cloud | CPANEL: client.vivzon.cloud
# APPS: phpmyadmin, filemanager, webmail
# ==============================================================================

export DEBIAN_FRONTEND=noninteractive

# --- Configuration Variables ---
MAIN_DOMAIN="vivzon.cloud"
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

if [ "$EUID" -ne 0 ]; then echo "Please run as root"; exit 1; fi

clear
echo -e "${BLUE}======================================================${NC}"
echo -e "${BLUE}     SHM PANEL v25.5 - PRODUCTION LIVE INSTALLER      ${NC}"
echo -e "${BLUE}======================================================${NC}"

# 1. SYSTEM UPDATES & REPOS
log "Updating system and adding PHP repositories..."
apt update && apt upgrade -y
apt install -y software-properties-common curl wget git zip unzip ufw fail2ban certbot python3-certbot-nginx acl quota bind9 dovecot-core dovecot-imapd dovecot-pop3d dovecot-mysql postfix postfix-mysql proftpd-basic proftpd-mod-mysql

add-apt-repository ppa:ondrej/php -y
apt update

# Install Multi-PHP (8.1, 8.2, 8.3)
for v in 8.1 8.2 8.3; do
    apt install -y php$v-fpm php$v-mysql php$v-common php$v-gd php$v-mbstring php$v-xml php$v-zip php$v-curl php$v-bcmath php$v-intl php$v-imagick php$v-cli
done

# 2. DATABASE INITIALIZATION
log "Configuring MariaDB/MySQL..."
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASS';"
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

# 3. DATABASE SCHEMA
log "Deploying Production Schema..."
mysql $DB_NAME << EOF
CREATE TABLE clients (id INT AUTO_INCREMENT PRIMARY KEY, username VARCHAR(32) UNIQUE, email VARCHAR(255), password VARCHAR(255), status ENUM('active','suspended') DEFAULT 'active', package_id INT, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);
CREATE TABLE domains (id INT AUTO_INCREMENT PRIMARY KEY, client_id INT, domain VARCHAR(255) UNIQUE, document_root VARCHAR(255), php_version VARCHAR(5) DEFAULT '8.2', ssl_active BOOLEAN DEFAULT 0, FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE CASCADE);
CREATE TABLE packages (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(50), disk_quota_mb INT, max_domains INT, max_dbs INT);
CREATE TABLE admins (id INT AUTO_INCREMENT PRIMARY KEY, username VARCHAR(50) UNIQUE, password VARCHAR(255));
INSERT INTO packages VALUES (1, 'Starter', 2000, 1, 2), (2, 'Business', 10000, 10, 20);
-- Default Admin: admin / admin123
INSERT INTO admins (username, password) VALUES ('admin', '\$2y\$10\$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi');
EOF

# 4. DIRECTORY STRUCTURE
log "Creating Production Directory Hierarchy..."
mkdir -p /var/www/panel/{whm,cpanel,shared}
mkdir -p /var/www/apps/{phpmyadmin,filemanager,webmail}
mkdir -p /var/www/clients
mkdir -p /etc/shm

cat > /etc/shm/config.sh << EOF
DB_NAME="$DB_NAME"
DB_USER="$DB_USER"
DB_PASS="$DB_PASS"
EOF

# 5. THE MASTER shm-manage SCRIPT (Backend Engine)
log "Deploying Central Management Tool..."
cat > /usr/local/bin/shm-manage << 'EOF'
#!/bin/bash
source /etc/shm/config.sh
case "$1" in
    create-client)
        # $2: username, $3: email, $4: pass
        useradd -m -d /var/www/clients/$2 -s /bin/bash $2
        chmod 711 /var/www/clients/$2
        mkdir -p /var/www/clients/$2/{public_html,logs,tmp}
        chown -R $2:$2 /var/www/clients/$2
        mysql -e "INSERT INTO clients (username, email, password, package_id) VALUES ('$2', '$3', '$4', 1);" $DB_NAME
        
        # Create PHP FPM Pool for Client
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
        ;;
    add-domain)
        # $2: username, $3: domain
        CLIENT_ID=$(mysql -N -s -e "SELECT id FROM clients WHERE username='$2'" $DB_NAME)
        DOC_ROOT="/var/www/clients/$2/public_html"
        mysql -e "INSERT INTO domains (client_id, domain, document_root) VALUES ($CLIENT_ID, '$3', '$DOC_ROOT');" $DB_NAME
        cat > /etc/nginx/sites-available/$3 << NGINX
server {
    listen 80;
    server_name $3 www.$3;
    root $DOC_ROOT;
    index index.php index.html;
    location ~ \.php$ { 
        include snippets/fastcgi-php.conf; 
        fastcgi_pass unix:/run/php/php8.2-fpm-$2.sock; 
    }
}
NGINX
        ln -s /etc/nginx/sites-available/$3 /etc/nginx/sites-enabled/
        systemctl reload nginx
        ;;
esac
EOF
chmod +x /usr/local/bin/shm-manage
echo "www-data ALL=(root) NOPASSWD: /usr/local/bin/shm-manage" > /etc/sudoers.d/shm

# 6. APP INSTALLATIONS
log "Installing sub-domain applications..."

# phpMyAdmin
wget -q https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.tar.gz
tar -xzf phpMyAdmin-latest-all-languages.tar.gz -C /var/www/apps/phpmyadmin --strip-components=1
rm phpMyAdmin-latest-all-languages.tar.gz

# File Manager (TinyFileManager)
wget -q -O /var/www/apps/filemanager/index.php https://raw.githubusercontent.com/prasathmani/tinyfilemanager/master/tinyfilemanager.php

# Roundcube (Webmail)
apt install -y roundcube roundcube-mysql
ln -s /usr/share/roundcube /var/www/apps/webmail/src # For clean pathing

# 7. PANEL PHP CODE (The Intelligence)
log "Writing Dashboard Logic..."

# Shared Config
cat > /var/www/panel/shared/config.php << EOF
<?php
\$host = 'localhost'; \$db = '$DB_NAME'; \$user = '$DB_USER'; \$pass = '$DB_PASS';
try { \$pdo = new PDO("mysql:host=\$host;dbname=\$db", \$user, \$pass); } catch(PDOException \$e) { die("DB Error"); }
function cmd(\$c) { return shell_exec("sudo /usr/local/bin/shm-manage " . \$c); }
session_start();
?>
EOF

# WHM Admin Dashboard
cat > /var/www/panel/whm/index.php << 'PHP'
<?php include '../shared/config.php'; 
if(!isset($_SESSION['admin'])) { 
    if(isset($_POST['login'])) {
        $s = $pdo->prepare("SELECT * FROM admins WHERE username=?"); $s->execute([$_POST['u']]);
        $a = $s->fetch();
        if($a && password_verify($_POST['p'], $a['password'])) { $_SESSION['admin'] = $a['username']; header("Location: /"); }
    }
    echo '<form method="POST"><h2>WHM Login</h2><input name="u"><input name="p" type="password"><button name="login">Login</button></form>'; exit;
}
if(isset($_POST['create'])) { cmd("create-client {$_POST['user']} {$_POST['email']} {$_POST['pass']}"); }
?>
<h1>WHM - Global Administration</h1>
<form method="POST"><h3>Create Client</h3>
<input name="user" placeholder="Username"><input name="email" placeholder="Email"><input name="pass" placeholder="Password"><button name="create">Create</button></form>
PHP

# CPanel Client Dashboard
cat > /var/www/panel/cpanel/index.php << 'PHP'
<?php include '../shared/config.php';
if(!isset($_SESSION['client'])) { 
     if(isset($_POST['login'])) {
        $s = $pdo->prepare("SELECT * FROM clients WHERE username=?"); $s->execute([$_POST['u']]);
        $c = $s->fetch();
        if($c && $_POST['p'] == $c['password']) { $_SESSION['client'] = $c['username']; header("Location: /"); }
    }
    echo '<form method="POST"><h2>Client Login</h2><input name="u"><input name="p" type="password"><button name="login">Login</button></form>'; exit;
}
if(isset($_POST['add_dom'])) { cmd("add-domain {$_SESSION['client']} {$_POST['dom']}"); }
?>
<h1>CPanel - Welcome <?php echo $_SESSION['client']; ?></h1>
<form method="POST"><input name="dom" placeholder="newdomain.com"><button name="add_dom">Add Domain</button></form>
<hr>
<a href="http://filemanager.vivzon.cloud">File Manager</a> | <a href="http://phpmyadmin.vivzon.cloud">Databases</a>
PHP

# 8. NGINX VHOST CONFIGURATION (The Production Routing)
log "Configuring Virtual Hosts..."

# Define a function to create Nginx blocks
create_vhost() {
    local domain=$1
    local root=$2
    cat > /etc/nginx/sites-available/$domain << EOF
server {
    listen 80;
    server_name $domain;
    root $root;
    index index.php index.html;
    location / { try_files \$uri \$uri/ /index.php?\$args; }
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
    }
}
EOF
    ln -s /etc/nginx/sites-available/$domain /etc/nginx/sites-enabled/
}

# Apply Vhosts
create_vhost "admin.vivzon.cloud" "/var/www/panel/whm"
create_vhost "client.vivzon.cloud" "/var/www/panel/cpanel"
create_vhost "phpmyadmin.vivzon.cloud" "/var/www/apps/phpmyadmin"
create_vhost "filemanager.vivzon.cloud" "/var/www/apps/filemanager"
create_vhost "webmail.vivzon.cloud" "/usr/share/roundcube"

# Main Landing Page
cat > /var/www/panel/shared/index.html << 'HTML'
<!DOCTYPE html><html><body style="font-family:sans-serif; text-align:center; padding-top:100px;">
<h1>Vivzon Cloud Production</h1>
<p><a href="http://admin.vivzon.cloud">WHM Admin</a> | <a href="http://client.vivzon.cloud">Client Login</a></p>
</body></html>
HTML
create_vhost "vivzon.cloud" "/var/www/panel/shared"

# 9. FINAL SECURITY & PERMISSIONS
log "Finalizing system..."
chown -R www-data:www-data /var/www/panel
chown -R www-data:www-data /var/www/apps
ufw allow 80,443,22,21,25,110,143/tcp --force
systemctl restart nginx mysql php8.2-fpm

log "INSTALLATION COMPLETE"
echo "------------------------------------------------------------"
echo "WHM ADMIN:    http://admin.vivzon.cloud"
echo "CPANEL:       http://client.vivzon.cloud"
echo "PHPMYADMIN:   http://phpmyadmin.vivzon.cloud"
echo "FILE MANAGER: http://filemanager.vivzon.cloud"
echo "WEBMAIL:      http://webmail.vivzon.cloud"
echo "------------------------------------------------------------"
echo "Admin Default: admin / admin123"
echo "MySQL Root Pass: $MYSQL_ROOT_PASS"
echo "Saved to: /root/shm-credentials.txt"

cat > /root/shm-credentials.txt << EOF
MySQL Root: $MYSQL_ROOT_PASS
Panel DB User: $DB_USER
Panel DB Pass: $DB_PASS
Admin: admin / admin123
EOF
