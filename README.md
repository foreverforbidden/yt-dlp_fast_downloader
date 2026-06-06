# yt-dlp v2 — PowerShell Downloader

Szybki, modularny skrypt PowerShell do pobierania audio/wideo z YouTube (i nie tylko) przy użyciu **yt-dlp**. Zaprojektowany do przypięcia do menu Start — otwórz, wklej linki, naciśnij Enter, gotowe.

---

## 🚀 Szybki start

1. Upewnij się, że masz zainstalowany **yt-dlp** i jest w PATH.
2. Zapisz `yt-dlpv2.ps1` w folderze (np. `Documents\powershell_scripts\yt-dlp_blazing_fast`).
3. Utwórz skrót do PowerShell z argumentem:
   ```
   powershell -NoExit -File "C:\Path\To\yt-dlpv2.ps1"
   ```
4. Przypnij skrót do menu Start / paska zadań.
5. Kliknij → wklej URL-e → Enter na pustej linii → pobieranie startuje automatycznie.

---

## ✨ Funkcje

| Funkcja | Opis |
|---------|------|
| **Szybkie wklejanie** | Wklejasz linki (nawet z otaczającym tekstem), regex sam wyciąga URL-e. |
| **Auto-fallback** | Jeśli `bestaudio` nie istnieje, skrypt automatycznie próbuje `bestaudio/best`, a potem `best`. |
| **Apple Music Auto-Add** | Przełącznik w menu — nowe pliki są automatycznie przenoszone do *Automatically Add to Apple Music*. |
| **SponsorBlock** | Opcjonalne usuwanie sponsorów, intro, outro z wideo. |
| **Archiwum pobierania** | Nie pobiera tego samego pliku dwa razy (plik `download_archive.txt`). |
| **Fragmenty równoległe** | `--concurrent-fragments` przyspiesza pobieranie DASH/HLS. |
| **Menu ustawień** | Wpisz `settings` zamiast URL-a, aby skonfigurować wszystko bez edycji kodu. |
| **Persistent config** | Wszystkie ustawienia zapisują się w `config.json` między uruchomieniami. |

---

## 📁 Struktura plików

```
yt-dlp_blazing_fast/
├── yt-dlpv2.ps1              # Główny skrypt
├── config.json               # Twoje ustawienia (automatycznie tworzony)
├── download_archive.txt      # Lista już pobranych plików
└── options/
    └── default.txt           # Flagi domyślne (synchronizowane z configiem)
```

---

## 🎮 Jak używać

### Podstawowy flow
```
Paste URLs (blank line to start downloading):

https://www.youtube.com/watch?v=Zf07To1EPYI
  Collected: 1 URL(s)

https://youtu.be/abc123 check this out
  Collected: 2 URL(s)

<Enter na pustej linii>
→ Pobieranie startuje automatycznie
```

### Komendy w promptcie
| Komenda | Działanie |
|---------|-----------|
| `settings` | Otwiera menu ustawień |
| `exit`, `quit`, `q` | Zamyka skrypt bez pobierania |
| `<pusta linia>` | Kończy wklejanie i startuje download (jeśli są URL-e) |

---

## ⚙️ Ustawienia (menu)

Wpisz `settings` w promptcie URL, aby otworzyć menu:

```
[1] Toggle Apple Music Auto-Add   [ON/OFF]
[2] Toggle SponsorBlock           [ON/OFF]
[3] Toggle Playlist Download      [ON/OFF]
[4] Output Folder                 (ścieżka)
[5] Concurrent Fragments          (1-16)
[6] Edit Download Flags           (edycja flag yt-dlp)
[0] Back to download
```

### Apple Music
Gdy włączone, po zakończeniu pobierania nowe pliki są automatycznie przenoszone do:
```
%USERPROFILE%\Music\Apple Music\Media\Automatically Add to Apple Music
```
iTunes/Apple Music automatycznie importuje je do biblioteki.

---

## 🔧 Rozwiązywanie problemów

### "No supported JavaScript runtime could be found"
YouTube wymaga teraz środowiska JS do pełnej ekstrakcji formatów. Zainstaluj:

```powershell
# Opcja A: Deno (zalecane przez yt-dlp, lekkie)
winget install deno

# Opcja B: Node.js
winget install OpenJS.NodeJS
```

Po instalacji zrestartuj terminal.

### "Requested format is not available"
Skrypt ma wbudowany **3-stopniowy fallback**:
1. Twoje zapisane flagi (np. `-f bestaudio`)
2. `-f bestaudio/best` — pobiera combined stream, jeśli czysty audio nie istnieje
3. `-f best` — pobiera najlepszy dostępny stream

Jeśli wszystkie 3 zawiodą, URL jest pomijany i skrypt przechodzi do następnego.

### "Your yt-dlp version is older than 90 days"
Zaktualizuj yt-dlp:
```powershell
yt-dlp -U
```

---

## 🛠️ Flagi domyślne (edytowalne)

Domyślne flagi w `config.json` / `options/default.txt`:
```
-f bestaudio --extract-audio --audio-format m4a --audio-quality 0 --embed-thumbnail --add-metadata --no-playlist
```

Możesz zmienić je w menu `settings` → `[6] Edit Download Flags`.

Przykłady innych presetów:
- **Wideo best quality:** `-f bestvideo*+bestaudio/best --merge-output-format mp4`
- **Wideo 1080p:** `-f "bestvideo[height<=1080]+bestaudio/best[height<=1080]" --merge-output-format mp4`
- **Wideo 4K:** `-f "bestvideo[height<=2160]+bestaudio/best[height<=2160]" --merge-output-format mp4`

---

## 📌 Wymagania

- Windows PowerShell 5.1 lub PowerShell 7+
- [yt-dlp](https://github.com/yt-dlp/yt-dlp) w PATH
- (Zalecane) [Deno](https://deno.com/) lub Node.js dla pełnej kompatybilności YouTube

---

## 📝 Licencja

Do wolnego użytku. Modyfikuj i rozbudowuj wedle uznania — kod jest modularny, każda funkcja to osobny blok, który można łatwo rozszerzyć.
