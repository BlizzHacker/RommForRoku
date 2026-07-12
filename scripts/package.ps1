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

# Roku (Linux) requires forward-slash paths with manifest/source/components at
# the archive root. PowerShell's Compress-Archive writes backslash separators,
# which Roku rejects with "Script directory /source does not exist". Use
# .NET ZipFile, which writes forward slashes, and add entries at the root.
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::Open($archivePath, 'Create')
try {
    foreach ($item in @('manifest', 'source', 'components')) {
        $full = Join-Path $projectRoot $item
        if (Test-Path $full -PathType Leaf) {
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $full, $item) | Out-Null
        } else {
            $base = (Resolve-Path $full).Path
            Get-ChildItem $full -Recurse -File | ForEach-Object {
                $rel = $_.FullName.Substring($base.Length + 1).Replace('\', '/')
                $entry = "$item/$rel"
                [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $_.FullName, $entry) | Out-Null
            }
        }
    }
} finally {
    $zip.Dispose()
}

Write-Output "Created $archivePath"
