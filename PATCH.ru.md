# Пропатченная игра: доступ к мирам на любом Android

[English](PATCH.md) | **Русский**

В пропатченной игре включён флаг `android:debuggable="true"`. С ним `backup.ps1` и `restore.ps1` работают на любой версии Android без root.

## 1. Пропатченные файлы

**Если пропатченные файлы у вас уже есть** (`base.apk`, `split_config.arm64_v8a.apk`) или вы можете их взять [отсюда](https://drive.google.com/drive/folders/1G7Tl45IkjGQT30ODldq_qQex4rTGLMiI?usp=sharing), то переходите к [шагу 3](#3-установить-пропатченную-игру).

**Если нет**, сделайте их по шагу 2 из оригинальных файлов (папка `apk` после `backup.ps1`).

## 2. Пропатчить игру

### Что скачать

1. **JDK 17**: `winget install Microsoft.OpenJDK.17`
2. **Android SDK command-line tools**: https://developer.android.com/studio#command-line-tools-only. Распакуйте в `C:\Android\sdk\cmdline-tools\latest`.
3. **apktool**: https://github.com/iBotPeaches/Apktool/releases. Сохраните как `C:\Android\apktool.jar`.

Установите build-tools:
```powershell
$env:JAVA_HOME = (Get-ChildItem 'C:\Program Files\Microsoft' -Directory -Filter 'jdk-17*')[0].FullName
C:\Android\sdk\cmdline-tools\latest\bin\sdkmanager.bat --sdk_root=C:\Android\sdk --licenses
C:\Android\sdk\cmdline-tools\latest\bin\sdkmanager.bat --sdk_root=C:\Android\sdk "build-tools;36.0.0"
```

### Патч

Положите оригинальные `base.apk` и `split_config.arm64_v8a.apk` в `C:\Android\work` и выполните:
```powershell
cd C:\Android\work
$java = "$env:JAVA_HOME\bin\java.exe"
$bt = 'C:\Android\sdk\build-tools\36.0.0'

# 1. Распаковать и включить debuggable
& $java -jar C:\Android\apktool.jar d -s -f base.apk -o base
$m = "$PWD\base\AndroidManifest.xml"
[IO.File]::WriteAllText($m, ([IO.File]::ReadAllText($m) -replace '<application ', '<application android:debuggable="true" '))

# 2. Собрать обратно
& $java -jar C:\Android\apktool.jar b base -o base-unsigned.apk

# 3. Создать ключ (один раз, запомните пароль)
& "$env:JAVA_HOME\bin\keytool.exe" -genkeypair -keystore blockcrazy-patch.jks -alias blockcrazy -keyalg RSA -keysize 2048 -validity 36500 -dname "CN=Block Crazy patch"

# 4. Выровнять и подписать ОБА файла одним ключом
mkdir patched
& "$bt\zipalign.exe" -f -p 4 base-unsigned.apk patched\base.apk
& "$bt\zipalign.exe" -f -p 4 split_config.arm64_v8a.apk patched\split_config.arm64_v8a.apk
& "$bt\apksigner.bat" sign --ks blockcrazy-patch.jks --ks-key-alias blockcrazy patched\base.apk
& "$bt\apksigner.bat" sign --ks blockcrazy-patch.jks --ks-key-alias blockcrazy patched\split_config.arm64_v8a.apk
```

Пропатченные файлы появятся в `C:\Android\work\patched`.

⚠️ Сохраните `blockcrazy-patch.jks` и пароль: без них игру не переустановить поверх без потери миров.

## 3. Установить пропатченную игру

Положите в одну папку `restore.ps1`, пропатченные файлы и копию миров (`blockcrazy.ab` или `worlds.tar`) и запустите:
```powershell
powershell -ExecutionPolicy Bypass -File .\restore.ps1
```
Если появится `Several copies of the game were found`, введите номер папки с пропатченными файлами.

## 4. Резервные копии

Запускайте `backup.ps1`: миры сохранятся в `worlds.tar`. Восстановление через `restore.ps1`.
