#Requires -Version 5.1
# yt-dlp v3.6 — Fast Edition with Auto-Fallback

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
if (-not (Test-Path $DefaultTxt)) {
    $DefaultConfig.DefaultFlags | Set-Content -Path $DefaultTxt -Encoding UTF8
}

if (Test-Path $ConfigPath) {
    try {
        $raw = Get-Content -Raw $ConfigPath
        $Config = $raw | ConvertFrom-Json
        foreach ($key in $DefaultConfig.Keys) {
            if (-not $Config.PSObject.Properties[$key]) {
                $Config | Add-Member -NotePropertyName $key -NotePropertyValue $DefaultConfig[$key]
            }
        }
    } catch {
        $Config = $DefaultConfig | ConvertTo-Json -Depth 10 | ConvertFrom-Json
    }
} else {
    $seed = (Get-Content -Raw $DefaultTxt -ErrorAction SilentlyContinue).Trim()
    if ($seed) { $DefaultConfig.DefaultFlags = $seed }
    $Config = $DefaultConfig | ConvertTo-Json -Depth 10 | ConvertFrom-Json
    Save-Config
}

function Save-Config {
    $Config | ConvertTo-Json -Depth 10 | Set-Content -Path $ConfigPath -Encoding UTF8
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

function Test-JsRuntime {
    $js = @("deno","node","qjs","quickjs","node.exe")
    foreach ($j in $js) {
        if (Get-Command $j -ErrorAction SilentlyContinue) { return $true }
    }
    return $false
}

# ==================== FAST URL COLLECTOR ====================
function Get-Urls {
    $urls = [System.Collections.Generic.List[string]]::new()

    Write-Host "Paste URLs (blank line to start downloading):" -ForegroundColor Yellow
    Write-Host ""

    while ($true) {
        $line = Read-Host
        $trimmed = $line.Trim()

        if ($trimmed -eq "") {
            if ($urls.Count -gt 0) { break }
            Write-Host "  No URLs yet. Paste a link or type 'settings'." -ForegroundColor DarkGray
            continue
        }

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
    param([int]$Attempt = 1)

    $parts = [System.Collections.Generic.List[string]]::new()
    $base = $Config.DefaultFlags
    if ([string]::IsNullOrWhiteSpace($base)) {
        $base = "-f bestaudio --extract-audio --audio-format m4a --audio-quality 0 --embed-thumbnail --add-metadata --no-playlist"
    }

    switch ($Attempt) {
        1 {
            # Your configured flags exactly as saved
            $parts.Add($base)
        }
        2 {
            # Fallback: try bestaudio/best (or whatever/best)
            $fallback = $base
            if ($fallback -match '-f\s+("[^"]+"|\S+)') {
                $fmt = ($matches[1] -replace '"','')
                if ($fmt -notmatch '/best$') {
                    $fallback = $fallback -replace '-f\s+("[^"]+"|\S+)', "-f $fmt/best"
                    Write-Host "  Fallback: format '$fmt' → '$fmt/best'" -ForegroundColor Yellow
                } else {
                    $fallback = $fallback -replace '-f\s+("[^"]+"|\S+)', ''
                    Write-Host "  Fallback: removed format filter" -ForegroundColor Yellow
                }
            } else {
                $fallback = "-f bestaudio/best $fallback"
                Write-Host "  Fallback: using 'bestaudio/best'" -ForegroundColor Yellow
            }
            $parts.Add($fallback)
        }
        3 {
            # Nuclear fallback: force 'best' combined stream
            # --extract-audio will still rip the audio track afterward
            $fallback = $base -replace '-f\s+("[^"]+"|\S+)', ''
            $parts.Add("-f best $fallback")
            Write-Host "  Fallback: using 'best' (combined stream)" -ForegroundColor Yellow
        }
    }

    if ($Config.SponsorBlock)        { $parts.Add("--sponsorblock-remove all") }
    if ($Config.UseArchive -and $Config.ArchivePath) {
        $parts.Add("--download-archive `"$($Config.ArchivePath)`"")
    }
    if ($Config.ConcurrentFragments -gt 1) {
        $parts.Add("--concurrent-fragments $($Config.ConcurrentFragments)")
    }

    $out = $Config.OutputPath
    if (-not (Test-Path $out)) { New-Item -ItemType Directory -Path $out -Force | Out-Null }
    $parts.Add("-o `"$out\%(title)s.%(ext)s`"")

    $parts.Add("--continue")
    $parts.Add("--retries 10")

    return ($parts -join " ")
}

function Start-Downloads {
    param([array]$Urls)

    $startTime = Get-Date
    $outDir    = $Config.OutputPath

    foreach ($url in $Urls) {
        Write-Host ""
        Write-Host "Downloading: $url" -ForegroundColor Cyan

        $success = $false
        for ($attempt = 1; $attempt -le 3; $attempt++) {
            if ($attempt -gt 1) {
                Write-Host ""
                Write-Host "Attempt $attempt : Retrying with fallback..." -ForegroundColor Yellow
            }

            $flags = Build-Flags -Attempt $attempt
            $cmd   = "yt-dlp $flags `"$url`""
            Write-Host "  $cmd" -ForegroundColor DarkGray
            Write-Host ""

            Invoke-Expression $cmd
            $exitCode = $LASTEXITCODE

            if ($exitCode -eq 0) {
                $success = $true
                break
            }

            if ($attempt -eq 3) {
                Write-Host "  Failed after all fallback attempts." -ForegroundColor Red
            }
        }

        if (-not $success) {
            Write-Host "  SKIPPED: $url" -ForegroundColor Red
        }
    }

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

if (-not (Test-JsRuntime)) {
    Write-Host "WARNING: No JavaScript runtime found (Deno/Node/QuickJS)." -ForegroundColor Red
    Write-Host "YouTube may fail or skip formats. Fix it:" -ForegroundColor Yellow
    Write-Host "  winget install deno     or     winget install OpenJS.NodeJS" -ForegroundColor White
    Write-Host ""
}

$urls = Get-Urls
if ($urls.Count -gt 0) {
    Start-Downloads -Urls $urls
} else {
    Write-Host "Nothing to do." -ForegroundColor Yellow
}