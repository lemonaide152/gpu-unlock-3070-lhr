# Stage 2: replace BOOTX64.EFI (probe) with the unlock EFI. Does NOT format anything.
# Run AFTER PROFILE.BIN has been written to RTX-UNLOCK\ on the same stick.
# The independent-display unlock always stops and waits for the U key before it touches the GPU.
# (A DEBUG.ON file, used by other upstream builds, is ignored by this build.)
param(
  [Parameter(Mandatory=$true)][ValidatePattern('^[A-Za-z]:?$')][string]$DriveLetter
)
$ErrorActionPreference='Stop'
$letter = $DriveLetter.TrimEnd(':').ToUpper()
$root = "${letter}:\"
$disk = Get-Disk -Number (Get-Partition -DriveLetter $letter).DiskNumber
if ($disk.BusType -ne 'USB') { throw "REFUSED: not a USB volume" }
$unlock  = Join-Path $root 'STAGE\UNLOCK.EFI'
$boot    = Join-Path $root 'EFI\BOOT\BOOTX64.EFI'
$profile = Join-Path $root 'RTX-UNLOCK\PROFILE.BIN'
if (-not (Test-Path $unlock))  { throw "Missing $unlock" }
if (-not (Test-Path $profile)) { throw "Missing PROFILE.BIN; build it from the probe capture first" }
Copy-Item -Force $unlock $boot
$h = (Get-FileHash $boot -Algorithm SHA256).Hash.ToLower()
Write-Host "BOOTX64.EFI is now UNLOCK. SHA256: $h"
if ($h -ne 'd7c22f5cc393543441b8fb69cfbbf44475c16ad3320ebb5f50f5ebe41dff669a') { Write-Warning "Hash differs from the reference build." }
