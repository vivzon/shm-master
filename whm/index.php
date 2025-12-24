<?php 
require_once '../shared/config.php';
// Add basic auth check
if(!isset($_SESSION['admin'])) { header("Location: /login.php"); exit; }

// Logic for stats
$total_clients = $pdo->query("SELECT COUNT(*) FROM clients")->fetchColumn();
$total_domains = $pdo->query("SELECT COUNT(*) FROM domains")->fetchColumn();
$clients = $pdo->query("SELECT * FROM clients ORDER BY created_at DESC LIMIT 5")->fetchAll();
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Vivzon WHM - Admin</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script src="https://unpkg.com/lucide@latest"></script>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">
    <style>body { font-family: 'Inter', sans-serif; background-color: #f8fafc; }</style>
</head>
<body class="flex min-h-screen">

    <!-- Sidebar -->
    <aside class="w-64 bg-slate-900 text-slate-300 hidden md:flex flex-col border-r border-slate-800">
        <div class="p-6 text-white font-bold text-xl flex items-center gap-2">
            <i data-lucide="cloud" class="text-blue-500"></i> Vivzon <span class="text-blue-400">WHM</span>
        </div>
        <nav class="flex-1 px-4 space-y-2 mt-4">
            <a href="#" class="flex items-center gap-3 p-3 bg-blue-600 text-white rounded-lg"><i data-lucide="layout-dashboard" class="w-5"></i> Dashboard</a>
            <a href="#" class="flex items-center gap-3 p-3 hover:bg-slate-800 rounded-lg transition"><i data-lucide="users" class="w-5"></i> Clients</a>
            <a href="#" class="flex items-center gap-3 p-3 hover:bg-slate-800 rounded-lg transition"><i data-lucide="globe" class="w-5"></i> Domains</a>
            <a href="#" class="flex items-center gap-3 p-3 hover:bg-slate-800 rounded-lg transition"><i data-lucide="server" class="w-5"></i> Server Status</a>
            <a href="#" class="flex items-center gap-3 p-3 hover:bg-slate-800 rounded-lg transition"><i data-lucide="settings" class="w-5"></i> Settings</a>
        </nav>
        <div class="p-4 border-t border-slate-800">
            <a href="/logout.php" class="flex items-center gap-3 p-3 text-red-400 hover:bg-red-500/10 rounded-lg transition"><i data-lucide="log-out" class="w-5"></i> Logout</a>
        </div>
    </aside>

    <!-- Main Content -->
    <main class="flex-1 flex flex-col">
        <!-- Header -->
        <header class="h-16 bg-white border-b flex items-center justify-between px-8">
            <h1 class="font-semibold text-slate-800">System Overview</h1>
            <div class="flex items-center gap-4">
                <span class="text-sm text-slate-500">Logged in as: <b>Admin</b></span>
                <div class="w-8 h-8 rounded-full bg-blue-100 flex items-center justify-center text-blue-600 font-bold">A</div>
            </div>
        </header>

        <div class="p-8 space-y-8">
            <!-- Stats Bento Grid -->
            <div class="grid grid-cols-1 md:grid-cols-4 gap-6">
                <div class="bg-white p-6 rounded-2xl border shadow-sm flex items-center gap-4">
                    <div class="p-3 bg-blue-50 text-blue-600 rounded-xl"><i data-lucide="users"></i></div>
                    <div><p class="text-sm text-slate-500">Total Clients</p><p class="text-2xl font-bold"><?=$total_clients?></p></div>
                </div>
                <div class="bg-white p-6 rounded-2xl border shadow-sm flex items-center gap-4">
                    <div class="p-3 bg-emerald-50 text-emerald-600 rounded-xl"><i data-lucide="globe"></i></div>
                    <div><p class="text-sm text-slate-500">Active Domains</p><p class="text-2xl font-bold"><?=$total_domains?></p></div>
                </div>
                <div class="bg-white p-6 rounded-2xl border shadow-sm flex items-center gap-4">
                    <div class="p-3 bg-orange-50 text-orange-600 rounded-xl"><i data-lucide="cpu"></i></div>
                    <div><p class="text-sm text-slate-500">CPU Load</p><p class="text-2xl font-bold">12%</p></div>
                </div>
                <div class="bg-white p-6 rounded-2xl border shadow-sm flex items-center gap-4">
                    <div class="p-3 bg-purple-50 text-purple-600 rounded-xl"><i data-lucide="hard-drive"></i></div>
                    <div><p class="text-sm text-slate-500">Disk Usage</p><p class="text-2xl font-bold">45 GB</p></div>
                </div>
            </div>

            <!-- Management Section -->
            <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
                <!-- Create Account Form -->
                <div class="lg:col-span-1 bg-white p-6 rounded-2xl border shadow-sm">
                    <h3 class="text-lg font-bold mb-4 flex items-center gap-2"><i data-lucide="user-plus" class="w-5 text-blue-600"></i> Create Hosting Account</h3>
                    <form method="POST" class="space-y-4">
                        <div>
                            <label class="text-xs font-semibold text-slate-500 uppercase tracking-wider">Username</label>
                            <input name="user" class="w-full mt-1 p-3 bg-slate-50 border rounded-xl focus:ring-2 focus:ring-blue-500 outline-none transition" placeholder="johndoe">
                        </div>
                        <div>
                            <label class="text-xs font-semibold text-slate-500 uppercase tracking-wider">Domain</label>
                            <input name="dom" class="w-full mt-1 p-3 bg-slate-50 border rounded-xl focus:ring-2 focus:ring-blue-500 outline-none transition" placeholder="example.com">
                        </div>
                        <div>
                            <label class="text-xs font-semibold text-slate-500 uppercase tracking-wider">Email</label>
                            <input name="email" class="w-full mt-1 p-3 bg-slate-50 border rounded-xl focus:ring-2 focus:ring-blue-500 outline-none transition" placeholder="john@gmail.com">
                        </div>
                        <div>
                            <label class="text-xs font-semibold text-slate-500 uppercase tracking-wider">Password</label>
                            <input name="pass" type="password" class="w-full mt-1 p-3 bg-slate-50 border rounded-xl focus:ring-2 focus:ring-blue-500 outline-none transition" placeholder="••••••••">
                        </div>
                        <button name="create_acc" class="w-full p-4 bg-blue-600 hover:bg-blue-700 text-white font-semibold rounded-xl transition shadow-lg shadow-blue-200">Create Account</button>
                    </form>
                </div>

                <!-- Recent Clients Table -->
                <div class="lg:col-span-2 bg-white rounded-2xl border shadow-sm overflow-hidden">
                    <div class="p-6 border-b flex items-center justify-between">
                        <h3 class="text-lg font-bold">Recent Clients</h3>
                        <button class="text-sm text-blue-600 font-medium">View All</button>
                    </div>
                    <table class="w-full text-left">
                        <thead class="bg-slate-50 border-b text-xs text-slate-500 uppercase font-bold">
                            <tr>
                                <th class="p-4">User</th>
                                <th class="p-4">Status</th>
                                <th class="p-4">Package</th>
                                <th class="p-4">Created</th>
                                <th class="p-4 text-right">Action</th>
                            </tr>
                        </thead>
                        <tbody class="divide-y">
                            <?php foreach($clients as $c): ?>
                            <tr class="hover:bg-slate-50 transition">
                                <td class="p-4">
                                    <div class="flex items-center gap-3">
                                        <div class="w-8 h-8 rounded-lg bg-blue-100 text-blue-600 flex items-center justify-center font-bold text-xs"><?=substr($c['username'],0,1)?></div>
                                        <div><p class="font-medium text-slate-800"><?=$c['username']?></p><p class="text-xs text-slate-400"><?=$c['email']?></p></div>
                                    </div>
                                </td>
                                <td class="p-4"><span class="px-2 py-1 bg-emerald-100 text-emerald-600 text-xs rounded-full font-bold">Active</span></td>
                                <td class="p-4 text-slate-600 text-sm font-medium">Starter</td>
                                <td class="p-4 text-slate-400 text-sm"><?=date('d M Y', strtotime($c['created_at']))?></td>
                                <td class="p-4 text-right"><button class="p-2 hover:bg-slate-200 rounded-lg transition"><i data-lucide="more-horizontal" class="w-4"></i></button></td>
                            </tr>
                            <?php endforeach; ?>
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    </main>

    <script>lucide.createIcons();</script>
</body>
</html>
