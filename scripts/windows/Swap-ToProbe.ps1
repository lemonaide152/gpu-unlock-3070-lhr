# Put the read-only probe back as BOOTX64.EFI (e.g. to re-probe after a BIOS or cabling change).
param([Parameter(Mandatory=$true)][ValidatePattern('^[A-Za-z]:?$')][string]$DriveLetter)
$ErrorActionPreference='Stop'
$letter = $DriveLetter.TrimEnd(':').ToUpper()
$disk = Get-Disk -Number (Get-Partition -DriveLetter $letter).DiskNumber
if ($disk.BusType -ne 'USB') { throw "REFUSED: not a USB volume" }
Copy-Item -Force "${letter}:\STAGE\PROBE.EFI" "${letter}:\EFI\BOOT\BOOTX64.EFI"
Write-Host "BOOTX64.EFI is now the read-only PROBE."
