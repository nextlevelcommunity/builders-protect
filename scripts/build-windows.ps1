# Monta o pacote portátil Windows do Builders Protect CLI.
# Saída: dist/Builders-Protect-CLI-windows-x64.zip (+ .sha256)
param(
  [string]$NodeVersion = "20.18.1"
)

$ErrorActionPreference = "Stop"

Write-Host "Baixando node v$NodeVersion win-x64..."
Invoke-WebRequest -Uri "https://nodejs.org/dist/v$NodeVersion/node-v$NodeVersion-win-x64.zip" -OutFile "node-portable.zip"
Expand-Archive "node-portable.zip" -DestinationPath "node-dist" -Force

$Stage = "dist/win-builders-protect"
if (Test-Path $Stage) { Remove-Item -Recurse -Force $Stage }
New-Item -ItemType Directory -Force -Path $Stage | Out-Null

Copy-Item "node-dist/node-v$NodeVersion-win-x64/node.exe" "$Stage/node.exe"
foreach ($dir in @("bin", "lib", "action", "docs", "examples")) {
  if (Test-Path $dir) { Copy-Item -Recurse $dir "$Stage/$dir" }
}
foreach ($file in @("package.json", "action.yml", "README.md", "LICENSE", "CHANGELOG.md", "SECURITY.md")) {
  if (Test-Path $file) { Copy-Item $file "$Stage/$file" }
}

# Launcher: roda o CLI com o node embutido
$cmd = @"
@echo off
setlocal
"%~dp0node.exe" "%~dp0bin\builders-protect.js" %*
endlocal
"@
Set-Content -Path "$Stage/builders-protect.cmd" -Value $cmd -Encoding ASCII

$readme = @"
Builders Protect CLI - Windows x64 (portatil)

COMO USAR
  1. Extraia esta pasta em qualquer lugar (ex.: C:\builders-protect).
  2. Abra o Prompt de Comando ou PowerShell nessa pasta.
  3. Execute:  .\builders-protect.cmd scan --path C:\caminho\do\projeto

Opcoes:  .\builders-protect.cmd --help

REQUISITOS
  Nenhum: o node.exe incluido roda o CLI sem instalacao.

AVISO DO SMARTSCREEN
  Este build ainda nao tem assinatura Authenticode. Ao executar pela
  primeira vez, o Windows pode mostrar um aviso: clique em
  "Mais informacoes" > "Executar assim mesmo".

Analisa lockfiles de npm, pnpm, Yarn, Bun, pip, Poetry, Cargo, Go,
RubyGems, Hex e Nix e cruza com a base de vulnerabilidades da
Cultura Builder Community.
"@
Set-Content -Path "$Stage/LEIA-ME-WINDOWS.txt" -Value $readme -Encoding UTF8

Write-Host "Compactando..."
if (Test-Path "dist/Builders-Protect-CLI-windows-x64.zip") { Remove-Item -Force "dist/Builders-Protect-CLI-windows-x64.zip" }
Compress-Archive -Path $Stage -DestinationPath "dist/Builders-Protect-CLI-windows-x64.zip" -Force

$hash = (Get-FileHash "dist/Builders-Protect-CLI-windows-x64.zip" -Algorithm SHA256).Hash.ToLower()
"$hash  Builders-Protect-CLI-windows-x64.zip" | Set-Content -Path "dist/Builders-Protect-CLI-windows-x64.zip.sha256" -Encoding ASCII

# Smoke test do layout: mesma chamada que o usuario final faria (sem pasta-alvo)
& "$Stage/node.exe" "$Stage/bin/builders-protect.js" --version
if ($LASTEXITCODE -ne 0) { throw "smoke test --version falhou" }

Write-Host "OK: dist/Builders-Protect-CLI-windows-x64.zip"
Write-Host "SHA256: $hash"
