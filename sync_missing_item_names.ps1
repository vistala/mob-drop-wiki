# =============================================================================
# Sync missing wiki item names from local Harbi2_Files data.
#
# It scans generated index.html for labels like "Item 600057", looks those VNUMs
# up in known local item_names.txt files, and appends missing names to the wiki's
# item_names.txt. Then run generate_wiki.ps1 to rebuild the site.
# =============================================================================

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$wikiItemNamesPath = Join-Path $scriptDir "item_names.txt"
$indexPath = Join-Path $scriptDir "index.html"

$candidateNameFiles = @(
    (Join-Path $scriptDir "item_names.txt"),
    "C:\Users\orkun\OneDrive\Documents\Github\Harbi2_Files\srv1\share\conf\item_names.txt",
    "C:\Users\orkun\OneDrive\Documents\Github\Harbi2_Files\srv1\share\locale\germany\item_names.txt",
    "C:\Users\orkun\OneDrive\Documents\Github\Harbi2_Files\srv1\share\locale\turkey\item_names.txt"
)

function Read-ItemNameMap {
    param([string[]]$Paths)

    $map = @{}
    foreach ($path in $Paths) {
        if (-not (Test-Path $path)) { continue }
        foreach ($line in [System.IO.File]::ReadAllLines($path, [System.Text.Encoding]::UTF8)) {
            $trimmed = $line.Trim()
            if ($trimmed -match "^(\d+)\s+(.+)$") {
                $vnum = $Matches[1]
                $name = $Matches[2].Trim()
                if (-not $map.ContainsKey($vnum) -and $name -and $name -notmatch "^Item\s+\d+$") {
                    $map[$vnum] = $name
                }
            }
        }
    }
    return $map
}

if (-not (Test-Path $indexPath)) {
    Write-Host "index.html bulunamadi. Once generate_wiki.ps1 calistir." -ForegroundColor Yellow
    exit 1
}

$knownNames = Read-ItemNameMap -Paths @($wikiItemNamesPath)
$allNames = Read-ItemNameMap -Paths $candidateNameFiles
$html = [System.IO.File]::ReadAllText($indexPath, [System.Text.Encoding]::UTF8)
$missingVnums = [regex]::Matches($html, "Item\s+(\d+)") |
    ForEach-Object { $_.Groups[1].Value } |
    Sort-Object -Unique

$additions = @()
$unresolved = @()
foreach ($vnum in $missingVnums) {
    if ($knownNames.ContainsKey($vnum)) { continue }
    if ($allNames.ContainsKey($vnum)) {
        $additions += "$vnum`t$($allNames[$vnum])"
    }
    else {
        $unresolved += $vnum
    }
}

if ($additions.Count -gt 0) {
    [System.IO.File]::AppendAllText($wikiItemNamesPath, "`r`n" + ($additions -join "`r`n") + "`r`n", [System.Text.Encoding]::UTF8)
}

$reportPath = Join-Path $scriptDir "missing_item_names_report.txt"
$report = @()
$report += "Eklenen isim sayisi: $($additions.Count)"
$report += "Cozulemeyen VNUM sayisi: $($unresolved.Count)"
if ($additions.Count -gt 0) {
    $report += ""
    $report += "Eklenenler:"
    $report += $additions
}
if ($unresolved.Count -gt 0) {
    $report += ""
    $report += "Cozulemeyenler:"
    $report += $unresolved
}
[System.IO.File]::WriteAllLines($reportPath, $report, [System.Text.Encoding]::UTF8)

Write-Host "Eksik item isim senkronu tamamlandi." -ForegroundColor Green
Write-Host "Eklenen: $($additions.Count) | Cozulemeyen: $($unresolved.Count)"
Write-Host "Rapor: $reportPath"
