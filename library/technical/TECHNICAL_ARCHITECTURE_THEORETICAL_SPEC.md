# 🛠️ TECHNICAL ARCHITECTURE & THEORETICAL REFERENCE SPECIFICATION
## System: Msixa Player & Msixa Admin Ecosystem
**Codebase Language:** Dart / Flutter (`>= 3.0.0`) & Kotlin (Android Native Layer)  
**Document Classification:** Engineering Design & QA Test Specification  
**Version:** 2.0 (Production Release)  
**Archive Location:** `library/technical/TECHNICAL_ARCHITECTURE_THEORETICAL_SPEC.md`  

---

## 1. System High-Level Architecture Diagram

```mermaid
graph TB
    subgraph "Flutter UI Presentation Layer"
        UI_USER["Msixa Player UI<br/>(Home, Library, Player, Upload, Equalizer)"]
        UI_ADMIN["Msixa Admin UI<br/>(PIN Barrier, Moderation, Directory, Analytics)"]
    end

    subgraph "State Controllers & Business Logic"
        PP["PlayerProvider (ChangeNotifier)<br/>Playback State, Queue, Local Audio"]
        CBS["CloudBackendService (ChangeNotifier Singleton)<br/>Auth, OTP, Moderation, Duplicate Engine"]
    end

    subgraph "Core Service Abstraction Layer"
        APS["AudioPlayerService<br/>(just_audio + audio_service)"]
        CS["CatalogService<br/>(17 Indian Master Tracks)"]
        SS["StorageService<br/>(SharedPreferences JSON Engine)"]
        DAS["DeviceAudioService<br/>(Offline Storage Scanner)"]
        ASS["AppShareService<br/>(MethodChannel Bridge)"]
    end

    subgraph "Native Android Subsystems (Kotlin & Gradle)"
        ACT["MainActivity : AudioServiceActivity<br/>com.msixa.msixa_player"]
        FP["androidx.core.content.FileProvider<br/>Authority: ${applicationId}.fileprovider"]
        INTENT["Android Intent System<br/>ACTION_SEND, MIME: application/vnd.android.package-archive"]
        MEDIA_SVC["AudioService (Foreground MediaBrowserService)<br/>Lockscreen & Notification Controls"]
    end

    UI_USER --> PP
    UI_USER --> CBS
    UI_ADMIN --> CBS

    PP --> APS
    PP --> CS
    PP --> SS
    PP --> DAS
    UI_USER --> ASS

    ASS -->|MethodChannel: com.msixa.player/app_share| ACT
    ACT -->|Extract base.apk -> Cache| FP
    FP --> INTENT
    APS --> MEDIA_SVC
```

---

## 2. Directory & Component Mapping

| Subdirectory | Core Files | Responsibility |
| :--- | :--- | :--- |
| `lib/models/` | `song.dart`, `user_profile.dart`, `playlist.dart`, `equalizer_preset.dart` | Immutable data structures, serialization (`toJson`/`fromJson`), and domain constraints. |
| `lib/services/` | `cloud_backend_service.dart`, `audio_player_service.dart`, `catalog_service.dart`, `app_share_service.dart`, `storage_service.dart`, `device_audio_service.dart` | Business logic, state synchronization, hardware abstraction, and audio decoding. |
| `lib/providers/` | `player_provider.dart` | Primary view-model orchestrating the audio queue, playback status, sleep timer, and equalizer curves. |
| `lib/screens/` | `home_screen.dart`, `upload_song_screen.dart`, `now_playing_screen.dart`, `search_screen.dart`, `library_screen.dart`, `equalizer_screen.dart` | User App views styled in obsidian dark theme. |
| `lib/screens/auth/` | `auth_screen.dart` | 3-stage user onboarding and OTP verification wizard. |
| `lib/screens/admin/` | `admin_dashboard_screen.dart` | Executive analytics, audio preview player, pending moderation, and user directory CRM. |
| `lib/` | `main.dart`, `main_admin.dart` | Entry points for User App and Admin App respectively. |
| `android/` | `AndroidManifest.xml`, `build.gradle`, `settings.gradle`, `file_paths.xml` | Native permissions, FileProvider registry, and Gradle dependency overrides. |
| `.github/workflows/` | `build_apk.yml` | Multi-target CI/CD compilation generating release APK artifacts. |

---

## 3. Deep Dive: State Management & Service Singletons

### 3.1 `CloudBackendService` Singleton Pattern
`CloudBackendService` acts as the simulated platform backend and central source of truth for both apps:
- **Instance Guarantee:** Implemented via a private constructor `CloudBackendService._internal()` and factory `CloudBackendService()`.
- **Reactivity:** Extends `ChangeNotifier`. Any modification (`approveSong`, `submitUserSong`, `completeVerification`) triggers `notifyListeners()`, causing all subscribed UI views to refresh automatically without page reloads.
- **Persistence Layer:** Uses `SharedPreferences` storing serialized JSON strings:
  - `msixa_current_user`: Active session profile.
  - `msixa_all_registered_users`: Full user directory array.
  - `msixa_community_songs`: All submitted, pending, and approved tracks.

### 3.2 User Registration & Verification State Machine

```mermaid
stateDiagram-v2
    [*] --> Unregistered: User launches User App
    Unregistered --> AuthScreen: Intercepted by UserAppRootView
    AuthScreen --> Stage1_UserInfo: Full Name, Email, Phone Number input
    Stage1_UserInfo --> Stage2_PhoneOtp: Send SMS OTP Triggered
    Stage2_PhoneOtp --> Stage3_EmailCode: 6-Digit Phone OTP Validated
    Stage3_EmailCode --> Stage2_PhoneOtp: Invalid OTP / Retry
    Stage3_EmailCode --> VerifiedActiveUser: 4-Digit Email Code Validated
    VerifiedActiveUser --> MainNavigationScreen: Session Persisted, Heartbeat Active
```

---

## 4. Deep Dive: Real-Time Duplicate Song Detection Algorithm

When an authenticated listener initiates a song upload in `UploadSongScreen`, the algorithm prevents catalog bloat and duplicate submissions.

### Theoretical Mathematical Formulation
Let the candidate track be defined as:
$$T_{new} = \{ \text{title}, \text{artist} \}$$
Let the combined song catalog be $C = C_{curated} \cup C_{community}$.

1. **Normalization Function $\mathcal{N}(s)$:**
   $$\mathcal{N}(s) = \text{trim}(\text{lowercase}(\text{regex\_replace}(s, [^\w\s], ""))) $$

2. **Matching Metric:**
   A match is flagged if:
   $$(\mathcal{N}(T_{new}.\text{title}) = \mathcal{N}(S.\text{title})) \lor \left(|\mathcal{N}(T_{new}.\text{title})| > 4 \land \mathcal{N}(S.\text{title}) \subset \mathcal{N}(T_{new}.\text{title})\right) \lor \left(|\mathcal{N}(S.\text{title})| > 4 \land \mathcal{N}(T_{new}.\text{title}) \subset \mathcal{N}(S.\text{title})\right)$$
   AND the artist name is either empty or shares a substring match:
   $$\mathcal{N}(T_{new}.\text{artist}) \subset \mathcal{N}(S.\text{artist}) \lor \mathcal{N}(S.\text{artist}) \subset \mathcal{N}(T_{new}.\text{artist})$$

3. **Runtime Execution Flow:**
   - If match found: Yields matched `Song` instance $\rightarrow$ UI presents dialog with direct play option $\rightarrow$ upload halted.
   - If no match found: Yields `null` $\rightarrow$ upload proceeds to Admin moderation queue.

---

## 5. Deep Dive: Native Direct APK File Sharing via FileProvider

### 5.1 The Android Security Sandbox Problem
Android prevents applications from exposing raw private filesystem paths (e.g., `file:///data/app/.../base.apk`) to external applications. Attempting to share such paths triggers a fatal `FileUriExposedException` on Android 7.0 (API 24) and above.

### 5.2 The Native Architectural Solution
Msixa implements a native `MethodChannel` bridging Flutter to Android's secure `FileProvider`:

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant Flutter as AppShareService (Dart)
    participant Platform as MethodChannel (com.msixa.player/app_share)
    participant Kotlin as MainActivity.kt
    participant Storage as Cache Storage (MsixaPlayer.apk)
    participant Provider as androidx.core.content.FileProvider
    participant Android as Android Sharesheet (WhatsApp, Bluetooth, Nearby)

    User->>Flutter: Tap "Share APK" Card
    Flutter->>Platform: invokeMethod('shareApk')
    Platform->>Kotlin: onMethodCall("shareApk")
    Kotlin->>Kotlin: Resolve applicationInfo.sourceDir
    Kotlin->>Storage: Stream copy sourceDir -> cacheDir/MsixaPlayer.apk
    Kotlin->>Provider: getUriForFile(this, "${packageName}.fileprovider", destApk)
    Provider-->>Kotlin: Returns content://com.msixa.msixa_player.fileprovider/apk_cache/MsixaPlayer.apk
    Kotlin->>Android: Intent(ACTION_SEND, MIME: application/vnd.android.package-archive)
    Android-->>User: Displays Native App Picker (WhatsApp, Bluetooth, Quick Share)
    Note over User,Android: Transmits real .apk installer file directly! Zero web links!
```

### 5.3 Configuration Files
1. **`android/app/src/main/res/xml/file_paths.xml`:**
   ```xml
   <paths xmlns:android="http://schemas.android.com/apk/res/android">
       <cache-path name="apk_cache" path="." />
       <external-cache-path name="ext_cache" path="." />
       <external-path name="ext_files" path="." />
   </paths>
   ```
2. **`AndroidManifest.xml` Provider Declaration:**
   ```xml
   <provider
       android:name="androidx.core.content.FileProvider"
       android:authorities="${applicationId}.fileprovider"
       android:exported="false"
       android:grantUriPermissions="true">
       <meta-data
           android:name="android.support.FILE_PROVIDER_PATHS"
           android:resource="@xml/file_paths" />
   </provider>
   ```

---

## 6. Deep Dive: Audio Engine, Equalizer & Foreground Media Service

### 6.1 Audio Playback Engine
Msixa uses `just_audio` coupled with `audio_service` running on an isolated background isolate:
- **Audio Formats Supported:** MP3 (MPEG-1 Audio Layer III), M4A (AAC-LC), WAV, OGG Vorbis.
- **Buffer Management:** Dynamic buffering with `bufferedPositionStream` emitting live progress to the seek bar.
- **Audio Routing:**
  - `assets/audio/...`: Read directly from compiled APK asset bundle via asset descriptor streams.
  - `/storage/emulated/0/...`: Read from device storage with read permissions.
  - `http://` / `https://`: Streamed via HTTP audio sink with background caching.

### 6.2 5-Band Graphic Equalizer Engine
The equalizer applies discrete frequency band gains ($-10.0\text{ dB}$ to $+10.0\text{ dB}$) across 5 standard center frequencies:
1. **Band 0 (60 Hz - Sub-Bass):** Controls sub-woofers, kick drums, and foundational bass depth.
2. **Band 1 (230 Hz - Low Mid/Bass):** Controls bass guitars, male vocal body, and warm acoustics.
3. **Band 2 (910 Hz - Midrange):** Controls vocal clarity, dholak/tabla pitch, and string instruments.
4. **Band 3 (3.6 kHz - High Mid):** Controls vocal presence, attack, and percussion snap.
5. **Band 4 (14 kHz - Treble/Air):** Controls cymbal sheen, atmosphere, and high-frequency sparkle.

---

## 7. Multi-Target CI/CD Build Pipeline

The GitHub Actions workflow (`.github/workflows/build_apk.yml`) compiles both production APK targets deterministically:

1. **Environment Setup:** Ubuntu latest, JDK 17, Flutter 3.22.x stable.
2. **Dependency Resolution:**
   Enforces Kotlin version `1.8.22` / `1.9.24` across all transitive dependencies in `android/app/build.gradle` and `android/build.gradle`:
   ```groovy
   configurations.all {
       exclude group: 'org.jetbrains.kotlin', module: 'kotlin-stdlib-jdk8'
       exclude group: 'org.jetbrains.kotlin', module: 'kotlin-stdlib-jdk7'
       resolutionStrategy.eachDependency { details ->
           if (details.requested.group == 'org.jetbrains.kotlin' && details.requested.name.startsWith('kotlin-stdlib')) {
               details.useVersion '1.8.22'
           }
       }
   }
   ```
3. **Target 1 Compilation (Msixa Player APK):**
   ```bash
   flutter build apk --release --no-tree-shake-icons
   cp build/app/outputs/flutter-apk/app-release.apk build/app/outputs/flutter-apk/msixa-player-release.apk
   ```
4. **Target 2 Compilation (Msixa Admin APK):**
   ```bash
   flutter build apk --release --target=lib/main_admin.dart --no-tree-shake-icons
   cp build/app/outputs/flutter-apk/app-release.apk build/app/outputs/flutter-apk/msixa-admin-release.apk
   ```
