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
$localConfDir = "c:\Users\orkun\OneDrive\Documents\GitHub\Harbi2_Files\srv1\share\conf"
$confDir = if (Test-Path $localConfDir) { $localConfDir } else { $scriptDir }

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
	foreach ($line in $lines) {
		$trimmed = $line.Trim()
		if ($trimmed -match "^(\d+)\s+(.+)$") {
			$nameMap[$Matches[1]] = $Matches[2].Trim()
		}
	}
	return $nameMap
}

function Get-ItemIconPaths {
	param([string]$Path)
	$iconMap = @{}
	if (-not (Test-Path $Path)) { return $iconMap }
	$lines = [System.IO.File]::ReadAllLines($Path, [System.Text.Encoding]::UTF8)
	foreach ($line in $lines) {
		$trimmed = $line.Trim()
		if ($trimmed -match "^(\d+)\s+\S+\s+(.+)$") {
			$iconMap[$Matches[1]] = $Matches[2].Trim().ToLowerInvariant()
		}
	}
	return $iconMap
}

function Get-ItemIconBaseVnums {
	param([string[]]$Paths)
	$baseMap = @{}
	foreach ($path in $Paths) {
		if (-not (Test-Path $path)) { continue }
		$lines = [System.IO.File]::ReadAllLines($path, [System.Text.Encoding]::UTF8)
		foreach ($line in $lines) {
			$parts = $line.Split("`t")
			if ($parts.Count -ge 31 -and $parts[0] -match "^\d+$" -and $parts[30] -match "^\d+$") {
				$base = [int]$parts[30]
				if ($base -ge 40000) {
					$baseMap[$parts[0].Trim()] = [string]$base
				}
			}
		}
	}
	return $baseMap
}

function Get-GlobalItemIconRefs {
	param([string]$Path)
	$refMap = @{}
	if (-not (Test-Path $Path)) { return $refMap }
	$lines = [System.IO.File]::ReadAllLines($Path, [System.Text.Encoding]::UTF8)
	foreach ($line in $lines) {
		$trimmed = $line.Trim()
		if ($trimmed -match "^(\d+)\s+.*\[IN;(\d+)\]") {
			$refMap[$Matches[1]] = $Matches[2]
		}
	}
	return $refMap
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

function Get-VisibleMobVnums {
	param([string]$Path)
	$vnums = @{}
	if (-not (Test-Path $Path)) { return $vnums }

	$lines = [System.IO.File]::ReadAllLines($Path, [System.Text.Encoding]::UTF8)
	foreach ($line in $lines) {
		$clean = ($line -replace "#.*$", "").Trim()
		if ($clean -match "^(\d+)\b") {
			$vnums[$Matches[1]] = $true
		}
	}
	return $vnums
}

function Merge-MobGroupsByVnum {
	param($Groups)

	$merged = @{}
	$order = @()
	foreach ($g in $Groups) {
		$key = [string]$g.MobVnum
		if (-not $merged.ContainsKey($key)) {
			$merged[$key] = @{
				MobVnum = $g.MobVnum
				MobName = $g.MobName
				Type    = $g.Type
				Items   = @()
			}
			$order += $key
		}
		$merged[$key].Items += $g.Items
	}

	$result = @()
	foreach ($key in $order) {
		$result += $merged[$key]
	}
	return $result
}

function Merge-ChestGroupsByVnum {
	param($Groups)

	$merged = @{}
	$order = @()
	foreach ($g in $Groups) {
		$key = [string]$g.ChestVnum
		if (-not $merged.ContainsKey($key)) {
			$merged[$key] = @{
				GroupName = $g.GroupName
				ChestVnum = $g.ChestVnum
				ChestName = $g.ChestName
				Type      = $g.Type
				Items     = @()
			}
			$order += $key
		}
		$merged[$key].Items += $g.Items
	}

	$result = @()
	foreach ($key in $order) {
		$result += $merged[$key]
	}
	return $result
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
								  <img class="drop-item-icon" src="icons/$iVnum.png" onerror="this.src='icons/default.png'" alt="$iName" loading="lazy">
								  <span class="drop-item-name">$iName</span>
								  $countDisplay
							  </div>
"@
		}

		$tableRowsHtml += @"
				<tr>
					<td class="metin-name-cell">$mobName</td>
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
						<div class="mob-table-filters">
							<label class="mob-table-filter"><i class="fas fa-dragon"></i><input type="text" class="mob-table-search" data-filter-kind="mob" placeholder="Canavar ara..."></label>
							<label class="mob-table-filter"><i class="fas fa-gem"></i><input type="text" class="mob-table-search" data-filter-kind="item" placeholder="Esya ara..."></label>
						</div>
						<div style="padding: 0.25rem 0.5rem; background: rgba(0,0,0,0.15); overflow-x: auto;">
							<table class="metin-drop-table">
								<thead>
									<tr>
										<th>Mob Name</th>
										<th>Drop List</th>
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
								  <img class="drop-item-icon" src="icons/$iVnum.png" onerror="this.src='icons/default.png'" alt="$iName" loading="lazy">
								  <span class="drop-item-name">$iName</span>
								  $countDisplay
							  </div>
"@
		}

		$tableRowsHtml += @"
				<tr>
					<td class="metin-name-cell">$mobName</td>
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
						<div class="mob-table-filters">
							<label class="mob-table-filter"><i class="fas fa-dragon"></i><input type="text" class="mob-table-search" data-filter-kind="mob" placeholder="Canavar ara..."></label>
							<label class="mob-table-filter"><i class="fas fa-gem"></i><input type="text" class="mob-table-search" data-filter-kind="item" placeholder="Esya ara..."></label>
						</div>
						<div style="padding: 0.25rem 0.5rem; background: rgba(0,0,0,0.15); overflow-x: auto;">
							<table class="metin-drop-table">
								<thead>
									<tr>
										<th>Mob Name</th>
										<th>Drop List</th>
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

function New-CostumeItem {
	param([string]$Vnum, [string]$Name, [string]$IconKey = "", [string]$IconVnum = "")
	if ($IconVnum -eq "") { $IconVnum = $Vnum }
	return @{ Vnum = $Vnum; Name = $Name; IconKey = $IconKey; IconVnum = $IconVnum }
}

function New-CostumeSlot {
	param([string]$Title, [array]$Items, [string]$Note = "")
	return @{ Title = $Title; Items = $Items; Note = $Note }
}

function New-CostumeSet {
	param([string]$Name, [array]$Slots, [hashtable]$Bonuses)
	return @{ Name = $Name; Slots = $Slots; Bonuses = $Bonuses }
}

function Get-SetRequirementLabel {
	param([string]$Token)
	switch ($Token) {
		"SET_ITEM_COSTUME_BODY" { return "Kostum" }
		"SET_ITEM_COSTUME_HAIR" { return "Kask" }
		"SET_ITEM_COSTUME_MOUNT" { return "Binek" }
		"SET_ITEM_COSTUME_ACCE" { return "Kusak" }
		"SET_ITEM_COSTUME_WEAPON" { return "Silah Kostumu" }
		"SET_ITEM_UNIQUE" { return "Yuzuk/Esya" }
		"SET_ITEM_PET" { return "Pet" }
		default { return ($Token -replace "^SET_ITEM_", "" -replace "_", " ") }
	}
}

function Get-ApplyLabel {
	param([string]$Apply)
	$labels = @{
		"MAX_HP" = "HP"
		"MOV_SPEED" = "Hareket Hizi"
		"MALL_EXPBONUS" = "EXP Bonusu"
		"MALL_ITEMBONUS" = "Esya Dusurme Sansi"
		"ITEM_DROP_BONUS" = "Esya Dusurme Sansi"
		"ATTBONUS_MONSTER" = "Canavarlara Karsi Guc"
		"ATTBONUS_STONE" = "Metinlere Karsi Guc"
		"SKILL_DAMAGE_BONUS" = "Beceri Hasari"
		"NORMAL_HIT_DAMAGE_BONUS" = "Ortalama Zarar"
		"NORMAL_HIT_DAMAGE_BONUS_BOSS_OR_MORE" = "Patronlara Karsi Saldiri Hasari"
		"MELEE_MAGIC_ATTBONUS_PER" = "Buyu/Yakin Dovus Saldiri"
		"STUN_PCT" = "Sersemletme Sansi"
		"HP_REGEN" = "HP Yenileme"
		"RESIST_FIRE" = "Atese Karsi Dayaniklilik"
		"RESIST_ICE" = "Buza Karsi Dayaniklilik"
		"ENCHANT_PER_ELECT" = "Simsek Gucu"
		"ENCHANT_PER_FIRE" = "Ates Gucu"
		"ENCHANT_PER_ICE" = "Buz Gucu"
		"ENCHANT_PER_WIND" = "Ruzgar Gucu"
		"ENCHANT_PER_EARTH" = "Toprak Gucu"
		"ENCHANT_PER_DARK" = "Karanlik Gucu"
		"ENCHANT_DARK" = "Karanlik Efsunu"
		"ATTBONUS_UNDEAD" = "Olumsuzlere Karsi Guc"
	}
	if ($labels.ContainsKey($Apply)) { return $labels[$Apply] }
	return ($Apply -replace "_", " ")
}

function Format-SetBonus {
	param([string]$Apply, [string]$Value)
	$label = Get-ApplyLabel -Apply $Apply
	if ($Apply -eq "MAX_HP" -or $Apply -match "^ENCHANT_") {
		return "+$Value $label"
	}
	return "+%$Value $label"
}

function Get-SetDisplayName {
	param([string]$GroupName)
	$name = $GroupName -replace "SetBonus", "" -replace "_", " "
	$name = $name.Trim()
	if ($name.EndsWith("+")) { $name = $name.Substring(0, $name.Length - 1).Trim() + "+" }
	return "$name Seti"
}

function New-ItemsFromRange {
	param([int]$Min, [int]$Max, [int]$Step, [hashtable]$ItemNames = @{}, [hashtable]$IconPaths = @{}, [hashtable]$IconBaseVnums = @{})
	if ($Max -le 0 -or $Max -lt $Min) { $Max = $Min }
	if ($Step -le 0) { $Step = 1 }

	$items = @()
	for ($v = $Min; $v -le $Max; $v += $Step) {
		$name = ""
		if ($ItemNames.ContainsKey([string]$v)) { $name = $ItemNames[[string]$v] }
		$iconKey = ""
		$iconVnum = [string]$v
		if ($IconPaths.ContainsKey([string]$v)) {
			$iconKey = $IconPaths[[string]$v]
		}
		elseif ($IconBaseVnums.ContainsKey([string]$v)) {
			$iconVnum = $IconBaseVnums[[string]$v]
			if ($IconPaths.ContainsKey($iconVnum)) { $iconKey = $IconPaths[$iconVnum] }
		}
		$items += New-CostumeItem -Vnum ([string]$v) -Name $name -IconKey $iconKey -IconVnum $iconVnum
	}
	return $items
}

function Parse-SetItemTable {
	param([string]$Path, [hashtable]$ItemNames = @{}, [hashtable]$IconPaths = @{}, [hashtable]$IconBaseVnums = @{}, [hashtable]$GlobalIconRefs = @{})
	if (-not (Test-Path $Path)) {
		Write-Host "UYARI: $Path bulunamadi" -ForegroundColor Yellow
		return @()
	}

	$sets = @()
	$lines = [System.IO.File]::ReadAllLines($Path, [System.Text.Encoding]::UTF8)
	$current = $null
	$inGroup = $false

	foreach ($line in $lines) {
		$clean = ($line -replace "#.*$", "").Trim()
		if ($clean -eq "") { continue }

		if ($clean -match "^Group\s+(.+)$") {
			$current = @{
				Name = $Matches[1].Trim()
				Requirements = @()
				BonusLines = @()
			}
			continue
		}
		if ($clean -eq "{") { $inGroup = $true; continue }
		if ($clean -eq "}") {
			if ($inGroup -and $current) {
				if ($current.Requirements.Count -gt 0 -and $current.BonusLines.Count -gt 0) {
					if ($current.Name -in @("Galip_Sandigi", "AzrailSetBonus+")) {
						$current = $null
						$inGroup = $false
						continue
					}
					$slots = @()
					$slotIndex = 1
					foreach ($req in $current.Requirements) {
						if ($req.Token -eq "SET_ITEM_UNIQUE") {
							$items = @()
							foreach ($fixedVnum in @("701000", "701030", "701040")) {
								$iconVnum = if ($GlobalIconRefs.ContainsKey($fixedVnum)) { $GlobalIconRefs[$fixedVnum] } else { $fixedVnum }
								$name = if ($ItemNames.ContainsKey($iconVnum)) { $ItemNames[$iconVnum] } elseif ($ItemNames.ContainsKey($fixedVnum)) { $ItemNames[$fixedVnum] } else { "Tilsim" }
								$iconKey = if ($IconPaths.ContainsKey($iconVnum)) { $IconPaths[$iconVnum] } else { "" }
								$items += New-CostumeItem -Vnum $fixedVnum -Name $name -IconKey $iconKey -IconVnum $iconVnum
							}
						}
						else {
							$items = New-ItemsFromRange -Min $req.Min -Max $req.Max -Step $req.Step -ItemNames $ItemNames -IconPaths $IconPaths -IconBaseVnums $IconBaseVnums
						}
						$note = if ($req.Max -gt $req.Min) { "Aralik: $($req.Min)-$($req.Max)" } else { "" }
						$slots += New-CostumeSlot -Title "$slotIndex. Urun - $($req.Label)" -Items $items -Note $note
						$slotIndex++
					}

					$bonuses = @{}
					foreach ($bonus in $current.BonusLines) {
						$key = [string]$bonus.Pieces
						$formatted = Format-SetBonus -Apply $bonus.Apply -Value $bonus.Value
						if ($bonuses.ContainsKey($key)) { $bonuses[$key] += " + $formatted" }
						else { $bonuses[$key] = $formatted }
					}

					$sets += New-CostumeSet -Name (Get-SetDisplayName -GroupName $current.Name) -Slots $slots -Bonuses $bonuses
				}
			}
			$current = $null
			$inGroup = $false
			continue
		}

		if (-not $inGroup -or -not $current) { continue }

		if ($clean -match "^SET_VALUE\s+(\d+)") { continue }
		if ($clean -match "^(SET_ITEM_[A-Z_]+)\s+(\d+)\s+(\d+)\s+(\d+)") {
			$min = [int]$Matches[2]
			$max = [int]$Matches[3]
			$step = [int]$Matches[4]
			$current.Requirements += @{
				Token = $Matches[1]
				Label = Get-SetRequirementLabel -Token $Matches[1]
				Min = $min
				Max = $max
				Step = $step
			}
			continue
		}
		if ($clean -match "^\d+\s+(\d+)\s+([A-Z0-9_]+)\s+(-?\d+)") {
			$current.BonusLines += @{
				Pieces = [int]$Matches[1]
				Apply = $Matches[2]
				Value = $Matches[3]
			}
		}
	}

	return $sets
}

function Resolve-CostumeItemNames {
	param([array]$Sets, [hashtable]$ItemNames = @{})
	foreach ($set in $Sets) {
		foreach ($slot in $set.Slots) {
			foreach ($item in $slot.Items) {
				if (($item.Name -eq "" -or $null -eq $item.Name) -and $ItemNames.ContainsKey([string]$item.Vnum)) {
					$item.Name = $ItemNames[[string]$item.Vnum]
				}
				elseif ($item.Name -eq "" -or $null -eq $item.Name) {
					$item.Name = "Item $($item.Vnum)"
				}
			}
		}
	}
	return $Sets
}

function Build-CostumeItemHtml {
	param($Item)
	$iVnum = [System.Security.SecurityElement]::Escape([string]$Item.Vnum)
	$iName = [System.Security.SecurityElement]::Escape([string]$Item.Name)
	$iconVnum = [System.Security.SecurityElement]::Escape([string]$Item.IconVnum)
	return "<span class=`"costume-item`" title=`"$iName`"><img src=`"icons/$iconVnum.png`" onerror=`"this.src='icons/default.png'`" alt=`"$iName`" loading=`"lazy`"></span>"
}

function Get-UniqueIconItems {
	param([array]$Items)
	$seen = @{}
	$unique = @()
	foreach ($item in $Items) {
		$key = [string]$item.IconKey
		if ($key -eq "") { $key = [string]$item.Vnum }
		if ($seen.ContainsKey($key)) { continue }
		$seen[$key] = $true
		$unique += $item
	}
	return $unique
}

function Build-CostumeSetsHtml {
	param([array]$Sets)

	$setsHtml = ""
	foreach ($set in $Sets) {
		$setName = [System.Security.SecurityElement]::Escape([string]$set.Name)
		$maxPieces = 0
		foreach ($slot in $set.Slots) {
			$pieceNo = 0
			if ([int]::TryParse(($slot.Title -replace "\D", ""), [ref]$pieceNo) -and $pieceNo -gt $maxPieces) {
				$maxPieces = $pieceNo
			}
		}

		$headCells = ""
		foreach ($slot in $set.Slots) {
			$slotTitle = [System.Security.SecurityElement]::Escape([string]$slot.Title)
			$itemsHtml = ""
			$visibleSlotItems = @($slot.Items | Where-Object { [string]$_.IconVnum -ne "76030" -and [string]$_.Vnum -ne "701010" })
			$uniqueItems = Get-UniqueIconItems -Items $visibleSlotItems
			$displayItems = @($uniqueItems | Select-Object -First 12)
			foreach ($item in $displayItems) {
				$itemsHtml += Build-CostumeItemHtml -Item $item
			}
			$noteHtml = ""
			$headCells += @"
									<th>
										<div class="costume-piece-title">$slotTitle</div>
										<div class="costume-icons">$itemsHtml</div>
										$noteHtml
									</th>
"@
		}

		$bonusRows = ""
		for ($i = 2; $i -le $maxPieces; $i++) {
			if ($set.Bonuses.ContainsKey([string]$i)) {
				$bonusText = [System.Security.SecurityElement]::Escape([string]$set.Bonuses[[string]$i])
				$bonusRows += @"
								<tr>
									<td class="bonus-tier">$i Urun Bonusu</td>
									<td colspan="$($set.Slots.Count)" class="bonus-text">$bonusText</td>
								</tr>
"@
			}
		}

		$setsHtml += @"
						<section class="costume-set-block">
							<h3>$setName</h3>
							<div class="costume-table-wrap">
								<table class="costume-set-table">
									<thead>
										<tr>
											<th class="bonus-corner"></th>
$headCells
										</tr>
									</thead>
									<tbody>
$bonusRows
									</tbody>
								</table>
							</div>
						</section>
"@
	}

	return @"
					<div class="wiki-card" id="costume-set-bonuses" data-category="costume" style="display:none;">
						<div class="w-card-header" style="background: linear-gradient(135deg, rgba(168,85,247,0.08), transparent);">
							<div class="w-icon" style="background: rgba(168,85,247,0.15); color: #a855f7;"><i class="fas fa-shirt"></i></div>
							<div>
								<div class="w-title">Kostum Set Bonuslari</div>
								<div class="w-type"><span class="cat-label cat-costume">Kostum</span> Parca sayisina gore aktif olan set bonuslari</div>
							</div>
						</div>
						<div class="costume-sets">
$setsHtml
						</div>
						<div class="w-card-footer">
							<span class="drop-count"><i class="fas fa-shirt"></i> $($Sets.Count) set</span>
						</div>
					</div>
"@
}

# ======================== MAIN ========================
Write-Host "=== Harbi2 Drop Wiki Generator v3 ===" -ForegroundColor Cyan

# Load item names for name resolution (chest names + item names)
$itemNamesPath = Join-Path $confDir "item_names.txt"
$itemNamesMap = Get-ItemNames -Path $itemNamesPath
Write-Host "Item isimleri yuklendi: $($itemNamesMap.Count) kayit" -ForegroundColor DarkGray

$itemListPath = Join-Path $scriptDir "item_list.txt"
$itemIconPaths = Get-ItemIconPaths -Path $itemListPath
Write-Host "Item icon yollari yuklendi: $($itemIconPaths.Count) kayit" -ForegroundColor DarkGray

$itemProtoPathForIcons = Join-Path $confDir "item_proto.txt"
$globalItemProtoPathForIcons = Join-Path $confDir "global_item_proto.txt"
$itemIconBaseVnums = Get-ItemIconBaseVnums -Paths @($itemProtoPathForIcons, $globalItemProtoPathForIcons)
Write-Host "Item base icon VNUM yuklendi: $($itemIconBaseVnums.Count) kayit" -ForegroundColor DarkGray

$globalItemNamesPath = Join-Path $confDir "global_item_names.txt"
$globalIconRefs = Get-GlobalItemIconRefs -Path $globalItemNamesPath
Write-Host "Global item icon referanslari yuklendi: $($globalIconRefs.Count) kayit" -ForegroundColor DarkGray

$setItemTablePath = Join-Path $sourceDir "set_item_table.txt"
$costumeSets = Parse-SetItemTable -Path $setItemTablePath -ItemNames $itemNamesMap -IconPaths $itemIconPaths -IconBaseVnums $itemIconBaseVnums -GlobalIconRefs $globalIconRefs
$costumeSets = Resolve-CostumeItemNames -Sets $costumeSets -ItemNames $itemNamesMap
Write-Host "Kostum setleri yuklendi: $($costumeSets.Count) set" -ForegroundColor Green

# Load mob names for name resolution
$mobNamesPath = Join-Path $confDir "mob_names.txt"
$mobNamesMap = Get-MobNames -Path $mobNamesPath
Write-Host "Mob isimleri yuklendi: $($mobNamesMap.Count) kayit" -ForegroundColor DarkGray

$mobGroups = Parse-MobDropFile -Path $mobDropFile -MobNames $mobNamesMap -ItemNames $itemNamesMap
$visibleMobVnumsPath = Join-Path $scriptDir "visible_mob_vnums.txt"
$visibleMobVnums = Get-VisibleMobVnums -Path $visibleMobVnumsPath
if ($visibleMobVnums.Count -gt 0) {
	$mobGroups = @($mobGroups | Where-Object { $visibleMobVnums.ContainsKey([string]$_.MobVnum) })
	Write-Host "Mob VNUM filtresi aktif: $($visibleMobVnums.Count) VNUM" -ForegroundColor DarkGray
}
$mobGroups = Merge-MobGroupsByVnum -Groups $mobGroups
Write-Host "Canavarlar: $($mobGroups.Count) grup" -ForegroundColor Green

$chestGroups = Parse-ChestDropFile -Path $chestDropFile -ItemNames $itemNamesMap
$visibleChestVnumsPath = Join-Path $scriptDir "visible_chest_vnums.txt"
$visibleChestVnums = Get-VisibleMobVnums -Path $visibleChestVnumsPath
if ($visibleChestVnums.Count -gt 0) {
	$chestGroups = @($chestGroups | Where-Object { $visibleChestVnums.ContainsKey([string]$_.ChestVnum) })
	Write-Host "Sandik VNUM filtresi aktif: $($visibleChestVnums.Count) VNUM" -ForegroundColor DarkGray
}
$chestGroups = Merge-ChestGroupsByVnum -Groups $chestGroups
Write-Host "Sandiklar: $($chestGroups.Count) grup" -ForegroundColor Green

# Build sidebar
$mobProtoPath = Join-Path $confDir "mob_proto.txt"
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
$sidebarHtml += "                        <div class=`"sidebar-section-title`"><i class=`"fas fa-dragon`"></i> Moblar <span class=`"section-count`">$($mobGroups.Count)</span></div>`n"

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
$sidebarHtml += "                        <div class=`"sidebar-section-title`"><i class=`"fas fa-shirt`"></i> Kostumler <span class=`"section-count`">$($costumeSets.Count)</span></div>`n"
$sidebarHtml += "                        <button class=`"w-cat-btn`" data-target=`"costume-set-bonuses`" data-category=`"costume`" style=`"margin-bottom: 0.5rem; background: rgba(168,85,247,0.08); border-left-color: #a855f7;`"><i class=`"fas fa-table`" style=`"margin-right: 6px;`"></i> Set Bonuslari</button>`n"
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
$cardsHtml += Build-CostumeSetsHtml -Sets $costumeSets

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
			--bg-card: #181c1f;
			--bg-sidebar: #111416;
			--bg-input: #1b1b1b;

			--text-high: #eaeaf4;
			--text-med: #9898b8;
			--text-low: #9aa6ad;
			--text-muted: #6f7a80;

			--accent-blue: #8ba4b8;
			--accent-blue-dim: rgba(139,164,184,0.14);
			--accent-gold: #9aa6ad;
			--accent-gold-dim: rgba(154,166,173,0.14);

			--brand-gold: #e7edf2;

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
		html { scroll-behavior: smooth; overflow-x: hidden; }
		body {
			font-family: var(--font-body);
			background: var(--bg-base);
			color: var(--text-high);
			min-height: 100vh;
			overflow-x: hidden;
		}

		::-webkit-scrollbar { width: 5px; height: 0; }
		::-webkit-scrollbar-track { background: #000; }
		::-webkit-scrollbar-thumb { background: #30383d; border-radius: 0; }

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
		.sidebar-subtitle {
			padding-top: 0.7rem;
			color: var(--text-low);
			letter-spacing: 1.5px;
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
		.cat-costume { background: rgba(168,85,247,0.15); color: #a855f7; }

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

		/* ========== COSTUME SETS ========== */
		.costume-sets {
			padding: 1rem;
			background: rgba(0,0,0,0.15);
		}
		.costume-set-block {
			margin-bottom: 1.25rem;
		}
		.costume-set-block:last-child { margin-bottom: 0; }
		.costume-set-block h3 {
			font-family: var(--font-display);
			font-size: 1rem;
			font-weight: 600;
			color: var(--text-high);
			letter-spacing: 1px;
			margin-bottom: 0.55rem;
		}
		.costume-table-wrap {
			overflow-x: auto;
			border: 1px solid var(--border);
			border-radius: var(--radius-sm);
			background: rgba(255,255,255,0.02);
		}
		.costume-set-table {
			width: 100%;
			min-width: 760px;
			border-collapse: collapse;
			table-layout: fixed;
		}
		.costume-set-table th,
		.costume-set-table td {
			border-bottom: 1px solid var(--border);
			border-right: 1px solid var(--border);
		}
		.costume-set-table th:last-child,
		.costume-set-table td:last-child { border-right: none; }
		.costume-set-table tbody tr:last-child td { border-bottom: none; }
		.costume-set-table thead th {
			padding: 0.45rem 0.5rem;
			background: rgba(120,0,0,0.5);
			vertical-align: top;
		}
		.costume-set-table .bonus-corner {
			width: 130px;
			background: rgba(120,0,0,0.35);
		}
		.costume-piece-title {
			font-size: 0.68rem;
			font-weight: 800;
			color: #f7d28b;
			margin-bottom: 0.35rem;
		}
		.costume-icons {
			display: flex;
			align-items: center;
			justify-content: center;
			gap: 0.25rem;
			flex-wrap: wrap;
			min-height: 38px;
		}
		.costume-item {
			display: inline-flex;
			width: 34px;
			min-height: 34px;
			align-items: center;
			justify-content: center;
			border-radius: 4px;
			background: rgba(0,0,0,0.22);
			border: 1px solid rgba(255,255,255,0.06);
		}
		.costume-item img {
			width: 30px;
			height: auto;
			max-height: 72px;
			image-rendering: pixelated;
		}
		.costume-more {
			display: inline-flex;
			align-items: center;
			justify-content: center;
			min-width: 34px;
			height: 34px;
			border-radius: 4px;
			background: rgba(168,85,247,0.14);
			color: #d8b4fe;
			font-size: 0.62rem;
			font-weight: 800;
			border: 1px solid rgba(168,85,247,0.25);
		}
		.costume-range-pill {
			display: inline-flex;
			align-items: center;
			justify-content: center;
			min-height: 34px;
			padding: 0 0.7rem;
			border-radius: 4px;
			background: rgba(168,85,247,0.14);
			color: #f7d28b;
			font-size: 0.66rem;
			font-weight: 800;
			border: 1px solid rgba(168,85,247,0.25);
		}
		.costume-note {
			margin-top: 0.25rem;
			color: #f4dca4;
			font-size: 0.58rem;
			font-style: italic;
		}
		.bonus-tier {
			width: 130px;
			padding: 0.35rem 0.55rem;
			background: rgba(120,0,0,0.45);
			color: #f7d28b;
			font-size: 0.62rem;
			font-weight: 800;
			white-space: nowrap;
		}
		.bonus-text {
			padding: 0.35rem 0.65rem;
			color: var(--text-high);
			font-size: 0.66rem;
			text-align: center;
			line-height: 1.35;
		}

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
		.metin-drop-table th:nth-child(2) { width: auto; }
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

		/* ========== DARK NEUTRAL WIKI SKIN OVERRIDE ========== */
		:root {
			--bg-base: #07090a;
			--bg-surface: #111416;
			--bg-card: #181c1f;
			--bg-sidebar: #111416;
			--bg-input: #1b1f22;
			--text-high: #e8eef2;
			--text-med: #b7c1c7;
			--text-low: #9aa6ad;
			--text-muted: #6f7a80;
			--accent-blue: #8ba4b8;
			--accent-blue-dim: rgba(139,164,184,0.14);
			--accent-gold: #9aa6ad;
			--accent-gold-dim: rgba(154,166,173,0.14);
			--brand-gold: #e7edf2;
			--border: #3f474d;
			--border-active: #65727a;
			--radius-sm: 2px;
			--radius-md: 2px;
		}
		body {
			background:
				radial-gradient(circle at 20% 0%, rgba(255,244,205,0.55), transparent 34rem),
				linear-gradient(90deg, rgba(116,72,35,0.12), transparent 16rem),
				#d7c3a3;
			color: var(--text-high);
		}
		::-webkit-scrollbar-thumb { background: #3f474d; }
		.sidebar {
			background: #111416;
			border-right: 1px solid #8c6a3e;
			box-shadow: inset -1px 0 0 rgba(255,255,255,0.45), 2px 0 10px rgba(58,35,16,0.16);
		}
		.sidebar-header {
			background: linear-gradient(#6d130e, #3b0906);
			border-bottom: 2px solid #3f474d;
			padding: 1rem;
		}
		.logo-icon {
			background: #232a2f;
			color: #5d100b;
			border: 1px solid #2b0805;
		}
		.logo-text h2 { color: #e7edf2; text-shadow: 0 1px 0 #000; }
		.logo-text p { color: #e9c987; }
		.sidebar-search {
			background: #d2b889;
			border-bottom: 1px solid #a47b48;
		}
		.search-box input,
		.hero-search .search-box input {
			background: #1b1f22;
			border: 1px solid #3f474d;
			color: #2b1a10;
			box-shadow: inset 0 1px 2px rgba(79,43,12,0.18);
		}
		.search-box input::placeholder,
		.hero-search .search-box input::placeholder { color: #8b765b; }
		.search-mode-toggle,
		.category-filter { background: #d2b889; }
		.search-mode-btn,
		.cat-filter-btn {
			background: #181c1f;
			border-color: #3f474d;
			color: #5b4027;
			font-weight: 700;
		}
		.search-mode-btn.active,
		.cat-filter-btn.active {
			background: linear-gradient(#65727a, #101315);
			border-color: #451008;
			color: #ffe4a0;
		}
		.sidebar-nav { padding: 0.4rem 0.55rem; }
		.sidebar-section {
			border: 1px solid #3f474d;
			background: rgba(157,122,76,0.35);
			margin-bottom: 0.55rem;
		}
		.sidebar-section-title {
			background: linear-gradient(#232a2f, #101315);
			color: #ffe4a0;
			padding: 0.45rem 0.65rem;
			letter-spacing: 1px;
			border-bottom: 1px solid #3f474d;
		}
		.section-count {
			background: rgba(255,228,160,0.16);
			color: #ffe4a0;
			border-radius: 2px;
		}
		.w-cat-btn {
			color: #3d2818;
			border-left: 0;
			border-top: 1px solid rgba(157,122,76,0.35);
			padding: 0.38rem 0.65rem;
			background: transparent !important;
		}
		.w-cat-btn:hover,
		.w-cat-btn.active {
			color: #232a2f;
			background: #232a2f !important;
			font-weight: 800;
		}
		.sidebar-footer {
			background: #d2b889;
			color: #5b4027;
			border-top-color: #3f474d;
		}
		.main-content {
			background: rgba(255,248,232,0.42);
			min-height: 100vh;
		}
		.page-hero {
			margin: 1rem 1.25rem 0;
			padding: 1.2rem 1.35rem;
			background: linear-gradient(#181c1f, #111416);
			border: 1px solid #3f474d;
			border-top: 5px solid #232a2f;
			box-shadow: 0 2px 8px rgba(59,34,13,0.14);
		}
		.hero-tag {
			color: #232a2f;
			border: 1px solid #3f474d;
			background: #181c1f;
			border-radius: 2px;
		}
		.hero-tag .dot { background: #232a2f; animation: none; }
		.page-hero h1 {
			color: #e8eef2;
			font-size: 1.65rem;
			letter-spacing: 1px;
			text-shadow: 0 1px 0 #fff4d2;
		}
		.page-hero p { color: #5b4027; font-weight: 500; }
		.stat-chip {
			background: #1b1f22;
			border: 1px solid #3f474d;
			color: #4b3524;
			border-radius: 2px;
		}
		.stat-chip strong { color: #232a2f; }
		.hero-search {
			margin: 0 1.25rem;
			padding: 0.75rem;
			background: #111416;
			border: 1px solid #3f474d;
			border-top: 0;
		}
		.content-area { padding: 1rem 1.25rem 3rem; }
		.wiki-card {
			background: #181c1f;
			border: 1px solid #3f474d;
			border-radius: 2px;
			box-shadow: 0 1px 4px rgba(59,34,13,0.12);
		}
		.wiki-card:hover {
			border-color: #232a2f;
			box-shadow: 0 2px 8px rgba(59,34,13,0.18);
		}
		.w-card-header {
			background: linear-gradient(#232a2f, #101315) !important;
			border-bottom: 2px solid #3f474d;
			color: #ffe4a0;
		}
		.w-icon {
			background: #232a2f !important;
			color: #5d100b !important;
			border: 1px solid #2b0805;
		}
		.w-title {
			color: #ffe4a0;
			text-transform: uppercase;
			letter-spacing: 1px;
			text-shadow: 0 1px 0 #000;
		}
		.w-type { color: #e9c987; }
		.cat-label {
			background: #232a2f !important;
			color: #e8eef2 !important;
			border: 1px solid #3f474d;
			border-radius: 2px;
		}
		.drop-grid-wrap,
		.costume-sets,
		.wiki-card > div[style*="overflow-x"] {
			background: #181c1f !important;
		}
		.drop-grid { gap: 7px; }
		.grid-item {
			background: #1b1f22;
			border: 1px solid #c6a86f;
			border-radius: 2px;
			box-shadow: inset 0 0 0 1px rgba(255,255,255,0.45);
		}
		.grid-item:hover {
			background: #181c1f;
			border-color: #65727a;
			transform: none;
			box-shadow: 0 1px 5px rgba(73,39,13,0.2);
		}
		.grid-name,
		.drop-item-name,
		.drop-items-cell { color: #4b3524; }
		.grid-chance,
		.drop-item-chance {
			background: #232a2f;
			color: #232a2f;
			border: 1px solid #c6a86f;
		}
		.grid-count,
		.drop-item-count {
			background: #232a2f;
			color: #ffe4a0;
		}
		.grid-item::after {
			background: #181c1f;
			color: #2b1a10;
			border-color: #3f474d;
		}
		.w-card-footer {
			background: #111416;
			border-top-color: #3f474d;
		}
		.drop-count { color: #5b4027; }
		.drop-count i { color: #232a2f; }
		.metin-drop-table,
		.costume-set-table {
			background: #1b1f22;
			border: 1px solid #3f474d;
			border-radius: 0;
		}
		.metin-drop-table thead,
		.costume-set-table thead th {
			background: linear-gradient(#232a2f, #101315);
		}
		.metin-drop-table th,
		.costume-set-table th {
			color: #ffe4a0;
			border-color: #3f474d;
		}
		.metin-drop-table td,
		.costume-set-table td {
			color: #3d2818;
			border-color: #d0b37d;
		}
		.metin-drop-table tbody tr:nth-child(even),
		.costume-set-table tbody tr:nth-child(even) { background: #181c1f; }
		.metin-drop-table tbody tr:hover { background: #232a2f; }
		.metin-name-cell { color: #e8eef2; }
		.drop-item-icon {
			background: #1b1f22;
			border: 1px solid #c6a86f;
		}
		.costume-set-block h3 {
			color: #e8eef2;
			border-bottom: 1px solid #3f474d;
			padding-bottom: 0.25rem;
		}
		.costume-table-wrap {
			background: #1b1f22;
			border-color: #3f474d;
			border-radius: 0;
		}
		.costume-set-table thead th,
		.costume-set-table .bonus-corner {
			background: linear-gradient(#232a2f, #101315);
		}
		.costume-piece-title { color: #ffe4a0; }
		.costume-item {
			background: #1b1f22;
			border: 1px solid #c6a86f;
			border-radius: 2px;
		}
		.bonus-tier {
			background: #232a2f;
			color: #ffe4a0;
			border-color: #3f474d;
		}
		.bonus-text {
			color: #ffffff;
			background: #1b1f22;
			font-weight: 700;
		}
		.mobile-topbar {
			background: linear-gradient(#232a2f, #101315);
			border-bottom: 2px solid #3f474d;
		}
		.mobile-topbar h3 { color: #ffe4a0; }
		.mobile-topbar button { color: #ffe4a0; }
		@media (max-width: 768px) {
			.page-hero { margin: 0; border-left: 0; border-right: 0; }
			.hero-search { margin: 0; border-left: 0; border-right: 0; }
		}

		/* ========== SET BONUS PAGE DARK METIN2 TUNING ========== */
		body {
			background: #050402;
		}
		.main-content {
			background: #0a0805;
		}
		.page-hero,
		.hero-search {
			background: #4f3908;
			border-color: #3f474d;
			box-shadow: none;
		}
		.page-hero {
			border-top-color: #b00000;
		}
		.page-hero h1,
		.page-hero p,
		.stat-chip,
		.stat-chip strong {
			color: #f3e7c0;
		}
		.stat-chip,
		.search-mode-btn,
		.cat-filter-btn,
		.hero-search .search-box input {
			background: #2b2008;
			color: #f3e7c0;
			border-color: #3f474d;
		}
		.search-mode-toggle,
		.category-filter {
			background: #4f3908;
		}
		.wiki-card {
			background: #4f3908;
			border-color: #3f474d;
			box-shadow: none;
		}
		.wiki-card:hover {
			border-color: #b00000;
			box-shadow: none;
		}
		.w-card-header {
			background: linear-gradient(#7f0000, #4b0000) !important;
			border-bottom-color: #b79a49;
		}
		.drop-grid-wrap,
		.costume-sets,
		.wiki-card > div[style*="overflow-x"] {
			background: #4f3908 !important;
		}
		.costume-set-block h3 {
			color: #e8eef2;
			border-bottom: 1px solid #3f474d;
			font-size: 1.15rem;
			letter-spacing: 0;
		}
		.costume-table-wrap {
			background: #4f3908;
			border-color: #3f474d;
		}
		.costume-set-table {
			background: #4f3908;
			border-color: #3f474d;
		}
		.costume-set-table thead th,
		.costume-set-table .bonus-corner {
			background: #7f0000;
			color: #f1f5f8;
			border-color: #3f474d;
		}
		.costume-piece-title {
			color: #f1f5f8;
			text-shadow: 0 1px 0 #000;
		}
		.costume-icons {
			min-height: 58px;
		}
		.costume-item {
			background: transparent;
			border: 0;
			width: 36px;
			min-height: 42px;
		}
		.costume-item img {
			width: 34px;
			max-height: 88px;
			border: 1px solid #d4a400;
			background: #111;
		}
		.costume-set-table td {
			background: #4f3908;
			border-color: #3f474d;
		}
		.bonus-tier {
			background: #121517;
			color: #f1f5f8;
			border-color: #3f474d;
			text-align: center;
			font-size: 0.68rem;
		}
		.bonus-text {
			background: #181c1f;
			color: #1b1f22;
			font-size: 0.68rem;
			font-weight: 600;
		}
		.w-card-footer {
			background: #4f3908;
			border-top-color: #3f474d;
		}
		.drop-count {
			color: #f3e7c0;
		}
		.drop-count i {
			color: #f1f5f8;
		}
		.grid-item {
			background: #5a410c;
			border-color: #3f474d;
		}
		.grid-item:hover {
			background: #654b11;
			border-color: #b00000;
		}
		.grid-name,
		.drop-item-name,
		.drop-items-cell,
		.metin-drop-table td {
			color: #1b1f22;
		}
		.metin-drop-table,
		.metin-drop-table tbody tr:nth-child(even) {
			background: #4f3908;
		}
		.metin-drop-table thead,
		.metin-drop-table th {
			background: #7f0000;
			color: #f1f5f8;
		}

		/* ========== SET BONUS REFERENCE MATCH ========== */
		:root {
			--game-page-bg: #000;
			--game-panel-bg: #181c1f;
			--game-header-bg: #121517;
			--game-border: #3f474d;
			--game-header-text: #f1f5f8;
			--game-body-text: #e8eef2;
			--game-title-text: #f1f5f8;
			--theme-layout-gap: 20px;
			--theme-content-width: 716px;
			--theme-table-width: 670px;
			--theme-bonus-col-width: 126px;
		}
		body { background: var(--game-page-bg); }
		.main-content {
			background: var(--game-page-bg);
			margin-left: var(--sidebar-w);
			width: calc(100vw - var(--sidebar-w));
			min-width: calc(var(--theme-content-width) + (var(--theme-layout-gap) * 2));
		}
		.content-area {
			width: var(--theme-content-width);
			max-width: var(--theme-content-width);
			margin: 0 auto;
			padding: 12px 0 3rem;
		}
		.wiki-card,
		.wiki-card#costume-set-bonuses {
			width: var(--theme-content-width);
			background: var(--game-panel-bg);
			border: 1px solid var(--game-border);
			border-radius: 0;
			box-shadow: none;
			margin-top: 0.75rem;
		}
		.wiki-card:hover {
			border-color: var(--game-border);
			box-shadow: none;
		}
		.wiki-card#costume-set-bonuses > .w-card-header,
		.wiki-card#costume-set-bonuses > .w-card-footer {
			display: none;
		}
		.wiki-card > div[style*="overflow-x"],
		.wiki-card#costume-set-bonuses .costume-sets {
			background: var(--game-panel-bg) !important;
			padding: 14px 22px 26px;
		}
		.costume-set-block {
			margin-bottom: 1.7rem;
		}
		.costume-set-block h3 {
			font-family: Georgia, "Times New Roman", serif;
			color: var(--game-title-text);
			font-size: 1.28rem;
			font-weight: 400;
			line-height: 1.2;
			margin: 0 0 0.55rem;
			padding: 0;
			border: 0;
			text-shadow: 0 1px 0 #000;
		}
		.costume-table-wrap {
			border: 1px solid var(--game-border);
			background: var(--game-panel-bg);
			overflow: hidden;
		}
		.metin-drop-table,
		.costume-set-table {
			min-width: var(--theme-table-width);
			width: 100%;
			background: var(--game-panel-bg);
			border: 0;
			table-layout: fixed;
			border-collapse: collapse;
		}
		.metin-drop-table th,
		.metin-drop-table td,
		.costume-set-table th,
		.costume-set-table td {
			border: 1px solid var(--game-border);
		}
		.metin-drop-table thead,
		.metin-drop-table th,
		.costume-set-table thead th,
		.costume-set-table .bonus-corner {
			background: var(--game-panel-bg);
			padding: 0;
			vertical-align: top;
		}
		.costume-set-table .bonus-corner {
			width: var(--theme-bonus-col-width);
			background: var(--game-header-bg);
		}
		.metin-drop-table th,
		.costume-piece-title {
			display: block;
			margin: 0;
			padding: 0.18rem 0.25rem;
			background: var(--game-header-bg);
			color: var(--game-header-text);
			font-family: Arial, sans-serif;
			font-size: 0.72rem;
			font-weight: 800;
			line-height: 1.15;
			text-align: center;
			text-transform: none;
			letter-spacing: 0;
			text-shadow: var(--theme-header-shadow, 0 1px 0 #000);
		}
		.metin-drop-table th {
			display: table-cell;
		}
		.costume-icons {
			min-height: 66px;
			padding: 0.42rem 0.35rem 0.5rem;
			background: var(--game-panel-bg);
			gap: 0.16rem;
		}
		.costume-item {
			width: auto;
			min-height: 0;
			background: transparent;
			border: 0;
		}
		.costume-item img {
			width: 32px;
			max-height: 82px;
			background: transparent;
			border: 1px solid var(--theme-icon-border, #3f474d);
			image-rendering: pixelated;
		}
		.bonus-tier {
			width: var(--theme-bonus-col-width);
			padding: 0.16rem 0.35rem;
			background: var(--theme-bonus-tier-bg, var(--game-header-bg));
			color: var(--theme-bonus-tier-text, var(--game-header-text));
			font-family: Arial, sans-serif;
			font-size: 0.72rem;
			font-weight: 800;
			line-height: 1.15;
			text-align: center;
			text-shadow: var(--theme-header-shadow, 0 1px 0 #000);
		}
		.bonus-text {
			padding: 0.16rem 0.45rem;
			background: var(--game-panel-bg);
			color: var(--theme-bonus-text, var(--game-body-text));
			font-family: Arial, sans-serif;
			font-size: var(--theme-bonus-size, 0.68rem);
			font-weight: var(--theme-bonus-weight, 400);
			line-height: var(--theme-bonus-line, 1.25);
			text-align: var(--theme-bonus-align, center);
			text-shadow: var(--theme-bonus-shadow, none);
		}
		.costume-set-table tbody tr {
			height: 18px;
		}
		.metin-drop-table {
			width: 100%;
			min-width: var(--theme-table-width);
			border: 1px solid var(--game-border);
			border-radius: 0;
		}
		.metin-drop-table th:nth-child(1) { width: var(--theme-bonus-col-width); }
		.metin-drop-table th {
			padding: 0.45rem 0.5rem;
			background: var(--theme-drop-header-bg, #1b1b1b);
			color: var(--theme-drop-header-text, #ffffff);
			font-family: var(--theme-table-font, Arial, sans-serif);
			font-size: var(--theme-drop-header-size, 0.72rem);
			font-weight: 800;
			line-height: 1.15;
			text-align: left;
			text-shadow: none;
		}
		.metin-drop-table td {
			padding: var(--theme-drop-cell-pad, 0.45rem);
			background: var(--theme-drop-row-bg, #202323);
			color: var(--theme-drop-text, #ffffff);
			font-family: Arial, sans-serif;
			font-size: var(--theme-drop-text-size, 0.68rem);
			font-weight: 400;
			line-height: 1.35;
			text-align: left;
			text-shadow: none;
			vertical-align: top;
		}
		.metin-drop-table tbody tr:nth-child(even) td {
			background: var(--theme-drop-row-alt-bg, #191b1b);
		}
		.metin-drop-table tbody tr:hover td {
			background: var(--theme-drop-row-hover-bg, #252929);
		}
		.metin-name-cell {
			color: var(--theme-drop-name-text, #ffffff);
			font-weight: 500;
			white-space: normal;
		}
		.drop-items-cell {
			color: var(--theme-drop-text, #ffffff);
		}
		.drop-item-row {
			display: flex;
			align-items: center;
			gap: 0.35rem;
			margin-left: 1.05rem;
			padding: 0.1rem 0;
			line-height: 1.35;
		}
		.drop-item-row::before {
			content: "\2022";
			color: var(--theme-drop-text, #ffffff);
			font-size: 0.8rem;
			line-height: 1;
		}
		.drop-item-icon {
			width: var(--theme-drop-icon-size, 22px);
			height: auto;
			max-height: 34px;
			margin: 0 0.35rem;
			vertical-align: middle;
			image-rendering: pixelated;
			background: transparent !important;
			border: 0 !important;
		}
		.drop-item-name {
			color: var(--theme-drop-text, #ffffff);
			font-size: var(--theme-drop-text-size, 0.68rem);
			vertical-align: middle;
			white-space: normal;
			overflow: visible;
			text-overflow: clip;
			flex: 0 1 auto;
		}
		.drop-item-count {
			color: var(--accent-gold);
			font-weight: 800;
			margin-left: 0.15rem;
			white-space: nowrap;
			flex: 0 0 auto;
		}
		.mob-table-filters {
			display: grid;
			grid-template-columns: repeat(2, minmax(0, 1fr));
			gap: 0.5rem;
			padding: 0.55rem 0.65rem;
			background: var(--game-panel-bg);
			border-top: 1px solid var(--game-border);
			border-bottom: 1px solid var(--game-border);
		}
		.mob-table-filter {
			position: relative;
			display: block;
		}
		.mob-table-filter i {
			position: absolute;
			left: 0.65rem;
			top: 50%;
			transform: translateY(-50%);
			color: var(--text-low);
			font-size: 0.72rem;
			pointer-events: none;
		}
		.mob-table-filter input {
			width: 100%;
			height: 32px;
			background: var(--bg-input);
			border: 1px solid var(--game-border);
			color: var(--text-high);
			font-family: var(--font-body);
			font-size: 0.72rem;
			padding: 0 0.65rem 0 1.9rem;
			outline: none;
		}
		.mob-table-filter input:focus {
			border-color: var(--border-active);
		}
		.mob-table-filter input::placeholder {
			color: var(--text-muted);
		}
		@media (max-width: 640px) {
			.mob-table-filters { grid-template-columns: 1fr; }
		}
		.page-hero,
		.hero-search {
			display: none;
		}
		.sidebar {
			background: #111416;
		}
		.sidebar-header {
			background: linear-gradient(#171b1e, #101315);
		}
		.sidebar-section-title {
			background: linear-gradient(#171b1e, #101315);
		}
		.logo-icon,
		.w-icon,
		.cat-label {
			background: var(--theme-ui-badge-bg, #171b1e) !important;
			color: var(--theme-ui-badge-text, #f1f5f8) !important;
			border: 1px solid var(--game-border);
		}
		.w-cat-btn {
			background: transparent !important;
			color: var(--theme-sidebar-text, #ffffff) !important;
		}
		.w-cat-btn:hover,
		.w-cat-btn.active {
			background: var(--theme-sidebar-active-bg, #232a2f) !important;
			color: var(--theme-sidebar-active-text, #f1f5f8) !important;
			border-left-color: var(--game-border) !important;
		}
		.sidebar-footer {
			background: var(--theme-sidebar-bg, #111416) !important;
			color: var(--theme-sidebar-text, #ffffff) !important;
		}
		.wiki-card#costume-set-bonuses .costume-table-wrap {
			overflow: hidden !important;
		}
		.wiki-card#costume-set-bonuses .costume-set-table {
			min-width: 0 !important;
			width: 100% !important;
		}
		.wiki-card#costume-set-bonuses {
			overflow: hidden !important;
		}
		@media (max-width: 768px) {
			.main-content {
				width: 100%;
				min-width: 0;
			}
			.content-area {
				width: min(var(--theme-content-width), calc(100vw - 18px));
				max-width: calc(100vw - 18px);
				padding-top: 9px;
			}
			.wiki-card,
			.wiki-card#costume-set-bonuses {
				width: 100%;
			}
		}

		/* ========== THEME EDITOR ========== */
		.theme-editor-toggle {
			position: fixed;
			right: 18px;
			bottom: 18px;
			z-index: 400;
			width: 44px;
			height: 44px;
			border: 1px solid var(--game-border);
			background: var(--game-header-bg);
			color: var(--game-header-text);
			cursor: pointer;
			box-shadow: 0 3px 10px rgba(0,0,0,0.45);
		}
		.theme-editor {
			position: fixed;
			top: 0;
			right: 0;
			bottom: 0;
			z-index: 500;
			width: min(380px, 100vw);
			background: #111416;
			color: #2b1a10;
			border-left: 2px solid #6f5b25;
			transform: translateX(100%);
			transition: transform 0.22s ease;
			display: flex;
			flex-direction: column;
			box-shadow: -8px 0 24px rgba(0,0,0,0.35);
		}
		.theme-editor.open { transform: translateX(0); }
		.theme-editor-header {
			display: flex;
			align-items: center;
			justify-content: space-between;
			padding: 0.75rem 0.9rem;
			background: linear-gradient(#171b1e, #101315);
			color: #f1f5f8;
			border-bottom: 2px solid #3f474d;
		}
		.theme-editor-header h3 {
			font-family: Georgia, "Times New Roman", serif;
			font-size: 1rem;
			font-weight: 600;
		}
		.theme-editor-header button,
		.theme-actions button {
			border: 1px solid #3f474d;
			background: #232a2f;
			color: #f1f5f8;
			cursor: pointer;
			padding: 0.35rem 0.5rem;
			font-weight: 700;
		}
		.theme-editor-body {
			overflow: auto;
			padding: 0.8rem;
		}
		.theme-section {
			border: 1px solid #3f474d;
			background: #181c1f;
			margin-bottom: 0.75rem;
		}
		.theme-section-title {
			padding: 0.4rem 0.55rem;
			background: #121517;
			color: #f1f5f8;
			font-weight: 800;
			font-size: 0.72rem;
			text-transform: uppercase;
			letter-spacing: 0.5px;
		}
		.theme-field {
			display: grid;
			grid-template-columns: 1fr auto;
			gap: 0.5rem;
			align-items: center;
			padding: 0.45rem 0.55rem;
			border-top: 1px solid rgba(111,91,37,0.25);
			font-size: 0.78rem;
		}
		.theme-field input[type="color"] {
			width: 44px;
			height: 28px;
			padding: 0;
			border: 1px solid #3f474d;
			background: transparent;
		}
		.theme-field input[type="range"] {
			width: 128px;
		}
		.theme-field select,
		.theme-field input[type="text"] {
			width: 160px;
			border: 1px solid #3f474d;
			background: #1b1f22;
			color: #2b1a10;
			padding: 0.3rem;
		}
		.theme-actions {
			display: grid;
			grid-template-columns: repeat(2, 1fr);
			gap: 0.45rem;
			padding: 0.65rem;
			border-top: 1px solid #3f474d;
			background: #d2b889;
		}
		.theme-actions button.wide { grid-column: 1 / -1; }
		.theme-json {
			width: 100%;
			min-height: 92px;
			resize: vertical;
			border: 1px solid #3f474d;
			background: #1b1f22;
			color: #2b1a10;
			padding: 0.45rem;
			font-family: Consolas, monospace;
			font-size: 0.68rem;
		}
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
					<button class="cat-filter-btn" data-filter="costume"><i class="fas fa-shirt"></i> Kostum</button>
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

	<button class="theme-editor-toggle" id="theme-editor-toggle" title="Tema paneli"><i class="fas fa-palette"></i></button>
	<aside class="theme-editor" id="theme-editor" aria-label="Tema paneli">
		<div class="theme-editor-header">
			<h3>Tema Paneli</h3>
			<button id="theme-editor-close" type="button"><i class="fas fa-xmark"></i></button>
		</div>
		<div class="theme-editor-body" id="theme-editor-body"></div>
		<div class="theme-actions">
			<button id="theme-save" type="button">Kaydet</button>
			<button id="theme-reset" type="button">Sifirla</button>
			<button id="theme-export" type="button">Disa aktar</button>
			<button id="theme-import" type="button">Ice aktar</button>
			<textarea class="theme-json" id="theme-json" placeholder="Tema JSON"></textarea>
		</div>
	</aside>

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
				clearMobTableFilters();
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

		function clearMobTableFilters() {
			document.querySelectorAll('.mob-table-search').forEach(input => { input.value = ''; });
			document.querySelectorAll('.metin-drop-table tbody tr').forEach(row => { row.style.display = ''; });
		}

		function applyMobTableFilters(card) {
			const mobInput = card.querySelector('.mob-table-search[data-filter-kind="mob"]');
			const itemInput = card.querySelector('.mob-table-search[data-filter-kind="item"]');
			if (!mobInput || !itemInput) return;
			const mobQuery = mobInput.value.toLowerCase().trim();
			const itemQuery = itemInput.value.toLowerCase().trim();
			let anyVisible = false;
			card.querySelectorAll('.metin-drop-table tbody tr').forEach(row => {
				const mobText = (row.querySelector('.metin-name-cell')?.textContent || '').toLowerCase();
				const itemText = Array.from(row.querySelectorAll('.drop-item-name')).map(el => el.textContent.toLowerCase()).join(' ');
				const mobMatch = !mobQuery || mobText.includes(mobQuery);
				const itemMatch = !itemQuery || itemText.includes(itemQuery);
				const visible = mobMatch && itemMatch;
				row.style.display = visible ? '' : 'none';
				if (visible) anyVisible = true;
			});
			emptyState.style.display = anyVisible ? 'none' : 'block';
		}

		document.querySelectorAll('.mob-table-search').forEach(input => {
			input.addEventListener('input', () => {
				const card = input.closest('.wiki-card');
				if (card) applyMobTableFilters(card);
			});
		});

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

	(function() {
		const STORAGE_KEY = 'harbi2-theme-editor-v3-dark';
		const root = document.documentElement;
		const editor = document.getElementById('theme-editor');
		const editorBody = document.getElementById('theme-editor-body');
		const jsonBox = document.getElementById('theme-json');
		const fields = [
			{ group: 'Genel Renkler', label: 'Sayfa Arka Plan', type: 'color', target: '--game-page-bg', value: '#000000' },
			{ group: 'Genel Renkler', label: 'Panel Zemini', type: 'color', target: '--game-panel-bg', value: '#181c1f' },
			{ group: 'Genel Renkler', label: 'Tablo Basligi', type: 'color', target: '--game-header-bg', value: '#121517' },
			{ group: 'Genel Renkler', label: 'Cizgi Rengi', type: 'color', target: '--game-border', value: '#3f474d' },
			{ group: 'Genel Renkler', label: 'Kart Zemini', type: 'color', target: '--bg-card', value: '#181c1f' },
			{ group: 'Genel Renkler', label: 'Input Zemini', type: 'color', target: '--bg-input', value: '#1b1b1b' },
			{ group: 'Genel Renkler', label: 'Kucuk Kutular', type: 'color', target: '--theme-ui-badge-bg', value: '#171b1e' },
			{ group: 'Genel Renkler', label: 'Kucuk Kutu Yazisi', type: 'color', target: '--theme-ui-badge-text', value: '#f1f5f8' },
			{ group: 'Vurgu Renkleri', label: 'Mavi Vurgu', type: 'color', target: '--accent-blue', value: '#8ba4b8' },
			{ group: 'Vurgu Renkleri', label: 'Altin Vurgu', type: 'color', target: '--accent-gold', value: '#9aa6ad' },
			{ group: 'Vurgu Renkleri', label: 'Marka Yazisi', type: 'color', target: '--brand-gold', value: '#e7edf2' },
			{ group: 'Yazilar', label: 'Baslik Yazisi', type: 'color', target: '--game-header-text', value: '#f1f5f8' },
			{ group: 'Yazilar', label: 'Govde Yazisi', type: 'color', target: '--game-body-text', value: '#e8eef2' },
			{ group: 'Yazilar', label: 'Set Basligi', type: 'color', target: '--game-title-text', value: '#f1f5f8' },
			{ group: 'Yazilar', label: 'Ana Metin', type: 'color', target: '--text-high', value: '#e8eef2' },
			{ group: 'Yazilar', label: 'Ikincil Metin', type: 'color', target: '--text-med', value: '#b7c1c7' },
			{ group: 'Yazilar', label: 'Soluk Metin', type: 'color', target: '--text-low', value: '#9aa6ad' },
			{ group: 'Yazilar', label: 'Baslik Fontu', type: 'select', target: '--font-display', value: 'Georgia, "Times New Roman", serif', options: [
				['Varsayilan', ''],
				['Georgia', 'Georgia, "Times New Roman", serif'],
				['Cinzel', 'Cinzel, serif'],
				['Arial', 'Arial, sans-serif'],
				['Times', '"Times New Roman", serif']
			] },
			{ group: 'Yazilar', label: 'Govde Fontu', type: 'select', target: '--font-body', value: 'Arial, sans-serif', options: [
				['Varsayilan', ''],
				['Arial', 'Arial, sans-serif'],
				['Inter', 'Inter, sans-serif'],
				['Georgia', 'Georgia, "Times New Roman", serif'],
				['Verdana', 'Verdana, sans-serif']
			] },
			{ group: 'Yazilar', label: 'Set Baslik Fontu', type: 'select', target: '--theme-title-font', value: 'Georgia, "Times New Roman", serif', options: [
				['Varsayilan', ''],
				['Georgia', 'Georgia, "Times New Roman", serif'],
				['Cinzel', 'Cinzel, serif'],
				['Arial', 'Arial, sans-serif'],
				['Times', '"Times New Roman", serif']
			] },
			{ group: 'Yazilar', label: 'Tablo Fontu', type: 'select', target: '--theme-table-font', value: 'Arial, sans-serif', options: [
				['Varsayilan', ''],
				['Arial', 'Arial, sans-serif'],
				['Inter', 'Inter, sans-serif'],
				['Georgia', 'Georgia, "Times New Roman", serif'],
				['Verdana', 'Verdana, sans-serif']
			] },
			{ group: 'Set Bonus Yazisi', label: 'Bonus Yazi Rengi', type: 'color', target: '--theme-bonus-text', value: '#e8eef2' },
			{ group: 'Set Bonus Yazisi', label: 'Sol Hucre Yazisi', type: 'color', target: '--theme-bonus-tier-text', value: '#f1f5f8' },
			{ group: 'Set Bonus Yazisi', label: 'Sol Hucre Zemini', type: 'color', target: '--theme-bonus-tier-bg', value: '#121517' },
			{ group: 'Set Bonus Yazisi', label: 'Bonus Yazi Boyutu', type: 'range', target: '--theme-bonus-size', value: '0.68rem', min: 0.45, max: 1.1, step: 0.01, unit: 'rem' },
			{ group: 'Set Bonus Yazisi', label: 'Bonus Kalinligi', type: 'range', target: '--theme-bonus-weight', value: '400', min: 300, max: 900, step: 100, unit: '' },
			{ group: 'Set Bonus Yazisi', label: 'Bonus Satir Arasi', type: 'range', target: '--theme-bonus-line', value: '1.25', min: 0.9, max: 2, step: 0.05, unit: '' },
			{ group: 'Set Bonus Yazisi', label: 'Bonus Hizalama', type: 'select', target: '--theme-bonus-align', value: 'center', options: [
				['Sol', 'left'],
				['Orta', 'center'],
				['Sag', 'right']
			] },
			{ group: 'Set Bonus Yazisi', label: 'Bonus Golgesi', type: 'select', target: '--theme-bonus-shadow', value: 'none', options: [
				['Yok', 'none'],
				['Hafif', '0 1px 0 rgba(0,0,0,0.35)'],
				['Normal', '0 1px 0 #000'],
				['Parlak', '0 0 4px rgba(180,205,220,0.35)']
			] },
			{ group: 'Set Bonus Yazisi', label: 'Baslik Golgesi', type: 'select', target: '--theme-header-shadow', value: '0 1px 0 #000', options: [
				['Yok', 'none'],
				['Hafif', '0 1px 0 rgba(0,0,0,0.35)'],
				['Normal', '0 1px 0 #000'],
				['Parlak', '0 0 4px rgba(180,205,220,0.35)']
			] },
			{ group: 'Drop Tablosu', label: 'Baslik Zemini', type: 'color', target: '--theme-drop-header-bg', value: '#1b1b1b' },
			{ group: 'Drop Tablosu', label: 'Baslik Yazisi', type: 'color', target: '--theme-drop-header-text', value: '#ffffff' },
			{ group: 'Drop Tablosu', label: 'Satir Zemini', type: 'color', target: '--theme-drop-row-bg', value: '#202323' },
			{ group: 'Drop Tablosu', label: 'Alternatif Satir', type: 'color', target: '--theme-drop-row-alt-bg', value: '#191b1b' },
			{ group: 'Drop Tablosu', label: 'Satir Hover', type: 'color', target: '--theme-drop-row-hover-bg', value: '#252929' },
			{ group: 'Drop Tablosu', label: 'Mob Adi Rengi', type: 'color', target: '--theme-drop-name-text', value: '#ffffff' },
			{ group: 'Drop Tablosu', label: 'Drop Yazi Rengi', type: 'color', target: '--theme-drop-text', value: '#ffffff' },
			{ group: 'Drop Tablosu', label: 'Baslik Boyutu', type: 'range', target: '--theme-drop-header-size', value: '0.72rem', min: 0.5, max: 1.1, step: 0.01, unit: 'rem' },
			{ group: 'Drop Tablosu', label: 'Drop Yazi Boyutu', type: 'range', target: '--theme-drop-text-size', value: '0.68rem', min: 0.45, max: 1.05, step: 0.01, unit: 'rem' },
			{ group: 'Drop Tablosu', label: 'Drop Ikon Boyutu', type: 'range', target: '--theme-drop-icon-size', value: '22px', min: 12, max: 48, step: 1, unit: 'px' },
			{ group: 'Drop Tablosu', label: 'Hucre Boslugu', type: 'range', target: '--theme-drop-cell-pad', value: '0.45rem', min: 0.15, max: 1.2, step: 0.01, unit: 'rem' },
			{ group: 'Olculer', label: 'Set Baslik Boyutu', type: 'range', target: '--theme-title-size', value: '1.28rem', min: 0.8, max: 2.2, step: 0.05, unit: 'rem' },
			{ group: 'Olculer', label: 'Tablo Yazi Boyutu', type: 'range', target: '--theme-table-size', value: '0.68rem', min: 0.45, max: 1.1, step: 0.01, unit: 'rem' },
			{ group: 'Olculer', label: 'Ikon Genisligi', type: 'range', target: '--theme-icon-size', value: '32px', min: 18, max: 64, step: 1, unit: 'px' },
			{ group: 'Olculer', label: 'Hucre Boslugu', type: 'range', target: '--theme-cell-pad', value: '0.42rem', min: 0.1, max: 1.2, step: 0.02, unit: 'rem' },
			{ group: 'Olculer', label: 'Icerik Genisligi', type: 'range', target: '--theme-content-width', value: '716px', min: 560, max: 1100, step: 2, unit: 'px' },
			{ group: 'Olculer', label: 'Tablo Genisligi', type: 'range', target: '--theme-table-width', value: '670px', min: 520, max: 1040, step: 2, unit: 'px' },
			{ group: 'Olculer', label: 'Sol Bonus Sutunu', type: 'range', target: '--theme-bonus-col-width', value: '126px', min: 80, max: 190, step: 2, unit: 'px' },
			{ group: 'Olculer', label: 'Icerik Boslugu', type: 'range', target: '--theme-layout-gap', value: '20px', min: 0, max: 80, step: 2, unit: 'px' },
			{ group: 'Olculer', label: 'Kart Radius', type: 'range', target: '--radius-md', value: '0px', min: 0, max: 18, step: 1, unit: 'px' },
			{ group: 'Olculer', label: 'Kucuk Radius', type: 'range', target: '--radius-sm', value: '0px', min: 0, max: 12, step: 1, unit: 'px' },
			{ group: 'Ikonlar', label: 'Ikon Kenarligi', type: 'color', target: '--theme-icon-border', value: '#3f474d' },
			{ group: 'Sol Menu', label: 'Menu Zemini', type: 'color', target: '--theme-sidebar-bg', value: '#111416' },
			{ group: 'Sol Menu', label: 'Menu Basligi', type: 'color', target: '--theme-sidebar-head', value: '#171b1e' },
			{ group: 'Sol Menu', label: 'Bolum Basligi', type: 'color', target: '--theme-sidebar-section', value: '#171b1e' },
			{ group: 'Sol Menu', label: 'Menu Yazisi', type: 'color', target: '--theme-sidebar-text', value: '#ffffff' },
			{ group: 'Sol Menu', label: 'Secili Menu Zemini', type: 'color', target: '--theme-sidebar-active-bg', value: '#232a2f' },
			{ group: 'Sol Menu', label: 'Secili Menu Yazisi', type: 'color', target: '--theme-sidebar-active-text', value: '#f1f5f8' },
			{ group: 'Sol Menu', label: 'Menu Genisligi', type: 'range', target: '--sidebar-w', value: '216px', min: 180, max: 380, step: 2, unit: 'px' }
		];

		const dynamicStyle = document.createElement('style');
		dynamicStyle.textContent = [
			'.costume-set-block h3 { font-family: var(--theme-title-font, Georgia, "Times New Roman", serif); font-size: var(--theme-title-size, 1.28rem); color: var(--game-title-text); }',
			'.bonus-tier, .costume-piece-title, .metin-drop-table td { font-family: var(--theme-table-font, Arial, sans-serif); font-size: var(--theme-table-size, 0.68rem); }',
			'.bonus-text { color: var(--theme-bonus-text, var(--game-body-text)) !important; font-family: var(--theme-table-font, Arial, sans-serif); font-size: var(--theme-bonus-size, 0.68rem); font-weight: var(--theme-bonus-weight, 400); line-height: var(--theme-bonus-line, 1.25); text-align: var(--theme-bonus-align, center); text-shadow: var(--theme-bonus-shadow, none); }',
			'.bonus-tier { color: var(--theme-bonus-tier-text, var(--game-header-text)) !important; background: var(--theme-bonus-tier-bg, var(--game-header-bg)) !important; }',
			'.bonus-tier, .costume-piece-title, .metin-drop-table th { text-shadow: var(--theme-header-shadow, 0 1px 0 #000); }',
			'.metin-drop-table th { background: var(--theme-drop-header-bg, #1b1b1b) !important; color: var(--theme-drop-header-text, #fff) !important; font-size: var(--theme-drop-header-size, 0.72rem); text-align: left; text-shadow: none; }',
			'.metin-drop-table td { background: var(--theme-drop-row-bg, #202323) !important; color: var(--theme-drop-text, #fff) !important; font-size: var(--theme-drop-text-size, 0.68rem); padding: var(--theme-drop-cell-pad, 0.45rem); text-align: left; vertical-align: top; text-shadow: none; }',
			'.metin-drop-table tbody tr:nth-child(even) td { background: var(--theme-drop-row-alt-bg, #191b1b) !important; }',
			'.metin-drop-table tbody tr:hover td { background: var(--theme-drop-row-hover-bg, #252929) !important; }',
			'.metin-name-cell { color: var(--theme-drop-name-text, #fff) !important; white-space: normal; }',
			'.drop-item-row { display: flex; align-items: center; gap: 0.35rem; margin-left: 1.05rem; padding: 0.1rem 0; }',
			'.drop-item-row::before { content: "\\2022"; color: var(--theme-drop-text, #fff); font-size: 0.8rem; line-height: 1; }',
			'.drop-item-icon { width: var(--theme-drop-icon-size, 22px); height: auto; max-height: 34px; margin: 0 0.35rem; vertical-align: middle; background: transparent !important; border: 0 !important; }',
			'.drop-item-name { color: var(--theme-drop-text, #fff) !important; font-size: var(--theme-drop-text-size, 0.68rem); white-space: normal; overflow: visible; text-overflow: clip; vertical-align: middle; flex: 0 1 auto; }',
			'.drop-item-count { margin-left: 0.15rem; white-space: nowrap; flex: 0 0 auto; }',
			'.mob-table-filters { background: var(--game-panel-bg); border-color: var(--game-border); }',
			'.mob-table-filter input { background: var(--bg-input); border-color: var(--game-border); color: var(--text-high); }',
			'.costume-item img { width: var(--theme-icon-size, 32px); border-color: var(--theme-icon-border, #3f474d); }',
			'.costume-icons { padding: var(--theme-cell-pad, 0.42rem) 0.35rem; }',
			'.main-content { margin-left: var(--sidebar-w, 216px); width: calc(100vw - var(--sidebar-w, 216px)); min-width: calc(var(--theme-content-width, 716px) + (var(--theme-layout-gap, 20px) * 2)); }',
			'.content-area { width: var(--theme-content-width, 716px); max-width: var(--theme-content-width, 716px); margin-left: auto; margin-right: auto; }',
			'.wiki-card, .wiki-card#costume-set-bonuses { width: var(--theme-content-width, 716px); }',
			'.metin-drop-table, .costume-set-table { min-width: var(--theme-table-width, 670px); }',
			'.wiki-card#costume-set-bonuses .costume-table-wrap { overflow: hidden !important; }',
			'.wiki-card#costume-set-bonuses .costume-set-table { min-width: 0 !important; width: 100% !important; }',
			'.wiki-card#costume-set-bonuses { overflow: hidden !important; }',
			'.costume-set-table .bonus-corner, .bonus-tier, .metin-drop-table th:nth-child(1) { width: var(--theme-bonus-col-width, 126px); }',
			'.sidebar { background: var(--theme-sidebar-bg, #111416); }',
			'.sidebar-header { background: linear-gradient(var(--theme-sidebar-head, #171b1e), #101315); }',
			'.sidebar-section-title { background: linear-gradient(var(--theme-sidebar-section, #171b1e), #101315); }',
			'.logo-icon, .w-icon, .cat-label { background: var(--theme-ui-badge-bg, #171b1e) !important; color: var(--theme-ui-badge-text, #f1f5f8) !important; border-color: var(--game-border, #3f474d) !important; }',
			'.w-cat-btn, .tree-header, .sidebar-footer { color: var(--theme-sidebar-text, #ffffff) !important; }',
			'.w-cat-btn { background: transparent !important; }',
			'.w-cat-btn:hover, .w-cat-btn.active { background: var(--theme-sidebar-active-bg, #232a2f) !important; color: var(--theme-sidebar-active-text, #f1f5f8) !important; border-left-color: var(--game-border, #3f474d) !important; }',
			'.sidebar-footer { background: var(--theme-sidebar-bg, #111416) !important; }',
			'.wiki-card { border-radius: var(--radius-md, 0px); }',
			'.theme-editor-toggle, .search-box input, .search-mode-btn, .cat-filter-btn { border-radius: var(--radius-sm, 0px); }'
		].join('\n');
		document.head.appendChild(dynamicStyle);

		function buildPanel() {
			const groups = {};
			fields.forEach(f => { (groups[f.group] ||= []).push(f); });
			editorBody.innerHTML = Object.entries(groups).map(([name, list]) =>
				'<section class="theme-section">' +
					'<div class="theme-section-title">' + name + '</div>' +
					list.map(renderField).join('') +
				'</section>'
			).join('');
			editorBody.querySelectorAll('[data-theme-target]').forEach(input => {
				input.addEventListener('input', () => applyField(input));
				input.addEventListener('change', () => applyField(input));
			});
		}

		function renderField(field) {
			if (field.type === 'select') {
				return '<label class="theme-field"><span>' + field.label + '</span><select data-theme-target="' + field.target + '">' +
					field.options.map(([label, value]) => '<option value="' + value + '">' + label + '</option>').join('') +
					'</select></label>';
			}
			if (field.type === 'range') {
				const numeric = parseFloat(field.value);
				return '<label class="theme-field"><span>' + field.label + '</span><input type="range" min="' + field.min + '" max="' + field.max + '" step="' + field.step + '" value="' + numeric + '" data-unit="' + field.unit + '" data-theme-target="' + field.target + '"></label>';
			}
			return '<label class="theme-field"><span>' + field.label + '</span><input type="' + field.type + '" value="' + field.value + '" data-theme-target="' + field.target + '"></label>';
		}

		function applyField(input) {
			const unit = input.dataset.unit || '';
			const value = input.type === 'range' ? input.value + unit : input.value;
			if (value === '') root.style.removeProperty(input.dataset.themeTarget);
			else root.style.setProperty(input.dataset.themeTarget, value);
		}

		function collectTheme() {
			const data = {};
			editorBody.querySelectorAll('[data-theme-target]').forEach(input => {
				const unit = input.dataset.unit || '';
				data[input.dataset.themeTarget] = input.type === 'range' ? input.value + unit : input.value;
			});
			return data;
		}

		function loadTheme(data) {
			Object.entries(data || {}).forEach(([key, value]) => {
				root.style.setProperty(key, value);
				const input = editorBody.querySelector('[data-theme-target="' + key + '"]');
				if (!input) return;
				input.value = input.type === 'range' ? parseFloat(value) : value;
			});
		}

		function defaultTheme() {
			return Object.fromEntries(fields.map(f => [f.target, f.value]));
		}

		buildPanel();
		loadTheme(defaultTheme());
		try { loadTheme(JSON.parse(localStorage.getItem(STORAGE_KEY) || '{}')); } catch {}

		document.getElementById('theme-editor-toggle').addEventListener('click', () => editor.classList.add('open'));
		document.getElementById('theme-editor-close').addEventListener('click', () => editor.classList.remove('open'));
		document.getElementById('theme-save').addEventListener('click', () => {
			localStorage.setItem(STORAGE_KEY, JSON.stringify(collectTheme()));
		});
		document.getElementById('theme-reset').addEventListener('click', () => {
			localStorage.removeItem(STORAGE_KEY);
			loadTheme(defaultTheme());
			jsonBox.value = '';
		});
		document.getElementById('theme-export').addEventListener('click', () => {
			jsonBox.value = JSON.stringify(collectTheme(), null, 2);
			jsonBox.select();
		});
		document.getElementById('theme-import').addEventListener('click', () => {
			try {
				const data = JSON.parse(jsonBox.value);
				loadTheme(data);
				localStorage.setItem(STORAGE_KEY, JSON.stringify(collectTheme()));
			} catch {
				alert('Tema JSON okunamadi.');
			}
		});
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
