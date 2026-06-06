# yt-dlp v2 — PowerShell Downloader

A fast, modular PowerShell script for downloading audio/video from YouTube (and beyond) using **yt-dlp**. Designed to be pinned to your Start Menu — open it, paste links, hit Enter, done.

---

## 🚀 Quick Start

1. Make sure **yt-dlp** is installed and available in your PATH.
2. Save `yt-dlpv2.ps1` in a folder (e.g., `Documents\powershell_scripts\yt-dlp_blazing_fast`).
3. Create a shortcut to PowerShell with the argument:
   ```
   powershell -NoExit -File "C:\Path\To\yt-dlpv2.ps1"
   ```
4. Pin the shortcut to your Start Menu / taskbar.
5. Click → paste URLs → Enter on a blank line → downloading starts automatically.

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| **Fast pasting** | Paste links (even surrounded by text) — regex extracts URLs automatically. |
| **Auto-fallback** | If `bestaudio` is unavailable, the script automatically retries with `bestaudio/best`, then `best`. |
| **Apple Music Auto-Add** | Toggle in menu — new files are automatically moved to *Automatically Add to Apple Music*. |
| **SponsorBlock** | Optionally remove sponsors, intros, outros from videos. |
| **Download archive** | Won't download the same file twice (`download_archive.txt`). |
| **Concurrent fragments** | `--concurrent-fragments` speeds up DASH/HLS downloads. |
| **Settings menu** | Type `settings` instead of a URL to configure everything without editing code. |
| **Persistent config** | All settings are saved to `config.json` between runs. |

---

## 📁 File Structure

```
yt-dlp_blazing_fast/
├── yt-dlpv2.ps1              # Main script
├── config.json               # Your settings (auto-created)
├── download_archive.txt      # List of already-downloaded files
└── options/
    └── default.txt           # Default flags (synced with config)
```

---

## 🎮 How to Use

### Basic Flow
```
Paste URLs (blank line to start downloading):

https://www.youtube.com/watch?v=Zf07To1EPYI
  Collected: 1 URL(s)

https://youtu.be/abc123 check this out
  Collected: 2 URL(s)

<Enter on blank line>
→ Download starts automatically
```

### Prompt Commands
| Command | Action |
|---------|--------|
| `settings` | Opens the settings menu |
| `exit`, `quit`, `q` | Closes the script without downloading |
| `<blank line>` | Finishes pasting and starts download (if URLs exist) |

---

## ⚙️ Settings (Menu)

Type `settings` at the URL prompt to open the menu:

```
[1] Toggle Apple Music Auto-Add   [ON/OFF]
[2] Toggle SponsorBlock           [ON/OFF]
[3] Toggle Playlist Download      [ON/OFF]
[4] Output Folder                 (path)
[5] Concurrent Fragments          (1-16)
[6] Edit Download Flags           (edit yt-dlp flags)
[0] Back to download
```

### Apple Music
When enabled, after downloading finishes new files are automatically moved to:
```
%USERPROFILE%\Music\Apple Music\Media\Automatically Add to Apple Music
```
iTunes/Apple Music will then auto-import them into your library.

---

## 🔧 Troubleshooting

### "No supported JavaScript runtime could be found"
YouTube now requires a JS runtime for full format extraction. Install one:

```powershell
# Option A: Deno (recommended by yt-dlp, lightweight)
winget install deno

# Option B: Node.js
winget install OpenJS.NodeJS
```

Restart your terminal after installation.

### "Requested format is not available"
The script has a built-in **3-tier fallback**:
1. Your saved flags (e.g., `-f bestaudio`)
2. `-f bestaudio/best` — downloads the combined stream if pure audio is missing
3. `-f best` — downloads the best available combined stream

If all 3 fail, the URL is skipped and the script moves to the next one.

### "Your yt-dlp version is older than 90 days"
Update yt-dlp:
```powershell
yt-dlp -U
```

---

## 🛠️ Default Flags (Editable)

Default flags in `config.json` / `options/default.txt`:
```
-f bestaudio --extract-audio --audio-format m4a --audio-quality 0 --embed-thumbnail --add-metadata --no-playlist
```

You can change them in the menu via `settings` → `[6] Edit Download Flags`.

Examples of other presets:
- **Video best quality:** `-f bestvideo*+bestaudio/best --merge-output-format mp4`
- **Video 1080p:** `-f "bestvideo[height<=1080]+bestaudio/best[height<=1080]" --merge-output-format mp4`
- **Video 4K:** `-f "bestvideo[height<=2160]+bestaudio/best[height<=2160]" --merge-output-format mp4`

---

## 📌 Requirements

- Windows PowerShell 5.1 or PowerShell 7+
- [yt-dlp](https://github.com/yt-dlp/yt-dlp) in your PATH
- (Recommended) [Deno](https://deno.com/) or Node.js for full YouTube compatibility

---

## 📝 License

Free to use. Modify and extend as you wish — the code is modular, every feature is a separate block that can be easily expanded.
