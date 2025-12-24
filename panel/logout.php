<?php
session_start();
session_destroy();
echo "Logged out. Redirecting...";
header("Refresh: 1; URL=http://vivzon.cloud");
?>
