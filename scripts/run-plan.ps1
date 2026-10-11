# Go-Plan/Codex-Run: jalankan plan (markdown dari ChatGPT Go) dengan Codex (akun Plus)
# Pakai: scripts\run-plan.ps1 plan.md [opsi-codex-tambahan...]
param(
  [Parameter(Mandatory = $true, Position = 0)][string]$Plan,
  [Parameter(ValueFromRemainingArguments = $true)][string[]]$CodexArgs
)

if (-not (Test-Path $Plan)) { Write-Error "file tidak ada: $Plan"; exit 1 }
if (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
  Write-Error "'codex' tidak ketemu. Install Codex CLI (npm i -g @openai/codex) lalu login dengan akun Plus: codex login"
  exit 1
}

$proj = if ($env:PROJECT_ROOT) { $env:PROJECT_ROOT } else { (Get-Location).Path }
$prompt = Get-Content -Raw $Plan
Write-Host "[codex-run] project : $proj"
Write-Host "[codex-run] plan    : $Plan"
Set-Location $proj
& codex exec @CodexArgs $prompt
