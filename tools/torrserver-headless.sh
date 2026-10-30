#!/bin/sh
# TorrServer MatriX демоном на :8090 (root, webOS 4.x).
# Почему не приложением: GUI-пакет не проходит проверку подписи — docs/TRAPS.md §7.
#   ./tools/torrserver-headless.sh install [ipk-url]
#   ./tools/torrserver-headless.sh start|stop|status|uninstall
set -e
DIR=${TS_DIR:-/media/developer/torrserver}
PORT=${TS_PORT:-8090}
HOOK=/var/lib/webosbrew/init.d/80-torrserver

. "$(dirname "$0")/../lib/hbc.sh"

root_sh() { printf '%s\n' "$1" | hc_exec; }

case "$1" in
install)
  url=${2:-$(latest_asset 6ebeng/torrserver-webos)}
  [ -n "$url" ] || die "не нашёл ipk TorrServer"
  tmp=$(mktemp -d); ipk=$tmp/ts.ipk
  log "скачиваю $url"
  curl -fsSL -o "$ipk" "$url" || die "скачивание"
  # ar → data.tar.gz (webOS ipk = ar с debian-binary/control.tar.gz/data.tar.gz)
  tar -xzf "$ipk" -C "$tmp" 2>/dev/null || true
  python3 - "$ipk" "$tmp/data.tar.gz" <<'PY'
import sys
raw = open(sys.argv[1], 'rb').read(); pos = 8; out = None
while pos + 60 <= len(raw):
    h = raw[pos:pos+60]; name = h[0:16].decode().strip()
    size = int(h[48:58].decode().strip()); pos += 60
    if name.startswith('data'):
        out = raw[pos:pos+size]
    pos += size + (size % 2)
open(sys.argv[2], 'wb').write(out or b'')
PY
  [ -s "$tmp/data.tar.gz" ] || die "в пакете нет data.tar.gz"
  mkdir -p "$tmp/x" && tar -xzf "$tmp/data.tar.gz" -C "$tmp/x"
  bin=$(find "$tmp/x" -type f -name TorrServer | head -1)
  [ -n "$bin" ] || die "в пакете нет бинаря TorrServer"
  log "кладу бинарь в $DIR"
  tv_ssh "cat > /tmp/TorrServer" < "$bin"
  root_sh "rm -rf $DIR && mkdir -p $DIR && cp /tmp/TorrServer $DIR/ && chmod 755 $DIR/TorrServer && rm -f /tmp/TorrServer && ls -la $DIR"
  install_hook "$(dirname "$0")/../hooks/80-torrserver" 80-torrserver
  root_sh "cd $DIR && setsid ./TorrServer --port $PORT --path $DIR >>$DIR/torrserver.log 2>&1 & sleep 5; tail -3 $DIR/torrserver.log"
  sleep 1
  curl -fsS "http://$TV:$PORT/echo" && echo " ← TorrServer отвечает" || die "порт $PORT молчит"
  rm -rf "$tmp"
  ;;
start)    root_sh "cd $DIR && setsid ./TorrServer --port $PORT --path $DIR >>$DIR/torrserver.log 2>&1 &" ;;
stop)     root_sh "pkill -f 'TorrServer --port $PORT' ; echo stopped" ;;
status)   curl -fsS "http://$TV:$PORT/echo" || { echo "не отвечает"; exit 1; } ;;
uninstall)
  root_sh "rm -f $HOOK; pkill -f 'TorrServer --port $PORT'; rm -rf $DIR; echo removed" ;;
*) sed -n '2,5p' "$0" >&2; exit 2 ;;
esac
