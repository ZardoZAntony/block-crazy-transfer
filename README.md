# Transfer Block Crazy worlds to a new android device

**English** | [Русский](README.ru.md)

Worlds can only be copied from an old device on **Android 11 or lower**, or from a device that already has the **patched game** ([PATCH.md](PATCH.md)). The new device gets the patched game, so the worlds stay movable later.

## 1. Is this guide for you?

<img src="img/icon.png" width="96" alt="Block Crazy icon">

| | |
|---|---|
| App name on the device | **Block Crazy** |
| Package name | `com.crazy.block.robo.monster.cliffs.craft` |
| Google Play | [link](https://play.google.com/store/apps/details?id=com.crazy.block.robo.monster.cliffs.craft) (removed from the store) |

## 2. What to download

The scripts **[backup.ps1](backup.ps1)** and **[restore.ps1](restore.ps1)**: open each one and click **Download raw file** (⬇). Put both in one folder, for example `C:\BlockCrazy`. The scripts download ADB by themselves.

## 3. Turn on USB debugging (on both devices)

**Stock Android:** Settings → About tablet → tap "Build number" 7 times. Settings → System → Developer options → turn on **USB debugging**.

**Xiaomi:** Settings → About tablet → tap "OS version" 7 times. Settings → Additional settings → Developer options → turn on **USB debugging** and **Install via USB**.

When a line ends with `[Enter]`, do what it says and press Enter. While connecting:
* `Tablet not found...`: connect the cable and turn on USB debugging;
* `On the tablet, tap "Allow USB debugging"`: tap **Allow** on the device;
* `More than one device is connected...`: leave only one device connected.

## 4. Old device → backup.ps1

Connect the **old** device. Open PowerShell and run:
```powershell
cd C:\BlockCrazy
powershell -ExecutionPolicy Bypass -File .\backup.ps1
```
* Original game: at `tap "Back up my data"...` tap "Back up my data" on the device, leave the password empty. The worlds are saved to `blockcrazy.ab`.
* Patched game (`Patched game detected`): nothing to tap. The worlds are saved to `worlds.tar`.

The game is saved to the `apk` folder. If you see `Worlds were NOT copied`, the device runs Android 12+ with the original game, and its worlds can't be copied.

## 5. Patched game

Prepare the patched files with [PATCH.md](PATCH.md). Put them in a separate folder inside `C:\BlockCrazy`, for example `C:\BlockCrazy\patched`.

## 6. New device → restore.ps1

Connect the **new** device. It must not have the original game. Run:
```powershell
cd C:\BlockCrazy
powershell -ExecutionPolicy Bypass -File .\restore.ps1
```
1. `Several copies of the game were found`: enter the number of the `patched` folder.
2. `If the tablet asks, tap "Install"`: tap "Install" on the device.
3. `The tablet blocked the USB install` (happens on Xiaomi): open Downloads on the device, tap `base.apk`, install it and press Enter.
4. `Done!`: the worlds are transferred.

⚠️ Worlds already on the new device will be replaced.

## 7. Done

Open the game and check the worlds. Turn off USB debugging on both devices. To make a backup, run `backup.ps1` on the new device.
