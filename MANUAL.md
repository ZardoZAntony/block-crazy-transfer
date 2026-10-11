# Transfer Block Crazy worlds by hand (no scripts)

**English** | [Русский](MANUAL.ru.md)

> ⚠️ **Read before transferring.** If the new tablet runs Android 12 or newer, worlds your child builds **after the transfer** can never be moved to another device. The backup made in step 3 will be your last backup.
>
> Exception: the new tablet has **root**. Then the worlds can be copied from `/data/data/com.crazy.block.robo.monster.cliffs.craft/games/com.mojang/minecraftWorlds/` to another rooted tablet. Root the tablet **before the transfer**: rooting usually wipes all data on the device.

To check that this guide fits your game, see the [README](README.md#1-is-this-guide-for-you).

## 1. What to download

1. **Android Platform-Tools** (ADB) for Windows: https://dl.google.com/android/repository/platform-tools-latest-windows.zip
   Unzip it to `C:\platform-tools`.
2. A USB cable for the tablet.

Run all commands in PowerShell. First go to the ADB folder:
```powershell
cd C:\platform-tools
```

## 2. Turn on USB debugging (on both tablets)

**Stock Android:** go to Settings → About tablet and tap "Build number" 7 times. Then go to Settings → System → Developer options and turn on **USB debugging**.

**Xiaomi:** go to Settings → About tablet and tap "OS version" 7 times. Then go to Settings → Additional settings → Developer options and turn on **USB debugging** and **Install via USB**.

Connect the tablet. It asks for permission: tap Allow. Check the connection:
```powershell
.\adb.exe devices
```
It should say `device`.

## 3. Copy the worlds from the old tablet

```powershell
.\adb.exe backup -f blockcrazy.ab -noapk com.crazy.block.robo.monster.cliffs.craft
```
On the tablet, tap "Back up my data". Leave the password empty.

**If `blockcrazy.ab` is smaller than 1 MB**, the worlds were not copied. This happens on Android 12+, and then ADB can't transfer this game's worlds. The built-in transfer during new tablet setup and vendor tools (Smart Switch, Mi Mover) don't transfer the game itself because it is no longer on Google Play. Tested.

## 4. Copy the game from the old tablet

**If you already have both game files** (`base.apk` and `split_config.arm64_v8a.apk`), put them in `C:\platform-tools` and go to step 5.

**If you don't**, copy them from the old tablet:
```powershell
.\adb.exe shell pm path com.crazy.block.robo.monster.cliffs.craft
```
The command prints two lines. Copy each file to the computer, without the `package:` prefix:
```powershell
.\adb.exe pull /data/app/...../base.apk .
.\adb.exe pull /data/app/...../split_config.arm64_v8a.apk .
```

## 5. Install the game on the new tablet

Disconnect the old tablet and connect the new one.
```powershell
.\adb.exe install-multiple base.apk split_config.arm64_v8a.apk
```

**If you get `INSTALL_FAILED_USER_RESTRICTED` (happens on Xiaomi):**

1. Copy `base.apk` to the tablet and install it with the tablet's file manager.
2. Add the second part:
```powershell
.\adb.exe push split_config.arm64_v8a.apk /data/local/tmp/split.apk
$size = (Get-Item split_config.arm64_v8a.apk).Length
$sid = [regex]::Match((.\adb.exe shell pm install-create -p com.crazy.block.robo.monster.cliffs.craft -S $size), '\[(\d+)\]').Groups[1].Value
.\adb.exe shell pm install-write -S $size $sid split /data/local/tmp/split.apk
.\adb.exe shell pm install-commit $sid
```

Check the result. The command should print two lines:
```powershell
.\adb.exe shell pm path com.crazy.block.robo.monster.cliffs.craft
```

Open the game once and close it.

## 6. Restore the worlds on the new tablet

```powershell
.\adb.exe shell am force-stop com.crazy.block.robo.monster.cliffs.craft
.\adb.exe restore blockcrazy.ab
```
On the tablet, tap "Restore my data". Leave the password empty. Wait 1–2 minutes.

⚠️ All worlds already on the new tablet will be replaced.

## 7. Done

Open the game and check the worlds. Then turn off USB debugging on both tablets.
