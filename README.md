# Msixa Player - Dark Premium Flutter Online MP3 Streaming Player

Msixa Player is a state-of-the-art Android music player application engineered in **Flutter**, built for streaming legal Creative Commons & Public Domain MP3 audio catalogs. Designed with an ultra-luxurious dark obsidian and neon aura theme, Msixa Player provides an immersive music listening experience.

---

## 🌟 Key Features

- **100% Legal Online MP3 Streaming**: Powered by the **Jamendo Free Music API** and a built-in curated catalog of Creative Commons (CC-BY, CC-BY-SA, CC0) and Public Domain audio streams. Strictly zero unauthorized YouTube-to-MP3 ripping or copyright violations.
- **Dark Premium Aesthetics**:
  - Obsidian & deep space background with neon cyan, radiant violet, and amber glow accents.
  - Frosted glassmorphism surfaces (`BackdropFilter`) with subtle border glows.
  - Interactive vinyl turntable disc with realistic vinyl grooves, spinning playback physics, and ambient backlight auras.
  - Dynamic equalizer bars visualizer with rhythm animations.
- **Audio Playback Engine**:
  - Gapless online MP3 streaming with buffered cache indicators.
  - Full playback controls: Play/Pause, Next/Previous, Shuffle, Repeat (Off, All, One).
  - Playback speed adjustment (`0.75x`, `1.0x`, `1.25x`, `1.5x`, `2.0x`).
  - Sleep timer with 15m, 30m, 45m, 60m countdown and auto-pause.
- **Sound FX & Equalizer**:
  - 5-Band Studio Graphic Equalizer (`60Hz`, `230Hz`, `910Hz`, `3.6kHz`, `14kHz`).
  - Presets: Flat, Bass Boost, Vocal Clarity, Electronic / EDM, Rock & Metal, Cyber Chill, Acoustic.
- **Persistent Mini-Player**:
  - Docked floating glassmorphism mini-player above the navigation bar with active track progress strip, album art, and instant controls.
- **Library & Search**:
  - Instant live search with genre filter chips.
  - Favorites with local persistence via `SharedPreferences`.
  - Recently played history.

---

## 📁 Project Architecture

```
msixa_player/
├── pubspec.yaml                       # Dependencies & Flutter asset definitions
├── README.md                          # Documentation and setup instructions
├── android/
│   └── app/
│       ├── build.gradle               # Android Gradle config (minSdkVersion 21)
│       └── src/main/
│           └── AndroidManifest.xml    # Permissions for audio streaming & foreground service
└── lib/
    ├── main.dart                      # App entry point with dark overlay config
    ├── models/
    │   ├── song.dart                  # Song model with CC attribution metadata
    │   ├── playlist.dart              # Playlist model
    │   └── equalizer_preset.dart      # 5-band sound curves & presets
    ├── services/
    │   ├── audio_player_service.dart  # Low-level audio engine (just_audio)
    │   ├── catalog_service.dart       # Jamendo REST API client & CC fallback catalog
    │   └── storage_service.dart       # Local persistence (favorites, recent, EQ)
    ├── providers/
    │   └── player_provider.dart       # ChangeNotifier state controller
    ├── theme/
    │   ├── app_colors.dart            # Obsidian & Neon dark theme palette
    │   └── app_theme.dart             # Outfit typography & dark Material 3 theme
    ├── widgets/
    │   ├── album_art_disc.dart        # Vinyl turntable disc with ambient glow
    │   ├── glowing_play_button.dart   # Dual-gradient glowing FAB
    │   ├── visualizer_bars.dart       # Animated frequency bar visualizer
    │   ├── song_list_tile.dart        # Track list row with CC license details
    │   ├── mini_player.dart           # Floating frosted glass mini player
    │   ├── genre_card.dart            # Gradient mood & genre cards
    │   └── sleep_timer_dialog.dart    # Modal sleep timer selector
    └── screens/
        ├── main_navigation_screen.dart # Root tab scaffold with persistent mini player
        ├── home_screen.dart           # Featured stream, genre carousel, trending tracks
        ├── search_screen.dart         # Live search bar with instant filter chips
        ├── library_screen.dart        # Favorites, Recently Played, and Playlists
        ├── now_playing_screen.dart    # Full-screen immersive player
        └── equalizer_screen.dart      # 5-band graphic equalizer & sound FX
```

---

## 🚀 Setup & Run Instructions

### 1. Prerequisites
- **Flutter SDK** (`>= 3.0.0`): Ensure Flutter is installed and added to your system `PATH`.
- **Android SDK & Emulator / Physical Device**: Android API level 21 or higher.

### 2. Install Dependencies
Open a terminal in the project directory:
```bash
cd C:\Users\rajes\.gemini\antigravity-ide\scratch\msixa_player
flutter pub get
```

### 3. Verify Android Permissions
The `AndroidManifest.xml` already includes the necessary permissions:
- `android.permission.INTERNET`
- `android.permission.ACCESS_NETWORK_STATE`
- `android.permission.WAKE_LOCK`
- `android.permission.FOREGROUND_SERVICE`
- `android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK`
- `android:usesCleartextTraffic="true"` (for HTTP audio CDN streams)

### 4. Build Android APK (.apk)

#### Option A: Cloud Build via GitHub Actions (Recommended - No local SDK setup needed)
A ready-to-run GitHub Actions workflow has been configured at [build_apk.yml](file:///c:/Users/rajes/.gemini/antigravity-ide/scratch/msixa_player/.github/workflows/build_apk.yml):
1. Push this folder to a GitHub repository.
2. In GitHub, go to the **Actions** tab. The build workflow will trigger automatically.
3. Once completed, download the **Msixa-Player-APK** artifact (`app-release.apk`) directly to your phone.

#### Option B: Build Locally on your PC
To build the `.apk` on your PC, you need Flutter SDK and Android SDK installed:
```bash
# 1. Fetch dependencies
flutter pub get

# 2. Build release APK
flutter build apk --release
```
Your compiled APK file will be located at:
```
build/app/outputs/flutter-apk/app-release.apk
```
Copy this file to your Android device and tap to install.

---

## ⚖️ Legal & Licensing Notice

All streaming tracks provided in Msixa Player are distributed under **Creative Commons Licenses** (CC-BY 4.0, CC-BY-SA, CC0 1.0) and public domain catalogs. Msixa Player does not download, scrape, or convert media from YouTube or any other unauthorized DRM-protected service.

