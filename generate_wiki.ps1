# =============================================================================
# Harbi2 Drop Wiki Generator v3
# mob_drop_item.txt + special_item_group.txt => index.html
# Grid-based icon display with real item icons
# =============================================================================

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Source data: prefer full Harbi2_Files locale data on local machine,
# fall back to local copies when running in GitHub Actions / CI
$localSourceDir = "c:\Users\orkun\OneDrive\Documents\GitHub\Harbi2_Files\srv1\share\locale\germany"
if (Test-Path $localSourceDir) {
    $sourceDir = $localSourceDir
    Write-Host "Kaynak: Harbi2_Files yerel klasoru kullaniliyor" -ForegroundColor DarkGray
}
else {
    $sourceDir = $scriptDir
    Write-Host "Kaynak: Yerel kopya kullaniliyor (CI modu)" -ForegroundColor DarkYellow
}

$mobDropFile = Join-Path $sourceDir "mob_drop_item.txt"
$chestDropFile = Join-Path $sourceDir "special_item_group.txt"

# Output always goes to the local mob_drop_wiki folder
$outputPath = Join-Path $scriptDir "index.html"

# ======================== PARSER: mob_drop_item.txt ========================
function Parse-MobDropFile {
    param([string]$Path, [hashtable]$MobNames = @{}, [hashtable]$ItemNames = @{})
    if (-not (Test-Path $Path)) {
        Write-Host "UYARI: $Path bulunamadi" -ForegroundColor Yellow
        return @()
    }
    $lines = [System.IO.File]::ReadAllLines($Path, [System.Text.Encoding]::UTF8)
    $groups = @()
    $currentGroup = $null
    $inGroup = $false

    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ($trimmed.StartsWith("#") -or $trimmed -eq "") { continue }
        if ($trimmed -match "^Group\s+(.+)$") {
            $groupName = $Matches[1].Trim()
            $currentGroup = @{ MobVnum = ""; MobName = $groupName; Type = ""; Items = @() }
            continue
        }
        if ($trimmed -eq "{") { $inGroup = $true; continue }
        if ($trimmed -eq "}") {
            $inGroup = $false
            if ($currentGroup -and $currentGroup.MobVnum) { $groups += $currentGroup }
            $currentGroup = $null
            continue
        }
        if ($inGroup -and $currentGroup) {
            if ($trimmed -match "^Mob\s+(\d+)") {
                $vnum = $Matches[1]
                $currentGroup.MobVnum = $vnum
                # Always resolve mob name from mob_names.txt by VNUM
                if ($MobNames.ContainsKey($vnum)) {
                    $currentGroup.MobName = $MobNames[$vnum]
                }
                else {
                    $currentGroup.MobName = "Mob $vnum"
                }
                continue
            }
            if ($trimmed -match "^Type\s+(.+)$") { $currentGroup.Type = $Matches[1].Trim(); continue }
            if ($trimmed -match "^\d+\s+(\d+)\s+([\d.]+)\s+([\d.]+)") {
                $capVnum = $Matches[1]
                $capCount = $Matches[2]
                $capChance = $Matches[3]
                # Always resolve item name from item_names.txt by VNUM
                if ($ItemNames.ContainsKey($capVnum)) {
                    $itemName = $ItemNames[$capVnum]
                }
                else {
                    $itemName = "Item $capVnum"
                }
                $currentGroup.Items += @{
                    Vnum = $capVnum; Count = $capCount; Chance = $capChance; Name = $itemName
                }
            }
        }
    }
    return $groups
}

# ======================== PARSER: mob_proto.txt ========================
function Get-MobCategories {
    param([string]$Path)
    $catMap = @{}
    if (-not (Test-Path $Path)) { return $catMap }
    $lines = [System.IO.File]::ReadAllLines($Path, [System.Text.Encoding]::UTF8)
    foreach ($line in $lines) {
        $parts = $line.Split("`t")
        if ($parts.Count -ge 5 -and $parts[0] -match "^\d+$") {
            $vnum = $parts[0]
            $rank = $parts[2]
            $type = $parts[3]
            if ($rank -eq "BOSS") { $catMap[$vnum] = "Patronlar" }
            elseif ($type -eq "STONE") { $catMap[$vnum] = "Metinler" }
            else { $catMap[$vnum] = "Canavarlar" }
        }
    }
    return $catMap
}

# ======================== PARSER: item_names.txt ========================
function Get-ItemNames {
    param([string]$Path)
    $nameMap = @{}
    if (-not (Test-Path $Path)) { return $nameMap }
    $lines = [System.IO.File]::ReadAllLines($Path, [System.Text.Encoding]::UTF8)
    $firstLine = $true
    foreach ($line in $lines) {
        if ($firstLine) { $firstLine = $false; continue } # skip header
        $parts = $line.Split("`t")
        if ($parts.Count -ge 2 -and $parts[0] -match "^\d+$") {
            $nameMap[$parts[0].Trim()] = $parts[1].Trim()
        }
    }
    return $nameMap
}

# ======================== LOADER: mob_names.txt ========================
function Get-MobNames {
    param([string]$Path)
    $nameMap = @{}
    if (-not (Test-Path $Path)) { return $nameMap }
    $lines = [System.IO.File]::ReadAllLines($Path, [System.Text.Encoding]::UTF8)
    $firstLine = $true
    foreach ($line in $lines) {
        if ($firstLine) { $firstLine = $false; continue } # skip header
        $parts = $line.Split("`t")
        if ($parts.Count -ge 2 -and $parts[0] -match "^\d+$") {
            $nameMap[$parts[0].Trim()] = $parts[1].Trim()
        }
    }
    return $nameMap
}

# ======================== PARSER: special_item_group.txt ========================
function Parse-ChestDropFile {
    param([string]$Path, [hashtable]$ItemNames = @{})
    if (-not (Test-Path $Path)) {
        Write-Host "UYARI: $Path bulunamadi" -ForegroundColor Yellow
        return @()
    }
    $lines = [System.IO.File]::ReadAllLines($Path, [System.Text.Encoding]::UTF8)
    $groups = @()
    $currentGroup = $null
    $inGroup = $false

    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ($trimmed.StartsWith("#") -or $trimmed -eq "") { continue }
        if ($trimmed -match "^Group\s+(.+)$") {
            $currentGroup = @{ GroupName = $Matches[1].Trim(); ChestVnum = ""; ChestName = ""; Type = ""; Items = @() }
            continue
        }
        if ($trimmed -eq "{") { $inGroup = $true; continue }
        if ($trimmed -eq "}") {
            $inGroup = $false
            if ($currentGroup -and $currentGroup.ChestVnum) {
                # Resolve chest name: priority = inline comment > item_names.txt > cleaned GroupName
                if (-not $currentGroup.ChestName) {
                    if ($ItemNames.ContainsKey($currentGroup.ChestVnum)) {
                        $currentGroup.ChestName = $ItemNames[$currentGroup.ChestVnum]
                    }
                    else {
                        $currentGroup.ChestName = $currentGroup.GroupName -replace "_", " "
                    }
                }
                $groups += $currentGroup
            }
            $currentGroup = $null
            continue
        }
        if ($inGroup -and $currentGroup) {
            if ($trimmed -match "^Vnum\s+(\d+)") {
                $vstr = $Matches[1]
                $currentGroup.ChestVnum = $vstr
                # Always resolve chest name from item_names.txt by VNUM
                if ($ItemNames.ContainsKey($vstr)) {
                    $currentGroup.ChestName = $ItemNames[$vstr]
                }
                else {
                    $currentGroup.ChestName = "Sandik $vstr"
                }
                continue
            }
            if ($trimmed -match "^[Tt]ype\s+(.+)$") { $currentGroup.Type = $Matches[1].Trim(); continue }
            # Skip exp and mob lines
            if ($trimmed -match "^\d+\s+(exp|mob)\s+" ) { continue }
            if ($trimmed -match "^\d+\s+(\d+)\s+([\d.]+)\s+([\d.]+)") {
                $capVnum = $Matches[1]
                $capCount = $Matches[2]
                $capChance = $Matches[3]
                # Always resolve item name from item_names.txt by VNUM
                if ($ItemNames.ContainsKey($capVnum)) {
                    $itemName = $ItemNames[$capVnum]
                }
                else {
                    $itemName = "Item $capVnum"
                }
                $currentGroup.Items += @{
                    Vnum = $capVnum; Count = $capCount; Chance = $capChance; Name = $itemName
                }
            }
        }
    }

    # Apply custom chest chance calculation
    # Probability = item_chance / sum_of_all_chances * 100
    # Count does NOT affect probability, only how many you receive
    foreach ($g in $groups) {
        $totalChance = 0.0
        foreach ($item in $g.Items) {
            $ch = 0.0
            [double]::TryParse($item.Chance, [ref]$ch) | Out-Null
            $totalChance += $ch
        }
        if ($totalChance -gt 0) {
            foreach ($item in $g.Items) {
                $ch = 0.0
                [double]::TryParse($item.Chance, [ref]$ch) | Out-Null
                $realProb = ($ch / $totalChance) * 100.0
                $item.Chance = [math]::Round($realProb, 2).ToString("0.##")
            }
        }
    }

    return $groups
}

# ======================== HTML HELPERS ========================
function Get-ChanceBadgeClass {
    param([string]$ChanceStr)
    $val = 0.0
    if ([double]::TryParse($ChanceStr, [ref]$val)) {
        if ($val -ge 80) { return "chance-high" }
        elseif ($val -ge 30) { return "chance-mid" }
        elseif ($val -ge 10) { return "chance-low" }
        else { return "chance-rare" }
    }
    return "chance-mid"
}

function Build-GridItemHtml {
    param($Item)
    $iVnum = $Item.Vnum
    $iName = $Item.Name
    $iChance = $Item.Chance
    $iCount = $Item.Count
    $badgeClass = Get-ChanceBadgeClass -ChanceStr $iChance
    $countHtml = ""
    $countVal = 0
    if ([int]::TryParse($iCount, [ref]$countVal) -and $countVal -gt 1) {
        $countHtml = "<span class=`"grid-count`">x$iCount</span>"
    }
    # Truncate name for display (max ~12 chars)
    $shortName = $iName
    if ($shortName.Length -gt 14) { $shortName = $shortName.Substring(0, 12) + ".." }

    return @"
                                <div class="grid-item" title="$iName (#$iVnum)">
                                    <div class="grid-icon-wrap">
                                        <img class="grid-icon" src="icons/$iVnum.png" onerror="this.src='icons/default.png'" alt="$iName" loading="lazy">
                                        $countHtml
                                    </div>
                                    <div class="grid-name">$shortName</div>
                                    <div class="grid-chance $badgeClass">%$iChance</div>
                                </div>
"@
}

function Build-CardHtml {
    param($Entity, [string]$Category, [string]$IdPrefix, [string]$SubCategory, [bool]$Hidden = $true)
    $entityName = if ($Category -eq "mob") { $Entity.MobName } else { $Entity.ChestName }
    $entityVnum = if ($Category -eq "mob") { $Entity.MobVnum } else { $Entity.ChestVnum }
    $cardId = "$IdPrefix-$entityVnum"
    $iconClass = if ($Category -eq "mob") { "fas fa-dragon" } else { "fas fa-box-open" }
    $headerGrad = if ($Category -eq "mob") { "rgba(99,102,241,0.08)" } else { "rgba(245,158,11,0.08)" }
    $iconBg = if ($Category -eq "mob") { "rgba(99,102,241,0.15)" } else { "rgba(245,158,11,0.15)" }
    $iconColor = if ($Category -eq "mob") { "var(--accent-blue)" } else { "var(--accent-gold)" }
    $displayAttr = if ($Hidden) { " style=`"display:none;`"" } else { "" }
	
    $catLabel = "Sandik"
    if ($Category -eq "mob") {
        if ($SubCategory -eq "Patronlar") { $catLabel = "Patron" }
        elseif ($SubCategory -eq "Metinler") { $catLabel = "Metin" }
        else { $catLabel = "Canavar" }
    }

    $gridItemsHtml = ""
    foreach ($item in $Entity.Items) {
        $gridItemsHtml += Build-GridItemHtml -Item $item
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
                        <div class="drop-grid-wrap">
                            <div class="drop-grid">
$gridItemsHtml
                            </div>
                        </div>
                        <div class="w-card-footer">
                            <span class="drop-count"><i class="fas fa-layer-group"></i> $($Entity.Items.Count) esya</span>
                        </div>
                    </div>

"@
}

# ======================== METIN TABLE BUILDER ========================
function Build-MetinTableHtml {
    param($MetinGroups)

    $tableRowsHtml = ""
    foreach ($g in $MetinGroups) {
        $mobName = [System.Security.SecurityElement]::Escape($g.MobName)
        $mobVnum = $g.MobVnum

        $dropItemsHtml = ""
        foreach ($item in $g.Items) {
            $iVnum = $item.Vnum
            $iName = [System.Security.SecurityElement]::Escape($item.Name)
            $iCount = $item.Count
            $iChance = $item.Chance
            $badgeClass = ""
            $chVal = 0.0
            if ([double]::TryParse($iChance, [ref]$chVal)) {
                if ($chVal -ge 80) { $badgeClass = "chance-high" }
                elseif ($chVal -ge 30) { $badgeClass = "chance-mid" }
                elseif ($chVal -ge 10) { $badgeClass = "chance-low" }
                else { $badgeClass = "chance-rare" }
            }
            $countDisplay = ""
            $countVal = 0
            if ([int]::TryParse($iCount, [ref]$countVal) -and $countVal -gt 1) {
                $countDisplay = "<span class=`"drop-item-count`">x$countVal</span>"
            }
            $dropItemsHtml += @"
		                      <div class="drop-item-row">
		                          <span class="drop-item-chance $badgeClass" style="margin-right: 4px; width: 40px; text-align: right;">%$iChance</span>
		                          $countDisplay
		                          <img class="drop-item-icon" src="icons/$iVnum.png" onerror="this.src='icons/default.png'" alt="$iName" loading="lazy">
		                          <span class="drop-item-name">$iName</span>
		                      </div>
"@
        }

        $tableRowsHtml += @"
                <tr>
                    <td class="metin-name-cell">$mobName</td>
                    <td class="metin-vnum-cell">$mobVnum</td>
                    <td class="drop-items-cell">$dropItemsHtml</td>
                </tr>
"@
    }

    $displayAttr = ""  # Always visible as first card

    return @"
	                   <div class="wiki-card" id="special-metin-table" data-category="mob"$displayAttr>
                        <div class="w-card-header" style="background: linear-gradient(135deg, rgba(99,102,241,0.08), transparent);">
                            <div class="w-icon" style="background: rgba(99,102,241,0.15); color: var(--accent-blue);"><i class="fas fa-table"></i></div>
                            <div>
                                <div class="w-title">Metin Drop Tablosu</div>
                                <div class="w-type"><span class="cat-label cat-mob">Ozet</span> Tum metinlerin drop listesi</div>
                            </div>
                        </div>
                        <div style="padding: 0.25rem 0.5rem; background: rgba(0,0,0,0.15); overflow-x: auto;">
                            <table class="metin-drop-table">
                                <thead>
                                    <tr>
                                        <th><i class="fas fa-meteor" style="margin-right:4px;color:var(--accent-blue)"></i> Metin Adi</th>
                                        <th><i class="fas fa-hashtag" style="margin-right:4px;color:var(--accent-blue)"></i> VNUM</th>
                                        <th><i class="fas fa-gift" style="margin-right:4px;color:var(--accent-blue)"></i> Drop Esyalar</th>
                                    </tr>
                                </thead>
                                <tbody>
$tableRowsHtml
                                </tbody>
                            </table>
                        </div>
                        <div class="w-card-footer">
                            <span class="drop-count"><i class="fas fa-meteor"></i> $($MetinGroups.Count) metin</span>
                        </div>
                    </div>
"@
}

# ======================== CATEGORY TABLE BUILDER ========================
function Build-CategoryTableHtml {
    param($MobGroups, [string]$Category, [string]$CardId, [string]$Icon, [string]$Title)

    $tableRowsHtml = ""
    foreach ($g in $MobGroups) {
        $mobName = [System.Security.SecurityElement]::Escape($g.MobName)
        $mobVnum = $g.MobVnum

        $dropItemsHtml = ""
        foreach ($item in $g.Items) {
            $iVnum = $item.Vnum
            $iName = [System.Security.SecurityElement]::Escape($item.Name)
            $iCount = $item.Count
            $iChance = $item.Chance
            $badgeClass = ""
            $chVal = 0.0
            if ([double]::TryParse($iChance, [ref]$chVal)) {
                if ($chVal -ge 80) { $badgeClass = "chance-high" }
                elseif ($chVal -ge 30) { $badgeClass = "chance-mid" }
                elseif ($chVal -ge 10) { $badgeClass = "chance-low" }
                else { $badgeClass = "chance-rare" }
            }
            $countDisplay = ""
            $countVal = 0
            if ([int]::TryParse($iCount, [ref]$countVal) -and $countVal -gt 1) {
                $countDisplay = "<span class=`"drop-item-count`">x$countVal</span>"
            }
            $dropItemsHtml += @"
		                      <div class="drop-item-row">
		                          <span class="drop-item-chance $badgeClass" style="margin-right: 4px; width: 40px; text-align: right;">%$iChance</span>
		                          $countDisplay
		                          <img class="drop-item-icon" src="icons/$iVnum.png" onerror="this.src='icons/default.png'" alt="$iName" loading="lazy">
		                          <span class="drop-item-name">$iName</span>
		                      </div>
"@
        }

        $tableRowsHtml += @"
                <tr>
                    <td class="metin-name-cell">$mobName</td>
                    <td class="metin-vnum-cell">$mobVnum</td>
                    <td class="drop-items-cell">$dropItemsHtml</td>
                </tr>
"@
    }

    return @"
	                   <div class="wiki-card" id="$CardId" data-category="mob" style="display:none;">
                        <div class="w-card-header" style="background: linear-gradient(135deg, rgba(99,102,241,0.08), transparent);">
                            <div class="w-icon" style="background: rgba(99,102,241,0.15); color: var(--accent-blue);"><i class="fas fa-$Icon"></i></div>
                            <div>
                                <div class="w-title">$Title</div>
                                <div class="w-type"><span class="cat-label cat-mob">Ozet</span> Tum $Category drop listesi</div>
                            </div>
                        </div>
                        <div style="padding: 0.25rem 0.5rem; background: rgba(0,0,0,0.15); overflow-x: auto;">
                            <table class="metin-drop-table">
                                <thead>
                                    <tr>
                                        <th><i class="fas fa-$Icon" style="margin-right:4px;color:var(--accent-blue)"></i> Mob Adi</th>
                                        <th><i class="fas fa-hashtag" style="margin-right:4px;color:var(--accent-blue)"></i> VNUM</th>
                                        <th><i class="fas fa-gift" style="margin-right:4px;color:var(--accent-blue)"></i> Drop Esyalar</th>
                                    </tr>
                                </thead>
                                <tbody>
$tableRowsHtml
                                </tbody>
                            </table>
                        </div>
                        <div class="w-card-footer">
                            <span class="drop-count"><i class="fas fa-$Icon"></i> $($MobGroups.Count) mob</span>
                        </div>
                    </div>
"@
}

# ======================== MAIN ========================
Write-Host "=== Harbi2 Drop Wiki Generator v3 ===" -ForegroundColor Cyan

# Load item names for name resolution (chest names + item names)
$itemNamesPath = Join-Path $scriptDir "item_names.txt"
$itemNamesMap = Get-ItemNames -Path $itemNamesPath
Write-Host "Item isimleri yuklendi: $($itemNamesMap.Count) kayit" -ForegroundColor DarkGray

# Load mob names for name resolution
$mobNamesPath = Join-Path $scriptDir "mob_names.txt"
$mobNamesMap = Get-MobNames -Path $mobNamesPath
Write-Host "Mob isimleri yuklendi: $($mobNamesMap.Count) kayit" -ForegroundColor DarkGray

$mobGroups = Parse-MobDropFile -Path $mobDropFile -MobNames $mobNamesMap -ItemNames $itemNamesMap
Write-Host "Canavarlar: $($mobGroups.Count) grup" -ForegroundColor Green

$chestGroups = Parse-ChestDropFile -Path $chestDropFile -ItemNames $itemNamesMap
Write-Host "Sandiklar: $($chestGroups.Count) grup" -ForegroundColor Green

# Build sidebar
$mobProtoPath = Join-Path $scriptDir "mob_proto.txt"
$mobCategories = Get-MobCategories -Path $mobProtoPath

$lists = @{
    "Canavarlar" = @()
    "Patronlar"  = @()
    "Metinler"   = @()
}

foreach ($g in $mobGroups) {
    $cat = $mobCategories[$g.MobVnum]
    if (-not $cat) { $cat = "Canavarlar" }
    $lists[$cat] += $g
}

$sidebarHtml = "                    <div class=`"sidebar-section`">`n"
$sidebarHtml += "                        <div class=`"sidebar-section-title`"><i class=`"fas fa-dragon`"></i> Canavarlar <span class=`"section-count`">$($mobGroups.Count)</span></div>`n"

$firstCard = $true
$icons = @{ "Canavarlar" = "fa-ghost"; "Patronlar" = "fa-crown"; "Metinler" = "fa-meteor" }

# Add category table buttons at the top
$metinGroups = $lists["Metinler"]
$patronGroups = $lists["Patronlar"]
$canavarGroups = $lists["Canavarlar"]

if ($metinGroups.Count -gt 0) {
    $activeClass = if ($firstCard) { " active" } else { "" }
    $sidebarHtml += "                        <button class=`"w-cat-btn$activeClass`" data-target=`"special-metin-table`" data-category=`"mob`" style=`"margin-bottom: 0.5rem; background: rgba(99,102,241,0.08); border-left-color: var(--accent-blue);`"><i class=`"fas fa-table`" style=`"margin-right: 6px;`"></i> Metin Drop Tablosu</button>`n"
    $firstCard = $false
}
if ($patronGroups.Count -gt 0) {
    $activeClass = if ($firstCard) { " active" } else { "" }
    $sidebarHtml += "                        <button class=`"w-cat-btn$activeClass`" data-target=`"special-patron-table`" data-category=`"mob`" style=`"margin-bottom: 0.5rem; background: rgba(245,158,11,0.08); border-left-color: var(--accent-gold);`"><i class=`"fas fa-table`" style=`"margin-right: 6px;`"></i> Patron Drop Tablosu</button>`n"
    $firstCard = $false
}
if ($canavarGroups.Count -gt 0) {
    $activeClass = if ($firstCard) { " active" } else { "" }
    $sidebarHtml += "                        <button class=`"w-cat-btn$activeClass`" data-target=`"special-canavar-table`" data-category=`"mob`" style=`"margin-bottom: 0.5rem; background: rgba(99,102,241,0.08); border-left-color: var(--accent-blue);`"><i class=`"fas fa-table`" style=`"margin-right: 6px;`"></i> Canavar Drop Tablosu</button>`n"
    $firstCard = $false
}

foreach ($catKey in @("Patronlar", "Metinler", "Canavarlar")) {
    $catList = $lists[$catKey]
    if ($catList.Count -gt 0) {
        $sidebarHtml += "                        <div class=`"tree-folder`">`n"
        $sidebarHtml += "                            <div class=`"tree-header`" onclick=`"this.parentElement.classList.toggle('open')`">`n"
        $sidebarHtml += "                                <i class=`"fas fa-chevron-right tree-icon`"></i> <i class=`"fas $($icons[$catKey])`" style=`"margin:0 4px; font-size:0.6rem; color:var(--text-low)`"></i> $catKey ($($catList.Count))`n"
        $sidebarHtml += "                            </div>`n"
        $sidebarHtml += "                            <div class=`"tree-content`">`n"
        foreach ($g in $catList) {
            $activeClass = if ($firstCard) { " active" } else { "" }
            $sidebarHtml += "                                <button class=`"w-cat-btn$activeClass`" data-target=`"mob-$($g.MobVnum)`" data-category=`"mob`">$($g.MobName)</button>`n"
            $firstCard = $false
        }
        $sidebarHtml += "                            </div>`n"
        $sidebarHtml += "                        </div>`n"
    }
}

# Boss chest VNUMs (50000-50999 range with boss_box icon)
$bossChestVnums = @(
    "50068", "50070", "50071", "50072", "50073", "50074", "50075", "50076", "50077", "50078", "50079", "50080", "50081", "50082", "50083",
    "50186", "50270", "50271", "50294", "54700", "54701", "54702", "54703", "54704", "54705"
)

# Separate boss chests from regular chests
$bossChests = @()
$regularChests = @()
foreach ($g in $chestGroups) {
    if ($g.ChestVnum -in $bossChestVnums) {
        $bossChests += $g
    }
    else {
        $regularChests += $g
    }
}

$sidebarHtml += "                    </div>`n"
$sidebarHtml += "                    <div class=`"sidebar-section`">`n"
$sidebarHtml += "                        <div class=`"sidebar-section-title`"><i class=`"fas fa-box-open`"></i> Sandiklar <span class=`"section-count`">$($regularChests.Count)</span></div>`n"
foreach ($g in $regularChests) {
    $sidebarHtml += "                        <button class=`"w-cat-btn`" data-target=`"chest-$($g.ChestVnum)`" data-category=`"chest`">$($g.ChestName)</button>`n"
}
if ($bossChests.Count -gt 0) {
    $sidebarHtml += "                        <div class=`"tree-folder`">`n"
    $sidebarHtml += "                            <div class=`"tree-header`" onclick=`"this.parentElement.classList.toggle('open')`">`n"
    $sidebarHtml += "                                <i class=`"fas fa-chevron-right tree-icon`"></i> <i class=`"fas fa-crown`" style=`"margin:0 4px; font-size:0.6rem; color:var(--text-low)`"></i> Boss Sandiklari ($($bossChests.Count))`n"
    $sidebarHtml += "                            </div>`n"
    $sidebarHtml += "                            <div class=`"tree-content`">`n"
    foreach ($g in $bossChests) {
        $sidebarHtml += "                                <button class=`"w-cat-btn`" data-target=`"chest-$($g.ChestVnum)`" data-category=`"chest`">$($g.ChestName)</button>`n"
    }
    $sidebarHtml += "                            </div>`n"
    $sidebarHtml += "                        </div>`n"
}
$sidebarHtml += "                    </div>`n"

# Build cards
$cardsHtml = ""
$isFirst = $true

# Add Metin Drop Table card first (shown by default as first card)
if ($metinGroups.Count -gt 0) {
    $cardsHtml += Build-MetinTableHtml -MetinGroups $metinGroups
    $isFirst = $false
}

# Add Patron Drop Table card
if ($patronGroups.Count -gt 0) {
    $cardsHtml += Build-CategoryTableHtml -MobGroups $patronGroups -Category "patronlarin" -CardId "special-patron-table" -Icon "crown" -Title "Patron Drop Tablosu"
}

# Add Canavar Drop Table card
if ($canavarGroups.Count -gt 0) {
    $cardsHtml += Build-CategoryTableHtml -MobGroups $canavarGroups -Category "canavarlarin" -CardId "special-canavar-table" -Icon "ghost" -Title "Canavar Drop Tablosu"
}

foreach ($catKey in @("Patronlar", "Metinler", "Canavarlar")) {
    foreach ($g in $lists[$catKey]) {
        $cardsHtml += Build-CardHtml -Entity $g -Category "mob" -IdPrefix "mob" -SubCategory $catKey -Hidden (-not $isFirst)
        $isFirst = $false
    }
}
# Add regular chests first
foreach ($g in $regularChests) {
    $cardsHtml += Build-CardHtml -Entity $g -Category "chest" -IdPrefix "chest" -SubCategory "Sandik" -Hidden $true
}
# Then add boss chests
foreach ($g in $bossChests) {
    $cardsHtml += Build-CardHtml -Entity $g -Category "chest" -IdPrefix "chest" -SubCategory "Boss Sandik" -Hidden $true
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
    <meta name="description" content="Harbi2 Metin2 - Canavar ve Sandik Drop Rehberi.">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Cinzel:wght@400;600;700&family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.0/css/all.min.css">
    <style>
        :root {
            --bg-base: #06060e;
            --bg-surface: #0c0c1a;
            --bg-card: #111128;
            --bg-sidebar: #090918;
            --bg-input: rgba(255,255,255,0.03);

            --text-high: #eaeaf4;
            --text-med: #9898b8;
            --text-low: #555578;
            --text-muted: #3a3a58;

            --accent-blue: #6366f1;
            --accent-blue-dim: rgba(99,102,241,0.15);
            --accent-gold: #f59e0b;
            --accent-gold-dim: rgba(245,158,11,0.15);

            --brand-gold: #c99c30;

            --border: rgba(255,255,255,0.06);
            --border-active: rgba(99,102,241,0.4);

            --radius-sm: 6px;
            --radius-md: 10px;

            --font-display: 'Cinzel', serif;
            --font-body: 'Inter', sans-serif;
            --sidebar-w: 280px;
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
        }

        ::-webkit-scrollbar { width: 5px; }
        ::-webkit-scrollbar-track { background: transparent; }
        ::-webkit-scrollbar-thumb { background: rgba(255,255,255,0.08); border-radius: 10px; }

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
            padding: 1.25rem 1rem;
            border-bottom: 1px solid var(--border);
            background: linear-gradient(180deg, rgba(99,102,241,0.04), transparent);
        }

        .sidebar-logo { display: flex; align-items: center; gap: 0.6rem; }

        .logo-icon {
            width: 32px; height: 32px;
            border-radius: var(--radius-sm);
            background: var(--accent-blue-dim);
            display: flex; align-items: center; justify-content: center;
            color: var(--accent-blue); font-size: 0.85rem;
        }

        .logo-text h2 {
            font-family: var(--font-display);
            font-size: 0.8rem; color: var(--brand-gold);
            letter-spacing: 3px;
        }

        .logo-text p { font-size: 0.58rem; color: var(--text-low); letter-spacing: 1px; margin-top: 1px; }

        .sidebar-search { padding: 0.6rem 0.85rem; }

        .search-box { position: relative; }
        .search-box i {
            position: absolute; left: 0.65rem; top: 50%;
            transform: translateY(-50%);
            color: var(--text-low); font-size: 0.7rem;
            pointer-events: none;
        }
        .search-box input {
            width: 100%; padding: 0.5rem 0.65rem 0.5rem 1.9rem;
            background: var(--bg-input);
            border: 1px solid var(--border);
            border-radius: var(--radius-sm);
            color: var(--text-high); font-size: 0.75rem;
            font-family: var(--font-body); outline: none;
            transition: border-color var(--anim-med);
        }
        .search-box input:focus { border-color: var(--border-active); }
        .search-box input::placeholder { color: var(--text-muted); }

        .search-mode-toggle {
            display: flex; gap: 2px; padding: 0.3rem 0.85rem 0;
        }
        .search-mode-btn {
            flex: 1; padding: 0.3rem;
            background: transparent;
            border: 1px solid var(--border);
            color: var(--text-low);
            font-size: 0.6rem; font-family: var(--font-body);
            cursor: pointer; transition: all var(--anim-fast);
        }
        .search-mode-btn:first-child { border-radius: var(--radius-sm) 0 0 var(--radius-sm); }
        .search-mode-btn:last-child { border-radius: 0 var(--radius-sm) var(--radius-sm) 0; }
        .search-mode-btn.active {
            background: var(--accent-blue-dim);
            border-color: var(--border-active);
            color: var(--accent-blue); font-weight: 600;
        }
        .search-mode-btn i { margin-right: 2px; }

        .category-filter {
            display: flex; gap: 2px; padding: 0.35rem 0.85rem 0.2rem;
        }
        .cat-filter-btn {
            flex: 1; padding: 0.3rem;
            background: transparent;
            border: 1px solid var(--border);
            color: var(--text-low);
            font-size: 0.6rem; font-family: var(--font-body);
            cursor: pointer; transition: all var(--anim-fast);
        }
        .cat-filter-btn:first-child { border-radius: var(--radius-sm) 0 0 var(--radius-sm); }
        .cat-filter-btn:last-child { border-radius: 0 var(--radius-sm) var(--radius-sm) 0; }
        .cat-filter-btn.active {
            background: var(--accent-blue-dim);
            border-color: var(--border-active);
            color: var(--accent-blue); font-weight: 600;
        }
        .cat-filter-btn i { margin-right: 2px; }

        .tree-folder { margin-bottom: 2px; }
        .tree-header { 
            padding: 0.4rem 0.85rem; 
            font-size: 0.65rem; color: var(--text-high); 
            cursor: pointer; display: flex; align-items: center; gap: 0.4rem; 
            border-radius: var(--radius-sm); transition: background 0.2s;
        }
        .tree-header:hover { background: rgba(255,255,255,0.05); }
        .tree-icon { font-size: 0.55rem; color: var(--text-muted); transition: transform 0.2s; }
        .tree-folder.open .tree-icon { transform: rotate(90deg); }
        .tree-content { display: none; margin-left: 0.5rem; padding-left: 0.5rem; border-left: 1px solid var(--border); margin-top: 2px; }
        .tree-folder.open .tree-content { display: block; }

        .sidebar-nav { flex: 1; overflow-y: auto; padding: 0.15rem 0; }
        .sidebar-section { margin-bottom: 0.15rem; }
        .sidebar-section-title {
            padding: 0.5rem 1rem 0.3rem;
            font-size: 0.58rem; font-weight: 700;
            text-transform: uppercase; letter-spacing: 2px;
            color: var(--text-muted);
            display: flex; align-items: center; gap: 0.4rem;
        }
        .sidebar-section-title i { font-size: 0.55rem; }
        .section-count {
            margin-left: auto;
            background: rgba(255,255,255,0.05);
            padding: 1px 5px; border-radius: 8px;
            font-size: 0.55rem;
        }

        .w-cat-btn {
            display: block; width: 100%;
            text-align: left;
            padding: 0.4rem 1rem 0.4rem 1.5rem;
            background: none; border: none;
            border-left: 2px solid transparent;
            color: var(--text-med);
            font-family: var(--font-body);
            font-size: 0.72rem;
            cursor: pointer;
            transition: all var(--anim-fast);
            white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
        }
        .w-cat-btn:hover { background: rgba(255,255,255,0.02); color: var(--text-high); }
        .w-cat-btn.active {
            background: linear-gradient(90deg, rgba(99,102,241,0.1), transparent);
            border-left-color: var(--accent-blue);
            color: var(--text-high); font-weight: 600;
        }

        .sidebar-footer {
            padding: 0.6rem 1rem;
            border-top: 1px solid var(--border);
            font-size: 0.55rem; color: var(--text-muted); text-align: center;
        }

        /* ========== MAIN ========== */
        .main-content { margin-left: var(--sidebar-w); min-height: 100vh; }

        .page-hero {
            padding: 2rem 2rem 1.5rem;
            border-bottom: 1px solid var(--border);
            background: radial-gradient(ellipse at 20% 0%, rgba(99,102,241,0.06) 0%, transparent 60%),
                        radial-gradient(ellipse at 80% 100%, rgba(245,158,11,0.04) 0%, transparent 50%);
        }
        .hero-tag {
            display: inline-flex; align-items: center; gap: 0.35rem;
            padding: 0.15rem 0.55rem;
            border: 1px solid rgba(99,102,241,0.25);
            border-radius: 50px;
            font-size: 0.58rem; color: var(--accent-blue);
            text-transform: uppercase; letter-spacing: 1.5px;
            margin-bottom: 0.6rem;
        }
        .hero-tag .dot {
            width: 5px; height: 5px; border-radius: 50%;
            background: #22c55e;
            animation: pulse 2s infinite;
        }
        @keyframes pulse { 0%,100%{opacity:1} 50%{opacity:0.3} }

        .page-hero h1 {
            font-family: var(--font-display);
            font-size: 1.4rem; font-weight: 700;
            color: var(--text-high); letter-spacing: 3px;
        }
        .page-hero p { color: var(--text-med); font-size: 0.78rem; margin-top: 0.35rem; font-weight: 300; }

        .stats-row { display: flex; gap: 1rem; margin-top: 1rem; flex-wrap: wrap; }
        .stat-chip {
            display: flex; align-items: center; gap: 0.4rem;
            padding: 0.35rem 0.7rem;
            background: var(--bg-surface);
            border: 1px solid var(--border);
            border-radius: var(--radius-sm);
            font-size: 0.68rem; color: var(--text-med);
        }

        /* ========== HERO SEARCH ========== */
        .hero-search {
            padding: 1rem 2rem 1.5rem 2rem;
            background: linear-gradient(180deg, rgba(99,102,241,0.03), transparent);
            border-bottom: 1px solid var(--border);
        }
        .hero-search-container {
            display: flex;
            flex-wrap: wrap;
            gap: 0.5rem;
            align-items: center;
        }
        .hero-search .search-mode-toggle {
            display: flex; gap: 2px; padding: 0;
        }
        .hero-search .category-filter {
            display: flex; gap: 2px; padding: 0;
        }
        .hero-search .search-box {
            flex: 1; min-width: 200px;
        }
        .hero-search .search-box input {
            width: 100%; padding: 0.5rem 0.65rem 0.5rem 2.5rem;
            background: var(--bg-input);
            border: 1px solid var(--border);
            border-radius: var(--radius-sm);
            color: var(--text-high); font-size: 0.75rem;
            font-family: var(--font-body); outline: none;
            transition: border-color var(--anim-med);
        }
        .hero-search .search-box input:focus { border-color: var(--border-active); }
        .hero-search .search-box input::placeholder { color: var(--text-muted); }
        .hero-search .search-box i {
            position: absolute; left: 0.65rem; top: 50%;
            transform: translateY(-50%);
            color: var(--text-low); font-size: 0.7rem;
            pointer-events: none;
        }
        .stat-chip i { font-size: 0.65rem; }
        .stat-chip .mob-icon { color: var(--accent-blue); }
        .stat-chip .chest-icon { color: var(--accent-gold); }
        .stat-chip .item-icon-stat { color: #a855f7; }
        .stat-chip strong { color: var(--text-high); font-weight: 600; }

        .content-area { padding: 1.25rem 2rem 3rem; }

        /* ========== WIKI CARD ========== */
        .wiki-card {
            background: var(--bg-card);
            border: 1px solid var(--border);
            border-radius: var(--radius-md);
            margin-bottom: 1.25rem;
            overflow: hidden;
            transition: border-color var(--anim-med), box-shadow var(--anim-med);
        }
        .wiki-card:hover {
            border-color: rgba(99,102,241,0.18);
            box-shadow: 0 2px 16px rgba(0,0,0,0.2);
        }

        .w-card-header {
            display: flex; align-items: center; gap: 0.6rem;
            padding: 0.5rem 0.75rem;
            border-bottom: 1px solid var(--border);
        }
        .w-icon {
            width: 32px; height: 32px;
            border-radius: var(--radius-sm);
            display: flex; align-items: center; justify-content: center;
            font-size: 0.85rem; flex-shrink: 0;
        }
        .w-title {
            font-family: var(--font-display);
            font-size: 0.9rem; font-weight: 600;
            color: var(--text-high); letter-spacing: 1px;
        }
        .w-type {
            font-size: 0.62rem; color: var(--text-low);
            margin-top: 2px;
            display: flex; align-items: center; gap: 0.4rem;
        }
        .cat-label {
            display: inline-block; padding: 1px 5px;
            border-radius: 3px; font-size: 0.54rem;
            font-weight: 700; text-transform: uppercase; letter-spacing: 1px;
        }
        .cat-mob { background: var(--accent-blue-dim); color: var(--accent-blue); }
        .cat-chest { background: var(--accent-gold-dim); color: var(--accent-gold); }

        /* ========== DROP GRID ========== */
        .drop-grid-wrap {
            padding: 0.75rem 1rem;
            background: rgba(0,0,0,0.15);
        }

        .drop-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(72px, 1fr));
            gap: 6px;
        }

        .grid-item {
            display: flex; flex-direction: column;
            align-items: center;
            padding: 6px 3px 5px;
            background: rgba(255,255,255,0.02);
            border: 1px solid rgba(255,255,255,0.04);
            border-radius: 6px;
            cursor: default;
            transition: all var(--anim-fast);
            position: relative;
        }

        .grid-item:hover {
            background: rgba(99,102,241,0.08);
            border-color: rgba(99,102,241,0.2);
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(0,0,0,0.3);
        }

        .grid-icon-wrap {
            position: relative;
            width: 36px; min-height: 36px; height: auto;
            display: flex; align-items: center; justify-content: center;
        }

        .grid-icon {
            width: 32px; height: auto; max-height: 96px;
            image-rendering: pixelated;
            border-radius: 3px;
        }

        .grid-count {
            position: absolute;
            bottom: -2px; right: -4px;
            background: rgba(99,102,241,0.9);
            color: #fff;
            font-size: 0.5rem; font-weight: 700;
            padding: 0px 3px;
            border-radius: 3px;
            line-height: 1.3;
        }

        .grid-name {
            font-size: 0.52rem;
            color: var(--text-med);
            margin-top: 3px;
            text-align: center;
            line-height: 1.2;
            max-width: 100%;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
        }

        .grid-chance {
            font-size: 0.5rem;
            font-weight: 700;
            margin-top: 1px;
            padding: 0px 4px;
            border-radius: 3px;
        }

        .chance-high { background: rgba(34,197,94,0.12); color: #22c55e; }
        .chance-mid { background: rgba(234,179,8,0.12); color: #eab308; }
        .chance-low { background: rgba(249,115,22,0.12); color: #f97316; }
        .chance-rare { background: rgba(239,68,68,0.12); color: #ef4444; }

        /* Tooltip */
        .grid-item::after {
            content: attr(title);
            position: absolute;
            bottom: calc(100% + 6px);
            left: 50%;
            transform: translateX(-50%);
            background: rgba(10,10,20,0.95);
            color: var(--text-high);
            font-size: 0.62rem;
            padding: 3px 8px;
            border-radius: 4px;
            white-space: nowrap;
            pointer-events: none;
            opacity: 0;
            transition: opacity var(--anim-fast);
            z-index: 10;
            border: 1px solid var(--border);
        }
        .grid-item:hover::after { opacity: 1; }

        .w-card-footer {
            padding: 0.3rem 0.75rem;
            border-top: 1px solid var(--border);
            background: rgba(0,0,0,0.1);
        }
        .drop-count { font-size: 0.62rem; color: var(--text-low); }
        .drop-count i { color: var(--accent-blue); margin-right: 3px; }

        /* ========== METIN DROP TABLE ========== */
        .metin-drop-table-container {
            display: none;
            padding: 1rem;
        }
        .metin-drop-table-container.active {
            display: block;
        }
        .metin-drop-table {
            width: 450px;
            max-width: 100%;
            border-collapse: collapse;
            background: var(--bg-card);
            border: 1px solid var(--border);
            border-radius: var(--radius-md);
            overflow: hidden;
            table-layout: fixed;
        }
        .metin-drop-table thead {
            background: linear-gradient(135deg, rgba(99,102,241,0.1), transparent);
        }
        .metin-drop-table th {
            padding: 0.4rem 0.8rem;
            text-align: left;
            font-size: 0.6rem;
            font-weight: 700;
            color: var(--text-high);
            text-transform: uppercase;
            letter-spacing: 0.3px;
            border-bottom: 1px solid var(--border);
            white-space: nowrap;
        }
        .metin-drop-table th:nth-child(1) { width: 140px; }
        .metin-drop-table th:nth-child(2) { width: 80px; }
        .metin-drop-table th:nth-child(3) { width: 230px; }
        .metin-drop-table td {
            padding: 0.3rem 0.8rem;
            font-size: 0.6rem;
            color: var(--text-med);
            border-bottom: 1px solid var(--border);
        }
        .metin-drop-table tbody tr:last-child td {
            border-bottom: none;
        }
        .metin-drop-table tbody tr:nth-child(even) {
            background: rgba(255, 255, 255, 0.02);
        }
        .metin-drop-table tbody tr:hover {
            background: rgba(99,102,241,0.08);
        }
        .metin-name-cell {
            font-weight: 600;
            color: var(--text-high);
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
        }
        .metin-vnum-cell {
            font-family: monospace;
            color: var(--accent-blue);
            font-size: 0.58rem;
        }
        .drop-items-cell {
            font-size: 0.65rem;
        }
        .drop-item-row {
            display: flex;
            align-items: center;
            gap: 0.2rem;
            padding: 0.05rem 0;
            line-height: 1.1;
        }
        .drop-item-icon {
            width: 16px;
            height: 16px;
            image-rendering: pixelated;
            border-radius: 2px;
            flex-shrink: 0;
        }
        .drop-item-name {
            flex: 1;
            color: var(--text-med);
            font-size: 0.58rem;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
            margin-right: 15px;
        }
        .drop-item-count {
            font-weight: 700;
            color: var(--accent-gold);
            font-size: 0.55rem;
            flex-shrink: 0;
            margin-right: 4px;
            width: 20px;
        }
        .drop-item-chance {
            font-weight: 600;
            padding: 0px 3px;
            border-radius: 2px;
            font-size: 0.52rem;
            flex-shrink: 0;
            display: inline-block;
        }

        /* ========== MOBILE ========== */
        .mobile-topbar {
            display: none; position: fixed; top: 0; left: 0; right: 0;
            height: 48px; background: var(--bg-sidebar);
            border-bottom: 1px solid var(--border);
            z-index: 200; align-items: center;
            justify-content: space-between; padding: 0 0.85rem;
        }
        .mobile-topbar h3 { font-family: var(--font-display); font-size: 0.75rem; color: var(--brand-gold); letter-spacing: 2px; }
        .mobile-topbar button { background: none; border: none; color: var(--text-med); font-size: 1.1rem; cursor: pointer; padding: 0.2rem 0.4rem; border-radius: var(--radius-sm); }

        @media (max-width: 768px) {
            .sidebar { transform: translateX(-100%); }
            .sidebar.open { transform: translateX(0); }
            .main-content { margin-left: 0; }
            .mobile-topbar { display: flex; }
            .page-hero { padding: calc(48px + 1rem) 1rem 1rem; }
            .page-hero h1 { font-size: 1.1rem; }
            .content-area { padding: 0.75rem; }
            .drop-grid { grid-template-columns: repeat(auto-fill, minmax(60px, 1fr)); gap: 4px; }
            .grid-icon { width: 28px; height: 28px; }
            .grid-icon-wrap { width: 30px; height: 30px; }
        }

        .sidebar-backdrop { display: none; position: fixed; inset: 0; background: rgba(0,0,0,0.6); z-index: 99; }
        .sidebar-backdrop.show { display: block; }

        .empty-state { display: none; text-align: center; padding: 3rem; color: var(--text-muted); }
        .empty-state i { font-size: 2rem; margin-bottom: 0.75rem; display: block; }
        .empty-state p { font-size: 0.8rem; }
    </style>
</head>
<body>

    <div class="mobile-topbar">
        <h3><i class="fas fa-scroll"></i> HARBI2 WIKI</h3>
        <button id="mobile-menu-btn"><i class="fas fa-bars"></i></button>
    </div>
    <div class="sidebar-backdrop" id="sidebar-backdrop"></div>

    <aside class="sidebar" id="sidebar">
        <div class="sidebar-header">
            <div class="sidebar-logo">
                <div class="logo-icon"><i class="fas fa-scroll"></i></div>
                <div class="logo-text">
                    <h2>HARBI2</h2>
                    <p>DROP WIKI</p>
                </div>
            </div>
        </div>
        <nav class="sidebar-nav" id="sidebar-nav">
$sidebarHtml
        </nav>
        <div class="sidebar-footer"><p>Harbi2 Drop Wiki</p></div>
    </aside>

    <main class="main-content">
        <div class="page-hero">
            <span class="hero-tag"><span class="dot"></span> Guncel</span>
            <h1>DROP WIKI</h1>
            <p>Canavar droplari ve sandik iceriklerinin detayli rehberi.</p>
            <div class="stats-row">
                <div class="stat-chip"><i class="fas fa-dragon mob-icon"></i> <strong>$totalMobs</strong> Canavar</div>
                <div class="stat-chip"><i class="fas fa-box-open chest-icon"></i> <strong>$totalChests</strong> Sandik</div>
                <div class="stat-chip"><i class="fas fa-gem item-icon-stat"></i> <strong>$totalItems</strong> Esya</div>
            </div>
        </div>
        <div class="hero-search">
            <div class="hero-search-container">
                <div class="search-mode-toggle">
                    <button class="search-mode-btn active" data-mode="entity"><i class="fas fa-crosshairs"></i> Mob/Sandik</button>
                    <button class="search-mode-btn" data-mode="item"><i class="fas fa-gem"></i> Esya</button>
                </div>
                <div class="category-filter">
                    <button class="cat-filter-btn active" data-filter="mob"><i class="fas fa-dragon"></i> Mob</button>
                    <button class="cat-filter-btn" data-filter="chest"><i class="fas fa-box-open"></i> Sandik</button>
                </div>
                <div class="search-box">
                    <input type="text" id="search-input" placeholder="Mob veya sandik ara...">
                    <i class="fas fa-search"></i>
                </div>
            </div>
        </div>
        <div class="content-area" id="content-area">
$cardsHtml
            <div class="empty-state" id="empty-state"><i class="fas fa-search"></i><p>Sonuc bulunamadi.</p></div>
        </div>
    </main>

    <script>
    (function() {
        const catBtns = document.querySelectorAll('.w-cat-btn');
        const wikiCards = document.querySelectorAll('.wiki-card');
        const searchInput = document.getElementById('search-input');
        const emptyState = document.getElementById('empty-state');
        let searchMode = 'entity';
        let categoryFilter = 'mob';

        catBtns.forEach(btn => {
            btn.addEventListener('click', () => {
                catBtns.forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
                searchInput.value = '';
                const targetId = btn.getAttribute('data-target');
                wikiCards.forEach(card => { card.style.display = card.id === targetId ? '' : 'none'; });
                emptyState.style.display = 'none';
                closeMobile();
                document.querySelector('.content-area').scrollIntoView({ behavior: 'smooth', block: 'start' });
            });
        });

        searchInput.addEventListener('input', () => {
            const q = searchInput.value.toLowerCase().trim();
            if (!q) { resetToActive(); return; }
            let anyVisible = false;
            wikiCards.forEach(card => {
                const cat = card.getAttribute('data-category');
                if (cat !== categoryFilter) { card.style.display = 'none'; return; }
                let match = false;
                if (searchMode === 'entity') {
                    const title = card.querySelector('.w-title');
                    if (title && title.textContent.toLowerCase().includes(q)) match = true;
                } else {
                    card.querySelectorAll('.grid-item').forEach(gi => {
                        if (gi.getAttribute('title').toLowerCase().includes(q)) match = true;
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

        document.querySelectorAll('.search-mode-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                document.querySelectorAll('.search-mode-btn').forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
                searchMode = btn.getAttribute('data-mode');
                searchInput.placeholder = searchMode === 'entity' ? 'Mob veya sandik ara...' : 'Esya adi ara...';
                searchInput.dispatchEvent(new Event('input'));
            });
        });

        document.querySelectorAll('.cat-filter-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                document.querySelectorAll('.cat-filter-btn').forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
                categoryFilter = btn.getAttribute('data-filter');
                catBtns.forEach(sb => {
                    const cat = sb.getAttribute('data-category');
                    sb.style.display = (cat === categoryFilter) ? '' : 'none';
                });
                document.querySelectorAll('.sidebar-section').forEach(sec => {
                    const btns = sec.querySelectorAll('.w-cat-btn');
                    let any = false;
                    btns.forEach(b => { if (b.style.display !== 'none') any = true; });
                    sec.style.display = any ? '' : 'none';
                });
                if (searchInput.value.trim()) { searchInput.dispatchEvent(new Event('input')); }
                else {
                    let found = false;
                    catBtns.forEach(b => b.classList.remove('active'));
                    wikiCards.forEach(card => {
                        const cat = card.getAttribute('data-category');
                        if (!found && cat === categoryFilter) {
                            card.style.display = ''; found = true;
                            const mb = document.querySelector('[data-target="'+card.id+'"]');
                            if (mb) mb.classList.add('active');
                        } else { card.style.display = 'none'; }
                    });
                    emptyState.style.display = found ? 'none' : 'block';
                }
            });
        });

        function resetToActive() {
            const ab = document.querySelector('.w-cat-btn.active');
            const at = ab ? ab.getAttribute('data-target') : '';
            wikiCards.forEach(card => { card.style.display = card.id === at ? '' : 'none'; });
            catBtns.forEach(b => {
                const cat = b.getAttribute('data-category');
                b.style.display = (cat === categoryFilter) ? '' : 'none';
            });
            document.querySelectorAll('.sidebar-section').forEach(sec => {
                const btns = sec.querySelectorAll('.w-cat-btn');
                let any = false;
                btns.forEach(b => { if (b.style.display !== 'none') any = true; });
                sec.style.display = any ? '' : 'none';
            });
            emptyState.style.display = 'none';
        }

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

# Write with UTF-8 BOM for proper encoding on all servers
$utf8Bom = New-Object System.Text.UTF8Encoding($true)
[System.IO.File]::WriteAllText($outputPath, $html, $utf8Bom)
Write-Host ""
Write-Host "Wiki olusturuldu: $outputPath" -ForegroundColor Green
Write-Host "  Canavarlar: $totalMobs | Sandiklar: $totalChests | Toplam Esya: $totalItems"
