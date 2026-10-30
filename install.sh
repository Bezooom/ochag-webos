#!/bin/sh
# webos-ru-kit — установка лаунчера, торрент-стека и RU-медиа на root-нутый LG webOS 4.x.
#   TV=192.168.1.103 KEY=~/.ssh/lgtv_webos ./install.sh hearth|torrserver|omp|youtube|verify|all
# Идемпотентно: повторный запуск ничего не ломает.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/lib/hbc.sh"

HEARTH_ID=tld.my.customlauncher
HEARTH_IPK_URL=${HEARTH_IPK_URL:-$(latest_asset rudra-avatar/Hearth)}
INPUTHOOK_IPK_URL=${INPUTHOOK_IPK_URL:-$(latest_asset Simon34545/lginputhook)}
OMP_IPK_URL=${OMP_IPK_URL:-$(curl -fsSL https://api.github.com/repos/spacesarmat/omp/releases/latest |
  sed -n 's/.*"browser_download_url": *"\([^"]*webOS\.ipk\)".*/\1/p' | head -1)}

fetch() {  # fetch <url> <файл>
  [ -s "$2" ] && { log "уже скачано: $2"; return 0; }
  log "скачиваю $1"
  curl -fsSL -o "$2" "$1" || die "не скачалось: $1"
}

need_root() {
  _uid=$(hc_root)
  [ "$_uid" = 0 ] || die "нет root через HBC (id -u = '${_uid:-?}'); проверь nc -z $TV $SSH_PORT"
  log "root подтверждён"
}

do_hearth() {
  need_root
  fetch "$HEARTH_IPK_URL" "$HERE/cache/hearth.ipk"
  hc_install_ipk "$HERE/cache/hearth.ipk" "$HEARTH_ID" || die "Hearth"
  install_hook "$HERE/hooks/90-launcher"  90-launcher   "$HEARTH_ID"
  install_hook "$HERE/hooks/85-home-watch" 85-home-watch "$HEARTH_ID"

  fetch "$INPUTHOOK_IPK_URL" "$HERE/cache/inputhook.ipk"
  hc_install_ipk "$HERE/cache/inputhook.ipk" org.webosbrew.inputhook || log "Input Hook уже стоит"
  hc_luna luna://com.webos.applicationManager/launch "{\"id\":\"org.webosbrew.inputhook\"}" >/dev/null
  # Home → лаунчер. Код 773 верен для тестового пульта; иначе ID берётся из лога Input Hook.
  printf 'mkdir -p /home/root/.config/lginputhook\n' > /tmp/_kb.sh
  printf 'printf %%s %s > /home/root/.config/lginputhook/keybinds.json\n' \
    "'{\"${HOME_KEY:-773}\":{\"action\":\"launch\",\"id\":\"$HEARTH_ID\"}}'" >> /tmp/_kb.sh
  printf 'cat /home/root/.config/lginputhook/keybinds.json\n' >> /tmp/_kb.sh
  hc_exec < /tmp/_kb.sh | grep -q "$HEARTH_ID" || log "биндинг Home записан не так, проверь вручную"

  hc_luna luna://com.webos.applicationManager/launch "{\"id\":\"$HEARTH_ID\"}" >/dev/null || true
  log "Hearth готов. Осталось на ТВ: Options → TV input и Replace LG Home (helper script)."
}

do_torrserver() { need_root; sh "$HERE/tools/torrserver-headless.sh" install; }

do_omp() {
  need_root
  fetch "$OMP_IPK_URL" "$HERE/cache/omp.ipk"
  hc_install_ipk "$HERE/cache/omp.ipk" com.spacesarmat.torrplayer
  hc_luna luna://com.webos.applicationManager/launch '{"id":"com.spacesarmat.torrplayer"}' >/dev/null || true
  log "OMP готов. На ТВ: Настройки → сервер → Найти в сети (или $TV:${TS_PORT:-8090})."
}

do_youtube() {
  need_root
  _url=$(curl -fsSL https://repo.webosbrew.org/api/apps.json |
    sed -n 's/.*"ipkUrl": *"\([^"]*youtube[^"]*\.ipk\)".*/\1/p' | head -1)
  [ -n "$_url" ] || die "не нашёл ad-free YouTube в репозитории webosbrew"
  fetch "$_url" "$HERE/cache/youtube.ipk"
  hc_install_ipk "$HERE/cache/youtube.ipk" youtube.leanback.v4
}

do_verify() {
  printf '== root:        '; hc_root
  printf '== init.d:      '; printf 'ls /var/lib/webosbrew/init.d/\n' | hc_exec | hc_out | tr '\n' ' '; echo
  printf '== apps:        '; printf 'ls /media/developer/apps/usr/palm/applications/\n' | hc_exec | hc_out | tr '\n' ' '; echo
  printf '== foreground:  '
  printf "luna-send -a webosbrew -n 1 luna://com.webos.applicationManager/getForegroundAppInfo '{}'\n" |
    hc_exec | hc_out | sed -n 's/.*"appId":"\([^"]*\)".*/\1/p' | head -1
  printf '== torrserver:  '; curl -fsS "http://$TV:${TS_PORT:-8090}/echo" || echo "нет"
  echo
}

mkdir -p "$HERE/cache"
case "$1" in
  hearth)     do_hearth ;;
  torrserver) do_torrserver ;;
  omp)        do_omp ;;
  youtube)    do_youtube ;;
  verify)     do_verify ;;
  all)        do_hearth; do_youtube; do_torrserver; do_omp; do_verify ;;
  *) sed -n '2,4p' "$0" >&2; exit 2 ;;
esac
