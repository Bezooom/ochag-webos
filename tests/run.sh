#!/bin/sh
# tests/run.sh — контрактные проверки без телевизора.
# Подменяет ssh фейком и проверяет то, что реально ломается: формат хеша,
# выбор транспорта, подстановку шаблонов хуков, форму keybinds.json.
set -u
HERE=$(cd "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
FAIL=0; PASS=0
ok()  { PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL  %s\n' "$1"; }
eq()  { [ "$2" = "$3" ] && ok "$1" || bad "$1 (ждали '$3', получили '$2')"; }

# --- фейковый ssh: пишет stdin и argv, отвечает успехом ---------------
mkdir -p "$WORK/bin"
cat > "$WORK/bin/ssh" <<'SH'
#!/bin/sh
: "${FAKE_DIR:?}"
{ printf '### %s\n' "$*"; cat; printf '\n'; } >> "$FAKE_DIR/stdin.log"
case "$*" in
  *exec*) echo '{"returnValue":true,"stdoutString":"HOOKED\n"}' ;;
  *)      echo '{"returnValue":true,"stdoutString":"0\n"}' ;;
esac
SH
chmod +x "$WORK/bin/ssh"
export PATH="$WORK/bin:$PATH" FAKE_DIR="$WORK"

# --- 1. подстановка шаблонов хуков -----------------------------------
. "$HERE/lib/hbc.sh"
export TV=10.0.0.1 KEY=/dev/null HBC_TEST=0
install_hook "$HERE/hooks/90-launcher" 90-launcher tld.my.customlauncher >/dev/null 2>&1
hook=$(cat "$WORK/stdin.log" 2>/dev/null)
case "$hook" in
  *'"id":"tld.my.customlauncher"'*) ok "90-launcher подставил id приложения" ;;
  *) bad "90-launcher: id не подставлен" ;;
esac
case "$hook" in
  *@APP@*) bad "90-launcher: остался плейсхолдер" ;;
  *) ok "90-launcher: плейсхолдеров не осталось" ;;
esac

install_hook "$HERE/hooks/80-torrserver" 80-torrserver >/dev/null 2>&1
hook=$(cat "$WORK/stdin.log" 2>/dev/null)
case "$hook" in
  *'/media/developer/torrserver'*'8090'*) ok "80-torrserver подставил путь и порт" ;;
  *) bad "80-torrserver: @TS_DIR@/@TS_PORT@ не подставлены" ;;
esac

# --- 2. хеш установщика: голый hex, без префикса ----------------------
printf 'x' > "$WORK/a.ipk"
h=$(ipk_hash "$WORK/a.ipk")
echo "$h" | grep -Eq '^[0-9a-f]{64}$' && ok "ipk_hash = голый sha256" || bad "ipk_hash: '$h'"

# --- 3. выбор транспорта по размеру ----------------------------------
dd if=/dev/zero of="$WORK/small.ipk" bs=1024 count=64 2>/dev/null
dd if=/dev/zero of="$WORK/big.ipk"   bs=1024 count=4096 2>/dev/null
out=$(HBC_TEST=1 hc_install_ipk "$WORK/small.ipk" x 2>/dev/null)
echo "$out" | grep -q 'MODE=pc' && ok "маленький ipk → HTTP с компьютера" || bad "маленький ipk: $out"
out=$(HBC_TEST=1 hc_install_ipk "$WORK/big.ipk" x 2>/dev/null)
echo "$out" | grep -q 'MODE=tv' && ok "большой ipk → сервер на самом ТВ" || bad "большой ipk: $out"

# --- 4. keybinds.json валиден и ведёт в лаунчер -----------------------
printf '{"773":{"action":"launch","id":"tld.my.customlauncher"}}' > "$WORK/kb.json"
if command -v node >/dev/null 2>&1; then
  node -e '
    var j = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
    var k = j[773];
    if (!k || k.action !== "launch" || k.id !== "tld.my.customlauncher") process.exit(1);
  ' "$WORK/kb.json" && ok "keybinds.json разбирается и указывает на лаунчер" || bad "keybinds.json"
else
  printf '  SKIP  node нет, keybinds.json не проверен\n'
fi

# --- 5. синтаксис всех скриптов --------------------------------------
for f in "$HERE/install.sh" "$HERE"/lib/*.sh "$HERE"/tools/*.sh "$HERE"/hooks/*; do
  if sh -n "$f" 2>/dev/null; then ok "sh -n $(basename "$f")"; else bad "sh -n $f"; fi
done

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" = 0 ]
