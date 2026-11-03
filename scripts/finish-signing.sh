#!/bin/zsh
# finish-signing.sh — um comando só, com o time e o Issuer já preenchidos.
# Roda o pipeline completo: certificado Developer ID -> assinatura -> notarização -> release.
# Uso: ./scripts/finish-signing.sh [TAG]
#   sem TAG usa a versão do package.json
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/.." && pwd)"
VERSION="$(node -p "require('$ROOT/package.json').version")"
TAG="${1:-v$VERSION}"

export ASC_KEY_ID="${ASC_KEY_ID:-GZPQDQ53F8}"
ISSUER="${ASC_ISSUER:-4ee22c1b-f18c-4943-968e-3d3d0ea59e6b}"
TEAM="${ASC_TEAM_ID:-8TA8YQY457}"

exec "$DIR/sign-release.sh" "$ISSUER" "$TEAM" "$TAG"
