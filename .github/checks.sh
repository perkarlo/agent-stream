#!/bin/bash
# Kod ile dokümanlar arasındaki tutarlılık kontrolleri.
# CI'da her push/PR'da, lokalde commit öncesi elle çalıştırılır: ./.github/checks.sh
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

GREEN='\033[0;32m'; RED='\033[0;31m'; DIM='\033[2m'; NC='\033[0m'
FAIL=0
ok()   { printf "  ${GREEN}✓${NC} %s\n" "$1"; }
fail() { printf "  ${RED}✗${NC} %s\n     ${DIM}%s${NC}\n" "$1" "$2"; FAIL=1; }

# ─── 1. Sözdizimi ───────────────────────────────────────────────────────────
if python3 -m py_compile agent-stream 2>/tmp/agent-stream-syntax.log; then
  ok "agent-stream derleniyor"
else
  fail "sözdizimi hatası" "$(tail -3 /tmp/agent-stream-syntax.log)"
fi
rm -rf __pycache__

# ─── 2. Çalıştırma izni ─────────────────────────────────────────────────────
if [ -x agent-stream ]; then
  ok "agent-stream çalıştırılabilir"
else
  fail "agent-stream çalıştırılabilir değil" "git update-index --chmod=+x agent-stream"
fi

# ─── 3. Yorum politikası: 4+ ardışık yorum satırı yok ───────────────────────
long=$(awk '
  /^#!/ || /^# \/\/\// || /^# requires-python/ || /^# dependencies/ { n=0; next }
  /^# [╔║╚]/ || /^# ───/ { n=0; next }
  /^[[:space:]]*#/ { n++; if (n>=4) print NR; next }
  { n=0 }
' agent-stream | head -3)
if [ -z "$long" ]; then
  ok "4+ ardışık yorum satırı yok"
else
  fail "uzun yorum bloğu: satır $(echo "$long" | tr '\n' ' ')" \
       "Kodda tek satırlık 'ne yapıyor' notu kalır; 'neden' CLAUDE.md → Savunma Satırları."
fi

# ─── 4. Alt komutlar dokümanlarda geçmeli ───────────────────────────────────
subs=$(awk '/^@app\.command\(/{getline; if ($0 ~ /^def /) {sub(/^def /,""); sub(/\(.*/,""); print}}' agent-stream)
subs="stream $subs"
missing=""
for s in $subs; do
  grep -q -- "$s" README.md && grep -q -- "$s" CLAUDE.md || missing="$missing $s"
done
if [ -z "$missing" ]; then
  ok "alt komutlar iki dokümanda da yazılı:$(echo " $subs" | tr '\n' ' ')"
else
  fail "dokümanda geçmeyen alt komut:$missing" \
       "README görünüm tablosu ve CLAUDE.md görünüm tablosu güncellenmeli."
fi

# ─── 5. PEP 723 bağımlılıkları ile importlar eşleşmeli ──────────────────────
deps=$(sed -n 's/^# dependencies = \[\(.*\)\]$/\1/p' agent-stream | tr -d '"' | tr ',' '\n' \
       | sed 's/[><=].*//' | tr -d ' ')
undeclared=""
for mod in $(grep -oE '^(import|from) [a-z_]+' agent-stream | awk '{print $2}' | sort -u); do
  case "$mod" in
    __future__|dataclasses|datetime|glob|json|os|pathlib|re|sys|time|tomllib|typing) continue ;;
  esac
  echo "$deps" | grep -qx "$mod" || undeclared="$undeclared $mod"
done
uninstalled=""
for d in $deps; do
  grep -qE "^(import|from) $d" agent-stream || uninstalled="$uninstalled $d"
done
if [ -z "$undeclared$uninstalled" ]; then
  ok "bağımlılık bloğu importlarla tutarlı: $(echo "$deps" | tr '\n' ' ')"
else
  fail "bağımlılık sapması — bildirilmemiş:${undeclared:- yok} · kullanılmayan:${uninstalled:- yok}" \
       "Shebang altındaki PEP 723 bloğu tek kaynak; uv o listeyi kurar."
fi

# ─── 6. Çıkış kodu sözleşmesi belgeli olmalı ────────────────────────────────
if grep -q "130" README.md && grep -q "130" CLAUDE.md; then
  ok "çıkış kodu sözleşmesi iki dokümanda da yazılı"
else
  fail "çıkış kodu sözleşmesi eksik" \
       "0 başarı · 1 hata · 2 kullanım · 130 Ctrl+C; EXIT_* sabitleri tek kaynak."
fi

echo
[ "$FAIL" = 0 ] && printf "${GREEN}Tüm kontroller geçti.${NC}\n" || printf "${RED}Kontroller başarısız.${NC}\n"
exit "$FAIL"
