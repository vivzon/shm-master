<?php 
require_once '../shared/config.php';
if(!isset($_SESSION['admin'])) { header("Location: /login.php"); exit; }

// --- HANDLE ACTIONS ---
if(isset($_POST['create_acc'])) {
    $u = escapeshellarg($_POST['user']);
    $d = escapeshellarg($_POST['dom']);
    $e = escapeshellarg($_POST['email']);
    $p = escapeshellarg($_POST['pass']);
    cmd("create-account $u $d $e $p");
    $msg = "Account created successfully!";
}

if(isset($_GET['delete'])) {
    $u = escapeshellarg($_GET['delete']);
    cmd("delete-account $u");
    header("Location: index.php?msg=Deleted"); exit;
}

if(isset($_GET['restart'])) {
    $s = escapeshellarg($_GET['restart']);
    cmd("service-control restart $s");
    header("Location: index.php?msg=Restarted"); exit;
}

// --- FETCH DATA ---
$stats_raw = cmd("get-stats");
list($cpu, $ram, $disk, $uptime) = explode('|', $stats_raw);

$clients = $pdo->query("SELECT c.*, d.domain FROM clients c LEFT JOIN domains d ON c.id = d.client_id ORDER BY c.created_at DESC")->fetchAll();
$services = ['nginx' => 'Web Server', 'mariadb' => 'Database', 'php8.2-fpm' => 'PHP Engine', 'bind9' => 'DNS Server'];
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8"><title>Vivzon WHM | Production</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script src="https://unpkg.com/lucide@latest"></script>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;600;700&display=swap" rel="stylesheet">
    <style>body { font-family: 'Inter', sans-serif; }</style>
</head>
<body class="bg-slate-50 flex min-h-screen">

    <!-- Sidebar -->
    <aside class="w-64 bg-slate-900 text-slate-400 p-6 flex flex-col border-r border-slate-800">
        <div class="text-white font-bold text-xl mb-10 flex items-center gap-2">
            <i data-lucide="shield-check" class="text-blue-500"></i> VIVZON <span class="text-blue-400">WHM</span>
        </div>
        <nav class="space-y-4 flex-1">
            <a href="#" class="flex items-center gap-3 text-white bg-blue-600/20 p-3 rounded-xl border border-blue-500/30"><i data-lucide="layout-dashboard"></i> Dashboard</a>
            <a href="#" class="flex items-center gap-3 hover:text-white p-3"><i data-lucide="users"></i> Accounts</a>
            <a href="#" class="flex items-center gap-3 hover:text-white p-3"><i data-lucide="server"></i> Services</a>
        </nav>
        <a href="/logout.php" class="text-red-400 p-3 flex items-center gap-3"><i data-lucide="log-out"></i> Logout</a>
    </aside>

    <main class="flex-1 p-8">
        <!-- Stats Row -->
        <div class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
            <div class="bg-white p-6 rounded-3xl border shadow-sm">
                <p class="text-slate-400 text-xs font-bold uppercase">CPU Usage</p>
                <h2 class="text-2xl font-bold mt-1"><?=$cpu?>%</h2>
                <div class="w-full bg-slate-100 h-1.5 mt-3 rounded-full"><div class="bg-blue-500 h-full rounded-full" style="width: <?=$cpu?>%"></div></div>
            </div>
            <div class="bg-white p-6 rounded-3xl border shadow-sm">
                <p class="text-slate-400 text-xs font-bold uppercase">RAM Usage</p>
                <h2 class="text-2xl font-bold mt-1"><?=$ram?>%</h2>
                <div class="w-full bg-slate-100 h-1.5 mt-3 rounded-full"><div class="bg-purple-500 h-full rounded-full" style="width: <?=$ram?>%"></div></div>
            </div>
            <div class="bg-white p-6 rounded-3xl border shadow-sm">
                <p class="text-slate-400 text-xs font-bold uppercase">Disk Usage</p>
                <h2 class="text-2xl font-bold mt-1"><?=$disk?>%</h2>
                <div class="w-full bg-slate-100 h-1.5 mt-3 rounded-full"><div class="bg-orange-500 h-full rounded-full" style="width: <?=$disk?>%"></div></div>
            </div>
            <div class="bg-white p-6 rounded-3xl border shadow-sm">
                <p class="text-slate-400 text-xs font-bold uppercase">Uptime</p>
                <h2 class="text-xl font-bold mt-1 truncate"><?=$uptime?></h2>
            </div>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
            <!-- Left: Account List -->
            <div class="lg:col-span-2 space-y-8">
                <div class="bg-white rounded-3xl border shadow-sm overflow-hidden">
                    <div class="p-6 border-b flex justify-between items-center">
                        <h3 class="font-bold text-lg">Active Hosting Accounts</h3>
                        <span class="bg-blue-100 text-blue-600 text-xs px-3 py-1 rounded-full font-bold"><?=count($clients)?> Total</span>
                    </div>
                    <table class="w-full text-left border-collapse">
                        <thead class="bg-slate-50 text-xs font-bold text-slate-400 uppercase">
                            <tr>
                                <th class="p-4">User / Domain</th>
                                <th class="p-4">Created</th>
                                <th class="p-4 text-right">Actions</th>
                            </tr>
                        </thead>
                        <tbody class="divide-y">
                            <?php foreach($clients as $c): ?>
                            <tr class="hover:bg-slate-50">
                                <td class="p-4">
                                    <p class="font-bold text-slate-800"><?=$c['username']?></p>
                                    <p class="text-xs text-blue-500"><?=$c['domain']?></p>
                                </td>
                                <td class="p-4 text-sm text-slate-500"><?=date('M d, Y', strtotime($c['created_at']))?></td>
                                <td class="p-4 text-right">
                                    <a href="?delete=<?=$c['username']?>" onclick="return confirm('Are you sure?')" class="text-red-400 hover:text-red-600"><i data-lucide="trash-2" class="w-5 mx-auto"></i></a>
                                </td>
                            </tr>
                            <?php endforeach; ?>
                        </tbody>
                    </table>
                </div>
            </div>

            <!-- Right: Service Control & Add Account -->
            <div class="space-y-8">
                <!-- Add Account -->
                <div class="bg-white p-6 rounded-3xl border shadow-sm">
                    <h3 class="font-bold mb-4">Quick Create</h3>
                    <form method="POST" class="space-y-4">
                        <input name="user" placeholder="Username" class="w-full p-3 bg-slate-50 border rounded-xl outline-none focus:ring-2 focus:ring-blue-500">
                        <input name="dom" placeholder="domain.com" class="w-full p-3 bg-slate-50 border rounded-xl outline-none focus:ring-2 focus:ring-blue-500">
                        <input name="email" placeholder="Email" class="w-full p-3 bg-slate-50 border rounded-xl outline-none focus:ring-2 focus:ring-blue-500">
                        <input name="pass" type="password" placeholder="Password" class="w-full p-3 bg-slate-50 border rounded-xl outline-none focus:ring-2 focus:ring-blue-500">
                        <button name="create_acc" class="w-full bg-blue-600 text-white p-3 rounded-xl font-bold hover:bg-blue-700 shadow-lg shadow-blue-200">Launch Account</button>
                    </form>
                </div>

                <!-- Services -->
                <div class="bg-white p-6 rounded-3xl border shadow-sm">
                    <h3 class="font-bold mb-4">System Services</h3>
                    <div class="space-y-4">
                        <?php foreach($services as $id => $name): 
                            $status = trim(cmd("service-status $id"));
                            $is_up = ($status == 'active');
                        ?>
                        <div class="flex items-center justify-between p-3 bg-slate-50 rounded-2xl border">
                            <div class="flex items-center gap-3">
                                <div class="w-2 h-2 rounded-full <?=$is_up ? 'bg-emerald-500' : 'bg-red-500'?>"></div>
                                <span class="text-sm font-semibold"><?=$name?></span>
                            </div>
                            <a href="?restart=<?=$id?>" class="p-2 hover:bg-white rounded-lg transition" title="Restart"><i data-lucide="rotate-cw" class="w-4 text-slate-400"></i></a>
                        </div>
                        <?php endforeach; ?>
                    </div>
                </div>
            </div>
        </div>
    </main>
    <script>lucide.createIcons();</script>
</body>
</html>
