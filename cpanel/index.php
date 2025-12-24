<?php 
require_once '../shared/config.php';
if(!isset($_SESSION['client'])) { header("Location: /login.php"); exit; }
// Fetch client specific domains
$stmt = $pdo->prepare("SELECT * FROM domains WHERE client_id = ?");
$stmt->execute([$_SESSION['cid']]);
$domains = $stmt->fetchAll();
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Vivzon CPanel</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script src="https://unpkg.com/lucide@latest"></script>
    <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;500;600;700&display=swap" rel="stylesheet">
    <style>body { font-family: 'Outfit', sans-serif; background-color: #f3f4f6; }</style>
</head>
<body class="bg-slate-50 min-h-screen">

    <!-- Top Navbar -->
    <nav class="bg-white border-b px-8 py-4 flex items-center justify-between sticky top-0 z-50">
        <div class="flex items-center gap-8">
            <div class="text-2xl font-black text-slate-900 flex items-center gap-2">
                <i data-lucide="box" class="text-blue-600"></i> Vivzon <span class="font-normal text-slate-400 text-lg">CPanel</span>
            </div>
            <div class="hidden md:flex gap-6 text-sm font-medium text-slate-500">
                <a href="#" class="text-blue-600 border-b-2 border-blue-600 pb-1">Home</a>
                <a href="#" class="hover:text-slate-800 transition">Domains</a>
                <a href="#" class="hover:text-slate-800 transition">Security</a>
                <a href="#" class="hover:text-slate-800 transition">Metrics</a>
            </div>
        </div>
        <div class="flex items-center gap-4">
            <button class="p-2 bg-slate-100 text-slate-600 rounded-full hover:bg-slate-200 transition"><i data-lucide="bell" class="w-5"></i></button>
            <div class="w-px h-6 bg-slate-200"></div>
            <span class="text-sm font-semibold text-slate-700"><?=$_SESSION['client']?></span>
            <a href="/logout.php" class="p-2 bg-red-50 text-red-500 rounded-full hover:bg-red-100 transition"><i data-lucide="log-out" class="w-5"></i></a>
        </div>
    </nav>

    <main class="max-w-7xl mx-auto p-8">
        <!-- Hero Welcome -->
        <div class="bg-blue-600 rounded-3xl p-10 text-white mb-10 relative overflow-hidden shadow-2xl shadow-blue-200">
            <div class="relative z-10">
                <h2 class="text-3xl font-bold">Hello, <?=$_SESSION['client']?>!</h2>
                <p class="text-blue-100 mt-2 text-lg">Manage your websites, files, and databases from your portal.</p>
                <div class="mt-8 flex gap-4">
                    <a href="http://filemanager.vivzon.cloud" class="px-6 py-3 bg-white/20 hover:bg-white/30 backdrop-blur-md rounded-xl font-bold transition flex items-center gap-2">
                        <i data-lucide="folder" class="w-5"></i> Open File Manager
                    </a>
                </div>
            </div>
            <!-- Decorative circle -->
            <div class="absolute -right-20 -bottom-20 w-80 h-80 bg-blue-500 rounded-full blur-3xl opacity-50"></div>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
            <!-- App Grid -->
            <div class="lg:col-span-2 space-y-8">
                <div>
                    <h3 class="text-xl font-bold mb-4 text-slate-800">Popular Apps</h3>
                    <div class="grid grid-cols-2 sm:grid-cols-4 gap-4">
                        <a href="http://filemanager.vivzon.cloud" class="bg-white p-6 rounded-2xl shadow-sm hover:shadow-md transition text-center group border">
                            <i data-lucide="folder-open" class="w-10 h-10 mx-auto text-orange-500 group-hover:scale-110 transition"></i>
                            <p class="mt-3 font-semibold text-slate-700">Files</p>
                        </a>
                        <a href="http://phpmyadmin.vivzon.cloud" class="bg-white p-6 rounded-2xl shadow-sm hover:shadow-md transition text-center group border">
                            <i data-lucide="database" class="w-10 h-10 mx-auto text-blue-500 group-hover:scale-110 transition"></i>
                            <p class="mt-3 font-semibold text-slate-700">MySQL</p>
                        </a>
                        <a href="http://webmail.vivzon.cloud" class="bg-white p-6 rounded-2xl shadow-sm hover:shadow-md transition text-center group border">
                            <i data-lucide="mail" class="w-10 h-10 mx-auto text-purple-500 group-hover:scale-110 transition"></i>
                            <p class="mt-3 font-semibold text-slate-700">Webmail</p>
                        </a>
                        <a href="#" class="bg-white p-6 rounded-2xl shadow-sm hover:shadow-md transition text-center group border">
                            <i data-lucide="shield-check" class="w-10 h-10 mx-auto text-emerald-500 group-hover:scale-110 transition"></i>
                            <p class="mt-3 font-semibold text-slate-700">SSL</p>
                        </a>
                    </div>
                </div>

                <div>
                    <h3 class="text-xl font-bold mb-4 text-slate-800">Your Active Domains</h3>
                    <div class="space-y-4">
                        <?php foreach($domains as $d): ?>
                        <div class="bg-white p-5 rounded-2xl border flex items-center justify-between shadow-sm">
                            <div class="flex items-center gap-4">
                                <div class="w-12 h-12 bg-slate-100 rounded-xl flex items-center justify-center text-slate-600"><i data-lucide="globe"></i></div>
                                <div><p class="font-bold text-slate-800"><?=$d['domain']?></p><p class="text-xs text-slate-400"><?=$d['document_root']?></p></div>
                            </div>
                            <div class="flex gap-2">
                                <button class="px-4 py-2 bg-slate-50 border rounded-lg text-sm font-semibold hover:bg-slate-100 transition">Settings</button>
                                <a href="http://<?=$d['domain']?>" target="_blank" class="p-2 bg-blue-50 text-blue-600 rounded-lg"><i data-lucide="external-link" class="w-4"></i></a>
                            </div>
                        </div>
                        <?php endforeach; ?>
                    </div>
                </div>
            </div>

            <!-- Stats Sidebar -->
            <div class="space-y-6">
                <div class="bg-white p-6 rounded-3xl shadow-sm border">
                    <h3 class="font-bold text-slate-800 mb-6">Resource Usage</h3>
                    <div class="space-y-6">
                        <div>
                            <div class="flex justify-between text-sm mb-2"><span>Disk Space</span><span class="font-bold">450MB / 2GB</span></div>
                            <div class="w-full h-2 bg-slate-100 rounded-full"><div class="w-[22%] h-full bg-blue-500 rounded-full"></div></div>
                        </div>
                        <div>
                            <div class="flex justify-between text-sm mb-2"><span>Bandwidth</span><span class="font-bold">12.5GB / 50GB</span></div>
                            <div class="w-full h-2 bg-slate-100 rounded-full"><div class="w-[25%] h-full bg-emerald-500 rounded-full"></div></div>
                        </div>
                        <div>
                            <div class="flex justify-between text-sm mb-2"><span>Mailboxes</span><span class="font-bold">2 / 5</span></div>
                            <div class="w-full h-2 bg-slate-100 rounded-full"><div class="w-[40%] h-full bg-orange-500 rounded-full"></div></div>
                        </div>
                    </div>
                </div>

                <div class="bg-slate-900 rounded-3xl p-6 text-white text-center">
                    <i data-lucide="award" class="w-12 h-12 mx-auto text-yellow-400 mb-4"></i>
                    <h4 class="font-bold">Starter Package</h4>
                    <p class="text-slate-400 text-xs mt-2">Need more power? Upgrade to Business for unlimited resources.</p>
                    <button class="w-full mt-6 py-3 bg-blue-600 rounded-xl font-bold hover:bg-blue-500 transition">Upgrade Now</button>
                </div>
            </div>
        </div>
    </main>

    <script>lucide.createIcons();</script>
</body>
</html>
