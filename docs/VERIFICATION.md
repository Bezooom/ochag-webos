# Верификация

## Стенд

| Параметр | Значение |
|---|---|
| Панель | LG **43UN71006LB** (2019), webOS **4.5.0** |
| Root | Homebrew Channel **0.6.3** (faultmanager-autoroot), `id -u` = `0` |
| SSH | dropbear на `9922`, пользователь `prisoner` |
| Компьютер | Ubuntu, `ssh`/`curl`/`node`/`python3` |
| Дата приёмки | 2026-10-30 |

Лишний раз подчёркиваем: **одна** панель, **одна** прошивка. Всё, что ниже — это не «работает везде»,
а «здесь и сейчас проверено командами из таблицы».

## Установленное и как проверялось

```text
$ luna-send-pub -n 1 luna://org.webosbrew.hbchannel.service/exec '{"command":"id -u"}'
{"returnValue":true,"stdoutString":"0\n",…}

$ ls /media/developer/apps/usr/palm/applications/
com.razagr.stremio  com.spacesarmat.torrplayer  ooo.lew.lifesgoodwithoutspying
org.webosbrew.hbchannel  org.webosbrew.inputhook  org.webosbrew.safeupdate
tld.my.customlauncher  youtube.leanback.v4

$ ls /var/lib/webosbrew/init.d/
50-lifesgoodwithoutspying  80-torrserver  85-home-watch  90-launcher  inputhook

$ luna-send -a webosbrew -n 1 luna://com.webos.applicationManager/getForegroundAppInfo '{}'
{"appId":"tld.my.customlauncher","returnValue":true,…}

$ curl -s http://<TV>:8090/echo
MatriX.142.2
$ curl -s -X POST -H 'Content-Type: application/json' -d '{"action":"list"}' http://<TV>:8090/torrents
[]
$ netstat -ltn | grep 8090
tcp   0   0 :::8090   :::*   LISTEN

$ cat /home/root/.config/lginputhook/keybinds.json
{"773":{"action":"launch","id":"tld.my.customlauncher"}}
$ tail -3 /tmp/lginput-hook-micomservice.log
[INFO] Keybinds reloaded due to config file change
```

## Хронология (что и почему заняло время)

1. **Установка через HBC.** Отправка `ipkUrl` локальным путём отвергнута (`Only absolute URLs`),
   `file://` — тоже. Хеш с префиксом `sha256:` отвергнут: установщик ждёт голый hex.
2. **Скорость.** Hearth 3.6 МБ по LAN-HTTP — ~400 с; OMP 488 КБ — ~600 с (≈0.8 КБ/с).
   `wget` с того же ТВ тот же файл отдаёт за <1 с → узкое место в установщике, не в сети.
   Решение: ipk кладётся в `/tmp` на ТВ и раздаётся node-сервером на `127.0.0.1:8081`.
3. **Dev Mode.** После истечения сессии: `Unknown method "install" for category "/dev"`;
   `ares-novacom --getkey` рапортует «Failed to get ssh private key», хотя настоящая причина —
   закрытое приложение Developer Mode. Ключ: `GET http://<TV>:9991/webos_rsa`,
   PEM зашифрован, пароль — 6-значный код с экрана.
4. **TorrServer.** Пакет не прошёл проверку подписи (`-5: ipk verified failed`) при совпавшем sha256;
   самодельный «тонкий» ipk (только `appinfo.json` + заглушка) — тоже.
   Итог: бинарь запущен демоном, автозапуск через `init.d`.
5. **Старый лаунчер.** Удалён вместе с хуками `90-freemytv` и генератором `91-fmtv-apps`;
   пакетная БД почистилась через `com.webos.appInstallService/remove`.

## Регрессионные тесты без телевизора

```text
$ make check && sh tests/run.sh
  PASS  90-launcher подставил id приложения
  PASS  90-launcher: плейсхолдеров не осталось
  PASS  80-torrserver подставил путь и порт
  PASS  ipk_hash = голый sha256
  PASS  маленький ipk → HTTP с компьютера
  PASS  большой ipk → сервер на самом ТВ
  PASS  keybinds.json разбирается и указывает на лаунчер
  PASS  sh -n install.sh … hooks/90-launcher
13 passed, 0 failed
```

Тесты проверяют то, что реально ломалось в живой сессии: форму хеша, выбор транспорта
и подстановку параметров в хуки. Сеть и ТВ в них не нужны — ssh подменён фейком.

## Проверка самого кита на живой панели

```text
$ TV=<TV> make verify
== root:        0
== init.d:      47-launcher-takeover 50-lifesgoodwithoutspying 80-torrserver 85-hearth-home-watch 90-hearth inputhook
== apps:        com.razagr.stremio com.spacesarmat.torrplayer ooo.lew.lifesgoodwithoutspying
                org.webosbrew.hbchannel org.webosbrew.inputhook org.webosbrew.safeupdate
                tld.my.customlauncher youtube.leanback.v4
== foreground:  youtube.leanback.v4
== torrserver:  MatriX.142.2
```

Два дефекта нашлись именно на этом прогоне и исправлены (см. TRAPS §11–12): `luna-send-pub`
без TTY молчит, а `getForegroundAppInfo` для `prisoner` закрыт — читаем через root-exec.

## Что не проверено

- webOS 3.x, 6.x, 7.x, 11: заявленных в Hearth сценариев не повторяли.
- Input Hook на других пультах: код `773` верен для тестового; при промахе ID берётся из
  `/tmp/lginput-hook-*.log` после нажатия кнопки.
- Прямое воспроизведение `OMP ↔ TorrServer`: адрес сервера вписывается на ТВ человеком,
  автоматической проверки нет.
