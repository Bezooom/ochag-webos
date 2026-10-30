# Грабли webOS 4.x, которые не описаны в апстримах

Каждый пункт получен на живой LG (webOS 4.5.0, HBC 0.6.3). Команды – для воспроизведения.

## 1. Установщик Homebrew Channel принимает только http(s) и голый sha256

```
luna-send -a webosbrew -n 30 luna://org.webosbrew.hbchannel.service/install \
  '{"ipkUrl":"/tmp/app.ipk","ipkHash":"<sha>","subscribe":true}'
→ {"returnValue":false,"errorText":"Only absolute URLs are supported"}

luna-send … '{"ipkUrl":"http://…/app.ipk","ipkHash":"sha256:<sha>",…}'
→ {"returnValue":false,"errorText":"Invalid file checksum (sha256:<sha> expected, got <sha>"}
```

Итог: `ipkUrl` – **http/https**, `ipkHash` – **просто hex без префикса**. `file://` тоже отклоняется.

## 2. Установщик скачивает по 0.8–1 КБ/с, даже по LAN

Файл 488 КБ ехал ~10 минут, 3.6 МБ – ~7 минут. `wget` с того же ТВ качает те же файлы за <1 с. Лечится тем, что ipk кладётся на ТВ и отдаётся **локальным** сервером:

```sh
# на ТВ
node /tmp/srv.js          # http на 127.0.0.1:8081, корень /tmp
# и установка
luna-send -a webosbrew -n 100 luna://org.webosbrew.hbchannel.service/install \
  '{"ipkUrl":"http://127.0.0.1:8081/app.ipk","ipkHash":"<sha>","subscribe":true}'
```

Скорость становится обычной (десятки МБ/с). Кит `lib/hbc.sh` поднимает такой сервер сам.

## 3. `dev/install` отваливается, когда сессия Developer Mode истекла

```
{"returnValue":false,"errCode":-1,"errorText":"Unknown method \"install\" for category \"/dev\""}
```

При этом сам Dev Mode может выглядеть включённым. `ares-install` и `ares-novacom` падают с тем же сообщением, `ares-novacom --getkey` – с бесполезным «Failed to get ssh private key».

## 4. Ключ Dev Mode – зашифрованный PEM на `:9991`, пароль = 6-значный код с экрана

`ares-novacom --getkey` – это обычный `GET http://TV:9991/webos_rsa`. Файл начинается с `Proc-Type: 4,ENCRYPTED`, и `DEK-Info: AES-128-CBC`, то есть в `ssh-keygen -y -f` нужно вводить тот же код, что на экране Dev Mode. Ключ живёт, только пока открыто приложение Developer Mode.

## 5. Переустановка той же версии зависает в `ipk parsing`

События установки: `"downgrade":true`, дальше `state:"ipk parsing"` и тишина. Поднимайте `version` в `appinfo.json` или ставьте файлы напрямую (пункт 6).

## 6. Подмена файлов в `/media/developer/apps/...` работает только для уже зарегистрированных приложений

Распаковать `data.tar.gz` руками и положить в каталог приложения:

- **уже установленное** приложение – работает (`io.freemytv` так обновлялся, переживал ребут);
- **новое** приложение – `launch` отвечает `"not exist"`, сервисные методы (`com.torrserver.app.service`) – «Service does not exist». Регистрация ролей идёт от установщика, руками её не подделать.

Отсюда трюк для бинарников: не ставить приложение, а запускать его бинарь как демон (см. `tools/torrserver-headless.sh`).

## 7. Неподписанные ipk валятся на проверке

```
{"returnValue":false,"errorText":"-5: ipk verified failed"}
```

Даже когда размер и sha256 сходятся. HBC-путь устанавливает только то, что подписано его цепочкой; самодельный «тонкий» ipk (только `appinfo.json` + заглушка) тоже не пройдёт – подпись считается по архиву.

## 8. После подмены приложения на лету appMgr может перезагрузить TV

`cp -a` поверх работающего приложения уронил `dropbear` и ушёл в ребут. Не пугайтесь: файлы на диске сохраняются, root-хук вернётся. Проверять так: `nc -z $TV 9922`.

## 9. `luna-send` через HBC exec ломается на одинарных кавычках

Команда едет внутри `sh -c '…'`, поэтому `'…'` внутри JSON обрывают строку. Рабочий приём: писать скрипт в `/tmp` и запускать `sh /tmp/x.sh`; для JSON внутри скрипта – двойные кавычки с экранированием.

## 10. `pkill -f <app>` и мёртвая сессия

`getForegroundAppInfo` может показывать `appId` с пустым `processId`, а `ps` – не видеть процесс: приложение уже упало, а appMgr держит запись. Перед выводом «не работает» проверяйте `processId`.

## 11. `luna-send-pub` по SSH отвечает пустотой, если нет TTY

`ssh prisoner@TV "luna-send-pub -n 1 luna://… '{}'"` → пустой вывод, хотя код возврата 0.
С `ssh -tt` (или `-t`) ответ приходит. Киты идут через `tv_luna_ssh` с `-tt` явно.

## 12. Часть luna-методов закрыта для `prisoner`, даже когда root есть

```
luna-send-pub … getForegroundAppInfo → Denied method call "getForegroundAppInfo" for category "/"
```

Чтение переднего плана, `-a webosbrew`-вызовы и всё, что трогает систему, надо выполнять
через root-сессию HBC:

```sh
luna-send -a webosbrew -n 1 luna://com.webos.applicationManager/getForegroundAppInfo '{}'
```

Именно поэтому сторож кнопки Home (`hooks/85-home-watch`) запускается как root-хук, а не из `prisoner`.
