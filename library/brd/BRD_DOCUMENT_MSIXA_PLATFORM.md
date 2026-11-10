# 📄 BUSINESS REQUIREMENTS DOCUMENT (BRD)
## Project Name: Msixa Music Streaming & Community Ecosystem
- **System Architecture:** Dual-APK Distributed Platform (`com.msixa.msixa_player` & `com.msixa.admin`)
- **Current Production Version:** `v1.0.72` (Build Code: `72`)
- **Document Version:** 3.0 (Master Release Specification)
- **Document Owner:** Antigravity AI Engineering & Architecture Team
- **Approval Status:** Production Verified & Live
- **Last Updated:** November 2026

---

## 1. Executive Summary & Vision Statement

### 1.1 Vision
Msixa is an ad-free, 100% free Indian music streaming and community-driven audio distribution ecosystem. It solves the fragmentation and aggressive paywalls of modern commercial music apps by providing:
1. **Instant, Zero-Cost High-Fidelity Audio**: 438+ curated master-quality Indian and regional tracks (Rajasthani, Bhakti, Sufi, Punjabi, Bollywood, Haryanvi, DJ Remix, Ghazal, Lo-Fi) hosted on Cloudflare R2 Edge CDN with guaranteed zero-buffering playback.
2. **Verified Community Uploads**: Any registered listener can contribute independent tracks, safeguarded by real-time duplicate detection algorithms.
3. **Rigorous Administrative Moderation**: Zero unverified content reaches users. A separate, dedicated Admin application enforces platform standards, audio quality checks, and real-time user directory visibility.
4. **Viral Offline Distribution & OTA Engine**: Native, link-free APK file sharing enables viral peer-to-peer distribution across rural and low-bandwidth environments via WhatsApp, Bluetooth, and Nearby Share, supplemented by an in-app chunked OTA update installer.

---

## 2. Business Objectives & Success Metrics (KPIs)

| Objective | Target Metric | Business Impact |
| :--- | :--- | :--- |
| **Zero Paywall Barrier** | 100% free access to all bundled & cloud audio | Maximizes listener retention and rapid app adoption. |
| **Clean User Identity** | 100% verified phone & email accounts | Eliminates bot accounts, spam uploads, and malicious content. |
| **Audio Quality Control** | 0% unmoderated uploads live on platform | Admin approval gate ensures only high-fidelity music is published. |
| **Duplicate Prevention** | < 1s instant duplicate matching & redirect | Saves cloud storage bandwidth and prevents catalog clutter. |
| **60 FPS Scrolling** | 0% UI lag or audio hitching during playback | StreamBuilder decoupling isolates progress ticks from tree renders. |
| **Viral Direct Sharing** | 1-tap APK installation transfer | Enables direct user acquisition without requiring Google Play Store access. |
| **OTA Update Adoption** | Real-time version check on app foreground | Keeps user base synchronized with latest features and bug fixes. |

---

## 3. Dual-Application Ecosystem Architecture

```mermaid
graph TD
    subgraph "Public Distribution Channel"
        UAPK["🎵 Msixa Player (User APK)<br/><code>com.msixa.msixa_player</code>"]
    end

    subgraph "Internal Operations Channel"
        AAPK["⚙️ Msixa Admin (Admin APK)<br/><code>com.msixa.admin</code> (PIN: 7777)"]
    end

    subgraph "Cloudflare R2 Edge CDN (Bucket: msixa-music)"
        CDN["🌐 High-Speed Edge CDN<br/><code>pub-d4f2e58dc2594d0c8dc1f30bbae4344f.r2.dev</code>"]
        SONGS["📄 db/songs.json (438 Songs)"]
        USERS["📄 db/users.json"]
        V_USER["🚀 update/version.json (v72)"]
        V_ADMIN["🚀 update/admin_version.json (v72)"]
        APKS["📦 msixa_player_latest.apk<br/>📦 msixa_admin_latest.apk"]
    end

    UAPK -->|Fetch Songs & Playback| CDN
    UAPK -->|User Registration & Auth| CDN
    UAPK -->|Check OTA Updates| V_USER
    AAPK -->|PIN 7777 Super Admin Auth| CDN
    AAPK -->|Song Curation, Approval, Purge| CDN
    AAPK -->|User Directory CRM (Call/WA/Email)| CDN
    AAPK -->|Check OTA Updates| V_ADMIN
    CDN --> SONGS
    CDN --> USERS
    CDN --> APKS
```

---

## 4. User Personas

### 4.1 Persona 1: The Devotional & Regional Music Lover (Aman, 28)
- **Goal:** Wants to listen to Hanuman Chalisa, Satinder Sartaaj Sufi songs, and Rajasthani folk music without paying monthly subscriptions or enduring annoying ads.
- **Pain Point:** Commercial streaming platforms lock master quality audio behind paywalls and constantly interrupt playback with loud ads.
- **Msixa Solution:** Zero-cost access, 5-band studio equalizer, sleep timer, offline playback fallback, and AI-generated artwork.

### 4.2 Persona 2: The Community Contributor / Indie Artist (Pooja, 22)
- **Goal:** Wants to share original devotional covers and independent songs with an appreciative Indian audience.
- **Pain Point:** Commercial distributors charge high upfront fees and take weeks to approve submissions.
- **Msixa Solution:** In-app upload screen, automatic duplicate checking, and rapid moderation queue in Msixa Admin.

### 4.3 Persona 3: Platform Super Administrator (Admin Rajesh)
- **Goal:** Complete operational visibility over platform songs, active users, storage metrics, and update distribution.
- **Msixa Solution:** Dedicated Admin APK protected by Master PIN (`7777`), responsive Cloudflare R2 storage monitor, in-app audio preview player, and one-tap user communication triggers.

---

## 5. Detailed Functional Requirements (FR)

### FR-01: Cloud-Synced Indian Master Library (438+ Songs)
- **Description:** System synchronizes 438 verified Indian songs across 11 genres from `db/songs.json` on Cloudflare R2 Edge CDN upon app launch.
- **Categories:** Bhakti, Rajasthani, Sufi, Punjabi, Bollywood, Haryanvi, DJ Remix, Ghazal, Lo-Fi, Desh Bhakti, Shiv Bhakti.
- **Offline Fallback:** If device is offline, bundled master recordings play immediately with zero network buffering.

### FR-02: Zero-OTP Mobile Authentication
- **Description:** User authentication uses 10-digit mobile number as User ID with a secure password (minimum 4 characters).
- **Duplicate Prevention:** If a mobile number is already registered, registration form displays guidance and automatically switches to Login mode with phone pre-filled.

### FR-03: Real-Time StreamBuilder Audio Engine (Anti-Lag Architecture)
- **Description:** Audio position ticks (`500ms`) are decoupled from global `notifyListeners()`.
- **Mechanism:** Progress bars, scrubbers, and duration indicators subscribe directly to `playerProvider.positionStream` via `StreamBuilder<Duration>`.
- **Result:** Scrolling remains 60 FPS buttery smooth during active music playback; zero GPU raster thrashing.

### FR-04: AI-Generated Photographic Dynamic Artwork
- **Description:** When track metadata has an empty cover or generic microphone icon, `AiArtworkService` dynamically resolves high-resolution genre photographic artwork based on track title and musical tags.

### FR-05: Real-Time Duplicate Song Detection & Instant Redirect
- **Description:** Before submitting an upload, client executes fuzzy matching on track title and artist against the entire database.
- **Action:** If match is found, upload halts, displays `[⚠️ गाना पहले से मौजूद है]`, and provides `[गाना अभी सुनें (Play Now)]` button.

### FR-06: Enterprise Admin Console (Master PIN: 7777)
- **Description:** Dedicated administrative application restricted by secure numeric PIN `7777`.
- **Capabilities:**
  - Real-time Cloudflare R2 storage monitor card with responsive layout and clean English/Hindi toggle.
  - Searchable user directory with instant CRM triggers (`📞 Call`, `💬 WhatsApp`, `✉️ Email`).
  - Pending song moderation center with audio preview player and 1-tap Approve/Reject.

### FR-07: In-App OTA Auto-Update System
- **Description:** Application checks remote manifest (`version.json` or `admin_version.json`) on launch.
- **Action:** Prompts with a glowing update banner and dialog, downloads chunked APK with progress bar, and triggers native Android PackageInstaller via `FileProvider`.

### FR-08: Peer-to-Peer Native APK Sharing
- **Description:** Clicking "Share APK" extracts the installed `base.apk` via `FileProvider` and shares the actual `.apk` file directly via WhatsApp, Bluetooth, or Nearby Share without web links.

---

## 6. Non-Functional Requirements (NFR)

| ID | Requirement Category | Specification |
| :--- | :--- | :--- |
| **NFR-01** | **Launch & Latency** | App cold launch < 1.2s; audio playback start < 300ms. |
| **NFR-02** | **Frame Rate** | Constant 60 FPS scrolling during active background audio playback. |
| **NFR-03** | **Network Architecture** | Zero-egress Cloudflare R2 object storage with global edge caching. |
| **NFR-04** | **Security** | Super Admin PIN gate; scoped URI file sharing via Android FileProvider. |
| **NFR-05** | **Android Compatibility** | Android 5.0 (API 21) through Android 14+ (API 34). |
| **NFR-06** | **UI/UX Aesthetics** | Obsidian Cyberpunk (`#090D16`), Cyan Neon (`#00E5FF`), Amber (`#FFB300`). |

---

## 7. Production Endpoints & Credentials Reference

- **Public CDN Base:** `https://pub-d4f2e58dc2594d0c8dc1f30bbae4344f.r2.dev`
- **Songs Catalog (438):** `https://pub-d4f2e58dc2594d0c8dc1f30bbae4344f.r2.dev/db/songs.json`
- **Users Directory:** `https://pub-d4f2e58dc2594d0c8dc1f30bbae4344f.r2.dev/db/users.json`
- **Player APK (v72):** `https://pub-d4f2e58dc2594d0c8dc1f30bbae4344f.r2.dev/update/msixa_player_latest.apk`
- **Admin APK (v72):** `https://pub-d4f2e58dc2594d0c8dc1f30bbae4344f.r2.dev/update/msixa_admin_latest.apk`
- **Admin Access PIN:** `7777`
- **Master Backup Zip:** `https://github.com/rajeshsainkdk-bot/msixa_player/raw/main/msixa.zip`
