#!/bin/sh
# lib/hbc.sh — транспорт до LG webOS 4.x: SSH 9922 + Homebrew Channel exec + установка ipk.
# Подключается из install.sh:  . "$(dirname "$0")/lib/hbc.sh"
#
# Почему так, а не как в апстримах — docs/TRAPS.md:
#   * установщик HBC принимает только http(s) и голый sha256;
#   * качает ~1 КБ/с по LAN → большие ipk отдаём локальным сервером на самом ТВ;
#   * luna-send внутри exec ломается на кавычках → root-команды идут файлом.

: "${TV:=}"
: "${KEY:=$HOME/.ssh/lgtv_webos}"
: "${SSH_PORT:=9922}"
: "${TV_HTTP_PORT:=8081}"
: "${SMALL_IPK:=2097152}"          # до 2 МиБ — обычный HTTP с компьютера
: "${HBC_TEST:=0}"                 # 1 — не ходить на ТВ, печатать план

log() { printf '[kit] %s\n' "$*" >&2; }
die() { log "FAIL: $*"; exit 1; }

tv_ssh() {
  [ -n "$TV" ] || die "не задан TV=<ip телевизора>"
  ssh -p "$SSH_PORT" -i "$KEY" \
      -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      -o LogLevel=ERROR -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedKeyTypes=+ssh-rsa \
      -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=8 \
      "prisoner@$TV" "$@"
}

tv_is_up() { nc -z -w2 "$TV" "$SSH_PORT" 2>/dev/null; }

# luna-send-pub и HBC exec отвечают только на TTY-сессии (без -tt ответ пустой)
tv_luna_ssh() {
  [ -n "$TV" ] || die "не задан TV=<ip телевизора>"
  ssh -tt -p "$SSH_PORT" -i "$KEY" \
      -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      -o LogLevel=ERROR -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedKeyTypes=+ssh-rsa \
      -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=8 \
      "prisoner@$TV" "$@" </dev/null
}

# hc_exec < local-script — выполняет скрипт как root через HBC (обход кавычек).
hc_exec() {
  if [ "$HBC_TEST" = 1 ]; then log "DRY root: $(head -c 60 -)"; return 0; fi
  tv_ssh 'cat > /tmp/_hbc.sh' || die "не смог положить /tmp/_hbc.sh"
  tv_luna_ssh "luna-send-pub -n 1 luna://org.webosbrew.hbchannel.service/exec '{\"command\":\"sh /tmp/_hbc.sh\"}'"
}

hc_luna() {  # uri json [replies]
  _n=${3:-1}
  if [ "$HBC_TEST" = 1 ]; then log "DRY luna: $1"; return 0; fi
  tv_luna_ssh "luna-send-pub -n $_n $1 '$2'"
}

hc_push() { tv_ssh "cat > $2" < "$1" || die "push $1 → $2"; }

# hc_out — вытаскивает stdoutString из ответа exec и разэкранирует \n и \"
hc_out() { sed -n 's/.*"stdoutString":"\(.*\)","stdoutBytes".*/\1/p' | sed 's/\\n/\n/g; s/\\"/"/g'; }

hc_root() {  # быстрая проверка root
  if [ "$HBC_TEST" = 1 ]; then echo 0; return 0; fi
  printf 'id -u\n' | hc_exec | hc_out | head -1
}

ipk_hash() { sha256sum "$1" | cut -d' ' -f1; }   # голый hex, без префикса sha256:

# Запуск статического сервера на самом ТВ (127.0.0.1:8081), если его нет.
hc_tv_server_up() {
  [ "$HBC_TEST" = 1 ] && { log "DRY tv-server up"; return 0; }
  cat > /tmp/_srv.js <<'JS'
var http = require('http'), fs = require('fs'), path = require('path');
http.createServer(function (req, res) {
  var p = path.join('/tmp', decodeURIComponent(req.url.split('?')[0]));
  fs.stat(p, function (e, st) {
    if (e || !st.isFile()) { res.writeHead(404); res.end('no'); return; }
    res.writeHead(200, {'Content-Type': 'application/octet-stream', 'Content-Length': st.size});
    fs.createReadStream(p).pipe(res);
  });
}).listen(8081, '127.0.0.1');
JS
  tv_ssh 'cat > /tmp/_srv.js'
  printf 'wget -q -O /dev/null http://127.0.0.1:%s/_srv.js && echo UP\n' "$TV_HTTP_PORT" | hc_exec | grep -q UP && return 0
  printf 'setsid node /tmp/_srv.js >/tmp/_srv.log 2>&1 &\nsleep 2\n' | hc_exec >/dev/null
}

# hc_install_ipk <файл.ipk> <id>; транспорт выбирается по размеру файла.
hc_install_ipk() {
  _ipk=$1; _id=$2
  _sum=$(ipk_hash "$_ipk"); _size=$(wc -c < "$_ipk")
  [ -n "$_sum" ] || die "нет файла $_ipk"
  if [ "$_size" -le "$SMALL_IPK" ]; then
    _mode=pc
  else
    _mode=tv
  fi
  log "ipk $_id ($_size B, ${_sum%${_sum#????????}}) через $_mode"
  if [ "$HBC_TEST" = 1 ]; then echo "MODE=$_mode HASH=$_sum"; return 0; fi

  if [ "$_mode" = pc ]; then
    _dir=$(mktemp -d); trap 'rm -rf "$_dir"; kill %1 2>/dev/null' EXIT
    cp "$_ipk" "$_dir/"; _name=$(basename "$_ipk")
    ( cd "$_dir" && python3 -m http.server 18081 >/dev/null 2>&1 ) &
    sleep 1
    _pcip=$(ip route get "$TV" | sed -n 's/.* src \([0-9.]*\).*/\1/p' | head -1)
    _url="http://$_pcip:18081/$_name"
  else
    tv_ssh "cat > /tmp/$(basename "$_ipk")" < "$_ipk" || die "push ipk"
    hc_tv_server_up
    _url="http://127.0.0.1:$TV_HTTP_PORT/$(basename "$_ipk")"
  fi

  log "install $_url"
  printf "timeout -t 900 luna-send -a webosbrew -n 120 luna://org.webosbrew.hbchannel.service/install '{\"ipkUrl\":\"%s\",\"ipkHash\":\"%s\",\"subscribe\":true}'\n" \
    "$_url" "$_sum" | hc_exec | tee /tmp/_inst.out >/dev/null
  if grep -q '"statusText":"Finished\."' /tmp/_inst.out; then
    log "OK $_id"
  else
    log "установка $_id не завершилась:"; grep -o '"errorText":"[^"]*"' /tmp/_inst.out | tail -2 >&2
    return 1
  fi
}

# install_hook <файл-шаблон> <имя-на-ТВ> [APP_ID] — подставляет @APP@/@TS_DIR@/@TS_PORT@ и кладёт в init.d
install_hook() {
  _t=$1; _dst=$2; _app=${3:-tld.my.customlauncher}
  _tmp=$(mktemp)
  sed -e "s|@APP@|$_app|g" -e "s|@TS_DIR@|${TS_DIR:-/media/developer/torrserver}|g" \
      -e "s|@TS_PORT@|${TS_PORT:-8090}|g" "$_t" > "$_tmp"
  tv_ssh "cat > /tmp/$_dst" < "$_tmp" || die "push hook $_dst"
  printf 'cp /tmp/%s /var/lib/webosbrew/init.d/%s && chmod 755 /var/lib/webosbrew/init.d/%s && sh /var/lib/webosbrew/init.d/%s >/dev/null 2>&1; echo HOOKED\n' \
    "$_dst" "$_dst" "$_dst" "$_dst" | hc_exec | grep -q HOOKED || die "hook $_dst"
  rm -f "$_tmp"
  log "hook $_dst"
}

latest_asset() {  # repo tag-filter: печатает URL первого .ipk
  curl -fsSL "https://api.github.com/repos/$1/releases/latest" |
    sed -n 's/.*"browser_download_url": *"\([^"]*\.ipk\)".*/\1/p' | head -1
}
