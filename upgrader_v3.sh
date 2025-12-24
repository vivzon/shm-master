#!/bin/bash

# 1. Load variables from the system config
source /etc/shm/config.sh

# 2. Fix Permissions
# Ensure the web server can read the config folder
chmod 755 /etc/shm
chmod 644 /etc/shm/config.sh
chown -R www-data:www-data /var/www/panel

# 3. Verify/Reset Database User
# This ensures the shm_admin user has the exact password stored in config.sh
mysql -u root << EOF
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

# 4. Update the PHP Config file to be more robust
# We will write the credentials directly into the shared file to avoid permission issues
cat > /var/www/panel/shared/db.php << EOF
<?php
\$host = 'localhost';
\$db   = '$DB_NAME';
\$user = '$DB_USER';
\$pass = '$DB_PASS';

try {
    \$pdo = new PDO("mysql:host=\$host;dbname=\$db;charset=utf8", \$user, \$pass);
    \$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch (PDOException \$e) {
    // If it fails, show the actual error for debugging
    die("Connection failed: " . \$e->getMessage());
}

function shm_manage(\$cmd) {
    return shell_exec("sudo /usr/local/bin/shm-manage " . \$cmd);
}
?>
EOF

# 5. Restart Services
systemctl restart mariadb || systemctl restart mysql
systemctl restart php8.2-fpm
systemctl restart nginx

echo "Repair Complete. Please refresh your browser."
