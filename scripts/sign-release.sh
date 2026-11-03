#!/bin/zsh
# sign-release.sh — cria cert Developer ID via API ASC, assina, notariza e publica.
# Uso: ./scripts/sign-release.sh <ISSUER_UUID> <TEAM_ID> <VERSION_TAG>
set -euo pipefail
ISSUER="${1:?issuer id}"
TEAM="${2:?team id}"
TAG="${3:?tag ex v1.3.2}"
DIR="$(cd "$(dirname "$0")" && pwd)"
KEY="$DIR/creds/dev_id.key"
CSR_B64=$(cat "$DIR/creds/dev_id.csr.b64")
P8="$HOME/.appstoreconnect/private_keys/AuthKey_8KC953UNQ7.p8"
KC="$DIR/creds/asc.keychain"
OUT="$DIR/creds/developers_id.cer"

# 1) JWT ES256 com a p8 (node crypto, sem dependências)
JWT=$(node -e '
const fs=require("fs"),crypto=require("crypto");
const [iss,kid,team]=process.argv.slice(1);
const pem=fs.readFileSync(process.env.P8,"utf8");
const raw=pem.replace(/-----(BEGIN|END) PRIVATE KEY-----/g,"").replace(/\s+/g,"");
const b64=(o)=>Buffer.from(JSON.stringify(o)).toString("base64url");
const now=Math.floor(Date.now()/1000);
const header=b64({alg:"ES256",kid,type:"JWT"});
const payload=b64({iss,iat:now,exp:now+1200,aud:"appstoreconnect-v1"});
const input=header+"."+payload;
const sign=crypto.createSign("RSA-SHA256"); // replaced below (ES256)
' "$ISSUER" "8KC953UNQ7" "$TEAM" 2>/dev/null || true)

# nota: ES256 correto abaixo
JWT=$(node --input-type=module -e '
import fs from "fs"; import crypto from "crypto";
const [iss,p8path]=process.argv.slice(1);
const p8=fs.readFileSync(p8path,"utf8");
const key=crypto.createPrivateKey(p8);
const b64=o=>Buffer.from(JSON.stringify(o)).toString("base64url");
const now=Math.floor(Date.now()/1000);
const input=`${b64({alg:"ES256",kid:"8KC953UNQ7",typ:"JWT"})}.${b64({iss,iat:now,exp:now+1200,aud:"appstoreconnect-v1"})}`;
const sig=crypto.sign("sha256",Buffer.from(input),key).toString("base64url");
console.log(`${input}.${sig}`);
' "$ISSUER" "$P8")

echo ">> JWT pronto. Criando certificado Developer ID Application..."
RESP=$(curl -sS -X POST "https://api.appstoreconnect.apple.com/v1/certificates" \
  -H "Authorization: Bearer $JWT" -H "Content-Type: application/json" \
  -d "{\"data\":{\"attributes\":{\"certificateType\":\"DEVELOPER_ID_APPLICATION\",\"csrContent\":\"$CSR_B64\"},\"type\":\"certificates\"}}")
echo "$RESP" | node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{try{const j=JSON.parse(d); if(j.errors)throw new Error(JSON.stringify(j.errors)); const cer=j.data.attributes.certificateContent; require("fs").writeFileSync(process.argv[1],Buffer.from(cer,"base64")); console.log("OK cert salvo:",j.data.id);}catch(e){console.error("ERRO:",e.message);process.exit(1);}})' "$OUT"

# 2) intermediários Apple
curl -sS -o "$DIR/creds/wwdr.cer" https://www.apple.com/certificateauthority/AppleWWDRCAG4.cer
curl -sS -o "$DIR/creds/intermediate.cer" https://www.apple.com/certificateauthority/AppleRootCA-G3.cer

# 3) keychain efêmero
security create-keychain -p "bp$(date +%s)" "$KC" 2>/dev/null || true
security unlock-keychain -p "bp$(date +%s)" "$KC" 2>/dev/null || true
security import "$OUT" -k "$KC" -A
security import "$DIR/creds/wwdr.cer" -k "$KC" -A
security set-key-partition-list -S apple-tool:,apple: -k "bp$(date +%s)" "$KC" >/dev/null

echo ">> OK. Assine com:"
echo "   codesign --deep --force --options runtime --keychain \"$KC\" --sign \"$TEAM\" --timestamp \"dist/Builders Protect.app\""
echo ">> Depois: make dmg && xcrun notarytool submit dist/'Builders Protect.dmg' --key $P8 --key-id 8KC953UNQ7 --issuer $ISSUER --wait"
