# Installs the Block Crazy game and restores its worlds on a tablet from existing files.
# Put next to the script (subfolders are fine): base.apk, split_config*.apk and a worlds backup:
#   blockcrazy.ab - from backup.ps1 on the original game (adb backup)
#   worlds.tar    - from backup.ps1 on the patched game (run-as)
# Original game on the tablet: only blockcrazy.ab can be restored (adb restore).
# Patched game on the tablet (see PATCH.md): both files can be restored (run-as).
# Run: powershell -ExecutionPolicy Bypass -File .\restore.ps1

$Pkg = 'com.crazy.block.robo.monster.cliffs.craft'
$Dir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$Tmp = '/data/local/tmp'

function Say($text, $color = 'Gray') { Write-Host $text -ForegroundColor $color }
function Pause-Enter($text) { Write-Host ''; Read-Host "$text  [Enter]" | Out-Null }
function Stop-Script($text) { Say $text Red; Pause-Enter 'Press'; exit 1 }

function Convert-AbToTar($ab, $tarPath) {
    # Unpacks the worlds from an unencrypted .ab backup into a tar with games/com.mojang/minecraftWorlds
    $root = Join-Path $env:TEMP "blockcrazy-ab-$PID"
    if (Test-Path $root) { Remove-Item $root -Recurse -Force }
    $fs = [IO.File]::OpenRead($ab)
    try {
        $nl = 0; while ($nl -lt 4) { if ($fs.ReadByte() -eq 10) { $nl++ } }
        $null = $fs.ReadByte(); $null = $fs.ReadByte()
        $ds = New-Object IO.Compression.DeflateStream($fs, [IO.Compression.CompressionMode]::Decompress)
        $h = New-Object byte[] 512; $buf = New-Object byte[] 1048576
        $read = { param($b, $n) $o = 0; while ($o -lt $n) { $r = $ds.Read($b, $o, $n - $o); if ($r -le 0) { return $false }; $o += $r }; $true }
        $str = { param($b, $off, $len) [Text.Encoding]::UTF8.GetString($b, $off, $len).Split([char]0)[0] }
        $prefix = "apps/$Pkg/r/"
        while (& $read $h 512) {
            $name = & $str $h 0 100; if (-not $name) { break }
            $pre = & $str $h 345 155
            $full = if ($pre) { "$pre/$name" } else { $name }
            $size = [Convert]::ToInt64((& $str $h 124 12).Trim(), 8)
            $left = [long]([Math]::Ceiling($size / 512) * 512)
            $keep = $full.StartsWith($prefix + 'games/com.mojang/minecraftWorlds/') -and [char]$h[156] -eq '0'
            $w = $null
            if ($keep) {
                $dest = Join-Path $root ($full.Substring($prefix.Length) -replace '/', '\')
                New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null
                $w = [IO.File]::Create($dest)
            }
            $rest = $size
            while ($left -gt 0) {
                $r = $ds.Read($buf, 0, [Math]::Min($buf.Length, $left)); if ($r -le 0) { break }
                if ($w -and $rest -gt 0) { $take = [Math]::Min($r, $rest); $w.Write($buf, 0, $take); $rest -= $take }
                $left -= $r
            }
            if ($w) { $w.Close() }
        }
    } finally { $fs.Close() }
    if (-not (Test-Path (Join-Path $root 'games'))) { return $false }
    & tar.exe -cf $tarPath -C $root games
    Remove-Item $root -Recurse -Force
    return (Test-Path $tarPath)
}

# --- Find files ---
$Bases = @(Get-ChildItem $Dir -Recurse -Filter 'base.apk' -ErrorAction SilentlyContinue)
if (-not $Bases.Count) { Stop-Script "base.apk not found in $Dir" }
$Base = $Bases[0]
if ($Bases.Count -gt 1) {
    Say 'Several copies of the game were found:' Yellow
    for ($i = 0; $i -lt $Bases.Count; $i++) { Say "  $($i + 1) - $($Bases[$i].DirectoryName)" }
    $n = [int](Read-Host 'Which one to install? Enter the number') - 1
    if ($n -lt 0 -or $n -ge $Bases.Count) { Stop-Script 'Wrong number.' }
    $Base = $Bases[$n]
}
$Splits = @(Get-ChildItem $Base.DirectoryName -Filter 'split_config*.apk')

$Worlds = Get-ChildItem $Dir -Recurse -Include '*.ab', 'worlds.tar' -ErrorAction SilentlyContinue |
    Where-Object { $_.Length -ge 1MB } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $Worlds) { Stop-Script "Worlds backup (blockcrazy.ab or worlds.tar) not found in $Dir" }

Say '=== Block Crazy restore ===' Cyan
Say "Game:   $($Base.FullName)$(($Splits | ForEach-Object { ', ' + $_.Name }) -join '')"
Say ("Worlds: {0} ({1:N0} MB, {2:dd.MM.yyyy HH:mm})" -f $Worlds.FullName, ($Worlds.Length / 1MB), $Worlds.LastWriteTime)

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

function Get-InstalledApks {
    @(& $Adb shell pm path $Pkg | Where-Object { $_ -like 'package:*' })
}

# --- Install the game ---
$have = Get-InstalledApks
if ($have.Count -ge (1 + $Splits.Count)) {
    Say 'The game is already installed.' Green
} else {
    if (-not $have.Count) {
        Say "`nInstalling the game. If the tablet asks, tap ""Install""." Yellow
        $res = & $Adb install-multiple $Base.FullName @($Splits | ForEach-Object FullName)
        if ("$res" -notmatch 'Success') {
            Say "`nThe tablet blocked the USB install (this happens on Xiaomi)." Yellow
            & $Adb push $Base.FullName '/sdcard/Download/base.apk' | Out-Null
            Say 'base.apk has been copied to the Download folder on the tablet.' Yellow
            Say 'Open the file manager on the tablet, tap base.apk and install it.' Yellow
            do { Pause-Enter 'When it is installed' } while (-not (Get-InstalledApks).Count)
            & $Adb shell rm -f '/sdcard/Download/base.apk' | Out-Null
        }
    }
    if ((Get-InstalledApks).Count -lt (1 + $Splits.Count)) {
        # Add the missing parts to the installed game (works around the Xiaomi block)
        Say 'Installing the second part of the game...' Cyan
        $total = ($Splits | Measure-Object Length -Sum).Sum
        $out = & $Adb shell pm install-create -p $Pkg -S $total
        $sid = [regex]::Match("$out", '\[(\d+)\]').Groups[1].Value
        if (-not $sid) { Stop-Script 'Failed to start installing the second part of the game.' }
        $i = 0
        foreach ($f in $Splits) {
            & $Adb push $f.FullName "$Tmp/split$i.apk" | Out-Null
            & $Adb shell pm install-write -S $f.Length $sid "split$i" "$Tmp/split$i.apk" | Out-Null
            $i++
        }
        $res = & $Adb shell pm install-commit $sid
        & $Adb shell rm -f "$Tmp/split*.apk" | Out-Null
        if ("$res" -notmatch 'Success') { Stop-Script "Failed to install the second part of the game: $res" }
    }
    Say 'The game is installed.' Green
}

$patched = "$(& $Adb shell dumpsys package $Pkg | Select-String 'flags=\[' | Select-Object -First 1)" -match 'DEBUGGABLE'

# --- Restore the worlds ---
if ($patched) {
    Say "`nPatched game detected: restoring the worlds with run-as." Green
    $tar = $Worlds.FullName
    if ($Worlds.Extension -eq '.ab') {
        Say 'Unpacking the worlds from the .ab backup...' Cyan
        $tar = Join-Path $env:TEMP "blockcrazy-worlds-$PID.tar"
        if (-not (Convert-AbToTar $Worlds.FullName $tar)) { Stop-Script 'No worlds found in the .ab backup.' }
    }
    Say 'All worlds already on this tablet will be replaced. Keep the cable connected.' Yellow
    & $Adb shell am force-stop $Pkg
    & $Adb push $tar "$Tmp/worlds.tar" | Out-Null
    & $Adb shell "run-as $Pkg rm -rf games/com.mojang/minecraftWorlds"
    & $Adb shell "cat $Tmp/worlds.tar | run-as $Pkg tar -xf - -C /data/data/$Pkg"
    & $Adb shell rm -f "$Tmp/worlds.tar"
    if ($tar -ne $Worlds.FullName) { Remove-Item $tar }
    $count = @(& $Adb shell run-as $Pkg ls games/com.mojang/minecraftWorlds | Where-Object { $_.Trim() }).Count
    & $Adb kill-server | Out-Null
    if (-not $count) { Stop-Script 'Worlds were NOT restored.' }
    Say "`nDone! $count worlds restored. Open the game and check them." Green
} else {
    if ($Worlds.Extension -ne '.ab') {
        Stop-Script "worlds.tar can only be restored into the patched game (see PATCH.md). The game on this tablet is the original one."
    }
    Pause-Enter 'Open the game on the tablet ONCE, wait for the menu, then close it'
    Say "`nRestoring the worlds. All worlds already on this tablet will be replaced." Yellow
    Say 'On the tablet, tap "Restore my data" and do NOT enter a password. Keep the cable connected.' Yellow
    & $Adb shell am force-stop $Pkg
    & $Adb restore $Worlds.FullName
    Pause-Enter 'Wait until the restore screen on the tablet closes'
    & $Adb kill-server | Out-Null
    Say "`nDone! Open the game and check the worlds." Green
}
Say 'Then turn off USB debugging on the tablet.' Green
Pause-Enter 'Press'
