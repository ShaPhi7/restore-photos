# restore_google_photos.ps1
# Processes Google Takeout ZIPs one by one, restores metadata, and re-zips output.

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Root folder (where ZIPs are located)
$root = Split-Path -Parent $MyInvocation.MyCommand.Definition
Write-Host "Working folder: $root"

# Find all ZIP files
$zips = Get-ChildItem -Path $root -Filter *.zip
Write-Host "Zips: $zips"

# Ensure $zips is always an array (works when there's 0, 1 or many)
$zips = @($zips)
if ($zips.Count -eq 0) {
    Write-Host "❌ No ZIP files found."
    exit
}

# Ensure exiftool is available
$exiftool = ".\exiftool.exe"
if (-not (Get-Command $exiftool -ErrorAction SilentlyContinue)) {
    Write-Host "❌ exiftool.exe not found in PATH. Please put it next to this script."
    exit
}

# Create output folder
$outRoot = Join-Path $root "Processed_Zips"
New-Item -ItemType Directory -Force -Path $outRoot | Out-Null

foreach ($zip in $zips) {
    Write-Host "`n>>> Processing $($zip.Name)..."

    # 1️⃣ Create a temporary extraction folder
    $tempDir = Join-Path $root ("temp_" + [IO.Path]::GetFileNameWithoutExtension($zip.Name))
    if (Test-Path $tempDir) { Remove-Item -Recurse -Force $tempDir }
    New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

    # 2️⃣ Extract the ZIP contents
    Write-Host "Extracting..."
    Expand-Archive -Path $zip.FullName -DestinationPath $tempDir -Force

    # 3️⃣ Recursively apply metadata using exiftool
    Write-Host "Restoring EXIF metadata (dates, GPS, description)..."
    & $exiftool -overwrite_original_in_place -r `
        "-DateTimeOriginal<PhotoTakenTimeTimestamp" `
        "-CreateDate<PhotoTakenTimeTimestamp" `
        "-ModifyDate<PhotoTakenTimeTimestamp" `
        "-Description<Description" `
        "-GPSLatitude<GeoDataLatitude" `
        "-GPSLongitude<GeoDataLongitude" `
        "-GPSLatitudeRef<GeoDataLatitude" `
        "-GPSLongitudeRef<GeoDataLongitude" `
        "$tempDir"

    # 4️⃣ Compress back into a new ZIP
    $zipOut = Join-Path $outRoot ("processed_" + $zip.Name)
    Write-Host "Re-zipping to $zipOut ..."
    if (Test-Path $zipOut) { Remove-Item $zipOut -Force }
    Compress-Archive -Path (Join-Path $tempDir '*') -DestinationPath $zipOut

    # 5️⃣ Clean up
    Remove-Item -Recurse -Force $tempDir
    Write-Host "✅ Done with $($zip.Name)"
}

Write-Host "`n🎉 All archives processed! Ready for upload in: $outRoot"
