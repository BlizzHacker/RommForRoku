param(
    [string]$Output
)

$projectRoot = Split-Path -Parent $PSScriptRoot

if (-not $Output) {
    $manifest = @{}
    foreach ($line in Get-Content (Join-Path $projectRoot "manifest")) {
        $key, $value = $line -split '=', 2
        $manifest[$key] = $value
    }
    $version = "$($manifest['major_version']).$($manifest['minor_version']).$($manifest['build_version'])"
    $Output = "dist/RommForRoku-$version.zip"
}

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
