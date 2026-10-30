# RU-медиа на webOS: id приложений и что из этого ставится

ID нужны для `keybinds.json`, списков исключений и скриптов. Здесь только идентификаторы
и источники — ни плейлистов, ни ключей, ни ссылок на контент.

## Стриминг (LG Content Store, RU-регион)

| ID | Приложение |
|---|---|
| `com.685631.3411` | Кинопоиск |
| `ivi` | Иви |
| `ru.rt.video.app.tv` | Wink |
| `yota.play` | Okko |
| `tntwebapp` | PREMIER |
| `start` | START |
| `rutube` | RUTUBE |
| `vkvideo` | VK Видео |
| `tv.lfstrm.smotreshka` | Смотрёшка |
| `ru.yandex.tvapp` | Яндекс |
| `channelone` | Первый |
| `com.huawei.app.webos.mts.tv.production` | КИОН / МТС |

## Инструменты, которые кит считает полезными

| ID | Что это |
|---|---|
| `youtube.leanback.v4` | ad-free YouTube (webosbrew) |
| `com.razagr.stremio` | Stremio (с Torrentio — каталог торрентов без своего сервера) |
| `de.benzac.msx` | Media Station X — свои плейлисты по HTTP |
| `tld.my.customlauncher` | Hearth, домашний экран |
| `com.spacesarmat.torrplayer` | OMP, плеер по каталогу TorrServer |
| `org.webosbrew.hbchannel`, `org.webosbrew.safeupdate`, `org.webosbrew.inputhook` | root, обновления, кнопка Home |

## Что на этой прошивке оказалось мусором

`com.webos.exampleapp.*` (11 штук), `com.webos.app.store-demo`, `com.webos.app.sync-demo`,
`com.webos.app.dangbei-*`, `com.lgshop.app79`, `airplay`, `com.webos.app.cmp-client`,
`com.webos.app.self-diagnosis`, `google.assistant`. Список получен из `listLaunchPoints`
на 43UN71006LB — на других моделях он другой, поэтому кит ничего не удаляет «по имени»,
а просто не показывает это в лаунчере.

## Внешние репозитории

- HBC-совместимый репозиторий Hearth: `https://raw.githubusercontent.com/rudra-avatar/Hearth/main/repo/apps.json`
- OMP: `https://raw.githubusercontent.com/spacesarmat/omp/gh-pages/apps.json`
- сообщество (сторонний): `https://webosappclub.github.io/` — Lampa, TorrServe MatriX, Xray CFG и др.
