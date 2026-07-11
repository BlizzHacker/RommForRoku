param(
    [string]$Output = "dist/RommForRoku-0.4.0.zip"
)

$projectRoot = Split-Path -Parent $PSScriptRoot
$archivePath = Join-Path $projectRoot $Output
$archiveDir = Split-Path -Parent $archivePath

New-Item -ItemType Directory -Force -Path $archiveDir | Out-Null
Remove-Item -Force -ErrorAction SilentlyContinue $archivePath
Compress-Archive -Path @(
    (Join-Path $projectRoot "manifest"),
    (Join-Path $projectRoot "source"),
    (Join-Path $projectRoot "components")
) -DestinationPath $archivePath -CompressionLevel Optimal

Write-Output "Created $archivePath"
