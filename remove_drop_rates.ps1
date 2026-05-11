param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Paths
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$outDir = Join-Path $scriptDir "sanitized_drop_files"
$reportPath = Join-Path $outDir "remove_drop_rates_report.txt"

function Get-DefaultInputFiles {
    $defaults = @(
        (Join-Path $scriptDir "mob_drop_item.txt"),
        (Join-Path $scriptDir "special_item_group.txt")
    )
    return @($defaults | Where-Object { Test-Path -LiteralPath $_ })
}

function Get-InputFiles {
    param([string[]]$RawPaths)

    if (-not $RawPaths -or $RawPaths.Count -eq 0) {
        return Get-DefaultInputFiles
    }

    $files = @()
    foreach ($rawPath in $RawPaths) {
        if (-not (Test-Path -LiteralPath $rawPath)) {
            Write-Host "Atlandi, bulunamadi: $rawPath" -ForegroundColor Yellow
            continue
        }

        $item = Get-Item -LiteralPath $rawPath
        if ($item.PSIsContainer) {
            $files += Get-ChildItem -LiteralPath $item.FullName -File -Filter "*.txt"
        }
        else {
            $files += $item
        }
    }

    return @($files | Sort-Object FullName -Unique)
}

function Remove-DropRateFromComment {
    param([string]$Comment)
    return ($Comment -replace "\s*\[%\s*\d+(?:[\.,]\d+)?\s*\]", "")
}

function Convert-DropLine {
    param([string]$Line)

    $comment = ""
    $body = $Line
    $commentIndex = $Line.IndexOf("--")
    if ($commentIndex -ge 0) {
        $body = $Line.Substring(0, $commentIndex)
        $comment = $Line.Substring($commentIndex)
        $comment = Remove-DropRateFromComment -Comment $comment
    }

    # mob_drop_item.txt style: index item_vnum count chance -- name
    if ($body -match "^(\s*#?\s*\d+\s+\d+\s+\d+)\s+\d+(?:[\.,]\d+)?\s*$") {
        return ($Matches[1] + $(if ($comment) { "`t" + $comment.TrimEnd() } else { "" })).TrimEnd()
    }

    # special_item_group.txt often keeps the visible rate only in the comment.
    if ($commentIndex -ge 0) {
        return ($body.TrimEnd() + $(if ($comment) { "`t" + $comment.TrimEnd() } else { "" })).TrimEnd()
    }

    return $Line
}

function Convert-File {
    param([System.IO.FileInfo]$File)

    $lines = [System.IO.File]::ReadAllLines($File.FullName, [System.Text.Encoding]::UTF8)
    $changed = 0
    $outLines = foreach ($line in $lines) {
        $newLine = Convert-DropLine -Line $line
        if ($newLine -ne $line) { $changed++ }
        $newLine
    }

    $targetPath = Join-Path $outDir $File.Name
    [System.IO.File]::WriteAllLines($targetPath, $outLines, [System.Text.UTF8Encoding]::new($false))

    return [pscustomobject]@{
        File = $File.FullName
        Output = $targetPath
        ChangedLines = $changed
    }
}

New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$inputFiles = Get-InputFiles -RawPaths $Paths

if (-not $inputFiles -or $inputFiles.Count -eq 0) {
    Write-Host "Temizlenecek dosya bulunamadi." -ForegroundColor Yellow
    exit 1
}

$results = foreach ($file in $inputFiles) {
    Convert-File -File $file
}

$report = @()
$report += "Drop rate temizleme raporu"
$report += "Tarih: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$report += "Dosya sayisi: $($results.Count)"
$report += ""
foreach ($result in $results) {
    $report += "Kaynak: $($result.File)"
    $report += "Cikti : $($result.Output)"
    $report += "Degisen satir: $($result.ChangedLines)"
    $report += ""
}
[System.IO.File]::WriteAllLines($reportPath, $report, [System.Text.UTF8Encoding]::new($false))

Write-Host "Drop rate temizleme tamamlandi." -ForegroundColor Green
Write-Host "Cikti klasoru: $outDir"
Write-Host "Rapor: $reportPath"
