#!/bin/zsh
# sign-release.sh — assina com Developer ID, notariza, grampeia e publica.
# Uso: ./scripts/sign-release.sh <ISSUER_UUID> <TEAM_ID> <TAG>
#   ex: ./scripts/sign-release.sh 69a6de70-... 8TA8YQY457 v1.3.3
# Pré-requisito: chave de API ASC em ~/.appstoreconnect/private_keys/AuthKey_<KID>.p8
#                 (ou defina ASC_KEY_ID / ASC_KEY_PATH)
set -euo pipefail

ISSUER="${1:?issuer id (App Store Connect > Integrações > chave de API)}"
TEAM="${2:?team id (developer.apple.com > Membership)}"
TAG="${3:?tag, ex v1.3.3}"
DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/.." && pwd)"
KID="${ASC_KEY_ID:-GZPQDQ53F8}"
P8="${ASC_KEY_PATH:-$HOME/.appstoreconnect/private_keys/AuthKey_$KID.p8}"
KEY="$DIR/creds/dev_id.key"
CSR_B64=$(tr -d '\n' < "$DIR/creds/dev_id.csr.b64")
KC="$DIR/creds/asc.keychain"
KCPASS="bp$(date +%s)"
OUT="$DIR/creds/developer_id.cer"
APP="$ROOT/dist/Builders Protect.app"
DMG="$ROOT/dist/Builders Protect.dmg"
ENT="$ROOT/Resources/BuildersProtect.entitlements"

[[ -f "$P8" ]] || { echo "ERRO: chave ASC não encontrada em $P8"; exit 1; }
[[ -d "$APP" ]] || { echo "ERRO: rode 'make dist' antes."; exit 1; }

jwt() {
    node --input-type=module -e '
import fs from "fs"; import crypto from "crypto";
const [iss,kid,p8path]=process.argv.slice(1);
const key=crypto.createPrivateKey(fs.readFileSync(p8path,"utf8"));
const b64=o=>Buffer.from(JSON.stringify(o)).toString("base64url");
const now=Math.floor(Date.now()/1000);
const input=`${b64({alg:"ES256",kid,typ:"JWT"})}.${b64({iss,iat:now,exp:now+1200,aud:"appstoreconnect-v1"})}`;
// Apple exige a assinatura ECDSA no formato cru JOSE (r||s), nao DER.
const sig=crypto.sign("sha256",Buffer.from(input),{key,dsaEncoding:"ieee-p1363"});
console.log(`${input}.${sig.toString("base64url")}`);
' "$ISSUER" "$KID" "$P8"
}

echo ">> 1/6 validando credenciais na API da Apple..."
TOKEN=$(jwt)
CODE=$(curl -sS -o /tmp/asc-preflight.json -w '%{http_code}' \
    -H "Authorization: Bearer $TOKEN" \
    "https://api.appstoreconnect.apple.com/v1/certificates?limit=1")
if [[ "$CODE" != "200" ]]; then
    echo "ERRO: API respondeu $CODE. Corpo:"
    head -c 400 /tmp/asc-preflight.json; echo
    echo "Dica: 401 = chave revogada ou Issuer de outro time; 403 = chave sem papel de Admin/Developer."
    exit 1
fi
echo "   ok — credenciais válidas"

echo ">> 2/6 obtendo certificado Developer ID Application..."
EXISTING=$(security find-identity -v -p codesigning 2>/dev/null | grep -c "Developer ID Application" || true)
if (( EXISTING > 0 )); then
    echo "   usando certificado já instalado no keychain"
else
    RESP=$(curl -sS -X POST "https://api.appstoreconnect.apple.com/v1/certificates" \
        -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
        -d "{\"data\":{\"type\":\"certificates\",\"attributes\":{\"certificateType\":\"DEVELOPER_ID_APPLICATION\",\"csrContent\":\"$CSR_B64\"}}}")
    echo "$RESP" | node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{
      try{const j=JSON.parse(d); if(j.errors) throw new Error(JSON.stringify(j.errors));
        require("fs").writeFileSync(process.argv[1],Buffer.from(j.data.attributes.certificateContent,"base64"));
        console.log("   ok — cert",j.data.id);}catch(e){console.error("ERRO:",e.message);process.exit(1);}
    })' "$OUT"

    security create-keychain -p "$KCPASS" "$KC" 2>/dev/null || true
    security set-keychain-settings -lut 21600 "$KC"
    security unlock-keychain -p "$KCPASS" "$KC"
    security import "$KEY" -k "$KC" -A -T /usr/bin/codesign
    security import "$OUT" -k "$KC" -A -T /usr/bin/codesign
    curl -sS -o "$DIR/creds/wwdr.cer" https://www.apple.com/certificateauthority/AppleWWDRCAG4.cer
    security import "$DIR/creds/wwdr.cer" -k "$KC" -A -T /usr/bin/codesign
    security set-key-partition-list -S apple-tool:,apple:,codesign: -k "$KCPASS" "$KC" >/dev/null
    security list-keychains -d user -s "$KC" $(security list-keychains -d user | tr -d '"')
fi

SIGN_ARGS=(--force --options runtime --timestamp --sign "Developer ID Application")
[[ -f "$ENT" ]] && SIGN_ARGS+=(--entitlements "$ENT")

echo ">> 3/6 assinando app e dmg..."
codesign "${SIGN_ARGS[@]}" --keychain "$KC" "$APP"
codesign "${SIGN_ARGS[@]}" "$DMG" 2>/dev/null || true
codesign --verify --strict --deep "$APP"
echo "   ok"

echo ">> 4/6 notarizando (pode levar minutos)..."
xcrun notarytool submit "$DMG" --key "$P8" --key-id "$KID" --issuer "$ISSUER" --wait

echo ">> 5/6 grampeando e verificando..."
xcrun stapler staple "$DMG"
xcrun stapler staple "$APP"
xcrun stapler validate "$DMG"
spctl -a -vvv -t exec "$APP"
shasum -a 256 "$DMG" > "$ROOT/dist/SHA256SUMS.txt"
echo "   ok — Gatekeeper aceita"

echo ">> 6/6 publicando $TAG..."
gh release create "$TAG" "$DMG" "$ROOT/dist/SHA256SUMS.txt" \
    --repo nextlevelcommunity/builders-protect \
    --title "Builders Protect $TAG" \
    --notes "Assinado com Developer ID e notarizado pela Apple. Universal (Apple Silicon + Intel). Verifique com SHA256SUMS.txt."

echo "PRONTO: $TAG publicado, assinado e notarizado."
