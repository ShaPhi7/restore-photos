<#
.SYNOPSIS
    Move (cut) all non-.json files from subfolders of a directory into a single output folder.

.DESCRIPTION
    For the given source directory, finds all immediate subfolders and moves all files
    whose extension is not .json from those subfolders into the output folder.

    Options:
      -Recurse    : search files recursively inside each subfolder
      -DryRun     : show what would be moved without performing the move
      -Overwrite  : overwrite files in the output folder when collisions occur

.EXAMPLE
    # Dry-run, non-recursive
    .\flatten_nonjson.ps1 -SourceDir 'C:\Users\me\Pictures\Takeout' -OutDir 'C:\temp\out' -DryRun

    # Move recursively and overwrite collisions
    .\flatten_nonjson.ps1 -SourceDir 'C:\Users\me\Pictures\Takeout' -OutDir 'C:\temp\out' -Recurse -Overwrite

#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$false, Position=0)]
    [string]$SourceDir = (Get-Location).Path,

    [Parameter(Mandatory=$false, Position=1)]
    [string]$OutDir = '',

    [switch]$Recurse,
    [switch]$DryRun,
    [switch]$Overwrite
)

function Write-Log {
    param([string]$Message)
    $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    Write-Host "$ts`t$Message"
}

# Normalize paths
$SourceDir = Resolve-Path -LiteralPath $SourceDir -ErrorAction Stop | Select-Object -ExpandProperty Path
if ([string]::IsNullOrWhiteSpace($OutDir)) { $OutDir = Join-Path $SourceDir 'flattened' }
$OutDir = Resolve-Path -LiteralPath $OutDir -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Path 2>$null
if (-not $OutDir) { $OutDir = Join-Path (Resolve-Path $SourceDir) 'flattened' }

Write-Log "SourceDir: $SourceDir"
Write-Log "OutDir: $OutDir"
if ($DryRun) { Write-Log "DRY RUN: No files will be moved." }
if ($Recurse) { Write-Log "Mode: recursive" } else { Write-Log "Mode: non-recursive (only top-level files in each folder)" }

# Ensure source exists
if (-not (Test-Path -LiteralPath $SourceDir)) { throw "Source directory does not exist: $SourceDir" }

# Create output dir (unless dry-run)
if (-not (Test-Path -LiteralPath $OutDir)) {
    if ($DryRun) { Write-Log "Would create output directory: $OutDir" } else { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null; Write-Log "Created output directory: $OutDir" }
}

# Find immediate subfolders
$folders = Get-ChildItem -Path $SourceDir -Directory -Force
$folders = @($folders)  # ensure array
if ($folders.Count -eq 0) { Write-Log "No subfolders found in $SourceDir"; exit 0 }

$moveCount = 0
$skippedCount = 0

foreach ($folder in $folders) {
    Write-Log "Scanning folder: $($folder.Name)"
    if ($Recurse) {
        $files = Get-ChildItem -Path $folder.FullName -File -Recurse -Force -ErrorAction SilentlyContinue
    } else {
        $files = Get-ChildItem -Path $folder.FullName -File -Force -ErrorAction SilentlyContinue
    }

    if (-not $files) { continue }

    # Filter out .json files (case-insensitive)
    $files = $files | Where-Object { $_.Extension -ne '.json' }

    foreach ($file in $files) {
        $dest = Join-Path $OutDir $file.Name

        if ((Test-Path -LiteralPath $dest) -and -not $Overwrite) {
            # create a unique name
            $base = [IO.Path]::GetFileNameWithoutExtension($file.Name)
            $ext  = $file.Extension
            $i = 1
            do {
                $candidate = "{0}_{1}{2}" -f $base, $i, $ext
                $dest = Join-Path $OutDir $candidate
                $i++
            } while (Test-Path -LiteralPath $dest)
        }

        if ($DryRun) {
            Write-Log "Would move: $($file.FullName) -> $dest"
            $moveCount++
        } else {
            try {
                Move-Item -LiteralPath $file.FullName -Destination $dest -Force:$Overwrite
                Write-Log "Moved: $($file.FullName) -> $dest"
                $moveCount++
            } catch {
                Write-Log "ERROR moving $($file.FullName): $($_.Exception.Message)"
                $skippedCount++
            }
        }
    }
}

Write-Log "Done. Files moved: $moveCount. Skipped/failed: $skippedCount." 

return @{Moved=$moveCount; Skipped=$skippedCount}
