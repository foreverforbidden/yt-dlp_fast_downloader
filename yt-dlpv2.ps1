# --- INITIAL SETUP ---
Set-Location "$env:USERPROFILE\Videos"
$urls = @()

# --- LOOP TO COLLECT URLS ---
do{
    $input = Read-Host "Do you want to download? (paste URL or 'n' to quit or start downloading.)"

    if ($input.ToLower().Trim() -eq 'n') {
        break
    }
    elseif ($input -match '\S') {
        $urls += $input
    }
} while ($true)

if ($urls.Count -eq 0) {
    Write-Host "No URLs collected. Exiting."
    exit
}

# --- CHOOSE SETTINGS ---
$choice = Read-Host "Use default.txt settings or input your own? (D/C)"
$choice = $choice.ToLower().Trim()

if ($choice -eq "d") {
    $flags = (Get-Content -Raw "$PSScriptRoot\options\default.txt").Trim()
} else {
    $flags = Read-Host "Enter your custom flags (example: -f bestaudio --extract-audio --audio-format m4a)"
}

# --- LOOP OVER URLS AND EXECUTE ---
foreach ($url in $urls) {
    $command = "yt-dlp $flags `"$url`""
    Write-Host "Executing: $command"
    Invoke-Expression $command
}

Write-Host "All downloads completed."
