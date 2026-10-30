# ОЧАГ (ochag-webos) — тихий домашний экран и торрент-стек на телевизоре LG (webOS 4.x, root)

> **Серия «Матчасть»** — ответ на «на LG webOS ничего нельзя, только Android TV».
> Второй проект серии — **[ТАКТ](https://github.com/Bezooom/takt-rt)** (детерминированное ядро реального времени).
> Здесь та же дисциплина, но прикладная: не пересказ чужих README, а сценарии поверх грабель,
> которые апстримы не описывают.

**Проверено на живой панели: LG 43UN71006LB, webOS 4.5.0, HBC 0.6.3, root.**

![bash](https://img.shields.io/badge/shell-POSIX%20sh-blue)
![webos](https://img.shields.io/badge/webOS-4.x-informational)
![root](https://img.shields.io/badge/HBC-root-brightgreen)
![deps](https://img.shields.io/badge/deps-ssh%2Bcurl%2Bnode-lightgrey)
![debug](https://img.shields.io/badge/%D0%B1%D0%B5%D0%B7%20%D0%BE%D0%B1%D0%BB%D0%B0%D0%BA%D0%B0-%D0%BB%D0%BE%D0%BA%D0%B0%D0%BB%D1%8C%D0%BD%D0%BE-orange)
![MIT](https://img.shields.io/badge/license-MIT-yellow)

Набор сценариев, который превращает штатный LG-экран в тихую заставку с часами, погодой и рядом
своих приложений, ставит ad-free YouTube, поднимает **TorrServer MatriX** демоном на `:8090`
и подключает к нему плеер **OMP**. Ключевая часть — три неочевидных механизма установки
и управления, которых нет ни в одном из апстримов (см. [docs/TRAPS.md](docs/TRAPS.md)).

---

## Результаты (полный лог — в [docs/VERIFICATION.md](docs/VERIFICATION.md))

| Критерий | Доказательство | Вердикт |
|---|---|---|
| Root-доступ без Dev Mode | `hbchannel/exec → id -u` = `0` | PASS |
| Лаунчер при включении ТВ | хук `init.d/90-hearth`, `getForegroundAppInfo` = `tld.my.customlauncher` | PASS |
| Кнопка Home не уходит в LG | Input Hook: `keybinds.json` + `Keybinds reloaded due to config file change`; сторож LG Home в `init.d/85-hearth-home-watch` | PASS |
| Торренты на самом ТВ | `curl http://TV:8090/echo` → `MatriX.142.2`, `POST /torrents` → `[]`, `netstat` слушает `:::8090` | PASS |
| Автозапуск торрент-сервера | `init.d/80-torrserver`, бинарник `/media/developer/torrserver/TorrServer` | PASS |
| Плеер по каталогу торрентов | OMP `com.spacesarmat.torrplayer` установлен, в foreground | PASS |
| Чистота системы | список приложений без `io.freemytv`; хуки `90-freemytv`/`91-fmtv-apps` сняты | PASS |
| Установка больших ipk за минуты, а не часы | LAN-HTTP: 488 КБ ≈ 600 с; **TV-local HTTP**: 23 МБ скачаны и проверены за прогон установщика, а `wget` с того же ТВ – <1 с | PASS |
| Неподписанный ipk не ставится через HBC | `-5: ipk verified failed` при совпадающем sha256 → обход через headless-бинарь | PASS (ограничение зафиксировано) |

`make verify` на подключённом ТВ повторяет всю таблицу read-only.

## Мотивация

Апстримы решают **одну** задачу каждый: Hearth — экран, TorrServer — сервер, OMP — плеер,
Input Hook — кнопку. Пользователь остаётся с десятком «а ещё надо…»:

- установщик HBC принимает **только http(s)** и **голый sha256**, причём качает по ~1 КБ/с по LAN —
  отсюда невозможность поставить 23 МБ пакет иначе как локальным сервером **на самом ТВ**;
- неподписанные пакеты отваливаются на `ipk verified failed`, но их **бинарь работает как демон**;
- сессия Dev Mode истекает → `Unknown method "install" for category "/dev"`, а `ares-novacom --getkey`
  прячет настоящую причину;
- ключ Dev Mode — **зашифрованный PEM** на `:9991`, пароль к нему — 6-значный код с экрана.

Кит собирает это в идемпотентные шаги, а расхождения с апстримом вынесены в `docs/TRAPS.md`
с командами для воспроизведения.

## Быстрый старт

Требуется: root на ТВ (Homebrew Channel), SSH-доступ на `9922`, на компьютере `ssh`, `curl`, `node`.

```bash
git clone https://github.com/Bezooom/ochag-webos && cd ochag-webos
export TV=192.168.1.103 KEY=~/.ssh/lgtv_webos

make check                  # синтаксис + shellcheck, без телевизора
make hearth                 # Hearth + Input Hook + автозапуск + перехват Home
make torrserver             # TorrServer MatriX демоном на :8090
make omp                    # плеер OMP
make youtube                # ad-free YouTube
make verify                 # матрица приёмки по живому ТВ (read-only)
```

Каждый шаг идемпотентен: повтор ничего не ломает.

## Что остаётся человеку (API наружу нет)

| Где | Что нажать |
|---|---|
| Hearth → Settings → Options | `Add the launcher as a TV input`, `Replace LG Home with a helper script` |
| OMP → Настройки → сервер | `Найти в сети` (сервер на этом же ТВ) или `TV:8090` |
| Input Hook | проверить ID кнопки Home в логах, если биндинг `773` не сработал |

## Документация

| Файл | Содержание |
|---|---|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | как связаны лаунчер, перехват кнопки, торрент-демон и плеер; порядок init.d |
| [docs/TRAPS.md](docs/TRAPS.md) | 10 грабель webOS 4.x с командами воспроизведения |
| [docs/VERIFICATION.md](docs/VERIFICATION.md) | стенд, сырые выводы, хронология приёмки |
| [docs/RU-MEDIA.md](docs/RU-MEDIA.md) | id приложений RU-медиа и что из них оказалось мусором |
| [docs/SOURCES.md](docs/SOURCES.md) | **все первоисточники**: какой проект поставлен, что взято, лицензия |

## Честные ограничения

- Всё проверено на **одной** панели (43UN71006LB, webOS 4.5.0). webOS 3.x/6.x/11 — не проверялось;
  в Hearth поддержка этих версий заявлена, у нас — нет.
- Сценарии требуют root: без Homebrew Channel работает только установка через Dev Mode и только на 1000 часов.
- `TorrServer` ставится **не приложением**, а демоном: GUI-пакет не проходит проверку подписи на этой прошивке.
- Ничего не скачивается из p2p-сетей самим китом: он поднимает сервер и плеер, содержимое — на совести пользователя.

## Лицензии

Скрипты кита — MIT (© 2026 Pavel Naumov). Бинарники не распространяются: только ссылки на релизы
и их sha256. Полный список первоисточников, того, что взято из каждого, и лицензий —
[docs/SOURCES.md](docs/SOURCES.md).
