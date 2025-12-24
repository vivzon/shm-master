# 1. Manually reset the database user permissions
# Replace the password below with the one from your shm-credentials.txt if it differs
DB_PASS="LrsAT5xLet/rxpNWZIfu4g=="

mysql -e "GRANT ALL PRIVILEGES ON shm_panel.* TO 'shm_admin'@'localhost' IDENTIFIED BY '$DB_PASS';"
mysql -e "FLUSH PRIVILEGES;"

# 2. Fix the PHP Configuration File
# We will create a consolidated config file that both WHM and CPanel will use.
mkdir -p /var/www/panel/shared
cat > /var/www/panel/shared/config.php << EOF
<?php
\$host = 'localhost';
\$db   = 'shm_panel';
\$user = 'shm_admin';
\$pass = '$DB_PASS';

try {
    \$pdo = new PDO("mysql:host=\$host;dbname=\$db;charset=utf8mb4", \$user, \$pass);
    \$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch (PDOException \$e) {
    // This will now show the actual error message to help you debug
    die("DB Connection Failed: " . \$e->getMessage());
}

function cmd(\$c) { 
    return shell_exec("sudo /usr/local/bin/shm-manage " . \$c); 
}

if (session_status() === PHP_SESSION_NONE) {
    session_start();
}
?>
EOF

# 3. Ensure PHP files are pointing to the correct config location
# This fixes the 'DB Error' by replacing old include paths
sed -i "s|require_once '../shared/db.php'|require_once '../shared/config.php'|g" /var/www/panel/whm/index.php 2>/dev/null
sed -i "s|require_once '../shared/db.php'|require_once '../shared/config.php'|g" /var/www/panel/cpanel/index.php 2>/dev/null
sed -i "s|include '../shared/config.php'|require_once '../shared/config.php'|g" /var/www/panel/whm/index.php 2>/dev/null
sed -i "s|include '../shared/config.php'|require_once '../shared/config.php'|g" /var/www/panel/cpanel/index.php 2>/dev/null

# 4. Fix Folder Permissions
# The web server (www-data) must own the panel files
chown -R www-data:www-data /var/www/panel
chmod -R 755 /var/www/panel

# 5. Restart Services
systemctl restart mariadb
systemctl restart php8.2-fpm
systemctl restart nginx
