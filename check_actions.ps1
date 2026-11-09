$res = Invoke-RestMethod -Uri "https://api.github.com/repos/rajeshsainkdk-bot/msixa_player/actions/runs?per_page=5" -Headers @{"User-Agent"="PowerShell"}
foreach ($run in $res.workflow_runs) {
    Write-Host "Run #$($run.run_number) - Status: $($run.status) - Conclusion: $($run.conclusion) - Commit: $($run.head_commit.message) - Updated: $($run.updated_at)"
}
$v = Invoke-RestMethod -Uri "https://pub-d4f2e58dc2594d0c8dc1f30bbae4344f.r2.dev/update/version.json"
Write-Host "R2 Player version.json: $($v | ConvertTo-Json -Compress)"
$va = Invoke-RestMethod -Uri "https://pub-d4f2e58dc2594d0c8dc1f30bbae4344f.r2.dev/update/admin_version.json"
Write-Host "R2 Admin version.json: $($va | ConvertTo-Json -Compress)"
