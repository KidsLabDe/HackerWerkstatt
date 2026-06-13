#Requires -Version 5.1
# setup-client.ps1 — Installiert und konfiguriert OpenCode für zu Hause
# Verwendet OpenRouter als KI-Provider (identisch zu KidsLab-Clients)
#
# Ausführen (direkt aus dem Web):
#   irm https://raw.githubusercontent.com/kidslabde/HackerWerkstatt/main/setup-client.ps1 | iex
#
# Ausführen (lokale Datei):
#   powershell -ExecutionPolicy Bypass -File setup-client.ps1

Set-StrictMode -Version Latest

# ── Ausgabe-Funktionen ────────────────────────────────────────────────────────
function Write-Ok   { param($msg) Write-Host "✓ $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "⚠ $msg" -ForegroundColor Yellow }
function Write-Err  { param($msg) Write-Host "✗ $msg" -ForegroundColor Red }
function Write-Step { param($msg) Write-Host "`n==> $msg" -ForegroundColor Cyan }

# ── Konstanten ────────────────────────────────────────────────────────────────
$OPENROUTER_BASE = "https://openrouter.ai/api/v1"
$DEFAULT_MODEL   = "google/gemma-4-26b-a4b-it"
$REPO_RAW        = "https://raw.githubusercontent.com/kidslabde/HackerWerkstatt/main"

# ── API-Key (wird in get_api_key gesetzt) ─────────────────────────────────────
$script:API_KEY = ""

# ══════════════════════════════════════════════════════════════════════════════
# Schritt 1: OpenCode installieren
# ══════════════════════════════════════════════════════════════════════════════
function Install-OpenCode {
    Write-Step "OpenCode installieren"

    if (Get-Command opencode -ErrorAction SilentlyContinue) {
        $version = & opencode version 2>&1 | Select-Object -First 1
        if (-not $version) { $version = "Version unbekannt" }
        Write-Ok "OpenCode bereits vorhanden ($version)"
        return
    }

    if (Get-Command npm -ErrorAction SilentlyContinue) {
        Write-Host "  Installiere OpenCode via npm..."
        npm install -g opencode-ai
        if ($LASTEXITCODE -eq 0) { Write-Ok "OpenCode via npm installiert"; return }
        Write-Warn "npm-Installation fehlgeschlagen, versuche winget..."
    }

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "  Installiere OpenCode via winget..."
        winget install SST.opencode --silent --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -eq 0) { Write-Ok "OpenCode via winget installiert"; return }
    }

    Write-Err "OpenCode konnte nicht automatisch installiert werden."
    Write-Err "Bitte OpenCode manuell installieren: https://opencode.ai"
    exit 1
}

# ══════════════════════════════════════════════════════════════════════════════
# Schritt 2: API-Key entschlüsseln
# ══════════════════════════════════════════════════════════════════════════════
function Get-ApiKey {
    Write-Step "KidsLab-API-Key entschlüsseln"

    # Verschlüsselte Key-Datei: zuerst lokal suchen, sonst aus Repo laden
    $encFile = $null
    $tmpFile = $null

    $scriptDir = Split-Path -Parent $MyInvocation.ScriptName 2>$null
    if ($scriptDir -and (Test-Path (Join-Path $scriptDir "opencode.key.enc"))) {
        $encFile = Join-Path $scriptDir "opencode.key.enc"
    } else {
        $tmpFile = [System.IO.Path]::GetTempFileName()
        Write-Host "  Lade verschlüsselte Key-Datei..."
        Invoke-WebRequest -Uri "$REPO_RAW/files/opencode.key.enc" -OutFile $tmpFile -UseBasicParsing
        $encFile = $tmpFile
    }

    Write-Host ""
    $vaultPass = Read-Host "  Jetzt Passwort eingeben"

    if ([string]::IsNullOrEmpty($vaultPass)) {
        Write-Err "Passwort darf nicht leer sein."
        if ($tmpFile) { Remove-Item $tmpFile -ErrorAction SilentlyContinue }
        exit 1
    }

    # openssl suchen (Git for Windows oder system)
    $opensslCmd = $null
    foreach ($candidate in @("openssl", "C:\Program Files\Git\usr\bin\openssl.exe")) {
        if (Get-Command $candidate -ErrorAction SilentlyContinue) {
            $opensslCmd = $candidate; break
        }
    }

    if (-not $opensslCmd) {
        Write-Err "openssl nicht gefunden. Bitte Git for Windows installieren: https://git-scm.com"
        if ($tmpFile) { Remove-Item $tmpFile -ErrorAction SilentlyContinue }
        exit 1
    }

    $script:API_KEY = & $opensslCmd enc -d -aes-256-cbc -pbkdf2 -base64 `
                        -in $encFile -pass "pass:$vaultPass" 2>$null

    if ($tmpFile) { Remove-Item $tmpFile -ErrorAction SilentlyContinue }

    if ([string]::IsNullOrEmpty($script:API_KEY)) {
        Write-Err "Falsches Passwort — API-Key konnte nicht entschlüsselt werden."
        exit 1
    }

    Write-Ok "API-Key entschlüsselt."
}

# ══════════════════════════════════════════════════════════════════════════════
# Schritt 3: OpenCode konfigurieren
# ══════════════════════════════════════════════════════════════════════════════
function Set-OpenCodeConfig {
    Write-Step "OpenCode konfigurieren"

    $configDir  = Join-Path $HOME ".config\opencode"
    $configFile = Join-Path $configDir "opencode.json"

    New-Item -ItemType Directory -Force -Path $configDir | Out-Null

    if (Test-Path $configFile) {
        $backup = "$configFile.bak.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Copy-Item $configFile $backup
        Write-Warn "Backup erstellt: $backup"
    }

    @"
{
  "`$schema": "https://opencode.ai/config.json",
  "provider": {
    "kidslab": {
      "name": "KidsLab AI",
      "npm": "@ai-sdk/openai-compatible",
      "options": {
        "baseURL": "$OPENROUTER_BASE",
        "apiKey": "$($script:API_KEY)"
      },
      "models": {
        "google/gemma-4-26b-a4b-it": {
          "name": "Gemma 4 (Standard)"
        },
        "deepseek/deepseek-chat-v3.1": {
          "name": "DeepSeek V3.1"
        },
        "qwen/qwen3-coder-30b-a3b-instruct": {
          "name": "Qwen3 Coder"
        },
        "mistralai/mistral-small-3.2-24b-instruct": {
          "name": "Mistral Small"
        }
      }
    }
  },
  "model": "kidslab/$DEFAULT_MODEL"
}
"@ | Set-Content -Path $configFile -Encoding UTF8

    Write-Ok "OpenCode konfiguriert: $configFile"
}

# ══════════════════════════════════════════════════════════════════════════════
# Schritt 4: Mentor-Prompt installieren
# ══════════════════════════════════════════════════════════════════════════════
function Set-MentorPrompt {
    Write-Step "KidsLab Coding-Mentor installieren"

    $configDir  = Join-Path $HOME ".config\opencode"
    $agentsFile = Join-Path $configDir "AGENTS.md"
    New-Item -ItemType Directory -Force -Path $configDir | Out-Null

    $scriptDir = Split-Path -Parent $MyInvocation.ScriptName 2>$null
    $localMentor = if ($scriptDir) { Join-Path $scriptDir "files\opencode-mentor.md" } else { $null }

    if ($localMentor -and (Test-Path $localMentor)) {
        Copy-Item $localMentor $agentsFile
    } else {
        Invoke-WebRequest -Uri "$REPO_RAW/files/opencode-mentor.md" -OutFile $agentsFile -UseBasicParsing
    }

    Write-Ok "Mentor-Prompt installiert: $agentsFile"
}

# ══════════════════════════════════════════════════════════════════════════════
# Haupt-Ablauf
# ══════════════════════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "╔══════════════════════════════════════════╗"
Write-Host "║   KidsLab — OpenCode Home-Setup          ║"
Write-Host "╚══════════════════════════════════════════╝"
Write-Host ""
Write-Host "  Betriebssystem : Windows"
Write-Host "  Provider       : OpenRouter (KidsLab AI)"
Write-Host "  Standard-Modell: $DEFAULT_MODEL"

Install-OpenCode
Get-ApiKey
Set-OpenCodeConfig
Set-MentorPrompt

Write-Host ""
Write-Host "════════════════════════════════════════════" -ForegroundColor Green
Write-Ok "Setup abgeschlossen!"
Write-Host ""
Write-Host "  OpenCode starten:  opencode"
Write-Host "  Modell wechseln:   /model  (nur KidsLab-Modelle verfügbar)"
Write-Host ""
