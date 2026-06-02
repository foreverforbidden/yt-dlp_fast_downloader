#Requires -Version 5.1
# yt-dlp v3.5 — Fast Pinned-Start-Menu Edition

# ==================== PATHS ====================
$ScriptDir   = $PSScriptRoot
$ConfigPath  = Join-Path $ScriptDir "config.json"
$OptionsDir  = Join-Path $ScriptDir "options"
$DefaultTxt  = Join-Path $OptionsDir "default.txt"

# ==================== DEFAULT CONFIG ====================
$DefaultConfig = @{
    AppleMusic = @{
        Enabled = $false
        Path    = "$env:USERPROFILE\Music\Apple Music\Media\Automatically Add to Apple Music"
    }
    OutputPath          = "$env:USERPROFILE\Videos"
    SponsorBlock        = $true
    UseArchive          = $true
    ArchivePath         = Join-Path $ScriptDir "download_archive.txt"
    ConcurrentFragments = 4
    DefaultFlags        = "-f bestaudio --extract-audio --audio-format m4a --audio-quality 0 --embed-thumbnail --add-metadata --no-playlist"
}

# ==================== INIT ====================
if (-not (Test-Path $OptionsDir)) { New-Item -ItemType Directory -Path $OptionsDir -Force | Out-Null }

# Seed default.txt if missing
if (-not (Test-Path $DefaultTxt)) {
    $DefaultConfig.DefaultFlags | Set-Content -Path $DefaultTxt -Encoding UTF8
}

# Load / merge config
if (Test-Path $ConfigPath) {
    try {
        $raw = Get-Content -Raw $ConfigPath
        $Config = $raw | ConvertFrom-Json
        # Merge any new keys from $DefaultConfig (for future updates)
        foreach ($key in $DefaultConfig.Keys) {
            if (-not $Config.PSObject.Properties[$key]) {
                $Config | Add-Member -NotePropertyName $key -NotePropertyValue $DefaultConfig[$key]
            }
        }
    } catch {
        $Config = $DefaultConfig | ConvertTo-Json -Depth 10 | ConvertFrom-Json
    }
} else {
    # Seed from existing default.txt if present
    $seed = (Get-Content -Raw $DefaultTxt -ErrorAction SilentlyContinue).Trim()
    if ($seed) { $DefaultConfig.DefaultFlags = $seed }
    $Config = $DefaultConfig | ConvertTo-Json -Depth 10 | ConvertFrom-Json
    Save-Config
}

function Save-Config {
    $Config | ConvertTo-Json -Depth 10 | Set-Content -Path $ConfigPath -Encoding UTF8
    # Keep default.txt in sync so you can still edit it manually if you want
    if ($Config.DefaultFlags) {
        $Config.DefaultFlags | Set-Content -Path $DefaultTxt -Encoding UTF8
    }
}

# ==================== UI HELPERS ====================
function Get-ModeLabel {
    $f = $Config.DefaultFlags
    if     ($f -match '--extract-audio')         { return "Audio" }
    elseif ($f -match 'bestvideo.*\+.*bestaudio') { return "Video" }
    elseif ($f -match 'bestvideo|bv\+ba')         { return "Video" }
    else                                         { return "Custom" }
}

function Show-Header {
    Clear-Host
    $mode = Get-ModeLabel
    $am   = if ($Config.AppleMusic.Enabled) { "ON" } else { "OFF" }
    $amC  = if ($Config.AppleMusic.Enabled) { "Green" } else { "Red" }

    Write-Host "yt-dlp v2  |  " -NoNewline -ForegroundColor Cyan
    Write-Host "$mode Mode" -NoNewline -ForegroundColor Yellow
    Write-Host "  |  Apple Music: " -NoNewline
    Write-Host $am -NoNewline -ForegroundColor $amC
    Write-Host "  |  type 'settings' to configure" -ForegroundColor DarkGray
    Write-Host ("-" * 65) -ForegroundColor DarkGray
}

# ==================== FAST URL COLLECTOR ====================
function Get-Urls {
    $urls = [System.Collections.Generic.List[string]]::new()

    Write-Host "Paste URLs (blank line to start downloading):" -ForegroundColor Yellow
    Write-Host ""

    while ($true) {
        $line = Read-Host
        $trimmed = $line.Trim()

        # Blank line = finish (if we have URLs)
        if ($trimmed -eq "") {
            if ($urls.Count -gt 0) { break }
            Write-Host "  No URLs yet. Paste a link or type 'settings'." -ForegroundColor DarkGray
            continue
        }

        # Commands
        if ($trimmed -eq "settings") {
            Show-Settings
            Show-Header
            Write-Host "Paste URLs (blank line to start downloading):" -ForegroundColor Yellow
            Write-Host ""
            continue
        }
        if ($trimmed -in @("exit","quit","q")) {
            Write-Host "Exiting." -ForegroundColor DarkGray
            exit
        }

        # Regex extraction: catches https://... and www.... even inside a sentence
        $pattern = '(https?://[^\s"''<>]+|www\.[^\s"''<>]+)'
        $matches = [regex]::Matches($trimmed, $pattern)

        if ($matches.Count -eq 0) {
            Write-Host "  No URL found. Try again." -ForegroundColor Red
            continue
        }

        foreach ($m in $matches) {
            $url = $m.Value
            if ($url -notmatch '^https?://') { $url = "https://$url" }

            if (-not $urls.Contains($url)) {
                $urls.Add($url)
            }
        }
        Write-Host "  Collected: $($urls.Count) URL(s)" -ForegroundColor Green
    }
    return $urls
}

# ==================== DOWNLOAD ENGINE ====================
function Build-Flags {
    $parts = [System.Collections.Generic.List[string]]::new()

    # Base flags from config (synced with default.txt)
    $base = $Config.DefaultFlags
    if ([string]::IsNullOrWhiteSpace($base)) {
        $base = "-f bestaudio --extract-audio --audio-format m4a --audio-quality 0 --embed-thumbnail --add-metadata --no-playlist"
    }
    $parts.Add($base)

    # Smart global options
    if ($Config.SponsorBlock)        { $parts.Add("--sponsorblock-remove all") }
    if ($Config.UseArchive -and $Config.ArchivePath) {
        $parts.Add("--download-archive `"$($Config.ArchivePath)`"")
    }
    if ($Config.ConcurrentFragments -gt 1) {
        $parts.Add("--concurrent-fragments $($Config.ConcurrentFragments)")
    }

    # Output directory
    $out = $Config.OutputPath
    if (-not (Test-Path $out)) { New-Item -ItemType Directory -Path $out -Force | Out-Null }
    $parts.Add("-o `"$out\%(title)s.%(ext)s`"")

    # Resume & stability
    $parts.Add("--continue")
    $parts.Add("--retries 10")

    return ($parts -join " ")
}

function Start-Downloads {
    param([array]$Urls)

    $flags     = Build-Flags
    $startTime = Get-Date
    $outDir    = $Config.OutputPath

    foreach ($url in $Urls) {
        Write-Host ""
        Write-Host "Downloading: $url" -ForegroundColor Cyan

        $cmd = "yt-dlp $flags `"$url`""
        Write-Host "  $cmd" -ForegroundColor DarkGray
        Write-Host ""

        try {
            Invoke-Expression $cmd
            if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
                Write-Host "  yt-dlp exited with code $LASTEXITCODE" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "  ERROR: $_" -ForegroundColor Red
        }
    }

    # Post-download: Apple Music
    if ($Config.AppleMusic.Enabled) {
        Move-NewFilesToAppleMusic -StartTime $startTime -OutputDir $outDir
    }

    Write-Host ""
    Write-Host "All downloads completed." -ForegroundColor Green
    Write-Host "Window stays open because of -noexit. Type 'exit' to close." -ForegroundColor DarkGray
}

function Move-NewFilesToAppleMusic {
    param([datetime]$StartTime, [string]$OutputDir)

    $dest = $Config.AppleMusic.Path
    if (-not (Test-Path $dest)) {
        Write-Host ""
        Write-Host "Apple Music folder not found:" -ForegroundColor Red
        Write-Host "  $dest" -ForegroundColor Red
        return
    }

    $newFiles = Get-ChildItem -Path $OutputDir -Recurse -File |
                Where-Object { $_.LastWriteTime -ge $StartTime }

    if (-not $newFiles) { return }

    Write-Host ""
    Write-Host "Moving new files to Apple Music..." -ForegroundColor Cyan
    foreach ($file in $newFiles) {
        try {
            $target = Join-Path $dest $file.Name
            if (Test-Path $target) {
                $base = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
                $ext  = [System.IO.Path]::GetExtension($file.Name)
                $target = Join-Path $dest "$base-$(Get-Random)$ext"
            }
            Move-Item -Path $file.FullName -Destination $target -Force
            Write-Host "  → $($file.Name)" -ForegroundColor Green
        } catch {
            Write-Host "  ✗ $($file.Name): $_" -ForegroundColor Red
        }
    }
}

# ==================== SETTINGS MENU ====================
function Show-Settings {
    while ($true) {
        Clear-Host
        $am  = if ($Config.AppleMusic.Enabled) { "ON" } else { "OFF" }
        $amC = if ($Config.AppleMusic.Enabled) { "Green" } else { "Red" }
        $sb  = if ($Config.SponsorBlock) { "ON" } else { "OFF" }
        $sbC = if ($Config.SponsorBlock) { "Green" } else { "Red" }
        $pl  = if ($Config.DefaultFlags -match '--no-playlist') { "OFF" } else { "ON" }
        $plC = if ($Config.DefaultFlags -match '--no-playlist') { "Red" } else { "Green" }

        Write-Host "SETTINGS" -ForegroundColor Cyan
        Write-Host ("-" * 40) -ForegroundColor DarkGray
        Write-Host "[1] Toggle Apple Music Auto-Add  [$am]" -ForegroundColor $amC
        Write-Host "[2] Toggle SponsorBlock            [$sb]" -ForegroundColor $sbC
        Write-Host "[3] Toggle Playlist Download       [$pl]" -ForegroundColor $plC
        Write-Host "[4] Output Folder: $($Config.OutputPath)" -ForegroundColor White
        Write-Host "[5] Concurrent Fragments: $($Config.ConcurrentFragments)" -ForegroundColor White
        Write-Host "[6] Edit Download Flags" -ForegroundColor White
        Write-Host "[0] Back to download" -ForegroundColor White
        Write-Host ""

        $c = Read-Host "Select option"
        switch ($c.Trim()) {
            "1" {
                $Config.AppleMusic.Enabled = -not $Config.AppleMusic.Enabled
                Save-Config
            }
            "2" {
                $Config.SponsorBlock = -not $Config.SponsorBlock
                Save-Config
            }
            "3" {
                # Toggle --no-playlist inside the flags string
                if ($Config.DefaultFlags -match '--no-playlist') {
                    $Config.DefaultFlags = $Config.DefaultFlags -replace '--no-playlist', '--yes-playlist'
                } elseif ($Config.DefaultFlags -match '--yes-playlist') {
                    $Config.DefaultFlags = $Config.DefaultFlags -replace '--yes-playlist', '--no-playlist'
                } else {
                    $Config.DefaultFlags += " --no-playlist"
                }
                Save-Config
            }
            "4" {
                $new = Read-Host "Enter new output folder path"
                if ($new.Trim()) {
                    $Config.OutputPath = $new.Trim()
                    Save-Config
                }
            }
            "5" {
                $new = Read-Host "Enter concurrent fragments (1-16)"
                if ($new -match '^\d+$') {
                    $n = [int]$new
                    if ($n -lt 1) { $n = 1 }; if ($n -gt 16) { $n = 16 }
                    $Config.ConcurrentFragments = $n
                    Save-Config
                }
            }
            "6" {
                Clear-Host
                Write-Host "CURRENT FLAGS" -ForegroundColor Cyan
                Write-Host $Config.DefaultFlags -ForegroundColor White
                Write-Host ""
                Write-Host "Enter new flags (blank to keep):" -ForegroundColor Yellow
                $new = Read-Host
                if ($new.Trim()) {
                    $Config.DefaultFlags = $new.Trim()
                    Save-Config
                }
            }
            "0" { return }
        }
    }
}

# ==================== MAIN ====================
Show-Header
$urls = Get-Urls
if ($urls.Count -gt 0) {
    Start-Downloads -Urls $urls
} else {
    Write-Host "Nothing to do." -ForegroundColor Yellow
}