# Copy the latest RTX30-PROBE\RUNxx capture off the USB to a local folder for analysis.
param(
  [Parameter(Mandatory=$true)][ValidatePattern('^[A-Za-z]:?$')][string]$DriveLetter,
  [string]$OutDir = (Join-Path (Get-Location) 'probe-capture')
)
$ErrorActionPreference='Stop'
$letter = $DriveLetter.TrimEnd(':').ToUpper()
$disk = Get-Disk -Number (Get-Partition -DriveLetter $letter).DiskNumber
if ($disk.BusType -ne 'USB') { throw "REFUSED: not a USB volume" }
$probe = Join-Path "${letter}:\" 'RTX30-PROBE'
if (-not (Test-Path $probe)) { throw "No RTX30-PROBE on ${letter}:" }
$run = Get-ChildItem $probe -Directory | Sort-Object Name -Descending | Select-Object -First 1
if (-not $run) { throw "No RUNxx directory under RTX30-PROBE" }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
Copy-Item -Recurse -Force $run.FullName (Join-Path $OutDir $run.Name)
Write-Host "Copied $($run.FullName) -> $(Join-Path $OutDir $run.Name)"
Get-ChildItem (Join-Path $OutDir $run.Name) | Format-Table Name, Length
