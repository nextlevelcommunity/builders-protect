# Assinatura e notarização (Developer ID)

Objetivo: o DMG abrir sem aviso do Gatekeeper. Só precisa ser feito **uma vez**;
depois todo tag `v*.*.*` sai assinado e notarizado pelo CI.

## O que falta hoje

O Mac tem a chave privada e o CSR (`scripts/creds/`, fora do git), mas a Apple
nunca emitiu o certificado: as três chaves de API ASC desta máquina respondem
**401** (revogadas ou de outro time) e o login do Xcode está com sessão vencida
(`missing Xcode-Token`). É preciso uma conta com papel **Admin/Developer** no
App Store Connect.

## Caminho A — pelo navegador (3 minutos, precisa de humano)

1. Entrar em <https://developer.apple.com/account/resources/certificates/add>.
2. Escolher **Developer ID Application** (seção *Software*).
3. Enviar o CSR já pronto: `scripts/creds/dev_id.csr` (ou o conteúdo de
   `scripts/creds/dev_id.csr.b64`, decodificado).
4. Baixar o `.cer`, importar no Acesso às Chaves junto com `scripts/creds/dev_id.key`
   (duplo clique nos dois, na mesma sessão) e exportar como `.p12` com senha.
5. Em App Store Connect > Usuários e Acesso > Integrações, gerar uma chave de API
   e anotar **Issuer ID**, **Key ID** e o `.p8`.
6. Anotar o **Team ID** em <https://developer.apple.com/account> (Membership).

Depois disso, na máquina:

```bash
./scripts/sign-release.sh <ISSUER_ID> <TEAM_ID> v1.3.4
```

O script valida a credencial antes de tudo, cria o certificado pela API se ainda
não existir, assina com hardened runtime, notariza, grampeia, verifica o
Gatekeeper e publica. Falha cedo e sem efeito colateral.

## Caminho B — pelo CI (depois do caminho A, sem Mac)

Cadastrar em *Settings > Secrets and variables > Actions*:

| Segredo | Conteúdo |
| --- | --- |
| `DEVELOPER_ID_P12` | `.p12` exportado no passo 4, em base64 (`base64 -i cert.p12`) |
| `DEVELOPER_ID_PASSWORD` | senha do `.p12` |
| `ASC_KEY_ID` | Key ID da chave de API |
| `ASC_ISSUER` | Issuer ID |
| `ASC_TEAM_ID` | Team ID |
| `ASC_KEY_P8` | conteúdo do `.p8`, em base64 |

Com os segredos presentes, o job `macos` do `release.yml` assina, notariza e
grampeia sozinho; sem eles, ele publica o DMG ad-hoc como hoje.

## Como saber se funcionou

```bash
spctl -a -vvv -t exec "/Applications/Builders Protect.app"
# esperado: accepted, source=Notarized Developer ID
```

`scripts/release-check.sh` mostra o mesmo estado em uma linha: `adhoc` + Gatekeeper
recusando = ainda sem notarização; identidade `Developer ID Application` + aceito =
pronto para distribuir.
