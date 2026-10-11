# Patched game: access to worlds on any Android

**English** | [Русский](PATCH.ru.md)

The patched game has the `android:debuggable="true"` flag turned on. With it, `backup.ps1` and `restore.ps1` work on any Android version without root.

> The patched files are made from **your own** copy of the game. Don't share them publicly.

## 1. Patched files

**If you already have patched files** (`base.apk`, `split_config.arm64_v8a.apk`) or you can get them from [here](https://drive.google.com/drive/folders/1G7Tl45IkjGQT30ODldq_qQex4rTGLMiI?usp=sharing) and go to [step 3](#3-install-the-patched-game).

**If you don't**, make them in step 2 from the original files (the `apk` folder from `backup.ps1`).

## 2. Patch the game

### What to download

1. **JDK 17**: `winget install Microsoft.OpenJDK.17`
2. **Android SDK command-line tools**: https://developer.android.com/studio#command-line-tools-only. Unzip to `C:\Android\sdk\cmdline-tools\latest`.
3. **apktool**: https://github.com/iBotPeaches/Apktool/releases. Save as `C:\Android\apktool.jar`.

Install build-tools:
```powershell
$env:JAVA_HOME = (Get-ChildItem 'C:\Program Files\Microsoft' -Directory -Filter 'jdk-17*')[0].FullName
C:\Android\sdk\cmdline-tools\latest\bin\sdkmanager.bat --sdk_root=C:\Android\sdk --licenses
C:\Android\sdk\cmdline-tools\latest\bin\sdkmanager.bat --sdk_root=C:\Android\sdk "build-tools;36.0.0"
```

### Patch

Put the original `base.apk` and `split_config.arm64_v8a.apk` in `C:\Android\work` and run:
```powershell
cd C:\Android\work
$java = "$env:JAVA_HOME\bin\java.exe"
$bt = 'C:\Android\sdk\build-tools\36.0.0'

# 1. Unpack and turn on debuggable
& $java -jar C:\Android\apktool.jar d -s -f base.apk -o base
$m = "$PWD\base\AndroidManifest.xml"
[IO.File]::WriteAllText($m, ([IO.File]::ReadAllText($m) -replace '<application ', '<application android:debuggable="true" '))

# 2. Pack again
& $java -jar C:\Android\apktool.jar b base -o base-unsigned.apk

# 3. Create a key (once, remember the password)
& "$env:JAVA_HOME\bin\keytool.exe" -genkeypair -keystore blockcrazy-patch.jks -alias blockcrazy -keyalg RSA -keysize 2048 -validity 36500 -dname "CN=Block Crazy patch"

# 4. Align and sign BOTH files with the same key
mkdir patched
& "$bt\zipalign.exe" -f -p 4 base-unsigned.apk patched\base.apk
& "$bt\zipalign.exe" -f -p 4 split_config.arm64_v8a.apk patched\split_config.arm64_v8a.apk
& "$bt\apksigner.bat" sign --ks blockcrazy-patch.jks --ks-key-alias blockcrazy patched\base.apk
& "$bt\apksigner.bat" sign --ks blockcrazy-patch.jks --ks-key-alias blockcrazy patched\split_config.arm64_v8a.apk
```

The patched files are in `C:\Android\work\patched`.

⚠️ Keep `blockcrazy-patch.jks` and its password: without them the game can't be reinstalled over itself without losing the worlds.

## 3. Install the patched game

Put `restore.ps1`, the patched files and the worlds backup (`blockcrazy.ab` or `worlds.tar`) in one folder and run:
```powershell
powershell -ExecutionPolicy Bypass -File .\restore.ps1
```
If you see `Several copies of the game were found`, enter the number of the folder with the patched files.

## 4. Backups

Run `backup.ps1`: the worlds are saved to `worlds.tar`. Restore them with `restore.ps1`.
