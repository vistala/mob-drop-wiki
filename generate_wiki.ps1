# =============================================================================
# Harbi2 Drop Wiki Generator
# mob_drop_item.txt + special_item_group.txt => index.html
# =============================================================================

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$mobDropFile = Join-Path $scriptDir "mob_drop_item.txt"
$chestDropFile = Join-Path $scriptDir "special_item_group.txt"
$outputPath = Join-Path $scriptDir "index.html"

# ======================== PARSER: mob_drop_item.txt ========================
function Parse-MobDropFile {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        Write-Host "UYARI: $Path bulunamadi" -ForegroundColor Yellow
        return @()
    }
    $lines = Get-Content $Path -Encoding UTF8
    $groups = @()
    $currentGroup = $null
    $inGroup = $false

    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ($trimmed.StartsWith("#") -or $trimmed -eq "") { continue }

        if ($trimmed -match "^Group\s+(.+)$") {
            $currentGroup = @{
                MobVnum = ""; MobName = ""; Type = ""; Items = @()
            }
            continue
        }
        if ($trimmed -eq "{") { $inGroup = $true; continue }
        if ($trimmed -eq "}") {
            $inGroup = $false
            if ($currentGroup -and $currentGroup.MobVnum) {
                $groups += $currentGroup
            }
            $currentGroup = $null
            continue
        }
        if ($inGroup -and $currentGroup) {
            if ($trimmed -match "^Mob\s+(\d+)") {
                $currentGroup.MobVnum = $Matches[1]
                if ($trimmed -match "--\s*(.+)$") {
                    $currentGroup.MobName = $Matches[1].Trim()
                } else {
                    $currentGroup.MobName = "Mob $($Matches[1])"
                }
                continue
            }
            if ($trimmed -match "^Type\s+(.+)$") {
                $currentGroup.Type = $Matches[1].Trim()
                continue
            }
            if ($trimmed -match "^\d+\s+(\d+)\s+(\d+)\s+(\d+)") {
                $itemVnum = $Matches[1]
                $itemCount = $Matches[2]
                $itemChance = $Matches[3]
                $itemName = ""
                if ($trimmed -match "--\s*(.+)$") { $itemName = $Matches[1].Trim() }
                else { $itemName = "Item $itemVnum" }
                $currentGroup.Items += @{
                    Vnum = $itemVnum; Count = $itemCount; Chance = $itemChance; Name = $itemName
                }
            }
        }
    }
    return $groups
}

# ======================== PARSER: special_item_group.txt ========================
function Parse-ChestDropFile {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        Write-Host "UYARI: $Path bulunamadi" -ForegroundColor Yellow
        return @()
    }
    $lines = Get-Content $Path -Encoding UTF8
    $groups = @()
    $currentGroup = $null
    $inGroup = $false

    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ($trimmed.StartsWith("#") -or $trimmed -eq "") { continue }

        if ($trimmed -match "^Group\s+(.+)$") {
            $currentGroup = @{
                GroupName = $Matches[1].Trim()
                ChestVnum = ""; ChestName = ""; Type = ""; Items = @()
            }
            continue
        }
        if ($trimmed -eq "{") { $inGroup = $true; continue }
        if ($trimmed -eq "}") {
            $inGroup = $false
            if ($currentGroup -and $currentGroup.ChestVnum -and $currentGroup.ChestName) {
                $groups += $currentGroup
            }
            $currentGroup = $null
            continue
        }
        if ($inGroup -and $currentGroup) {
            # Vnum line: "Vnum  38055 -- Yavrucuk Kutusu" or "Vnum  10050"
            if ($trimmed -match "^Vnum\s+(\d+)") {
                $currentGroup.ChestVnum = $Matches[1]
                if ($trimmed -match "--\s*(.+)$") {
                    $currentGroup.ChestName = $Matches[1].Trim()
                }
                continue
            }
            # Type line
            if ($trimmed -match "^[Tt]ype\s+(.+)$") {
                $currentGroup.Type = $Matches[1].Trim()
                continue
            }
            # Item line: index vnum chance count -- name
            if ($trimmed -match "^\d+\s+(\d+)\s+(\d[\d.]*)\s+(\d+)") {
                $itemVnum = $Matches[1]
                $rawChance = $Matches[2]
                $itemCount = $Matches[3]
                $itemName = ""
                if ($trimmed -match "--\s*(.+)$") { $itemName = $Matches[1].Trim() }
                else { $itemName = "Item $itemVnum" }
                
                # Remove % prefix from name if present
                if ($itemName -match "^%\d+\s+(.+)$") {
                    $itemName = $Matches[1].Trim()
                }

                $currentGroup.Items += @{
                    Vnum = $itemVnum; Count = $itemCount; Chance = $rawChance; Name = $itemName
                }
            }
        }
    }
    return $groups
}

# ======================== HTML HELPERS ========================
function Get-ChanceBadgeHtml {
    param([string]$ChanceStr, [bool]$IsChest = $false)
    $val = 0
    # Try parsing as integer first
    if ([int]::TryParse($ChanceStr, [ref]$val)) {
        if ($val -ge 80) { return "<span class=`"chance-badge chance-high`">%$val</span>" }
        elseif ($val -ge 30) { return "<span class=`"chance-badge chance-mid`">%$val</span>" }
        elseif ($val -ge 10) { return "<span class=`"chance-badge chance-low`">%$val</span>" }
        else { return "<span class=`"chance-badge chance-rare`">%$val</span>" }
    }
    # Fallback - just display the raw value
    return "<span class=`"chance-badge chance-mid`">$ChanceStr</span>"
}

function Get-ItemIconHtml {
    param([string]$Vnum)
    return "<img class=`"item-icon`" src=`"icons/$Vnum.png`" onerror=`"this.style.display='none';this.nextElementSibling.style.display='flex'`" alt=`"`"><span class=`"item-icon-fallback`"><i class=`"fas fa-cube`"></i></span>"
}

function Build-CardHtml {
    param($Entity, [string]$Category, [string]$IdPrefix, [bool]$Hidden = $true)
    $entityName = if ($Category -eq "mob") { $Entity.MobName } else { $Entity.ChestName }
    $entityVnum = if ($Category -eq "mob") { $Entity.MobVnum } else { $Entity.ChestVnum }
    $entityType = if ($Category -eq "mob") { $Entity.Type } else { $Entity.Type }
    $cardId = "$IdPrefix-$entityVnum"
    $iconClass = if ($Category -eq "mob") { "fas fa-dragon" } else { "fas fa-box-open" }
    $headerGrad = if ($Category -eq "mob") { "rgba(74, 124, 255, 0.08)" } else { "rgba(201, 156, 48, 0.08)" }
    $iconBg = if ($Category -eq "mob") { "rgba(74, 124, 255, 0.15)" } else { "rgba(201, 156, 48, 0.15)" }
    $iconColor = if ($Category -eq "mob") { "var(--accent-blue)" } else { "var(--brand-gold)" }
    $displayAttr = if ($Hidden) { " style=`"display:none;`"" } else { "" }
    $catLabel = if ($Category -eq "mob") { "Canavar" } else { "Sandık" }

    $dropListHtml = ""
    foreach ($item in $Entity.Items) {
        $chanceBadge = Get-ChanceBadgeHtml -ChanceStr $item.Chance
        $countBadge = ""
        $countVal = 0
        if ([int]::TryParse($item.Count, [ref]$countVal) -and $countVal -gt 1) {
            $countBadge = "<span class=`"count-badge`">x$($item.Count)</span>"
        }
        $iconHtml = Get-ItemIconHtml -Vnum $item.Vnum
        $dropListHtml += "                            <li>$iconHtml <span class=`"item-name`">$($item.Name)</span> $countBadge $chanceBadge <span class=`"vnum-tag`">#$($item.Vnum)</span></li>`n"
    }

    return @"
                    <div class="wiki-card" id="$cardId" data-category="$Category"$displayAttr>
                        <div class="w-card-header" style="background: linear-gradient(135deg, $headerGrad, transparent);">
                            <div class="w-icon" style="background: $iconBg; color: $iconColor;"><i class="$iconClass"></i></div>
                            <div>
                                <div class="w-title">$entityName</div>
                                <div class="w-type"><span class="cat-label cat-$Category">$catLabel</span> VNUM: $entityVnum</div>
                            </div>
                        </div>
                        <div class="w-drop-header">
                            <span><i class="fas fa-list"></i> Eşya Adı</span>
                            <span>Şans</span>
                        </div>
                        <ul class="w-drop-list">
$dropListHtml                        </ul>
                        <div class="w-card-footer">
                            <span class="drop-count"><i class="fas fa-layer-group"></i> $($Entity.Items.Count) eşya</span>
                        </div>
                    </div>

"@
}

# ======================== MAIN ========================
Write-Host "=== Harbi2 Drop Wiki Generator ===" -ForegroundColor Cyan

$mobGroups = Parse-MobDropFile -Path $mobDropFile
Write-Host "Canavarlar: $($mobGroups.Count) grup" -ForegroundColor Green

$chestGroups = Parse-ChestDropFile -Path $chestDropFile
Write-Host "Sandiklar: $($chestGroups.Count) grup" -ForegroundColor Green

# Build sidebar
$sidebarHtml = "                    <div class=`"sidebar-section`">`n"
$sidebarHtml += "                        <div class=`"sidebar-section-title`"><i class=`"fas fa-dragon`"></i> Canavarlar <span class=`"section-count`">$($mobGroups.Count)</span></div>`n"
$firstCard = $true
foreach ($g in $mobGroups) {
    $activeClass = if ($firstCard) { " active" } else { "" }
    $sidebarHtml += "                        <button class=`"w-cat-btn$activeClass`" data-target=`"mob-$($g.MobVnum)`" data-category=`"mob`">$($g.MobName)</button>`n"
    $firstCard = $false
}
$sidebarHtml += "                    </div>`n"
$sidebarHtml += "                    <div class=`"sidebar-section`">`n"
$sidebarHtml += "                        <div class=`"sidebar-section-title`"><i class=`"fas fa-box-open`"></i> Sandıklar <span class=`"section-count`">$($chestGroups.Count)</span></div>`n"
foreach ($g in $chestGroups) {
    $sidebarHtml += "                        <button class=`"w-cat-btn`" data-target=`"chest-$($g.ChestVnum)`" data-category=`"chest`">$($g.ChestName)</button>`n"
}
$sidebarHtml += "                    </div>`n"

# Build cards
$cardsHtml = ""
$isFirst = $true
foreach ($g in $mobGroups) {
    $cardsHtml += Build-CardHtml -Entity $g -Category "mob" -IdPrefix "mob" -Hidden (-not $isFirst)
    $isFirst = $false
}
foreach ($g in $chestGroups) {
    $cardsHtml += Build-CardHtml -Entity $g -Category "chest" -IdPrefix "chest" -Hidden $true
}

$totalMobs = $mobGroups.Count
$totalChests = $chestGroups.Count
$totalItems = 0
foreach ($g in $mobGroups) { $totalItems += $g.Items.Count }
foreach ($g in $chestGroups) { $totalItems += $g.Items.Count }

# ======================== FULL HTML ========================
$html = @"
<!DOCTYPE html>
<html lang="tr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Harbi2 Drop Wiki</title>
    <meta name="description" content="Harbi2 Metin2 - Canavar ve Sandık Drop Rehberi. Tüm mob dropları ve sandık içerikleri.">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Cinzel:wght@400;600;700&family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.0/css/all.min.css">
    <style>
        :root {
            --bg-base: #06060e;
            --bg-surface: #0c0c1a;
            --bg-card: #111128;
            --bg-card-hover: #161638;
            --bg-sidebar: #090918;
            --bg-input: rgba(255,255,255,0.03);

            --text-high: #eaeaf4;
            --text-med: #9898b8;
            --text-low: #555578;
            --text-muted: #3a3a58;

            --accent-blue: #6366f1;
            --accent-blue-dim: rgba(99,102,241,0.15);
            --accent-cyan: #22d3ee;
            --accent-gold: #f59e0b;
            --accent-gold-dim: rgba(245,158,11,0.15);
            --accent-red: #ef4444;
            --accent-green: #22c55e;
            --accent-purple: #a855f7;

            --brand-gold: #c99c30;
            --brand-red: #d31a1a;

            --border: rgba(255,255,255,0.06);
            --border-active: rgba(99,102,241,0.4);

            --radius-sm: 6px;
            --radius-md: 10px;
            --radius-lg: 14px;

            --shadow-card: 0 2px 12px rgba(0,0,0,0.25);
            --shadow-glow: 0 0 30px rgba(99,102,241,0.08);

            --font-display: 'Cinzel', serif;
            --font-body: 'Inter', sans-serif;
            --sidebar-w: 290px;

            --anim-fast: 0.15s;
            --anim-med: 0.3s;
        }

        * { margin: 0; padding: 0; box-sizing: border-box; }
        html { scroll-behavior: smooth; }

        body {
            font-family: var(--font-body);
            background: var(--bg-base);
            color: var(--text-high);
            min-height: 100vh;
            overflow-x: hidden;
        }

        /* ========== SCROLLBAR ========== */
        ::-webkit-scrollbar { width: 5px; }
        ::-webkit-scrollbar-track { background: transparent; }
        ::-webkit-scrollbar-thumb { background: rgba(255,255,255,0.08); border-radius: 10px; }
        ::-webkit-scrollbar-thumb:hover { background: rgba(255,255,255,0.15); }

        /* ========== SIDEBAR ========== */
        .sidebar {
            position: fixed; top: 0; left: 0;
            width: var(--sidebar-w); height: 100vh;
            background: var(--bg-sidebar);
            border-right: 1px solid var(--border);
            display: flex; flex-direction: column;
            z-index: 100;
            transition: transform var(--anim-med) ease;
        }

        .sidebar-header {
            padding: 1.5rem 1.25rem;
            border-bottom: 1px solid var(--border);
            background: linear-gradient(180deg, rgba(99,102,241,0.04), transparent);
        }

        .sidebar-logo {
            display: flex; align-items: center; gap: 0.75rem;
        }

        .logo-icon {
            width: 36px; height: 36px;
            border-radius: var(--radius-sm);
            background: var(--accent-blue-dim);
            display: flex; align-items: center; justify-content: center;
            color: var(--accent-blue); font-size: 0.95rem;
        }

        .logo-text h2 {
            font-family: var(--font-display);
            font-size: 0.9rem; color: var(--brand-gold);
            letter-spacing: 3px;
        }

        .logo-text p {
            font-size: 0.62rem; color: var(--text-low);
            letter-spacing: 1px; margin-top: 1px;
        }

        /* Search */
        .sidebar-search { padding: 0.75rem 1rem; }

        .search-box {
            position: relative;
        }

        .search-box i {
            position: absolute; left: 0.75rem; top: 50%;
            transform: translateY(-50%);
            color: var(--text-low); font-size: 0.75rem;
            pointer-events: none;
            transition: color var(--anim-fast);
        }

        .search-box input {
            width: 100%; padding: 0.55rem 0.75rem 0.55rem 2.1rem;
            background: var(--bg-input);
            border: 1px solid var(--border);
            border-radius: var(--radius-sm);
            color: var(--text-high); font-size: 0.78rem;
            font-family: var(--font-body);
            outline: none;
            transition: border-color var(--anim-med), background var(--anim-med);
        }

        .search-box input:focus {
            border-color: var(--border-active);
            background: rgba(99,102,241,0.04);
        }

        .search-box input:focus + i, .search-box input:focus ~ i {
            color: var(--accent-blue);
        }

        .search-box input::placeholder { color: var(--text-muted); }

        /* Search mode toggle */
        .search-mode-toggle {
            display: flex; gap: 2px;
            padding: 0.4rem 1rem 0;
        }

        .search-mode-btn {
            flex: 1; padding: 0.35rem;
            background: transparent;
            border: 1px solid var(--border);
            color: var(--text-low);
            font-size: 0.65rem; font-family: var(--font-body);
            cursor: pointer;
            transition: all var(--anim-fast);
        }

        .search-mode-btn:first-child { border-radius: var(--radius-sm) 0 0 var(--radius-sm); }
        .search-mode-btn:last-child { border-radius: 0 var(--radius-sm) var(--radius-sm) 0; }

        .search-mode-btn.active {
            background: var(--accent-blue-dim);
            border-color: var(--border-active);
            color: var(--accent-blue);
            font-weight: 600;
        }

        .search-mode-btn i { margin-right: 3px; }

        /* Category filter */
        .category-filter {
            display: flex; gap: 2px;
            padding: 0.5rem 1rem 0.25rem;
        }

        .cat-filter-btn {
            flex: 1; padding: 0.35rem;
            background: transparent;
            border: 1px solid var(--border);
            color: var(--text-low);
            font-size: 0.65rem; font-family: var(--font-body);
            cursor: pointer;
            transition: all var(--anim-fast);
        }

        .cat-filter-btn:first-child { border-radius: var(--radius-sm) 0 0 var(--radius-sm); }
        .cat-filter-btn:nth-child(2) { border-radius: 0; }
        .cat-filter-btn:last-child { border-radius: 0 var(--radius-sm) var(--radius-sm) 0; }

        .cat-filter-btn.active {
            background: var(--accent-blue-dim);
            border-color: var(--border-active);
            color: var(--accent-blue);
            font-weight: 600;
        }

        .cat-filter-btn i { margin-right: 3px; }

        /* Sidebar Nav */
        .sidebar-nav {
            flex: 1; overflow-y: auto;
            padding: 0.25rem 0;
        }

        .sidebar-section { margin-bottom: 0.25rem; }

        .sidebar-section-title {
            padding: 0.6rem 1.25rem 0.35rem;
            font-size: 0.62rem;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 2px;
            color: var(--text-muted);
            display: flex; align-items: center; gap: 0.5rem;
            user-select: none;
        }

        .sidebar-section-title i { font-size: 0.6rem; }

        .section-count {
            margin-left: auto;
            background: rgba(255,255,255,0.05);
            padding: 1px 6px;
            border-radius: 10px;
            font-size: 0.58rem;
            font-weight: 500;
        }

        .w-cat-btn {
            display: block; width: 100%;
            text-align: left;
            padding: 0.5rem 1.25rem 0.5rem 1.75rem;
            background: none; border: none;
            border-left: 2px solid transparent;
            color: var(--text-med);
            font-family: var(--font-body);
            font-size: 0.75rem; font-weight: 400;
            cursor: pointer;
            transition: all var(--anim-fast);
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
        }

        .w-cat-btn:hover {
            background: rgba(255,255,255,0.02);
            color: var(--text-high);
            padding-left: 1.9rem;
        }

        .w-cat-btn.active {
            background: linear-gradient(90deg, rgba(99,102,241,0.1), transparent);
            border-left-color: var(--accent-blue);
            color: var(--text-high);
            font-weight: 600;
        }

        .sidebar-footer {
            padding: 0.75rem 1.25rem;
            border-top: 1px solid var(--border);
            font-size: 0.6rem; color: var(--text-muted);
            text-align: center;
        }

        /* ========== MAIN ========== */
        .main-content {
            margin-left: var(--sidebar-w);
            min-height: 100vh;
        }

        /* Hero */
        .page-hero {
            padding: 2.5rem 2.5rem 2rem;
            border-bottom: 1px solid var(--border);
            background:
                radial-gradient(ellipse at 20% 0%, rgba(99,102,241,0.06) 0%, transparent 60%),
                radial-gradient(ellipse at 80% 100%, rgba(245,158,11,0.04) 0%, transparent 50%);
        }

        .hero-tag {
            display: inline-flex; align-items: center; gap: 0.4rem;
            padding: 0.2rem 0.65rem;
            border: 1px solid rgba(99,102,241,0.25);
            border-radius: 50px;
            font-size: 0.62rem; color: var(--accent-blue);
            text-transform: uppercase; letter-spacing: 1.5px;
            margin-bottom: 0.75rem;
        }

        .hero-tag .dot {
            width: 5px; height: 5px;
            border-radius: 50%;
            background: var(--accent-green);
            animation: pulse 2s infinite;
        }

        @keyframes pulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.3; }
        }

        .page-hero h1 {
            font-family: var(--font-display);
            font-size: 1.6rem; font-weight: 700;
            color: var(--text-high);
            letter-spacing: 3px;
        }

        .page-hero p {
            color: var(--text-med);
            font-size: 0.82rem; margin-top: 0.4rem;
            font-weight: 300;
        }

        .stats-row {
            display: flex; gap: 1.5rem;
            margin-top: 1.25rem;
            flex-wrap: wrap;
        }

        .stat-chip {
            display: flex; align-items: center; gap: 0.5rem;
            padding: 0.45rem 0.85rem;
            background: var(--bg-surface);
            border: 1px solid var(--border);
            border-radius: var(--radius-sm);
            font-size: 0.72rem; color: var(--text-med);
        }

        .stat-chip i { font-size: 0.7rem; }
        .stat-chip .mob-icon { color: var(--accent-blue); }
        .stat-chip .chest-icon { color: var(--accent-gold); }
        .stat-chip .item-icon-stat { color: var(--accent-purple); }
        .stat-chip strong { color: var(--text-high); font-weight: 600; }

        /* Content */
        .content-area {
            padding: 1.5rem 2.5rem 4rem;
        }

        /* ========== WIKI CARD ========== */
        .wiki-card {
            background: var(--bg-card);
            border: 1px solid var(--border);
            border-radius: var(--radius-md);
            margin-bottom: 1.25rem;
            overflow: hidden;
            transition: border-color var(--anim-med), box-shadow var(--anim-med), transform var(--anim-fast);
        }

        .wiki-card:hover {
            border-color: rgba(99,102,241,0.2);
            box-shadow: var(--shadow-card), var(--shadow-glow);
            transform: translateY(-1px);
        }

        .w-card-header {
            display: flex; align-items: center; gap: 1rem;
            padding: 1.1rem 1.25rem;
            border-bottom: 1px solid var(--border);
        }

        .w-icon {
            width: 40px; height: 40px;
            border-radius: var(--radius-sm);
            display: flex; align-items: center; justify-content: center;
            font-size: 1rem;
            flex-shrink: 0;
        }

        .w-title {
            font-family: var(--font-display);
            font-size: 0.95rem; font-weight: 600;
            color: var(--text-high);
            letter-spacing: 1px;
        }

        .w-type {
            font-size: 0.68rem; color: var(--text-low);
            margin-top: 2px;
            display: flex; align-items: center; gap: 0.5rem;
        }

        .cat-label {
            display: inline-block;
            padding: 1px 6px;
            border-radius: 3px;
            font-size: 0.58rem;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 1px;
        }

        .cat-mob {
            background: var(--accent-blue-dim);
            color: var(--accent-blue);
        }

        .cat-chest {
            background: var(--accent-gold-dim);
            color: var(--accent-gold);
        }

        .w-drop-header {
            display: flex; justify-content: space-between;
            padding: 0.4rem 1.25rem;
            font-size: 0.6rem;
            text-transform: uppercase; letter-spacing: 1.5px;
            color: var(--text-muted);
            border-bottom: 1px solid var(--border);
            background: rgba(0,0,0,0.2);
        }

        .w-drop-header i { margin-right: 3px; }

        .w-drop-list {
            list-style: none;
            padding: 0.25rem 0;
            max-height: 500px;
            overflow-y: auto;
        }

        .w-drop-list li {
            display: flex; align-items: center; gap: 0.5rem;
            padding: 0.4rem 1.25rem;
            font-size: 0.78rem;
            color: var(--text-med);
            transition: background var(--anim-fast);
            border-bottom: 1px solid rgba(255,255,255,0.015);
        }

        .w-drop-list li:last-child { border-bottom: none; }
        .w-drop-list li:hover { background: rgba(255,255,255,0.025); }

        /* Item icon */
        .item-icon {
            width: 28px; height: 28px;
            border-radius: 4px;
            object-fit: contain;
            flex-shrink: 0;
            background: rgba(255,255,255,0.03);
            border: 1px solid var(--border);
        }

        .item-icon-fallback {
            width: 28px; height: 28px;
            border-radius: 4px;
            background: rgba(255,255,255,0.03);
            border: 1px solid var(--border);
            display: flex; align-items: center; justify-content: center;
            color: var(--text-muted);
            font-size: 0.6rem;
            flex-shrink: 0;
        }

        .item-name {
            flex: 1; min-width: 0;
            overflow: hidden; text-overflow: ellipsis;
            white-space: nowrap;
        }

        .count-badge {
            background: var(--accent-blue-dim);
            color: var(--accent-blue);
            font-size: 0.6rem; font-weight: 700;
            padding: 1px 5px; border-radius: 3px;
            flex-shrink: 0;
        }

        .chance-badge {
            font-size: 0.6rem; font-weight: 700;
            padding: 2px 6px; border-radius: 3px;
            flex-shrink: 0; min-width: 32px;
            text-align: center;
        }

        .chance-high { background: rgba(34,197,94,0.12); color: #22c55e; }
        .chance-mid { background: rgba(234,179,8,0.12); color: #eab308; }
        .chance-low { background: rgba(249,115,22,0.12); color: #f97316; }
        .chance-rare { background: rgba(239,68,68,0.12); color: #ef4444; }

        .vnum-tag {
            font-size: 0.55rem; color: var(--text-muted);
            flex-shrink: 0; font-family: monospace;
        }

        .w-card-footer {
            padding: 0.5rem 1.25rem;
            border-top: 1px solid var(--border);
            background: rgba(0,0,0,0.12);
        }

        .drop-count {
            font-size: 0.65rem; color: var(--text-low);
        }
        .drop-count i { color: var(--accent-blue); margin-right: 4px; }

        /* ========== MOBILE ========== */
        .mobile-topbar {
            display: none;
            position: fixed; top: 0; left: 0; right: 0;
            height: 52px;
            background: var(--bg-sidebar);
            border-bottom: 1px solid var(--border);
            z-index: 200;
            align-items: center;
            justify-content: space-between;
            padding: 0 1rem;
        }

        .mobile-topbar h3 {
            font-family: var(--font-display);
            font-size: 0.8rem; color: var(--brand-gold);
            letter-spacing: 2px;
        }

        .mobile-topbar button {
            background: none; border: none;
            color: var(--text-med); font-size: 1.2rem;
            cursor: pointer; padding: 0.25rem 0.5rem;
            border-radius: var(--radius-sm);
            transition: background var(--anim-fast);
        }

        .mobile-topbar button:hover { background: rgba(255,255,255,0.05); }

        @media (max-width: 768px) {
            .sidebar { transform: translateX(-100%); }
            .sidebar.open { transform: translateX(0); }
            .main-content { margin-left: 0; }
            .mobile-topbar { display: flex; }
            .page-hero { padding: calc(52px + 1.5rem) 1.25rem 1.5rem; }
            .page-hero h1 { font-size: 1.2rem; }
            .content-area { padding: 1rem; }
            .w-card-header { padding: 0.85rem 1rem; }
            .w-drop-list li { padding: 0.35rem 0.75rem; font-size: 0.74rem; }
            .stats-row { gap: 0.5rem; }
            .stat-chip { padding: 0.3rem 0.6rem; font-size: 0.65rem; }
        }

        .sidebar-backdrop {
            display: none; position: fixed; inset: 0;
            background: rgba(0,0,0,0.65); z-index: 99;
            backdrop-filter: blur(2px);
        }
        .sidebar-backdrop.show { display: block; }

        /* Empty state */
        .empty-state {
            display: none;
            text-align: center; padding: 4rem 2rem;
            color: var(--text-muted);
        }
        .empty-state i { font-size: 2.5rem; margin-bottom: 1rem; display: block; }
        .empty-state p { font-size: 0.85rem; }
    </style>
</head>
<body>

    <!-- Mobile -->
    <div class="mobile-topbar">
        <h3><i class="fas fa-scroll"></i> HARBİ2 WİKİ</h3>
        <button id="mobile-menu-btn" aria-label="Menu"><i class="fas fa-bars"></i></button>
    </div>
    <div class="sidebar-backdrop" id="sidebar-backdrop"></div>

    <!-- Sidebar -->
    <aside class="sidebar" id="sidebar">
        <div class="sidebar-header">
            <div class="sidebar-logo">
                <div class="logo-icon"><i class="fas fa-scroll"></i></div>
                <div class="logo-text">
                    <h2>HARBİ2</h2>
                    <p>DROP WİKİ</p>
                </div>
            </div>
        </div>

        <div class="sidebar-search">
            <div class="search-box">
                <input type="text" id="search-input" placeholder="Ara...">
                <i class="fas fa-search"></i>
            </div>
        </div>

        <div class="search-mode-toggle">
            <button class="search-mode-btn active" data-mode="entity" id="search-mode-entity">
                <i class="fas fa-crosshairs"></i> Mob/Sandık
            </button>
            <button class="search-mode-btn" data-mode="item" id="search-mode-item">
                <i class="fas fa-gem"></i> Eşya
            </button>
        </div>

        <div class="category-filter">
            <button class="cat-filter-btn active" data-filter="all" id="filter-all">
                <i class="fas fa-globe"></i> Tümü
            </button>
            <button class="cat-filter-btn" data-filter="mob" id="filter-mob">
                <i class="fas fa-dragon"></i> Mob
            </button>
            <button class="cat-filter-btn" data-filter="chest" id="filter-chest">
                <i class="fas fa-box-open"></i> Sandık
            </button>
        </div>

        <nav class="sidebar-nav" id="sidebar-nav">
$sidebarHtml
        </nav>

        <div class="sidebar-footer">
            <p>Otomatik oluşturuldu &bull; Harbi2 Drop Wiki</p>
        </div>
    </aside>

    <!-- Main -->
    <main class="main-content">
        <div class="page-hero">
            <span class="hero-tag"><span class="dot"></span> Güncel Veriler</span>
            <h1>DROP WİKİ</h1>
            <p>Canavar dropları ve sandık içeriklerinin detaylı rehberi.</p>
            <div class="stats-row">
                <div class="stat-chip"><i class="fas fa-dragon mob-icon"></i> <strong>$totalMobs</strong> Canavar</div>
                <div class="stat-chip"><i class="fas fa-box-open chest-icon"></i> <strong>$totalChests</strong> Sandık</div>
                <div class="stat-chip"><i class="fas fa-gem item-icon-stat"></i> <strong>$totalItems</strong> Eşya</div>
            </div>
        </div>

        <div class="content-area" id="content-area">
$cardsHtml
            <div class="empty-state" id="empty-state">
                <i class="fas fa-search"></i>
                <p>Sonuç bulunamadı.</p>
            </div>
        </div>
    </main>

    <script>
    (function() {
        const catBtns = document.querySelectorAll('.w-cat-btn');
        const wikiCards = document.querySelectorAll('.wiki-card');
        const searchInput = document.getElementById('search-input');
        const emptyState = document.getElementById('empty-state');
        let searchMode = 'entity'; // 'entity' or 'item'
        let categoryFilter = 'all'; // 'all', 'mob', 'chest'

        // --- Sidebar click ---
        catBtns.forEach(btn => {
            btn.addEventListener('click', () => {
                catBtns.forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
                searchInput.value = '';
                const targetId = btn.getAttribute('data-target');
                wikiCards.forEach(card => {
                    card.style.display = card.id === targetId ? '' : 'none';
                });
                emptyState.style.display = 'none';
                closeMobile();
                document.querySelector('.content-area').scrollIntoView({ behavior: 'smooth', block: 'start' });
            });
        });

        // --- Search ---
        searchInput.addEventListener('input', () => {
            const q = searchInput.value.toLowerCase().trim();
            if (!q) {
                resetToActive();
                return;
            }
            let anyVisible = false;
            wikiCards.forEach(card => {
                const cat = card.getAttribute('data-category');
                if (categoryFilter !== 'all' && cat !== categoryFilter) {
                    card.style.display = 'none';
                    return;
                }
                let match = false;
                if (searchMode === 'entity') {
                    const title = card.querySelector('.w-title');
                    if (title && title.textContent.toLowerCase().includes(q)) match = true;
                } else {
                    const items = card.querySelectorAll('.item-name');
                    items.forEach(item => {
                        if (item.textContent.toLowerCase().includes(q)) match = true;
                    });
                }
                card.style.display = match ? '' : 'none';
                if (match) anyVisible = true;
            });
            catBtns.forEach(btn => {
                const target = document.getElementById(btn.getAttribute('data-target'));
                btn.style.display = (target && target.style.display !== 'none') ? '' : 'none';
            });
            emptyState.style.display = anyVisible ? 'none' : 'block';
        });

        // --- Search mode toggle ---
        document.querySelectorAll('.search-mode-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                document.querySelectorAll('.search-mode-btn').forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
                searchMode = btn.getAttribute('data-mode');
                searchInput.placeholder = searchMode === 'entity' ? 'Mob veya sandık ara...' : 'Eşya adı ara...';
                searchInput.dispatchEvent(new Event('input'));
            });
        });

        // --- Category filter ---
        document.querySelectorAll('.cat-filter-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                document.querySelectorAll('.cat-filter-btn').forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
                categoryFilter = btn.getAttribute('data-filter');
                // Filter sidebar buttons
                catBtns.forEach(sb => {
                    const cat = sb.getAttribute('data-category');
                    sb.style.display = (categoryFilter === 'all' || cat === categoryFilter) ? '' : 'none';
                });
                // Filter section titles
                document.querySelectorAll('.sidebar-section').forEach(sec => {
                    const btnsInSec = sec.querySelectorAll('.w-cat-btn');
                    let anyVisible = false;
                    btnsInSec.forEach(b => { if (b.style.display !== 'none') anyVisible = true; });
                    sec.style.display = anyVisible ? '' : 'none';
                });
                // Re-trigger search or reset
                if (searchInput.value.trim()) {
                    searchInput.dispatchEvent(new Event('input'));
                } else {
                    // Show first visible card of active category
                    let found = false;
                    catBtns.forEach(b => b.classList.remove('active'));
                    wikiCards.forEach(card => {
                        const cat = card.getAttribute('data-category');
                        if (!found && (categoryFilter === 'all' || cat === categoryFilter)) {
                            card.style.display = '';
                            found = true;
                            const matchBtn = document.querySelector('[data-target="' + card.id + '"]');
                            if (matchBtn) matchBtn.classList.add('active');
                        } else {
                            card.style.display = 'none';
                        }
                    });
                    emptyState.style.display = found ? 'none' : 'block';
                }
            });
        });

        function resetToActive() {
            const activeBtn = document.querySelector('.w-cat-btn.active');
            const activeTarget = activeBtn ? activeBtn.getAttribute('data-target') : '';
            wikiCards.forEach(card => {
                card.style.display = card.id === activeTarget ? '' : 'none';
            });
            catBtns.forEach(b => {
                const cat = b.getAttribute('data-category');
                b.style.display = (categoryFilter === 'all' || cat === categoryFilter) ? '' : 'none';
            });
            document.querySelectorAll('.sidebar-section').forEach(sec => {
                const btnsInSec = sec.querySelectorAll('.w-cat-btn');
                let anyVisible = false;
                btnsInSec.forEach(b => { if (b.style.display !== 'none') anyVisible = true; });
                sec.style.display = anyVisible ? '' : 'none';
            });
            emptyState.style.display = 'none';
        }

        // --- Mobile ---
        document.getElementById('mobile-menu-btn').addEventListener('click', () => {
            document.getElementById('sidebar').classList.toggle('open');
            document.getElementById('sidebar-backdrop').classList.toggle('show');
        });
        document.getElementById('sidebar-backdrop').addEventListener('click', closeMobile);

        function closeMobile() {
            document.getElementById('sidebar').classList.remove('open');
            document.getElementById('sidebar-backdrop').classList.remove('show');
        }
    })();
    </script>
</body>
</html>
"@

[System.IO.File]::WriteAllText($outputPath, $html, [System.Text.Encoding]::UTF8)
Write-Host ""
Write-Host "Wiki olusturuldu: $outputPath" -ForegroundColor Green
Write-Host "  Canavarlar: $totalMobs | Sandiklar: $totalChests | Toplam Esya: $totalItems"
