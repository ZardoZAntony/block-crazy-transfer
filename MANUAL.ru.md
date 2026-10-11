# Перенос миров Block Crazy вручную (без скрипта)

[English](MANUAL.md) | **Русский**

> ⚠️ **Важно до переноса.** Если на новом планшете Android 12 или новее, миры, которые ребёнок построит **после переноса**, потом уже нельзя будет перенести ни на какое другое устройство. Копия, сделанная на шаге 3, останется последней резервной копией.
>
> Исключение: на новом планшете есть **root**. Тогда миры можно будет скопировать из папки `/data/data/com.crazy.block.robo.monster.cliffs.craft/games/com.mojang/minecraftWorlds/` на другой планшет, тоже с root. Root нужно получить **до переноса**: при получении root планшет обычно стирает все данные.

Как определить, что инструкция для вашей игры, написано в [README](README.ru.md#1-подходит-ли-вам-эта-инструкция).

## 1. Что скачать

1. **Android Platform-Tools** (программа ADB) для Windows: https://dl.google.com/android/repository/platform-tools-latest-windows.zip
   Распакуйте архив в `C:\platform-tools`.
2. Нужен USB-кабель для планшета.

Все команды вводите в PowerShell. Перед этим перейдите в папку с ADB:
```powershell
cd C:\platform-tools
```

## 2. Включить отладку по USB (на обоих планшетах)

**Обычный Android:** откройте «Настройки → О планшете» и 7 раз нажмите на «Номер сборки». Затем «Настройки → Система → Для разработчиков» → включите **Отладка по USB**.

**Xiaomi:** откройте «Настройки → О планшете» и 7 раз нажмите на «Версия ОС». Затем «Настройки → Дополнительные настройки → Для разработчиков» → включите **Отладка по USB** и **Установка через USB**.

Подключите планшет. На экране появится запрос, нажмите «Разрешить». Проверьте подключение:
```powershell
.\adb.exe devices
```
Должно быть написано `device`.

## 3. Скопировать миры со старого планшета

```powershell
.\adb.exe backup -f blockcrazy.ab -noapk com.crazy.block.robo.monster.cliffs.craft
```
На планшете нажмите «Создать резервную копию данных». Пароль не вводите.

**Если `blockcrazy.ab` весит меньше 1 МБ**, миры не скопировались. Так бывает на Android 12+, и через ADB миры этой игры тогда не перенести. Встроенный перенос при настройке нового планшета и программы производителей (Smart Switch, Mi Mover) не переносят саму игру, потому что её больше нет в Google Play. Это проверено.

## 4. Скопировать игру со старого планшета

**Если у вас уже есть оба файла игры** (`base.apk` и `split_config.arm64_v8a.apk`), положите их в `C:\platform-tools` и переходите к шагу 5.

**Если файлов нет**, скопируйте их со старого планшета:
```powershell
.\adb.exe shell pm path com.crazy.block.robo.monster.cliffs.craft
```
Команда выведет две строки. Каждую скопируйте на компьютер, убрав `package:`:
```powershell
.\adb.exe pull /data/app/...../base.apk .
.\adb.exe pull /data/app/...../split_config.arm64_v8a.apk .
```

## 5. Установить игру на новый планшет

Отключите старый планшет и подключите новый.
```powershell
.\adb.exe install-multiple base.apk split_config.arm64_v8a.apk
```

**Если появляется ошибка `INSTALL_FAILED_USER_RESTRICTED` (бывает на Xiaomi):**

1. Скопируйте `base.apk` на планшет и установите его через файловый менеджер планшета.
2. Доустановите вторую часть:
```powershell
.\adb.exe push split_config.arm64_v8a.apk /data/local/tmp/split.apk
$size = (Get-Item split_config.arm64_v8a.apk).Length
$sid = [regex]::Match((.\adb.exe shell pm install-create -p com.crazy.block.robo.monster.cliffs.craft -S $size), '\[(\d+)\]').Groups[1].Value
.\adb.exe shell pm install-write -S $size $sid split /data/local/tmp/split.apk
.\adb.exe shell pm install-commit $sid
```

Проверьте результат: команда должна вывести две строки.
```powershell
.\adb.exe shell pm path com.crazy.block.robo.monster.cliffs.craft
```

Запустите игру один раз и закройте её.

## 6. Восстановить миры на новом планшете

```powershell
.\adb.exe shell am force-stop com.crazy.block.robo.monster.cliffs.craft
.\adb.exe restore blockcrazy.ab
```
На планшете нажмите «Восстановить данные». Пароль не вводите. Подождите 1–2 минуты.

⚠️ Все миры, которые уже есть на новом планшете, будут заменены.

## 7. Готово

Откройте игру и проверьте миры. После этого выключите «Отладку по USB» на обоих планшетах.
