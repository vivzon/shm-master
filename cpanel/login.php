<?php 
require_once '../shared/config.php';
if(isset($_SESSION['client'])) { header("Location: /"); exit; }

if($_SERVER['REQUEST_METHOD'] == 'POST') {
    $u = $_POST['u']; $p = $_POST['p'];
    // In our system, client passwords are stored as plain text or simple hashes for now
    $stmt = $pdo->prepare("SELECT * FROM clients WHERE username = ? AND password = ?");
    $stmt->execute([$u, $p]);
    $user = $stmt->fetch();
    
    if($user) {
        $_SESSION['client'] = $user['username'];
        $_SESSION['cid'] = $user['id'];
        header("Location: /index.php"); exit;
    } else {
        $error = "Invalid username or password";
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8"><title>CPanel Login | Vivzon Cloud</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;600&display=swap" rel="stylesheet">
</head>
<body class="bg-blue-600 flex items-center justify-center min-h-screen font-['Outfit']">
    <div class="w-full max-w-md p-8 bg-white rounded-3xl shadow-2xl">
        <div class="text-center mb-8">
            <h1 class="text-2xl font-bold text-slate-800">CPanel Login</h1>
            <p class="text-slate-500 text-sm">Secure Client Portal</p>
        </div>
        <?php if(isset($error)): ?>
            <div class="bg-red-50 text-red-500 p-4 rounded-xl mb-4 text-sm font-semibold text-center"><?php echo $error; ?></div>
        <?php endif; ?>
        <form method="POST" class="space-y-6">
            <div>
                <label class="block text-xs font-bold text-slate-500 uppercase mb-2">Username</label>
                <input name="u" required class="w-full p-4 bg-slate-50 border rounded-2xl outline-none focus:ring-2 focus:ring-blue-500 transition" placeholder="Username">
            </div>
            <div>
                <label class="block text-xs font-bold text-slate-500 uppercase mb-2">Password</label>
                <input name="p" type="password" required class="w-full p-4 bg-slate-50 border rounded-2xl outline-none focus:ring-2 focus:ring-blue-500 transition" placeholder="Password">
            </div>
            <button class="w-full p-4 bg-blue-600 hover:bg-blue-700 text-white font-bold rounded-2xl shadow-lg shadow-blue-200 transition">Access My Hosting</button>
        </form>
    </div>
</body>
</html>
