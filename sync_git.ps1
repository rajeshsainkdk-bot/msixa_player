$git = "C:\Users\rajes\AppData\Local\GitHubDesktop\app-3.6.10\resources\app\git\cmd\git.exe"
$repo = "C:\Users\rajes\OneDrive\Documents\GitHub\msixa_player"

& $git -C $repo add .
& $git -C $repo commit -m "feat: AI professional thumbnails, artists and albums in user panel, auto folder playlists, admin preview scrubber line"
& $git -C $repo push origin main
Write-Host "GIT_SYNC_COMPLETE"
