#requires -RunAsAdministrator
<#
.SYNOPSIS
  Formats ONE removable USB as GPT FAT32 and copies the unlock package.
  Refuses any non-removable disk, any NVMe/SATA/SCSI disk, and any disk larger than 64 GiB.
  Does NOT touch C:, the Windows ESP, BCD, Secure Boot, BitLocker, or power limits.
#>
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
param(
  [Parameter(Mandatory=$true)][ValidatePattern('^[A-Za-z]:?$')][string]$DriveLetter,
  [string]$Source = (Join-Path $PSScriptRoot '..\..\usb-payload'),
  [int]$MaxSizeGiB = 64,
  [string]$VolumeLabel = 'GPUUNLOCK'
)

$ErrorActionPreference = 'Stop'
$letter = $DriveLetter.TrimEnd(':').ToUpper()
$Source = (Resolve-Path $Source).Path

if (-not (Test-Path (Join-Path $Source 'EFI\BOOT\BOOTX64.EFI'))) {
  throw "Source missing EFI\BOOT\BOOTX64.EFI: $Source"
}
if (-not (Test-Path (Join-Path $Source 'RTX-UNLOCK\ASSETS\gsp_ga10x.bin'))) {
  throw "Source missing firmware assets under RTX-UNLOCK\ASSETS"
}

$vol = Get-Volume -DriveLetter $letter -ErrorAction Stop
$part = Get-Partition -DriveLetter $letter -ErrorAction Stop
$disk = Get-Disk -Number $part.DiskNumber -ErrorAction Stop

Write-Host "Candidate:"
Write-Host ("  Disk {0}: {1}  Bus={2}  Style={3}  Size={4:N1} GiB  Removable={5}" -f `
  $disk.Number, $disk.FriendlyName, $disk.BusType, $disk.PartitionStyle, ($disk.Size/1GB), $disk.IsRemovable)
Write-Host ("  Volume {0}: Label='{1}' FS={2}" -f $letter, $vol.FileSystemLabel, $vol.FileSystem)

# Hard refuse list
if ($disk.BusType -in @('NVMe','SATA','SCSI','RAID','SAS','Fibre Channel','iSCSI')) {
  throw "REFUSED: BusType $($disk.BusType) is never a USB stick."
}
if (-not $disk.IsRemovable -and $disk.BusType -ne 'USB') {
  throw "REFUSED: disk is not removable and BusType is not USB."
}
if ($disk.BusType -ne 'USB') {
  throw "REFUSED: BusType must be USB (got $($disk.BusType))."
}
if ($disk.Size -gt ([uint64]$MaxSizeGiB * 1GB)) {
  throw "REFUSED: disk larger than $MaxSizeGiB GiB ($([math]::Round($disk.Size/1GB,1)) GiB)."
}
# Refuse if this disk hosts Windows or the ESP of the boot disk
$bootParts = Get-Partition | Where-Object { $_.IsBoot -or $_.IsSystem }
foreach ($bp in $bootParts) {
  if ($bp.DiskNumber -eq $disk.Number) {
    throw "REFUSED: this disk hosts a boot/system partition (Windows disk)."
  }
}

$confirm = Read-Host "Type the disk number $($disk.Number) to ERASE and load GPU unlock files"
if ($confirm -ne [string]$disk.Number) { throw "Aborted: confirmation mismatch." }

if ($PSCmdlet.ShouldProcess("Disk $($disk.Number) ($letter`:)", "Clear + GPT + FAT32 + copy package")) {
  # Clear and rebuild GPT with a single FAT32 partition spanning the stick
  Clear-Disk -Number $disk.Number -RemoveData -RemoveOEM -Confirm:$false
  Initialize-Disk -Number $disk.Number -PartitionStyle GPT -Confirm:$false
  # Microsoft Basic Data partition; leave a small MSR optional — skip MSR for simplicity
  $newPart = New-Partition -DiskNumber $disk.Number -UseMaximumSize -DriveLetter $letter
  Format-Volume -DriveLetter $letter -FileSystem FAT32 -NewFileSystemLabel $VolumeLabel -Confirm:$false | Out-Null

  $dest = "${letter}:\"
  Write-Host "Copying from $Source to $dest ..."
  # robocopy mirrors the package; /MIR would delete extras — use /E instead
  & robocopy $Source $dest /E /R:2 /W:2 /NFL /NDL /NJH /NJS /XD '.git' | Out-Null
  if ($LASTEXITCODE -ge 8) { throw "robocopy failed with code $LASTEXITCODE" }

  Write-Host "Done. Verify:"
  Get-ChildItem $dest -Recurse -File | Select-Object FullName, Length | Format-Table -AutoSize
  Write-Host "Boot entry name in firmware menu will typically be 'UEFI: <USB name>'."
  Write-Host "Stage 1 BOOTX64.EFI is the READ-ONLY probe. After capture, run Swap-ToUnlock.ps1."
}
