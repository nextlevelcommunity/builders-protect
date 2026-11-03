#!/bin/zsh
# release-check.sh — checagem pontual e rápida do artefato antes de publicar.
# Não roda a suíte inteira: valida só o que quebra na mão de quem baixa.
# Uso: ./scripts/release-check.sh [dist/"Builders Protect.dmg"]
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/Builders Protect.app"
DMG="${1:-$ROOT/dist/Builders Protect.dmg}"
FAIL=0

pass() { print -r -- "  ok   $1" }
fail() { print -r -- "  FALHA $1"; FAIL=1 }
info() { print -r -- "  info $1" }

print -r -- "== artefato =="
[[ -d "$APP" ]] || { fail "app ausente em dist/"; exit 1; }

BIN="$APP/Contents/MacOS/CVEBuilder"
ARCHS=$(lipo -archs "$BIN" 2>/dev/null)
if [[ "$ARCHS" == *arm64* && "$ARCHS" == *x86_64* ]]; then
    pass "binário universal ($ARCHS)"
else
    fail "binário não é universal (tem: ${ARCHS:-?}) — Macs Intel não rodam"
fi

PLIST_VER=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist" 2>/dev/null)
PKG_VER=$(node -p "require('$ROOT/package.json').version" 2>/dev/null)
if [[ -n "$PLIST_VER" && "$PLIST_VER" == "$PKG_VER" ]]; then
    pass "versão consistente ($PLIST_VER)"
else
    fail "versão divergente: app=$PLIST_VER package.json=$PKG_VER"
fi

BUNDLE_VER=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP/Contents/Info.plist" 2>/dev/null)
[[ "$BUNDLE_VER" == "$PLIST_VER" ]] && pass "CFBundleVersion alinhado" || fail "CFBundleVersion ($BUNDLE_VER) != versão curta"

print -r -- "== assinatura =="
if codesign --verify --strict --deep "$APP" 2>/dev/null; then
    pass "assinatura íntegra"
else
    fail "assinatura inválida (rode scripts/build-app.sh)"
fi

FLAGS=$(codesign -dvvv "$APP" 2>&1 | sed -n 's/^CodeDirectory.*flags=\(0x[0-9a-f]*\).*/\1/p')
if (( 0x${FLAGS#0x} & 0x10000 )); then
    pass "hardened runtime ativo (flags=$FLAGS)"
else
    fail "hardened runtime ausente (flags=${FLAGS:-?}) — notarização vai recusar"
fi

SIG=$(codesign -dvvv "$APP" 2>&1 | sed -n 's/^Signature=//p')
TEAM=$(codesign -dvvv "$APP" 2>&1 | sed -n 's/^TeamIdentifier=//p')
if [[ "$SIG" == "adhoc" ]]; then
    info "assinatura ad-hoc (TeamIdentifier=${TEAM:-none}) — distribuição exige Developer ID + notarização"
else
    pass "assinatura de identidade ($SIG, team $TEAM)"
fi

print -r -- "== gatekeeper =="
if spctl -a -vvv -t exec "$APP" >/dev/null 2>&1; then
    pass "Gatekeeper aceita direto (notarizado)"
else
    info "Gatekeeper rejeita (esperado sem notarização) — o passo a passo do README precisa funcionar"
fi

print -r -- "== execução =="
if [[ "${BP_SKIP_LAUNCH:-}" == "1" ]]; then
    info "abertura real pulada (BP_SKIP_LAUNCH=1)"
else
# O app é instância única por bundle id: fecha o que estiver aberto, testa o
# artefato e devolve o app instalado ao ar no fim.
RUNNING_BEFORE=$(pgrep -f "Builders Protect.app/Contents/MacOS/CVEBuilder" | wc -l | tr -d ' ')
osascript -e 'tell application id "com.culturabuilder.buildersprotect" to quit' >/dev/null 2>&1 || true
sleep 2
open -n "$APP" >/dev/null 2>&1
sleep 5
PID=$(pgrep -f "$APP/Contents/MacOS/CVEBuilder" | head -1)
if [[ -n "$PID" ]]; then
    pass "app sobe e permanece vivo (pid $PID)"
    kill "$PID" 2>/dev/null
    sleep 1
else
    fail "app não permaneceu vivo (veja 'log stream --predicate process==CVEBuilder')"
fi
if (( RUNNING_BEFORE > 0 )); then
    open "$HOME/Applications/Builders Protect.app" >/dev/null 2>&1 || true
    info "app instalado reaberto"
fi
fi

print -r -- "== dmg =="
if [[ -f "$DMG" ]]; then
    MP=$(mktemp -d /tmp/bp-mnt.XXXXXX)
    if hdiutil attach "$DMG" -nobrowse -readonly -mountpoint "$MP" >/dev/null 2>&1; then
        pass "dmg monta"
        [[ -d "$MP/Builders Protect.app" ]] && pass "app presente no dmg" || fail "dmg sem o app"
        if [[ -d "$MP/Builders Protect.app" ]]; then
            A=$(shasum -a 256 "$MP/Builders Protect.app/Contents/MacOS/CVEBuilder" | cut -d' ' -f1)
            B=$(shasum -a 256 "$BIN" | cut -d' ' -f1)
            [[ "$A" == "$B" ]] && pass "binário do dmg é o mesmo de dist/ (build atual)" || fail "dmg defasado: binário diferente do build atual"
        fi
        [[ -L "$MP/Applications" ]] && pass "atalho para /Applications presente" || fail "dmg sem atalho para /Applications"
        hdiutil detach "$MP" -quiet 2>/dev/null
    else
        fail "dmg não monta"
    fi
    rmdir "$MP" 2>/dev/null
    shasum -a 256 "$DMG" > "$ROOT/dist/SHA256SUMS.txt"
    pass "SHA256SUMS.txt atualizado"
else
    info "dmg ausente (rode make dmg)"
fi

print -r -- "== credenciais =="
if git -C "$ROOT" ls-files --error-unmatch scripts/creds/dev_id.key >/dev/null 2>&1; then
    fail "chave privada versionada em scripts/creds/"
else
    pass "chave privada fora do git"
fi

print -r -- ""
(( FAIL == 0 )) && print -r -- "RESULTADO: pronto" || print -r -- "RESULTADO: pendências acima"
exit $FAIL
