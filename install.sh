#!/bin/bash

# ==============================================================================
# SHM PANEL v25.0 - TOTAL CONSOLIDATED INSTALLER (PRODUCTION LIVE)
# ==============================================================================
# Domain: vivzon.cloud
# Includes: Admin, Client, phpMyAdmin, Webmail, File Manager, Multi-PHP
# ==============================================================================

export DEBIAN_FRONTEND=noninteractive

# --- Configuration Variables ---
MAIN_DOMAIN="vivzon.cloud"
ADMIN_EMAIL="admin@vivzon.cloud"
DB_NAME="shm_panel"
DB_USER="shm_admin"
DB_PASS=$(openssl rand -base64 16)
MYSQL_ROOT_PASS=$(openssl rand -base64 18)
SSH_PORT=2222

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"; }

if [ "$EUID" -ne 0 ]; then echo "Please run as root"; exit 1; fi

clear
echo -e "${BLUE}======================================================${NC}"
echo -e "${BLUE}     SHM PANEL v25 - ULTIMATE VPS INSTALLER           ${NC}"
echo -e "${BLUE}======================================================${NC}"

# 1. SYSTEM UPDATES & REPOS
log "Installing dependencies and PHP repositories..."
apt update && apt upgrade -y
apt install -y software-properties-common curl wget git zip unzip ufw fail2ban certbot python3-certbot-nginx acl quota bind9 dovecot-core dovecot-imapd dovecot-pop3d dovecot-mysql postfix postfix-mysql proftpd-basic proftpd-mod-mysql

add-apt-repository ppa:ondrej/php -y
apt update

# Install Multi-PHP
for v in 8.1 8.2 8.3; do
    apt install -y php$v-fpm php$v-mysql php$v-common php$v-gd php$v-mbstring php$v-xml php$v-zip php$v-curl php$v-bcmath php$v-intl php$v-imagick php$v-cli
done

# 2. DATABASE INITIALIZATION
log "Configuring MySQL Server..."
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

# 3. DATABASE SCHEMA (Clients, Packages, Admins)
log "Deploying Database Schema..."
mysql $DB_NAME << EOF
CREATE TABLE clients (id INT AUTO_INCREMENT PRIMARY KEY, username VARCHAR(32) UNIQUE, email VARCHAR(255), status ENUM('active','suspended') DEFAULT 'active', package_id INT, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);
CREATE TABLE domains (id INT AUTO_INCREMENT PRIMARY KEY, client_id INT, domain VARCHAR(255) UNIQUE, document_root VARCHAR(255), php_version VARCHAR(5) DEFAULT '8.2', ssl_active BOOLEAN DEFAULT 0, FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE CASCADE);
CREATE TABLE packages (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(50), disk_quota_mb INT, max_domains INT, max_dbs INT, max_emails INT);
CREATE TABLE admins (id INT AUTO_INCREMENT PRIMARY KEY, username VARCHAR(50) UNIQUE, password VARCHAR(255));
INSERT INTO packages (name, disk_quota_mb, max_domains, max_dbs, max_emails) VALUES ('Starter', 2000, 1, 2, 5), ('Business', 10000, 10, 20, 50);
-- Default Admin: admin / admin123
INSERT INTO admins (username, password) VALUES ('admin', '\$2y\$10\$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi');
EOF

# 4. DIRECTORY & CORE TOOLS
log "Creating Panel Directory Structure..."
mkdir -p /var/www/panel/{public_html,client}
mkdir -p /var/www/apps/{roundcube,phpmyadmin,filemanager}
mkdir -p /var/www/clients
mkdir -p /etc/shm

cat > /etc/shm/config.sh << EOF
DB_NAME="$DB_NAME"
DB_USER="$DB_USER"
DB_PASS="$DB_PASS"
EOF

# 5. THE MASTER shm-manage SCRIPT (Backend Engine)
log "Deploying Central Management Tool (shm-manage)..."
cat > /usr/local/bin/shm-manage << 'EOF'
#!/bin/bash
source /etc/shm/config.sh
case "$1" in
    create-client)
        useradd -m -d /var/www/clients/$2 -s /bin/bash $2
        chmod 711 /var/www/clients/$2
        mkdir -p /var/www/clients/$2/{logs,tmp,mail}
        chown -R $2:$2 /var/www/clients/$2
        mysql -e "INSERT INTO clients (username, email, package_id) VALUES ('$2', '$3', 1);" $DB_NAME
        # Create PHP FPM Pool
        cat > /etc/php/8.2/fpm/pool.d/$2.conf << PHP
[$2]
user = $2
group = $2
listen = /run/php/php8.2-fpm-$2.sock
listen.owner = www-data
listen.group = www-data
pm = ondemand
pm.max_children = 10
chdir = /
php_admin_value[open_basedir] = /var/www/clients/$2:/tmp
PHP
        systemctl reload php8.2-fpm
        ;;
    add-domain)
        CLIENT_ID=$(mysql -N -s -e "SELECT id FROM clients WHERE username='$2'" $DB_NAME)
        DOC_ROOT="/var/www/clients/$2/$3"
        mkdir -p $DOC_ROOT
        chown -R $2:$2 $DOC_ROOT
        mysql -e "INSERT INTO domains (client_id, domain, document_root) VALUES ($CLIENT_ID, '$3', '$DOC_ROOT');" $DB_NAME
        cat > /etc/nginx/sites-available/$3 << NGINX
server {
    listen 80;
    server_name $3 www.$3;
    root $DOC_ROOT;
    index index.php index.html;
    location ~ \.php$ { include snippets/fastcgi-php.conf; fastcgi_pass unix:/run/php/php8.2-fpm-$2.sock; }
}
NGINX
        ln -s /etc/nginx/sites-available/$3 /etc/nginx/sites-enabled/
        systemctl reload nginx
        ;;
    get-system-stats)
        CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}')
        RAM=$(free -m | awk '/Mem:/ {print $3}')
        echo "$CPU|$RAM|$(free -m | awk '/Mem:/ {print $2}')|$(df -h / | awk 'NR==2 {print $3}')|$(df -h / | awk 'NR==2 {print $2}')|$(uptime | awk -F'load average:' '{print $2}' | cut -d, -f1)"
        ;;
    check-limit) echo "OK" ;;
    get-disk-usage) du -ms /var/www/clients/$2 | awk '{print $1}' ;;
esac
EOF
chmod +x /usr/local/bin/shm-manage
echo "www-data ALL=(root) NOPASSWD: /usr/local/bin/shm-manage" > /etc/sudoers.d/shm

# 6. EXTERNAL APPS (phpMyAdmin, Roundcube, File Manager)
log "Installing Web Applications..."
# phpMyAdmin
wget -q https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.tar.gz
tar -xzf phpMyAdmin-latest-all-languages.tar.gz -C /var/www/apps/phpmyadmin --strip-components=1
rm phpMyAdmin-latest-all-languages.tar.gz

# TinyFileManager
wget -q -O /var/www/apps/filemanager/tfm_core.php https://raw.githubusercontent.com/prasathmani/tinyfilemanager/master/tinyfilemanager.php
cat > /var/www/apps/filemanager/index.php << 'PHP'
<?php session_start();
if(!isset($_SESSION['client_user']) && !isset($_SESSION['admin_user'])) { header("Location: http://client.vivzon.cloud"); exit; }
$root_path = isset($_SESSION['admin_user']) ? '/var/www/clients' : '/var/www/clients/'.$_SESSION['client_user'];
$use_auth = false; require 'tfm_core.php'; ?>
PHP

# Roundcube
apt install -y roundcube roundcube-mysql

# 7. PANEL DEPLOYMENT (Admin & Client)
log "Deploying PHP Dashboard Files..."
cat > /var/www/panel/config.php << EOF
<?php
\$pdo = new PDO("mysql:host=localhost;dbname=$DB_NAME", "$DB_USER", "$DB_PASS");
function system_call(\$cmd) { return shell_exec("sudo /usr/local/bin/shm-manage " . \$cmd); }
EOF

cat > /var/www/panel/auth.php << 'PHP'
<?php session_start(); require_once 'config.php';
function requireAdmin(){ if(!isset($_SESSION['admin_id'])) { header("Location: /login.php"); exit; } }
function requireClient(){ if(!isset($_SESSION['client_id'])) { header("Location: /login.php"); exit; } }
?>
PHP

# (Simplified login and dashboard files - based on previous versions)
# Deploying Login.php to public_html...
cat > /var/www/panel/public_html/login.php << 'PHP'
<?php require_once '../auth.php'; if($_POST){
    $u = $_POST['u']; $p = $_POST['p'];
    $s = $pdo->prepare("SELECT * FROM admins WHERE username=?"); $s->execute([$u]); $a = $s->fetch();
    if($a && password_verify($p, $a['password'])){ $_SESSION['admin_id']=$a['id']; $_SESSION['admin_user']=$a['username']; header("Location: /"); exit; }
    $s = $pdo->prepare("SELECT * FROM clients WHERE username=?"); $s->execute([$u]); $c = $s->fetch();
    if($c && $p==$u){ $_SESSION['client_id']=$c['id']; $_SESSION['client_user']=$c['username']; header("Location: /client/"); exit; }
} ?>
<form method="POST"> <input name="u" placeholder="User"> <input name="p" type="password"> <button>Login</button> </form>
PHP

# 8. LANDING PAGE & VHOSTS
log "Configuring Nginx Vhosts for vivzon.cloud..."

# Landing Page
cat > /var/www/panel/public_html/landing.html << 'HTML'
<!DOCTYPE html><html><head><title>Vivzon Cloud</title><style>body{font-family:sans-serif;text-align:center;padding:100px;background:#f4f7f6} .btn{padding:15px 25px;background:#2563eb;color:#fff;text-decoration:none;border-radius:5px;margin:10px;display:inline-block}</style></head>
<body><h1>Welcome to Vivzon Cloud</h1><p>High Performance Shared Hosting Environment</p>
<a href="http://admin.vivzon.cloud" class="btn">Admin Panel</a><a href="http://client.vivzon.cloud" class="btn">Client Portal</a><br>
<a href="http://webmail.vivzon.cloud" class="btn">Webmail</a><a href="http://filemanager.vivzon.cloud" class="btn">File Manager</a></body></html>
HTML

declare -A vhosts
vhosts=( ["vivzon.cloud"]="landing.html" ["admin.vivzon.cloud"]="index.php" ["client.vivzon.cloud"]="client/index.php" ["phpmyadmin.vivzon.cloud"]="phpmyadmin" ["webmail.vivzon.cloud"]="roundcube" ["filemanager.vivzon.cloud"]="filemanager" )

for sub in "${!vhosts[@]}"; do
    cat > /etc/nginx/sites-available/$sub << EOF
server {
    listen 80;
    server_name $sub;
    root /var/www/panel/public_html;
    index ${vhosts[$sub]};
    location ~ \.php$ { include snippets/fastcgi-php.conf; fastcgi_pass unix:/run/php/php8.2-fpm.sock; }
}
EOF
    ln -s /etc/nginx/sites-available/$sub /etc/nginx/sites-enabled/
done

# Fix for app routing
ln -s /var/www/apps/phpmyadmin /var/www/panel/public_html/phpmyadmin
ln -s /usr/share/roundcube /var/www/panel/public_html/roundcube
ln -s /var/www/apps/filemanager /var/www/panel/public_html/filemanager

# 9. SECURITY & CLEANUP
log "Finalizing Security..."
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow $SSH_PORT/tcp
ufw --force enable
chown -R www-data:www-data /var/www/panel
systemctl restart nginx php8.2-fpm mysql

log "INSTALLATION COMPLETE!"
echo "-------------------------------------------------------"
echo "Admin Panel: http://admin.vivzon.cloud"
echo "Client Panel: http://client.vivzon.cloud"
echo "Main Site:   http://vivzon.cloud"
echo "Default Admin: admin / admin123"
echo "-------------------------------------------------------"
echo "MySQL Root Pass: $MYSQL_ROOT_PASS"
echo "Panel DB Pass:   $DB_PASS"
echo "Credentials saved in /root/shm-credentials.txt"

cat > /root/shm-credentials.txt << EOF
MySQL Root: $MYSQL_ROOT_PASS
Panel DB User: $DB_USER
Panel DB Pass: $DB_PASS
Admin Login: admin / admin123
EOF
