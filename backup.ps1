# Copies the Block Crazy game and its worlds from a tablet to this computer.
# Output appears next to the script: the apk folder (base.apk, split_config*.apk) and the worlds:
#   blockcrazy.ab - original game (adb backup, works on Android 11 or lower)
#   worlds.tar    - patched game (run-as, works on any Android, see PATCH.md)
# Run: powershell -ExecutionPolicy Bypass -File .\backup.ps1

$Pkg       = 'com.crazy.block.robo.monster.cliffs.craft'
$Dir       = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$Backup    = Join-Path $Dir 'blockcrazy.ab'
$WorldsTar = Join-Path $Dir 'worlds.tar'
$ApkDir    = Join-Path $Dir 'apk'
$Tmp       = '/data/local/tmp'

function Say($text, $color = 'Gray') { Write-Host $text -ForegroundColor $color }
function Pause-Enter($text) { Write-Host ''; Read-Host "$text  [Enter]" | Out-Null }
function Stop-Script($text) { Say $text Red; Pause-Enter 'Press'; exit 1 }

Say '=== Block Crazy backup ===' Cyan

# --- ADB ---
$AdbFile = Get-ChildItem $Dir -Recurse -Filter 'adb.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($AdbFile) { $Adb = $AdbFile.FullName } else {
    Say 'Downloading ADB (Android Platform-Tools) from Google...' Cyan
    $zip = Join-Path $Dir 'platform-tools.zip'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -UseBasicParsing 'https://dl.google.com/android/repository/platform-tools-latest-windows.zip' -OutFile $zip
    Expand-Archive -Force $zip $Dir
    Remove-Item $zip
    $Adb = Join-Path $Dir 'platform-tools\adb.exe'
    if (-not (Test-Path $Adb)) { Stop-Script 'Failed to download ADB.' }
}

# --- Connection ---
while ($true) {
    $lines = @(& $Adb devices | Select-Object -Skip 1 | Where-Object { $_.Trim() })
    if ($lines.Count -eq 1 -and $lines[0] -match '\sdevice$') { break }
    if ($lines.Count -gt 1) { Pause-Enter 'More than one device is connected. Leave only one tablet' }
    elseif ($lines -match 'unauthorized') { Pause-Enter 'On the tablet, tap "Allow USB debugging"' }
    else { Pause-Enter 'Tablet not found. Connect the cable and turn on USB debugging' }
}
Say "Connected: $((& $Adb shell getprop ro.product.model).Trim()), Android $((& $Adb shell getprop ro.build.version.release).Trim())" Green

$paths = @(& $Adb shell pm path $Pkg | Where-Object { $_ -like 'package:*' } | ForEach-Object { $_.Substring(8).Trim() })
if (-not $paths.Count) { Stop-Script 'Block Crazy is not installed on this tablet.' }

$patched = "$(& $Adb shell dumpsys package $Pkg | Select-String 'flags=\[' | Select-Object -First 1)" -match 'DEBUGGABLE'
if ($patched) { Say 'Patched game detected: worlds will be copied with run-as (works on any Android).' Green }
elseif ([int](& $Adb shell getprop ro.build.version.sdk).Trim() -ge 31) { Say 'Warning: Android 12 or newer. The worlds will most likely not be copied (see PATCH.md).' Yellow }

# --- Game ---
Say "`nCopying the game ($($paths.Count) file(s))..." Cyan
if (Test-Path $ApkDir) { Remove-Item $ApkDir -Recurse -Force }
New-Item -ItemType Directory $ApkDir | Out-Null
foreach ($p in $paths) { & $Adb pull $p $ApkDir | Out-Null }
Get-ChildItem $ApkDir | ForEach-Object { Say ("  {0}  {1:N0} MB" -f $_.Name, ($_.Length / 1MB)) }

# --- Worlds ---
if ($patched) {
    Say "`nCopying the worlds..." Cyan
    & $Adb shell am force-stop $Pkg
    & $Adb shell "run-as $Pkg tar -cf - games/com.mojang/minecraftWorlds > $Tmp/worlds.tar"
    & $Adb pull "$Tmp/worlds.tar" $WorldsTar | Out-Null
    & $Adb shell rm -f "$Tmp/worlds.tar"
    & $Adb kill-server | Out-Null
    $size  = if (Test-Path $WorldsTar) { (Get-Item $WorldsTar).Length } else { 0 }
    $count = if ($size) { @(& tar.exe -tf $WorldsTar | Where-Object { $_ -like '*/levelname.txt' }).Count } else { 0 }
    if (-not $count) { Stop-Script "`nWorlds were NOT copied." }
    Say ("`nDone: the game is in the apk folder, {0} worlds are in worlds.tar ({1:N0} MB)." -f $count, ($size / 1MB)) Green
} else {
    Say "`nCopying the worlds. On the tablet, tap ""Back up my data"" and do NOT enter a password." Yellow
    & $Adb backup -f $Backup -noapk $Pkg
    & $Adb kill-server | Out-Null
    $size = if (Test-Path $Backup) { (Get-Item $Backup).Length } else { 0 }
    if ($size -lt 1MB) {
        Say "`nWorlds were NOT copied (file is $([int]($size / 1KB)) KB)." Red
        Say "This happens on Android 12+: ADB can't transfer this game's worlds (see PATCH.md)." Yellow
        Say "Setup transfer, Smart Switch and Mi Mover don't transfer the game itself (it's not on Google Play)." Yellow
        Pause-Enter 'Press'
        exit 1
    }
    Say ("`nDone: the game is in the apk folder, the worlds are in blockcrazy.ab ({0:N0} MB)." -f ($size / 1MB)) Green
}
Say 'Keep this folder. To transfer to another tablet, run restore.ps1.' Green
Pause-Enter 'Press'
