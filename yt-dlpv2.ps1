#Requires -Version 5.1
#requires -Modules Microsoft.PowerShell.Utility

# ==================== CONFIGURATION ====================
$Script:AppName    = "yt-dlp PowerShell Suite"
$Script:Version   = "2.0"
$Script:ScriptDir  = $PSScriptRoot
$Script:ConfigPath = Join-Path $Script:ScriptDir "config.json"
$Script:OptionsDir = Join-Path $Script:ScriptDir "options"
$Script:DefaultTxt = Join-Path $Script:OptionsDir "default.txt"

# Default configuration object
$Script:DefaultConfig = @{
    AppleMusic = @{
        Enabled = $false
        Path    = "$env:USERPROFILE\Music\Apple Music\Media\Automatically Add to Apple Music"
    }
    Download = @{
        OutputPath          = "$env:USERPROFILE\Videos"
        Preset              = "default"   # default | audio | video-best | video-1080 | video-4k | custom
        CustomFlags         = ""
        UseArchive          = $true
        ArchivePath         = Join-Path $Script:ScriptDir "download_archive.txt"
        ConcurrentFragments = 4
        SponsorBlock        = $true
        EmbedThumbnail      = $true
        AddMetadata         = $true
        EmbedSubs           = $false
        SubLangs            = "en"
        CookiesFromBrowser  = ""          # e.g., "chrome", "firefox", "edge"
        Playlist            = $false
    }
}

# ==================== COLORS ====================
$Script:Color = @{
    Header    = "Cyan"
    Success   = "Green"
    Error     = "Red"
    Warning   = "Yellow"
    Info      = "White"
    Accent    = "Magenta"
    Dim       = "Gray"
    MenuNum   = "Yellow"
}

# ==================== CORE FUNCTIONS ====================

function Initialize-Environment {
    if (-not (Test-Path $Script:OptionsDir)) {
        New-Item -ItemType Directory -Path $Script:OptionsDir -Force | Out-Null
    }
    # Ensure default.txt exists with sensible defaults if missing
    if (-not (Test-Path $Script:DefaultTxt)) {
        @"
-f bestaudio --extract-audio --audio-format m4a --audio-quality 0 --embed-thumbnail --add-metadata --no-playlist
"@ | Set-Content -Path $Script:DefaultTxt -Encoding UTF8
    }
}

function Load-Config {
    if (Test-Path $Script:ConfigPath) {
        try {
            $Script:Config = Get-Content $Script:ConfigPath -Raw | ConvertFrom-Json
            # Merge missing keys (for future upgrades)
            foreach ($key in $Script:DefaultConfig.Keys) {
                if (-not $Script:Config.PSObject.Properties[$key]) {
                    $Script:Config | Add-Member -NotePropertyName $key -NotePropertyValue $Script:DefaultConfig[$key]
                }
            }
        } catch {
            Write-Color "Failed to load config. Resetting to defaults." $Script:Color.Error
            $Script:Config = $Script:DefaultConfig | ConvertTo-Json -Depth 10 | ConvertFrom-Json
            Save-Config
        }
    } else {
        $Script:Config = $Script:DefaultConfig | ConvertTo-Json -Depth 10 | ConvertFrom-Json
        Save-Config
    }
}

function Save-Config {
    $Script:Config | ConvertTo-Json -Depth 10 | Set-Content -Path $Script:ConfigPath -Encoding UTF8
}

function Write-Color {
    param([string]$Text, [string]$Color = "White", [switch]$NoNewline)
    $params = @{ Object = $Text; ForegroundColor = $Color }
    if ($NoNewline) { $params.NoNewline = $true }
    Write-Host @params
}

function Write-Header {
    Clear-Host
    $amStatus = if ($Script:Config.AppleMusic.Enabled) { "ON " } else { "OFF" }
    $amColor  = if ($Script:Config.AppleMusic.Enabled) { $Script:Color.Success } else { $Script:Color.Error }
    $preset   = $Script:Config.Download.Preset.ToUpper()
    $sbStatus = if ($Script:Config.Download.SponsorBlock) { "ON" } else { "OFF" }

    Write-Color "╔══════════════════════════════════════════════════════════════╗" $Script:Color.Header
    Write-Color "║" $Script:Color.Header -NoNewline
    Write-Color "  $Script:AppName v$Script:Version".PadRight(61) $Script:Color.Accent -NoNewline
    Write-Color "║" $Script:Color.Header
    Write-Color "╠══════════════════════════════════════════════════════════════╣" $Script:Color.Header
    Write-Color "║" $Script:Color.Header -NoNewline
    Write-Color "  Preset: $preset  |  SponsorBlock: $sbStatus  |   Music Mover: ".PadRight(50) $Script:Color.Info -NoNewline
    Write-Color "$amStatus" $amColor -NoNewline
    Write-Color "  ║" $Script:Color.Header
    Write-Color "╚══════════════════════════════════════════════════════════════╝" $Script:Color.Header
    Write-Host ""
}

function Show-MenuItem {
    param([string]$Key, [string]$Label, [string]$Status = "", [string]$StatusColor = "White")
    Write-Color "  [$Key] " $Script:Color.MenuNum -NoNewline
    Write-Color $Label.PadRight(45) $Script:Color.Info -NoNewline
    if ($Status) {
        Write-Color $Status $StatusColor
    } else {
        Write-Host ""
    }
}

function Pause-AnyKey {
    param([string]$Message = "Press any key to continue...")
    Write-Host ""
    Write-Color $Message $Script:Color.Dim
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Test-AppleMusicPath {
    $path = $Script:Config.AppleMusic.Path
    if ($Script:Config.AppleMusic.Enabled -and -not (Test-Path $path)) {
        Write-Color "WARNING: Apple Music path not found!" $Script:Color.Warning
        Write-Color "  $path" $Script:Color.Dim
        Write-Color "Please verify Apple Music is installed or update the path in Settings." $Script:Color.Warning
        return $false
    }
    return $true
}

# ==================== DOWNLOAD ENGINE ====================

function Get-Urls {
    $urls = @()
    Write-Color " Paste URLs one per line. Type 'n' or leave blank and Enter to finish." $Script:Color.Dim
    Write-Host ""
    do {
        $input = Read-Host "  URL"
        $clean = $input.Trim()
        if ($clean.ToLower() -eq 'n' -or $clean -eq '') {
            if ($urls.Count -eq 0) { return $null }
            break
        }
        if ($clean -match '^https?://') {
            $urls += $clean
            Write-Color "  ✓ Added ($($urls.Count) total)" $Script:Color.Success
        } else {
            Write-Color "  ✗ Invalid URL. Must start with http:// or https://" $Script:Color.Error
        }
    } while ($true)
    return $urls
}

function Build-Flags {
    param([string]$Url)

    $cfg = $Script:Config.Download
    $parts = [System.Collections.Generic.List[string]]::new()

    # Preset base flags
    switch ($cfg.Preset) {
        "default" {
            if (Test-Path $Script:DefaultTxt) {
                $defaultRaw = (Get-Content -Raw $Script:DefaultTxt).Trim()
                $parts.Add($defaultRaw)
            } else {
                $parts.Add("-f bestaudio --extract-audio --audio-format m4a --audio-quality 0 --embed-thumbnail --add-metadata --no-playlist")
            }
        }
        "audio" {
            $parts.Add("-f bestaudio --extract-audio --audio-format m4a --audio-quality 0 --embed-thumbnail --add-metadata --no-playlist")
        }
        "video-best" {
            $parts.Add("-f bestvideo*+bestaudio/best --merge-output-format mp4 --embed-thumbnail --add-metadata")
        }
        "video-1080" {
            $parts.Add('-f "bestvideo[height<=1080]+bestaudio/best[height<=1080]" --merge-output-format mp4 --embed-thumbnail --add-metadata')
        }
        "video-4k" {
            $parts.Add('-f "bestvideo[height<=2160]+bestaudio/best[height<=2160]" --merge-output-format mp4 --embed-thumbnail --add-metadata')
        }
        "custom" {
            if ($cfg.CustomFlags) {
                $parts.Add($cfg.CustomFlags)
            } else {
                Write-Color "Custom preset selected but no flags configured! Falling back to default." $Script:Color.Warning
                $parts.Add("-f bestaudio --extract-audio --audio-format m4a --audio-quality 0")
            }
        }
    }

    # Global toggles
    if ($cfg.SponsorBlock) {
        $parts.Add("--sponsorblock-remove all")
    }
    if ($cfg.EmbedThumbnail) {
        $parts.Add("--embed-thumbnail")
    }
    if ($cfg.AddMetadata) {
        $parts.Add("--add-metadata")
    }
    if ($cfg.EmbedSubs) {
        $parts.Add("--embed-subs --sub-langs $($cfg.SubLangs)")
    }
    if ($cfg.UseArchive -and $cfg.ArchivePath) {
        $parts.Add("--download-archive `"$($cfg.ArchivePath)`"")
    }
    if ($cfg.ConcurrentFragments -gt 1) {
        $parts.Add("--concurrent-fragments $($cfg.ConcurrentFragments)")
    }
    if ($cfg.CookiesFromBrowser) {
        $parts.Add("--cookies-from-browser $($cfg.CookiesFromBrowser)")
    }
    if (-not $cfg.Playlist) {
        $parts.Add("--no-playlist")
    } else {
        $parts.Add("--yes-playlist")
    }

    # Output path
    $outputDir = $cfg.OutputPath
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
    $parts.Add("-o `"$outputDir\%(title)s.%(ext)s`"")

    # Continue partial, limit retries
    $parts.Add("--continue")
    $parts.Add("--retries 10")

    return ($parts -join " ")
}

function Invoke-Downloads {
    param([array]$Urls)

    $cfg = $Script:Config.Download
    $outputDir = $cfg.OutputPath
    $startTime = Get-Date

    # Snapshot existing files to know what's new
    $existingFiles = @()
    if (Test-Path $outputDir) {
        $existingFiles = Get-ChildItem -Path $outputDir -Recurse -File | Select-Object -ExpandProperty FullName
    }

    foreach ($url in $Urls) {
        Write-Header
        Write-Color " Processing URL: $url" $Script:Color.Accent
        Write-Host ""

        $flags = Build-Flags -Url $url
        $command = "yt-dlp $flags `"$url`""

        Write-Color " Command:" $Script:Color.Dim
        Write-Color "  $command" $Script:Color.Dim
        Write-Host ""

        try {
            Invoke-Expression $command
            if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
                Write-Color " yt-dlp exited with code $LASTEXITCODE" $Script:Color.Warning
            }
        } catch {
            Write-Color " ERROR: $_" $Script:Color.Error
        }
        Write-Host ""
    }

    # Post-processing: Move to Apple Music
    if ($Script:Config.AppleMusic.Enabled) {
        Move-NewFilesToAppleMusic -OutputDir $outputDir -ExistingFiles $existingFiles -StartTime $startTime
    }

    Write-Host ""
    Write-Color " All operations completed." $Script:Color.Success
    Pause-AnyKey
}

function Move-NewFilesToAppleMusic {
    param([string]$OutputDir, [array]$ExistingFiles, [datetime]$StartTime)

    $dest = $Script:Config.AppleMusic.Path
    if (-not (Test-Path $dest)) {
        Write-Color " Apple Music destination not found. Skipping move." $Script:Color.Error
        return
    }

    # Find files that didn't exist before this run
    $newFiles = Get-ChildItem -Path $OutputDir -Recurse -File | Where-Object {
        $_.FullName -notin $ExistingFiles -and $_.LastWriteTime -ge $StartTime
    }

    if (-not $newFiles) {
        Write-Color " No new files detected to move." $Script:Color.Warning
        return
    }

    Write-Host ""
    Write-Color " Moving $($newFiles.Count) new file(s) to Apple Music..." $Script:Color.Accent

    foreach ($file in $newFiles) {
        try {
            $target = Join-Path $dest $file.Name
            # Handle duplicate names
            if (Test-Path $target) {
                $base = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
                $ext  = [System.IO.Path]::GetExtension($file.Name)
                $target = Join-Path $dest "$base-$(Get-Random)$ext"
            }
            Move-Item -Path $file.FullName -Destination $target -Force
            Write-Color "  → $($file.Name)" $Script:Color.Success
        } catch {
            Write-Color "  ✗ Failed to move $($file.Name): $_" $Script:Color.Error
        }
    }
}

# ==================== MENUS ====================

function Show-MainMenu {
    do {
        Write-Header
        Show-MenuItem "1" "Start Download" ""
        Show-MenuItem "2" "Settings & Presets" ""
        Show-MenuItem "3" "Toggle Apple Music Auto-Add" "$(if($Script:Config.AppleMusic.Enabled){'ENABLED'}else{'DISABLED'})" $(if($Script:Config.AppleMusic.Enabled){$Script:Color.Success}else{$Script:Color.Error})
        Show-MenuItem "4" "Edit Custom Flags" "$(if($Script:Config.Download.Preset -eq 'custom'){$Script:Config.Download.CustomFlags}else{'N/A'})" $Script:Color.Dim
        Show-MenuItem "0" "Exit" ""
        Write-Host ""
        $choice = Read-Host "  Select option"

        switch ($choice.Trim()) {
            "1" { Start-DownloadFlow }
            "2" { Show-SettingsMenu }
            "3" { Toggle-AppleMusic }
            "4" { Edit-CustomFlags }
            "0" { exit }
            default { continue }
        }
    } while ($true)
}

function Start-DownloadFlow {
    Write-Header
    $urls = Get-Urls
    if (-not $urls) {
        Write-Color " No URLs provided. Returning to menu." $Script:Color.Warning
        Pause-AnyKey
        return
    }

    # Summary
    Write-Header
    Write-Color " DOWNLOAD SUMMARY" $Script:Color.Accent
    Write-Color "  URLs to process: $($urls.Count)" $Script:Color.Info
    Write-Color "  Preset: $($Script:Config.Download.Preset)" $Script:Color.Info
    Write-Color "  Output: $($Script:Config.Download.OutputPath)" $Script:Color.Info
    Write-Color "  Apple Music: $(if($Script:Config.AppleMusic.Enabled){'YES'}else{'NO'})" $(if($Script:Config.AppleMusic.Enabled){$Script:Color.Success}else{$Script:Color.Dim})
    Write-Host ""
    $confirm = Read-Host "  Proceed? (Y/n)"
    if ($confirm.Trim() -and $confirm.Trim().ToLower() -ne 'y') {
        Write-Color " Cancelled." $Script:Color.Warning
        Pause-AnyKey
        return
    }

    Invoke-Downloads -Urls $urls
}

function Toggle-AppleMusic {
    $Script:Config.AppleMusic.Enabled = -not $Script:Config.AppleMusic.Enabled
    Save-Config
    if ($Script:Config.AppleMusic.Enabled) {
        Test-AppleMusicPath | Out-Null
    }
}

function Edit-CustomFlags {
    Write-Header
    Write-Color " CUSTOM FLAGS EDITOR" $Script:Color.Accent
    Write-Color " Current preset: $($Script:Config.Download.Preset)" $Script:Color.Info
    Write-Color " Current custom flags:" $Script:Color.Dim
    Write-Color "  $($Script:Config.Download.CustomFlags)" $Script:Color.Dim
    Write-Host ""
    Write-Color " Enter new custom flags (blank to keep current):" $Script:Color.Info
    $new = Read-Host "  "
    if ($new.Trim()) {
        $Script:Config.Download.CustomFlags = $new.Trim()
        $Script:Config.Download.Preset = "custom"
        Save-Config
        Write-Color " Saved and preset set to 'custom'." $Script:Color.Success
    } else {
        Write-Color " No changes made." $Script:Color.Dim
    }
    Pause-AnyKey
}

function Show-SettingsMenu {
    do {
        Write-Header
        Write-Color " SETTINGS" $Script:Color.Accent
        Write-Host ""
        Show-MenuItem "1" "Change Preset" "Current: $($Script:Config.Download.Preset)" $Script:Color.Accent
        Show-MenuItem "2" "Output Directory" "$($Script:Config.Download.OutputPath)" $Script:Color.Dim
        Show-MenuItem "3" "Toggle SponsorBlock" "$(if($Script:Config.Download.SponsorBlock){'ON'}else{'OFF'})" $(if($Script:Config.Download.SponsorBlock){$Script:Color.Success}else{$Script:Color.Error})
        Show-MenuItem "4" "Toggle Thumbnail Embed" "$(if($Script:Config.Download.EmbedThumbnail){'ON'}else{'OFF'})" $(if($Script:Config.Download.EmbedThumbnail){$Script:Color.Success}else{$Script:Color.Error})
        Show-MenuItem "5" "Toggle Metadata" "$(if($Script:Config.Download.AddMetadata){'ON'}else{'OFF'})" $(if($Script:Config.Download.AddMetadata){$Script:Color.Success}else{$Script:Color.Error})
        Show-MenuItem "6" "Toggle Subtitles" "$(if($Script:Config.Download.EmbedSubs){'ON'}else{'OFF'})" $(if($Script:Config.Download.EmbedSubs){$Script:Color.Success}else{$Script:Color.Error})
        Show-MenuItem "7" "Toggle Archive File" "$(if($Script:Config.Download.UseArchive){'ON'}else{'OFF'})" $(if($Script:Config.Download.UseArchive){$Script:Color.Success}else{$Script:Color.Error})
        Show-MenuItem "8" "Toggle Playlist Mode" "$(if($Script:Config.Download.Playlist){'ON'}else{'OFF'})" $(if($Script:Config.Download.Playlist){$Script:Color.Success}else{$Script:Color.Error})
        Show-MenuItem "9" "Concurrent Fragments" "$($Script:Config.Download.ConcurrentFragments)" $Script:Color.Accent
        Show-MenuItem "A" "Cookies from Browser" "$(if($Script:Config.Download.CookiesFromBrowser){$Script:Config.Download.CookiesFromBrowser}else{'None'})" $Script:Color.Dim
        Show-MenuItem "B" "Apple Music Path" "$($Script:Config.AppleMusic.Path)" $Script:Color.Dim
        Show-MenuItem "0" "Back to Main Menu" ""
        Write-Host ""
        $choice = Read-Host "  Select option"

        switch ($choice.Trim().ToLower()) {
            "1" { Change-Preset }
            "2" { Change-OutputDir }
            "3" { $Script:Config.Download.SponsorBlock = -not $Script:Config.Download.SponsorBlock; Save-Config }
            "4" { $Script:Config.Download.EmbedThumbnail = -not $Script:Config.Download.EmbedThumbnail; Save-Config }
            "5" { $Script:Config.Download.AddMetadata = -not $Script:Config.Download.AddMetadata; Save-Config }
            "6" { Toggle-Subs }
            "7" { $Script:Config.Download.UseArchive = -not $Script:Config.Download.UseArchive; Save-Config }
            "8" { $Script:Config.Download.Playlist = -not $Script:Config.Download.Playlist; Save-Config }
            "9" { Change-Concurrent }
            "a" { Change-Cookies }
            "b" { Change-AppleMusicPath }
            "0" { return }
            default { continue }
        }
    } while ($true)
}

function Change-Preset {
    Write-Header
    Write-Color " SELECT PRESET" $Script:Color.Accent
    Write-Color "  1) default  - Use your options\default.txt file" $Script:Color.Info
    Write-Color "  2) audio    - Best audio only → M4A with thumbnail/metadata" $Script:Color.Info
    Write-Color "  3) video-best - Best quality video + audio, MP4 container" $Script:Color.Info
    Write-Color "  4) video-1080 - Best quality up to 1080p" $Script:Color.Info
    Write-Color "  5) video-4k   - Best quality up to 4K" $Script:Color.Info
    Write-Color "  6) custom   - Enter your own flags manually" $Script:Color.Info
    Write-Host ""
    $p = Read-Host "  Select preset (1-6)"
    switch ($p.Trim()) {
        "1" { $Script:Config.Download.Preset = "default" }
        "2" { $Script:Config.Download.Preset = "audio" }
        "3" { $Script:Config.Download.Preset = "video-best" }
        "4" { $Script:Config.Download.Preset = "video-1080" }
        "5" { $Script:Config.Download.Preset = "video-4k" }
        "6" { $Script:Config.Download.Preset = "custom" }
        default { return }
    }
    Save-Config
}

function Change-OutputDir {
    Write-Header
    Write-Color " OUTPUT DIRECTORY" $Script:Color.Accent
    Write-Color " Current: $($Script:Config.Download.OutputPath)" $Script:Color.Dim
    $new = Read-Host "  Enter new path (blank to keep)"
    if ($new.Trim()) {
        $Script:Config.Download.OutputPath = $new.Trim()
        Save-Config
        Write-Color " Updated." $Script:Color.Success
        Pause-AnyKey
    }
}

function Toggle-Subs {
    $Script:Config.Download.EmbedSubs = -not $Script:Config.Download.EmbedSubs
    if ($Script:Config.Download.EmbedSubs) {
        $lang = Read-Host "  Subtitle languages (default: en)"
        if ($lang.Trim()) { $Script:Config.Download.SubLangs = $lang.Trim() }
    }
    Save-Config
}

function Change-Concurrent {
    Write-Header
    Write-Color " CONCURRENT FRAGMENTS" $Script:Color.Accent
    Write-Color " Higher = faster but more CPU/network. Default: 4" $Script:Color.Dim
    $val = Read-Host "  Enter number (1-16)"
    if ($val -match '^\d+$') {
        $num = [int]$val
        if ($num -lt 1) { $num = 1 }
        if ($num -gt 16) { $num = 16 }
        $Script:Config.Download.ConcurrentFragments = $num
        Save-Config
    }
}

function Change-Cookies {
    Write-Header
    Write-Color " BROWSER COOKIES" $Script:Color.Accent
    Write-Color " Useful for age-restricted or members-only content." $Script:Color.Dim
    Write-Color " Leave blank to disable. Examples: chrome, firefox, edge, safari" $Script:Color.Dim
    $new = Read-Host "  Browser name"
    $Script:Config.Download.CookiesFromBrowser = $new.Trim()
    Save-Config
}

function Change-AppleMusicPath {
    Write-Header
    Write-Color " APPLE MUSIC AUTO-ADD PATH" $Script:Color.Accent
    Write-Color " Current: $($Script:Config.AppleMusic.Path)" $Script:Color.Dim
    $new = Read-Host "  Enter new path (blank to keep)"
    if ($new.Trim()) {
        $Script:Config.AppleMusic.Path = $new.Trim()
        Save-Config
        Write-Color " Updated." $Script:Color.Success
        Pause-AnyKey
    }
}

# ==================== ENTRY POINT ====================

Initialize-Environment
Load-Config
Show-MainMenu