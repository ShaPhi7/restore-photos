# restore_google_photos_full.ps1
$workdir = "Restored_Photos"
New-Item -ItemType Directory -Force -Path $workdir | Out-Null

Write-Host ">>> Unzipping Takeout archives..."
Get-ChildItem -Filter *.zip | ForEach-Object {
    Write-Host "Unzipping $($_.Name)..."
    Expand-Archive -Path $_.FullName -DestinationPath $workdir -Force
}

Set-Location $workdir
Write-Host ">>> Restoring EXIF dates, location, and description..."

Get-ChildItem -Recurse -Filter *.json | ForEach-Object {
    $jsonPath = $_.FullName
    $photoPath = $jsonPath -replace '\.json$', ''
    if (Test-Path $photoPath) {
        $json = Get-Content $jsonPath | ConvertFrom-Json
        $ts   = $json.photoTakenTime.timestamp
        $desc = $json.description
        $lat  = $json.geoData.latitude
        $lon  = $json.geoData.longitude

        $cmd = @("-overwrite_original")

        if ($ts) {
            $cmd += "-DateTimeOriginal=$((Get-Date -UnixTimeSeconds $ts -Format 'yyyy:MM:dd HH:mm:ss'))"
            $cmd += "-CreateDate=$((Get-Date -UnixTimeSeconds $ts -Format 'yyyy:MM:dd HH:mm:ss'))"
            $cmd += "-ModifyDate=$((Get-Date -UnixTimeSeconds $ts -Format 'yyyy:MM:dd HH:mm:ss'))"
        }

        if ($lat -and $lon -ne 0) {
            $cmd += "-GPSLatitude=$lat"
            $cmd += "-GPSLongitude=$lon"
            $cmd += "-GPSLatitudeRef=$(if ($lat -ge 0) {'N'} else {'S'})"
            $cmd += "-GPSLongitudeRef=$(if ($lon -ge 0) {'E'} else {'W'})"
        }

        if ($desc) {
            $cmd += "-ImageDescription=$desc"
        }

        Write-Host "Updating: $photoPath"
        & exiftool @cmd "$photoPath" | Out-Null
    }
}

$delete = Read-Host "Delete JSON files now? (y/N)"
if ($delete -match "^[Yy]$") {
    Get-ChildItem -Recurse -Filter *.json | Remove-Item -Force
}

Write-Host ">>> Done! Photos ready in $workdir"
