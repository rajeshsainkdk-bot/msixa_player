$git = "C:\Users\rajes\AppData\Local\GitHubDesktop\app-3.6.10\resources\app\git\cmd\git.exe"
$repo = "C:\Users\rajes\OneDrive\Documents\GitHub\msixa_player"

& $git -C $repo add .
& $git -C $repo commit -m "fix: correct SongListTile parameters in album and artist detail screens to complete release build"
& $git -C $repo push origin main
Write-Host "GIT_SYNC_COMPLETE"
