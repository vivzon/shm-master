<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Vivzon Cloud | Premium Hosting Solutions</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script src="https://unpkg.com/lucide@latest"></script>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;500;600;700;800&display=swap" rel="stylesheet">
    <style>
        body { font-family: 'Plus Jakarta Sans', sans-serif; }
        .glass { background: rgba(255, 255, 255, 0.03); backdrop-filter: blur(10px); border: 1px solid rgba(255, 255, 255, 0.05); }
        .hero-gradient { background: radial-gradient(circle at top right, #1e40af, #0f172a, #020617); }
    </style>
</head>
<body class="bg-[#020617] text-white overflow-x-hidden">

    <!-- Navigation -->
    <nav class="flex items-center justify-between px-8 py-6 max-w-7xl mx-auto relative z-50">
        <div class="flex items-center gap-2 text-2xl font-extrabold tracking-tighter">
            <div class="bg-blue-600 p-1 rounded-lg"><i data-lucide="cloud" class="w-6 h-6"></i></div>
            VIVZON <span class="text-blue-500 underline decoration-blue-500/30">CLOUD</span>
        </div>
        <div class="hidden md:flex gap-8 text-sm font-medium text-slate-400">
            <a href="http://client.vivzon.cloud" class="hover:text-white transition">Client Portal</a>
            <a href="http://webmail.vivzon.cloud" class="hover:text-white transition">Webmail</a>
            <a href="http://admin.vivzon.cloud" class="hover:text-white transition">Admin</a>
        </div>
        <a href="http://client.vivzon.cloud" class="bg-white text-black px-6 py-2.5 rounded-full font-bold text-sm hover:bg-blue-500 hover:text-white transition shadow-lg shadow-white/5">
            Get Started
        </a>
    </nav>

    <!-- Hero Section -->
    <section class="relative pt-20 pb-32 px-8 hero-gradient">
        <div class="max-w-7xl mx-auto text-center">
            <div class="inline-flex items-center gap-2 px-4 py-2 rounded-full glass text-blue-400 text-xs font-bold tracking-widest uppercase mb-8 border border-blue-500/20">
                <span class="relative flex h-2 w-2">
                  <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-blue-400 opacity-75"></span>
                  <span class="relative inline-flex rounded-full h-2 w-2 bg-blue-500"></span>
                </span>
                Next-Gen Hosting Infrastructure
            </div>
            <h1 class="text-5xl md:text-7xl font-extrabold tracking-tighter mb-6 bg-clip-text text-transparent bg-gradient-to-b from-white to-slate-500">
                High Performance <br> Shared Cloud Hosting.
            </h1>
            <p class="text-slate-400 text-lg md:text-xl max-w-2xl mx-auto mb-10 leading-relaxed">
                Experience ultra-fast loading speeds, hardened security, and an intuitive management panel built for developers and businesses.
            </p>
        </div>
    </section>

    <!-- Portal Grid (The Hub) -->
    <section class="px-8 -mt-24 relative z-20">
        <div class="max-w-7xl mx-auto grid grid-cols-1 md:grid-cols-3 gap-6">
            
            <!-- Card: Client Panel -->
            <a href="http://client.vivzon.cloud" class="glass p-8 rounded-[32px] group hover:bg-blue-600/10 hover:border-blue-500/50 transition-all duration-500">
                <div class="w-14 h-14 bg-blue-600 rounded-2xl flex items-center justify-center mb-6 shadow-xl shadow-blue-600/20 group-hover:scale-110 transition">
                    <i data-lucide="user" class="w-7 h-7"></i>
                </div>
                <h3 class="text-2xl font-bold mb-2">Client Portal</h3>
                <p class="text-slate-400 text-sm leading-relaxed mb-6">Manage your domains, databases, and hosting resources in one place.</p>
                <div class="flex items-center gap-2 text-blue-400 font-bold text-sm">
                    Enter Dashboard <i data-lucide="arrow-right" class="w-4 h-4"></i>
                </div>
            </a>

            <!-- Card: Webmail -->
            <a href="http://webmail.vivzon.cloud" class="glass p-8 rounded-[32px] group hover:bg-purple-600/10 hover:border-purple-500/50 transition-all duration-500">
                <div class="w-14 h-14 bg-purple-600 rounded-2xl flex items-center justify-center mb-6 shadow-xl shadow-purple-600/20 group-hover:scale-110 transition">
                    <i data-lucide="mail" class="w-7 h-7"></i>
                </div>
                <h3 class="text-2xl font-bold mb-2">Webmail Access</h3>
                <p class="text-slate-400 text-sm leading-relaxed mb-6">Access your professional business emails securely from any browser.</p>
                <div class="flex items-center gap-2 text-purple-400 font-bold text-sm">
                    Check Emails <i data-lucide="arrow-right" class="w-4 h-4"></i>
                </div>
            </a>

            <!-- Card: File Manager -->
            <a href="http://filemanager.vivzon.cloud" class="glass p-8 rounded-[32px] group hover:bg-emerald-600/10 hover:border-emerald-500/50 transition-all duration-500">
                <div class="w-14 h-14 bg-emerald-600 rounded-2xl flex items-center justify-center mb-6 shadow-xl shadow-emerald-600/20 group-hover:scale-110 transition">
                    <i data-lucide="folder-tree" class="w-7 h-7"></i>
                </div>
                <h3 class="text-2xl font-bold mb-2">Cloud Files</h3>
                <p class="text-slate-400 text-sm leading-relaxed mb-6">Upload and manage your website files with our powerful browser editor.</p>
                <div class="flex items-center gap-2 text-emerald-400 font-bold text-sm">
                    Manage Files <i data-lucide="arrow-right" class="w-4 h-4"></i>
                </div>
            </a>

        </div>
    </section>

    <!-- Secondary Links -->
    <section class="max-w-7xl mx-auto px-8 py-20">
        <div class="flex flex-wrap justify-center gap-4">
            <a href="http://phpmyadmin.vivzon.cloud" class="px-6 py-3 glass rounded-2xl hover:bg-slate-800 transition text-sm flex items-center gap-2">
                <i data-lucide="database" class="w-4 h-4 text-blue-500"></i> phpMyAdmin
            </a>
            <a href="http://admin.vivzon.cloud" class="px-6 py-3 glass rounded-2xl hover:bg-slate-800 transition text-sm flex items-center gap-2">
                <i data-lucide="shield-check" class="w-4 h-4 text-red-500"></i> WHM Admin
            </a>
        </div>
    </section>

    <!-- Footer -->
    <footer class="border-t border-slate-900 mt-20 py-12 px-8">
        <div class="max-w-7xl mx-auto flex flex-col md:flex-row justify-between items-center gap-8">
            <div class="text-slate-500 text-sm italic">
                &copy; 2025 Vivzon Cloud Infrastructure. All rights reserved.
            </div>
            <div class="flex gap-6 text-slate-500 text-sm">
                <a href="#" class="hover:text-white">Terms</a>
                <a href="#" class="hover:text-white">Privacy</a>
                <a href="mailto:admin@vivzon.cloud" class="hover:text-white">Support</a>
            </div>
        </div>
    </footer>

    <script>lucide.createIcons();</script>
</body>
</html>
