$ErrorActionPreference = "Stop"

$repo = "C:\Users\rajes\OneDrive\Documents\GitHub\msixa_player"
$staging = "$repo\temp_msixa_backup"
$msixaRoot = "$staging\msixa"
$zipPathRepo = "$repo\msixa.zip"
$zipPathArtifact = "C:\Users\rajes\.gemini\antigravity\brain\29cecb86-2313-4d4a-8d85-442899486999\msixa.zip"

Write-Host "1. Cleaning previous backup staging..."
if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
if (Test-Path $zipPathRepo) { Remove-Item $zipPathRepo -Force }

New-Item -ItemType Directory -Path "$msixaRoot\msixa_player" -Force | Out-Null
New-Item -ItemType Directory -Path "$msixaRoot\msixa_admin" -Force | Out-Null
New-Item -ItemType Directory -Path "$msixaRoot\documentation" -Force | Out-Null
New-Item -ItemType Directory -Path "$msixaRoot\scripts_and_ci_cd" -Force | Out-Null

$playerDir = "$msixaRoot\msixa_player"
$adminDir = "$msixaRoot\msixa_admin"
$docDir = "$msixaRoot\documentation"
$ciDir = "$msixaRoot\scripts_and_ci_cd"

Write-Host "2. Copying Player Codebase..."
Copy-Item "$repo\lib" -Destination "$playerDir\lib" -Recurse -Force
Copy-Item "$repo\android" -Destination "$playerDir\android" -Recurse -Force
Copy-Item "$repo\test" -Destination "$playerDir\test" -Recurse -Force
Copy-Item "$repo\pubspec.yaml" -Destination "$playerDir\pubspec.yaml" -Force
Copy-Item "$repo\README.md" -Destination "$playerDir\README.md" -Force
if (Test-Path "$repo\.gitignore") {
    Copy-Item "$repo\.gitignore" -Destination "$playerDir\.gitignore" -Force
}

Write-Host "3. Copying Admin Codebase..."
Copy-Item "$repo\lib" -Destination "$adminDir\lib" -Recurse -Force
Copy-Item "$repo\android" -Destination "$adminDir\android" -Recurse -Force
Copy-Item "$repo\test" -Destination "$adminDir\test" -Recurse -Force
Copy-Item "$repo\pubspec.yaml" -Destination "$adminDir\pubspec.yaml" -Force
if (Test-Path "$repo\.gitignore") {
    Copy-Item "$repo\.gitignore" -Destination "$adminDir\.gitignore" -Force
}

# In admin codebase, copy main_admin.dart to main.dart so running 'flutter run' opens admin dashboard directly
Copy-Item "$adminDir\lib\main_admin.dart" -Destination "$adminDir\lib\main.dart" -Force

# Set distinct Admin Package ID (com.msixa.admin) in Admin Android Manifest & Gradle
$adminManifest = "$adminDir\android\app\src\main\AndroidManifest.xml"
if (Test-Path $adminManifest) {
    $mContent = [System.IO.File]::ReadAllText($adminManifest)
    $mContent = $mContent.Replace('android:label="Msixa Player"', 'android:label="Msixa Admin"')
    [System.IO.File]::WriteAllText($adminManifest, $mContent)
}

$adminGradle = "$adminDir\android\app\build.gradle"
if (Test-Path $adminGradle) {
    $gContent = [System.IO.File]::ReadAllText($adminGradle)
    $gContent = $gContent.Replace('applicationId = "com.msixa.msixa_player"', 'applicationId = "com.msixa.admin"')
    $gContent = $gContent.Replace('applicationId "com.msixa.msixa_player"', 'applicationId "com.msixa.admin"')
    [System.IO.File]::WriteAllText($adminGradle, $gContent)
}

Write-Host "4. Copying and Organizing Master Documentation & BRD..."
Copy-Item "$repo\library\brd\BRD_DOCUMENT_MSIXA_PLATFORM.md" -Destination "$docDir\01_BUSINESS_REQUIREMENTS_DOCUMENT_BRD.md" -Force
Copy-Item "$repo\library\technical\TECHNICAL_ARCHITECTURE_THEORETICAL_SPEC.md" -Destination "$docDir\02_TECHNICAL_ARCHITECTURE_SPECIFICATION.md" -Force
Copy-Item "$repo\library\testing\TEST_CASES_AND_QA_CHECKLIST.md" -Destination "$docDir\03_TEST_CASES_AND_QA_CHECKLIST.md" -Force
Copy-Item "$repo\library\testing\AUTOMATED_TESTING_RELEASE_GATE.md" -Destination "$docDir\04_AUTOMATED_TESTING_RELEASE_GATE.md" -Force

Write-Host "5. Writing R2 Database, OTA Engine & Live Links Documentation..."
$r2Doc = @"
# ☁️ CLOUDFLARE R2 DATABASE & S3 API SPECIFICATION
**Bucket:** msixa-music
**Account ID:** 25622df2e6919b63cf30e7d06532d778
**Public CDN Base:** https://pub-d4f2e58dc2594d0c8dc1f30bbae4344f.r2.dev
**Access Key:** 2635fe3eb5b79a32c25e2d63428987d1
**Secret Key:** 161726a84f3c71439247ebce60580daefce9e5bc531b7e64bc6b65ee2366b1a1

## Database Files in Cloudflare R2
1. db/songs.json        - 438 verified Indian & regional songs (Rajasthani, Bhakti, Sufi, Punjabi, Bollywood, DJ Remix, Ghazal, etc.)
2. db/users.json        - Registered users directory with verified credentials
3. db/deleted_songs.json- Tombstone list of permanently purged song IDs
4. db/playlists.json    - Cloud-synced user playlists & community collections
5. update/version.json  - Live OTA update manifest for Msixa Player (Current: v72)
6. update/admin_version.json - Live OTA update manifest for Msixa Admin (Current: v72)
"@
[System.IO.File]::WriteAllText("$docDir\05_CLOUDFLARE_R2_DATABASE_AND_API_SPEC.md", $r2Doc)

$otaDoc = @"
# 📲 IN-APP OTA AUTO-UPDATE ENGINE SPECIFICATION
- Live Cloud Manifests:
  - User: https://pub-d4f2e58dc2594d0c8dc1f30bbae4344f.r2.dev/update/version.json
  - Admin: https://pub-d4f2e58dc2594d0c8dc1f30bbae4344f.r2.dev/update/admin_version.json
- Checks versionCode dynamically against remote manifest
- Prompts user with What's New dialog and top glowing update banner
- Downloads APK in chunks with live percentage progress bar
- Launches native Android PackageInstaller via FileProvider without requiring Google Play Store
"@
[System.IO.File]::WriteAllText("$docDir\06_OTA_AUTO_UPDATE_SYSTEM_SPEC.md", $otaDoc)

$liveLinks = @"
================================================================================
MSIXA ECOSYSTEM - PRODUCTION V72 LIVE DOWNLOAD LINKS
================================================================================

1. MSIXA PLAYER (USER MOBILE APP):
   - Direct APK: https://pub-d4f2e58dc2594d0c8dc1f30bbae4344f.r2.dev/update/msixa_player_latest.apk
   - Manifest:   https://pub-d4f2e58dc2594d0c8dc1f30bbae4344f.r2.dev/update/version.json
   - Version:    v1.0.72 (Code 72)
   - Size:       ~23.89 MB

2. MSIXA ADMIN (ADMINISTRATION CONSOLE):
   - Direct APK: https://pub-d4f2e58dc2594d0c8dc1f30bbae4344f.r2.dev/update/msixa_admin_latest.apk
   - Manifest:   https://pub-d4f2e58dc2594d0c8dc1f30bbae4344f.r2.dev/update/admin_version.json
   - Version:    v1.0.72 (Code 72)
   - Size:       ~23.38 MB
   - Master PIN: 7777

3. CLOUDFLARE R2 CDN ENDPOINTS:
   - Public CDN: https://pub-d4f2e58dc2594d0c8dc1f30bbae4344f.r2.dev
   - Songs DB:   https://pub-d4f2e58dc2594d0c8dc1f30bbae4344f.r2.dev/db/songs.json
   - Users DB:   https://pub-d4f2e58dc2594d0c8dc1f30bbae4344f.r2.dev/db/users.json
================================================================================
"@
[System.IO.File]::WriteAllText("$msixaRoot\LIVE_PRODUCTION_LINKS_V72.txt", $liveLinks)

$htmlDashboard = @"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Msixa Platform v72 - Direct APK Downloads</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      background: #090D16;
      color: #FFFFFF;
      margin: 0;
      padding: 40px 20px;
      display: flex;
      flex-direction: column;
      align-items: center;
    }
    .card {
      background: #131A2A;
      border: 1px solid rgba(0, 229, 255, 0.3);
      border-radius: 20px;
      padding: 30px;
      max-width: 580px;
      width: 100%;
      box-shadow: 0 10px 30px rgba(0,0,0,0.5);
      text-align: center;
    }
    h1 {
      color: #00E5FF;
      margin-top: 0;
      font-size: 26px;
    }
    p {
      color: #A0AEC0;
      font-size: 14px;
      line-height: 1.6;
    }
    .btn {
      display: block;
      padding: 14px 20px;
      margin: 14px 0;
      border-radius: 12px;
      text-decoration: none;
      font-weight: bold;
      font-size: 15px;
      transition: 0.2s all;
    }
    .btn-player {
      background: linear-gradient(135deg, #00E5FF, #4F46E5);
      color: #000;
      box-shadow: 0 4px 15px rgba(0, 229, 255, 0.3);
    }
    .btn-admin {
      background: linear-gradient(135deg, #FFB300, #FF6D00);
      color: #000;
      box-shadow: 0 4px 15px rgba(255, 179, 0, 0.3);
    }
    .btn:hover {
      transform: translateY(-2px);
      filter: brightness(1.1);
    }
    .badge {
      display: inline-block;
      background: rgba(255,255,255,0.1);
      padding: 4px 10px;
      border-radius: 8px;
      font-size: 12px;
      margin-bottom: 15px;
      color: #64DD17;
    }
    .links-box {
      background: rgba(0,0,0,0.3);
      border-radius: 10px;
      padding: 15px;
      margin-top: 20px;
      text-align: left;
      font-size: 12px;
      word-break: break-all;
    }
    .links-box a {
      color: #00E5FF;
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="badge">● PRODUCTION V72 LIVE EDGE CDN</div>
    <h1>🎵 Msixa Ecosystem - Direct Downloads</h1>
    <p>Click below to download the latest signed production APKs directly from Cloudflare R2 high-speed storage:</p>

    <a class="btn btn-player" href="https://pub-d4f2e58dc2594d0c8dc1f30bbae4344f.r2.dev/update/msixa_player_latest.apk" target="_blank">
      ⬇️ Download Msixa Player v72 APK (User App)
    </a>

    <a class="btn btn-admin" href="https://pub-d4f2e58dc2594d0c8dc1f30bbae4344f.r2.dev/update/msixa_admin_latest.apk" target="_blank">
      ⬇️ Download Msixa Admin v72 APK (Master PIN: 7777)
    </a>

    <div class="links-box">
      <strong>Cloudflare R2 Database Endpoints:</strong><br><br>
      • Player APK: <a href="https://pub-d4f2e58dc2594d0c8dc1f30bbae4344f.r2.dev/update/msixa_player_latest.apk">msixa_player_latest.apk</a><br>
      • Admin APK: <a href="https://pub-d4f2e58dc2594d0c8dc1f30bbae4344f.r2.dev/update/msixa_admin_latest.apk">msixa_admin_latest.apk</a><br>
      • Player Version Manifest: <a href="https://pub-d4f2e58dc2594d0c8dc1f30bbae4344f.r2.dev/update/version.json">version.json</a><br>
      • Admin Version Manifest: <a href="https://pub-d4f2e58dc2594d0c8dc1f30bbae4344f.r2.dev/update/admin_version.json">admin_version.json</a><br>
      • Cloud Songs (438): <a href="https://pub-d4f2e58dc2594d0c8dc1f30bbae4344f.r2.dev/db/songs.json">db/songs.json</a>
    </div>
  </div>
</body>
</html>
"@
[System.IO.File]::WriteAllText("$msixaRoot\DOWNLOAD_APKS_HERE.html", $htmlDashboard)

Write-Host "6. Copying CI/CD Automation & Build Scripts..."
Copy-Item "$repo\.github\workflows\build_apk.yml" -Destination "$ciDir\github_actions_workflow.yml" -Force
Copy-Item "$repo\check_actions.ps1" -Destination "$ciDir\check_actions.ps1" -Force
Copy-Item "$repo\sync_git.ps1" -Destination "$ciDir\sync_git.ps1" -Force

$readmeRoot = @"
# 🎵 MSIXA COMPLETE PLATFORM ARCHIVE (v72)

This archive contains the complete dual-app codebase, technical documentation, and Business Requirements Document (BRD) for the Msixa Music Ecosystem.

## Directory Layout:
- 📁 msixa_player/       -> Full User Player codebase & Android native layer
- 📁 msixa_admin/        -> Full Admin Console codebase & Android native layer (Master PIN: 7777)
- 📁 documentation/      -> Full BRD, Technical Architecture, R2 DB specs & QA checklists
- 📁 scripts_and_ci_cd/  -> GitHub Actions multi-target build pipeline & scripts
- 📄 LIVE_PRODUCTION_LINKS_V72.txt -> Direct Cloudflare R2 download links for v72 APKs
"@
[System.IO.File]::WriteAllText("$msixaRoot\README.md", $readmeRoot)

Write-Host "7. Compressing into msixa.zip..."
Compress-Archive -Path "$staging\msixa" -DestinationPath $zipPathRepo -CompressionLevel Optimal -Force

Write-Host "8. Copying msixa.zip to artifact directory..."
Copy-Item $zipPathRepo -Destination $zipPathArtifact -Force

Write-Host "9. Cleaning temporary staging folder..."
Remove-Item $staging -Recurse -Force

$zipSizeMb = [math]::Round((Get-Item $zipPathRepo).Length / 1MB, 2)
Write-Host "SUCCESS: msixa.zip generated cleanly! Size: $zipSizeMb MB"
