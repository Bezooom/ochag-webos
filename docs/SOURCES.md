# Первоисточники

Кит ничего не содержит из чужих проектов: он только **ставит** их и знает неочевидные места.
Ниже — всё, что использовалось, с лицензиями и тем, что именно взято.

## Приложения, которые ставятся

| Проект | Что берём | Лицензия | Ссылка |
|---|---|---|---|
| **Hearth** | домашний экран (id `tld.my.customlauncher`), его же методы `Replace LG Home` и `TV input` | MIT | [rudra-avatar/Hearth](https://github.com/rudra-avatar/Hearth) |
| **LG Input Hook** | перехват кнопки Home, файл `/home/root/.config/lginputhook/keybinds.json` | MIT (для скриптовой части) | [Simon34545/lginputhook](https://github.com/Simon34545/lginputhook) |
| **OMP** | плеер по каталогу TorrServer (`com.spacesarmat.torrplayer`) | GPL-3.0 | [spacesarmat/omp](https://github.com/spacesarmat/omp) |
| **TorrServer MatriX** | бинарь `TorrServer` (Go, ARMv7), запускается демоном на `:8090` | GPL-3.0 | [YouROK/TorrServer](https://github.com/YouROK/TorrServer) |
| **torrserver-webos** | откуда кит берёт **упаковку** бинаря (его же `data.tar.gz`, без GUI) | MIT (обёртка) | [6ebeng/torrserver-webos](https://github.com/6ebeng/torrserver-webos) |
| **Homebrew Channel** | root, сервис `exec`/`install`, `init.d`, безопасные обновления | MIT | [webosbrew/webos-homebrew-channel](https://github.com/webosbrew/webos-homebrew-channel) |
| **safeupdate** | заморозка обновлений прошивки | MIT | [webosbrew/safeupdate](https://github.com/webosbrew/safeupdate) |
| **ad-free YouTube** | пакет `youtube.leanback.v4` из репозитория webosbrew | см. репозиторий | [repo.webosbrew.org](https://repo.webosbrew.org/) |
| **Life's Good Without Spying** | деблоат и отключение телеметрии (ставится отдельно, кит только проверяет) | см. проект | [webosbrew](https://repo.webosbrew.org/) |

## Откуда взяты приёмы

| Приём | Источник | Что пришлось выяснять самим |
|---|---|---|
| Запуск приложения при старте и подмена Home на скрипт | Hearth (`src/takeover/README.md`), [Glasshouse](https://github.com/rorygallagher2024/glasshouse) | свой сторож `85-home-watch`: Hearth отдаёт это только галочкой в Options |
| Установка ipk через HBC | [webosbrew](https://github.com/webosbrew/webos-homebrew-channel) | установщик берёт **только http(s)** и **голый sha256**, а по LAN читает ~1 КБ/с → локальный сервер на самом ТВ (`docs/TRAPS.md` §1–2) |
| Прямой запуск TorrServer | [6ebeng/torrserver-webos](https://github.com/6ebeng/torrserver-webos) | пакет не проходит проверку подписи на webOS 4.5, GUI-сервис не регистрируется без установки → демонизация бинаря (§6–7) |
| Ключ Developer Mode | [dev-manager-desktop](https://github.com/webosbrew/dev-manager-desktop), [ares-cli](https://webostv.developer.lge.com/develop/tools/cli-installation) | ключ лежит на `:9991/webos_rsa` и он **зашифрован паролем-кодом с экрана** (§4) |
| Список сторонних приложений | [webosappclub.github.io](https://webosappclub.github.io/) (сообщество) | — |

## Идеи и вдохновение

- [jakubkralka](https://x.com/jakubkralka/status/2112432879439651323) — «свой лаунчер вместо заводского экрана LG»;
- [cleanyour.tv](https://cleanyour.tv/) — идея деблоата без перепрошивки и «чужого» домашнего экрана;
- [partridgeworks/webos-launcher](https://github.com/partridgeworks/webos-launcher) — скелет webOS-приложения и список приложений (на нём вырос Hearth).

## Что в ките наше

- `lib/hbc.sh`: выбор транспорта по размеру пакета, подъём node-сервера на ТВ, обход кавычек в HBC exec, `hc_out` для разэкранирования ответа.
- `hooks/*`: шаблоны с параметрами и идемпотентная установка.
- `tools/torrserver-headless.sh`: извлечение бинаря из ar-пакета и жизненный цикл демона.
- `docs/TRAPS.md`: 12 воспроизводимых грабель прошивки.
- `tests/run.sh`: контрактные тесты без железа.

## Товарные знаки

LG, webOS, Homebrew Channel, TorrServer, OMP, Hearth — собственность их авторов.
Проект не связан с LG Electronics и не распространяет её файлы.
