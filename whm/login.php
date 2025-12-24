<?php 
require_once '../shared/config.php';
if(isset($_SESSION['admin'])) { header("Location: /"); exit; }

if($_SERVER['REQUEST_METHOD'] == 'POST') {
    $u = $_POST['u']; $p = $_POST['p'];
    $stmt = $pdo->prepare("SELECT * FROM admins WHERE username = ?");
    $stmt->execute([$u]);
    $user = $stmt->fetch();
    
    if($user && password_verify($p, $user['password'])) {
        $_SESSION['admin'] = $user['username'];
        header("Location: /index.php"); exit;
    } else {
        $error = "Invalid credentials";
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8"><title>WHM Login | Vivzon Cloud</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600&display=swap" rel="stylesheet">
</head>
<body class="bg-slate-900 flex items-center justify-center min-h-screen font-['Inter']">
    <div class="w-full max-w-md p-8 bg-white rounded-3xl shadow-2xl">
        <div class="text-center mb-8">
            <h1 class="text-2xl font-bold text-slate-800">WHM Login</h1>
            <p class="text-slate-500 text-sm">Vivzon Cloud Administration</p>
        </div>
        <?php if(isset($error)): ?>
            <div class="bg-red-50 text-red-500 p-4 rounded-xl mb-4 text-sm font-semibold text-center"><?php echo $error; ?></div>
        <?php endif; ?>
        <form method="POST" class="space-y-6">
            <div>
                <label class="block text-xs font-bold text-slate-500 uppercase mb-2">Username</label>
                <input name="u" required class="w-full p-4 bg-slate-50 border rounded-2xl outline-none focus:ring-2 focus:ring-blue-500 transition">
            </div>
            <div>
                <label class="block text-xs font-bold text-slate-500 uppercase mb-2">Password</label>
                <input name="p" type="password" required class="w-full p-4 bg-slate-50 border rounded-2xl outline-none focus:ring-2 focus:ring-blue-500 transition">
            </div>
            <button class="w-full p-4 bg-blue-600 hover:bg-blue-700 text-white font-bold rounded-2xl shadow-lg shadow-blue-200 transition">Log In to WHM</button>
        </form>
    </div>
</body>
</html>
