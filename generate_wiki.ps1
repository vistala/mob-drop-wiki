# Mob Drop Item Wiki Generator
# mob_drop_item.txt dosyasini okur ve wiki HTML sayfasi olusturur

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$inputFile = "..\..\Harbi2_Files\srv1\share\locale\germany\mob_drop_item.txt"
$inputPath = Join-Path $scriptDir $inputFile
$outputPath = Join-Path $scriptDir "index.html"

if (-not (Test-Path $inputPath)) {
    Write-Host "HATA: mob_drop_item.txt bulunamadi: $inputPath" -ForegroundColor Red
    exit 1
}

Write-Host "Dosya okunuyor: $inputPath"

$lines = Get-Content $inputPath -Encoding UTF8
$groups = @()
$currentGroup = $null
$inGroup = $false

foreach ($line in $lines) {
    $trimmed = $line.Trim()
    
    # Yorum satirlarini atla
    if ($trimmed.StartsWith("#")) { continue }
    if ($trimmed -eq "") { continue }
    
    if ($trimmed -match "^Group\s+(.+)$") {
        $currentGroup = @{
            GroupName = $Matches[1]
            MobVnum = ""
            MobName = ""
            Type = ""
            Items = @()
        }
        continue
    }
    
    if ($trimmed -eq "{") {
        $inGroup = $true
        continue
    }
    
    if ($trimmed -eq "}") {
        $inGroup = $false
        if ($currentGroup) {
            $groups += $currentGroup
            $currentGroup = $null
        }
        continue
    }
    
    if ($inGroup -and $currentGroup) {
        # Mob satiri
        if ($trimmed -match "^Mob\s+(\d+)") {
            $currentGroup.MobVnum = $Matches[1]
            # -- sonrasi mob adi
            if ($trimmed -match "--\s*(.+)$") {
                $currentGroup.MobName = $Matches[1].Trim()
            } else {
                $currentGroup.MobName = "Mob $($Matches[1])"
            }
            continue
        }
        
        # Type satiri
        if ($trimmed -match "^Type\s+(.+)$") {
            $currentGroup.Type = $Matches[1]
            continue
        }
        
        # Item satiri: index vnum count chance -- name
        if ($trimmed -match "^\d+\s+(\d+)\s+(\d+)\s+(\d+)") {
            $itemVnum = $Matches[1]
            $itemCount = $Matches[2]
            $itemChance = $Matches[3]
            $itemName = ""
            if ($trimmed -match "--\s*(.+)$") {
                $itemName = $Matches[1].Trim()
            } else {
                $itemName = "Item $itemVnum"
            }
            $currentGroup.Items += @{
                Vnum = $itemVnum
                Count = $itemCount
                Chance = $itemChance
                Name = $itemName
            }
        }
    }
}

Write-Host "$($groups.Count) grup bulundu."

# HTML olustur
$htmlItems = ""
$sidebarItems = ""
$groupIndex = 0

foreach ($g in $groups) {
    $groupIndex++
    $mobLabel = if ($g.MobName) { "$($g.MobName) ($($g.MobVnum))" } else { "Mob $($g.MobVnum)" }
    $cardId = "mob-$($g.MobVnum)"
    
    # Sidebar item
    $activeClass = if ($groupIndex -eq 1) { " active" } else { "" }
    $sidebarItems += "                    <button class=`"w-cat-btn$activeClass`" data-target=`"$cardId`">$($g.MobName)</button>`n"
    
    # Drop list
    $dropListHtml = ""
    foreach ($item in $g.Items) {
        $chanceBadge = ""
        $chanceVal = [int]$item.Chance
        if ($chanceVal -ge 80) {
            $chanceBadge = "<span class=`"chance-badge chance-high`">%$($item.Chance)</span>"
        } elseif ($chanceVal -ge 30) {
            $chanceBadge = "<span class=`"chance-badge chance-mid`">%$($item.Chance)</span>"
        } elseif ($chanceVal -ge 10) {
            $chanceBadge = "<span class=`"chance-badge chance-low`">%$($item.Chance)</span>"
        } else {
            $chanceBadge = "<span class=`"chance-badge chance-rare`">%$($item.Chance)</span>"
        }
        
        $countBadge = ""
        if ([int]$item.Count -gt 1) {
            $countBadge = "<span class=`"count-badge`">x$($item.Count)</span>"
        }
        
        $dropListHtml += "                            <li><i class=`"fas fa-caret-right`"></i> <span class=`"item-name`">$($item.Name)</span> $countBadge $chanceBadge <span class=`"vnum-tag`">#$($item.Vnum)</span></li>`n"
    }
    
    $displayStyle = if ($groupIndex -eq 1) { "" } else { " style=`"display:none;`"" }
    
    $htmlItems += @"
                    <div class="wiki-card" id="$cardId"$displayStyle>
                        <div class="w-card-header">
                            <div class="w-icon"><i class="fas fa-gem"></i></div>
                            <div>
                                <div class="w-title">$($g.MobName)</div>
                                <div class="w-type">VNUM: $($g.MobVnum) &bull; Tip: $($g.Type)</div>
                            </div>
                        </div>
                        <div class="w-drop-header">
                            <span>Eşya Adı</span>
                            <span>Şans</span>
                        </div>
                        <ul class="w-drop-list">
$dropListHtml                        </ul>
                        <div class="w-card-footer">
                            <span class="drop-count"><i class="fas fa-layer-group"></i> $($g.Items.Count) eşya</span>
                        </div>
                    </div>

"@
}

$html = @"
<!DOCTYPE html>
<html lang="tr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Mob Drop Wiki - Harbi2</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Cinzel:wght@400;700&family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <style>
        :root {
            --bg-base: #0a0a10;
            --bg-pane: #0e0e18;
            --bg-card: #14142a;
            --bg-sidebar: #0c0c1a;
            --bg-glass: rgba(20, 20, 42, 0.9);

            --text-high: #e8e8f0;
            --text-med: #a0a0c0;
            --text-low: #606080;

            --brand-red: #d31a1a;
            --brand-gold: #c99c30;
            --accent-blue: #4a7cff;
            --accent-cyan: #22d3ee;

            --border-glass: rgba(255, 255, 255, 0.06);
            --border-red: rgba(211, 26, 26, 0.3);

            --font-head: 'Cinzel', serif;
            --font-body: 'Inter', sans-serif;
            --sidebar-width: 280px;
        }

        * { margin: 0; padding: 0; box-sizing: border-box; }
        html { scroll-behavior: smooth; }
        body {
            font-family: var(--font-body);
            background: var(--bg-base);
            color: var(--text-high);
            min-height: 100vh;
        }

        /* ========== SIDEBAR ========== */
        .sidebar {
            position: fixed;
            top: 0;
            left: 0;
            width: var(--sidebar-width);
            height: 100vh;
            background: var(--bg-sidebar);
            border-right: 1px solid var(--border-glass);
            display: flex;
            flex-direction: column;
            z-index: 100;
            overflow: hidden;
        }

        .sidebar-brand {
            padding: 1.5rem;
            border-bottom: 1px solid var(--border-glass);
            text-align: center;
        }

        .sidebar-brand h2 {
            font-family: var(--font-head);
            font-size: 1rem;
            color: var(--brand-gold);
            letter-spacing: 2px;
        }

        .sidebar-brand p {
            font-size: 0.7rem;
            color: var(--text-low);
            margin-top: 0.25rem;
        }

        .sidebar-search {
            padding: 1rem 1.25rem;
            border-bottom: 1px solid var(--border-glass);
        }

        .sidebar-search input {
            width: 100%;
            padding: 0.6rem 1rem;
            background: rgba(255,255,255,0.04);
            border: 1px solid var(--border-glass);
            border-radius: 6px;
            color: var(--text-high);
            font-size: 0.8rem;
            outline: none;
            transition: border-color 0.3s;
        }

        .sidebar-search input:focus {
            border-color: var(--accent-blue);
        }

        .sidebar-search input::placeholder {
            color: var(--text-low);
        }

        .sidebar-nav {
            flex: 1;
            overflow-y: auto;
            padding: 0.5rem 0;
        }

        .sidebar-nav::-webkit-scrollbar {
            width: 4px;
        }

        .sidebar-nav::-webkit-scrollbar-track {
            background: transparent;
        }

        .sidebar-nav::-webkit-scrollbar-thumb {
            background: rgba(255,255,255,0.1);
            border-radius: 4px;
        }

        .w-cat-btn {
            display: block;
            width: 100%;
            text-align: left;
            padding: 0.65rem 1.5rem;
            background: none;
            border: none;
            border-left: 3px solid transparent;
            color: var(--text-med);
            font-family: var(--font-body);
            font-size: 0.78rem;
            cursor: pointer;
            transition: all 0.2s;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
        }

        .w-cat-btn:hover {
            background: rgba(255, 255, 255, 0.03);
            color: var(--text-high);
        }

        .w-cat-btn.active {
            background: linear-gradient(90deg, rgba(74, 124, 255, 0.12), transparent);
            border-left-color: var(--accent-blue);
            color: var(--text-high);
            font-weight: 600;
        }

        .sidebar-footer {
            padding: 1rem 1.5rem;
            border-top: 1px solid var(--border-glass);
            font-size: 0.65rem;
            color: var(--text-low);
            text-align: center;
        }

        /* ========== MAIN CONTENT ========== */
        .main-content {
            margin-left: var(--sidebar-width);
            min-height: 100vh;
        }

        .page-header {
            padding: 3rem 3rem 2rem;
            border-bottom: 1px solid var(--border-glass);
            background: linear-gradient(180deg, rgba(74, 124, 255, 0.05), transparent);
        }

        .page-header .sub-tag {
            display: inline-block;
            padding: 0.25rem 0.75rem;
            border: 1px solid var(--border-red);
            border-radius: 50px;
            font-size: 0.7rem;
            color: var(--brand-red);
            text-transform: uppercase;
            letter-spacing: 1px;
            margin-bottom: 0.75rem;
        }

        .page-header h1 {
            font-family: var(--font-head);
            font-size: 1.8rem;
            color: var(--text-high);
            letter-spacing: 2px;
        }

        .page-header p {
            color: var(--text-med);
            font-size: 0.85rem;
            margin-top: 0.5rem;
        }

        .stats-bar {
            display: flex;
            gap: 2rem;
            margin-top: 1rem;
        }

        .stat-item {
            display: flex;
            align-items: center;
            gap: 0.5rem;
            font-size: 0.8rem;
            color: var(--text-low);
        }

        .stat-item i {
            color: var(--accent-blue);
        }

        .stat-item strong {
            color: var(--text-high);
        }

        .content-area {
            padding: 2rem 3rem 4rem;
        }

        /* ========== WIKI CARD ========== */
        .wiki-card {
            background: var(--bg-card);
            border: 1px solid var(--border-glass);
            border-radius: 8px;
            margin-bottom: 1.5rem;
            overflow: hidden;
            transition: border-color 0.3s, box-shadow 0.3s;
        }

        .wiki-card:hover {
            border-color: rgba(74, 124, 255, 0.2);
            box-shadow: 0 4px 20px rgba(0, 0, 0, 0.3);
        }

        .w-card-header {
            display: flex;
            align-items: center;
            gap: 1rem;
            padding: 1.25rem 1.5rem;
            background: linear-gradient(135deg, rgba(74, 124, 255, 0.08), transparent);
            border-bottom: 1px solid var(--border-glass);
        }

        .w-icon {
            width: 42px;
            height: 42px;
            border-radius: 8px;
            background: rgba(74, 124, 255, 0.15);
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 1.1rem;
            color: var(--accent-blue);
            flex-shrink: 0;
        }

        .w-title {
            font-family: var(--font-head);
            font-size: 1rem;
            color: var(--text-high);
            letter-spacing: 1px;
        }

        .w-type {
            font-size: 0.7rem;
            color: var(--text-low);
            margin-top: 2px;
        }

        .w-drop-header {
            display: flex;
            justify-content: space-between;
            padding: 0.5rem 1.5rem;
            font-size: 0.65rem;
            text-transform: uppercase;
            letter-spacing: 1px;
            color: var(--text-low);
            border-bottom: 1px solid var(--border-glass);
            background: rgba(0,0,0,0.2);
        }

        .w-drop-list {
            list-style: none;
            padding: 0.5rem 0;
            max-height: 450px;
            overflow-y: auto;
        }

        .w-drop-list::-webkit-scrollbar {
            width: 4px;
        }

        .w-drop-list::-webkit-scrollbar-thumb {
            background: rgba(255,255,255,0.1);
            border-radius: 4px;
        }

        .w-drop-list li {
            display: flex;
            align-items: center;
            gap: 0.5rem;
            padding: 0.45rem 1.5rem;
            font-size: 0.82rem;
            color: var(--text-med);
            transition: background 0.15s;
            border-bottom: 1px solid rgba(255,255,255,0.02);
        }

        .w-drop-list li:last-child {
            border-bottom: none;
        }

        .w-drop-list li:hover {
            background: rgba(255, 255, 255, 0.03);
        }

        .w-drop-list li i {
            color: var(--accent-blue);
            font-size: 0.6rem;
            flex-shrink: 0;
        }

        .item-name {
            flex: 1;
            min-width: 0;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
        }

        .count-badge {
            background: rgba(74, 124, 255, 0.15);
            color: var(--accent-blue);
            font-size: 0.65rem;
            font-weight: 600;
            padding: 1px 6px;
            border-radius: 3px;
            flex-shrink: 0;
        }

        .chance-badge {
            font-size: 0.65rem;
            font-weight: 600;
            padding: 1px 6px;
            border-radius: 3px;
            flex-shrink: 0;
            min-width: 36px;
            text-align: center;
        }

        .chance-high {
            background: rgba(34, 197, 94, 0.15);
            color: #22c55e;
        }

        .chance-mid {
            background: rgba(234, 179, 8, 0.15);
            color: #eab308;
        }

        .chance-low {
            background: rgba(249, 115, 22, 0.15);
            color: #f97316;
        }

        .chance-rare {
            background: rgba(239, 68, 68, 0.15);
            color: #ef4444;
        }

        .vnum-tag {
            font-size: 0.6rem;
            color: var(--text-low);
            opacity: 0.5;
            flex-shrink: 0;
        }

        .w-card-footer {
            padding: 0.6rem 1.5rem;
            border-top: 1px solid var(--border-glass);
            background: rgba(0,0,0,0.15);
        }

        .drop-count {
            font-size: 0.7rem;
            color: var(--text-low);
        }

        .drop-count i {
            color: var(--accent-blue);
            margin-right: 4px;
        }

        /* ========== MOBILE ========== */
        .mobile-bar {
            display: none;
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            height: 56px;
            background: var(--bg-sidebar);
            border-bottom: 1px solid var(--border-glass);
            z-index: 200;
            align-items: center;
            justify-content: space-between;
            padding: 0 1rem;
        }

        .mobile-bar h3 {
            font-family: var(--font-head);
            font-size: 0.85rem;
            color: var(--brand-gold);
        }

        .mobile-bar button {
            background: none;
            border: none;
            color: var(--brand-gold);
            font-size: 1.3rem;
            cursor: pointer;
        }

        @media (max-width: 768px) {
            .sidebar {
                transform: translateX(-100%);
                transition: transform 0.3s;
            }

            .sidebar.open {
                transform: translateX(0);
            }

            .main-content {
                margin-left: 0;
            }

            .mobile-bar {
                display: flex;
            }

            .page-header {
                padding-top: calc(56px + 2rem);
            }

            .page-header h1 {
                font-size: 1.3rem;
            }

            .content-area {
                padding: 1.5rem 1rem;
            }

            .w-card-header {
                padding: 1rem;
            }

            .w-drop-list li {
                padding: 0.4rem 1rem;
                font-size: 0.78rem;
            }
        }

        /* Backdrop for mobile */
        .sidebar-backdrop {
            display: none;
            position: fixed;
            inset: 0;
            background: rgba(0,0,0,0.6);
            z-index: 99;
        }

        .sidebar-backdrop.show {
            display: block;
        }

        /* No results */
        .no-results {
            text-align: center;
            padding: 3rem;
            color: var(--text-low);
            font-size: 0.9rem;
        }
    </style>
</head>
<body>

    <!-- Mobile Bar -->
    <div class="mobile-bar">
        <h3><i class="fas fa-gem"></i> MOB DROP WİKİ</h3>
        <button id="mobile-menu-btn"><i class="fas fa-bars"></i></button>
    </div>

    <!-- Sidebar Backdrop -->
    <div class="sidebar-backdrop" id="sidebar-backdrop"></div>

    <!-- Sidebar -->
    <aside class="sidebar" id="sidebar">
        <div class="sidebar-brand">
            <h2><i class="fas fa-gem"></i> MOB DROP</h2>
            <p>Metin Taşı Drop Rehberi</p>
        </div>
        <div class="sidebar-search">
            <input type="text" id="search-input" placeholder="Mob veya eşya ara...">
        </div>
        <nav class="sidebar-nav" id="sidebar-nav">
$sidebarItems
        </nav>
        <div class="sidebar-footer">
            <p>mob_drop_item.txt verilerinden oluşturuldu</p>
        </div>
    </aside>

    <!-- Main -->
    <main class="main-content">
        <div class="page-header">
            <span class="sub-tag">Detaylı Rehber</span>
            <h1>MOB DROP WİKİ</h1>
            <p>Metin taşları ve mobların düşürdüğü tüm eşyaların listesi.</p>
            <div class="stats-bar">
                <div class="stat-item"><i class="fas fa-layer-group"></i> Toplam: <strong>$($groups.Count)</strong> Mob</div>
                <div class="stat-item"><i class="fas fa-gem"></i> Kaynak: <strong>mob_drop_item.txt</strong></div>
            </div>
        </div>

        <div class="content-area" id="content-area">
$htmlItems
        </div>
    </main>

    <script>
        // Sidebar navigation
        const catBtns = document.querySelectorAll('.w-cat-btn');
        const wikiCards = document.querySelectorAll('.wiki-card');
        
        catBtns.forEach(btn => {
            btn.addEventListener('click', () => {
                catBtns.forEach(b => b.classList.remove('active'));
                btn.classList.add('active');

                const targetId = btn.getAttribute('data-target');
                wikiCards.forEach(card => {
                    card.style.display = card.id === targetId ? '' : 'none';
                });

                // Close mobile sidebar
                document.getElementById('sidebar').classList.remove('open');
                document.getElementById('sidebar-backdrop').classList.remove('show');

                // Scroll to top of content
                document.querySelector('.content-area').scrollIntoView({ behavior: 'smooth', block: 'start' });
            });
        });

        // Search
        const searchInput = document.getElementById('search-input');
        searchInput.addEventListener('input', (e) => {
            const query = e.target.value.toLowerCase().trim();
            
            if (query === '') {
                // Show only the active one
                const activeBtn = document.querySelector('.w-cat-btn.active');
                const activeTarget = activeBtn ? activeBtn.getAttribute('data-target') : '';
                wikiCards.forEach(card => {
                    card.style.display = card.id === activeTarget ? '' : 'none';
                });
                catBtns.forEach(b => b.style.display = '');
                return;
            }

            // Show all matching cards, filter sidebar
            let anyMatch = false;
            wikiCards.forEach(card => {
                const text = card.textContent.toLowerCase();
                if (text.includes(query)) {
                    card.style.display = '';
                    anyMatch = true;
                } else {
                    card.style.display = 'none';
                }
            });

            catBtns.forEach(btn => {
                const btnText = btn.textContent.toLowerCase();
                const targetCard = document.getElementById(btn.getAttribute('data-target'));
                if (btnText.includes(query) || (targetCard && targetCard.style.display !== 'none')) {
                    btn.style.display = '';
                } else {
                    btn.style.display = 'none';
                }
            });
        });

        // Mobile menu
        document.getElementById('mobile-menu-btn').addEventListener('click', () => {
            document.getElementById('sidebar').classList.toggle('open');
            document.getElementById('sidebar-backdrop').classList.toggle('show');
        });

        document.getElementById('sidebar-backdrop').addEventListener('click', () => {
            document.getElementById('sidebar').classList.remove('open');
            document.getElementById('sidebar-backdrop').classList.remove('show');
        });
    </script>
</body>
</html>
"@

[System.IO.File]::WriteAllText($outputPath, $html, [System.Text.Encoding]::UTF8)
Write-Host "Wiki sayfasi olusturuldu: $outputPath" -ForegroundColor Green
Write-Host "Toplam $($groups.Count) mob grubu islendi."
