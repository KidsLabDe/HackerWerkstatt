#Requires -Version 5.1
# setup-client.ps1 — Installiert und konfiguriert OpenCode + VS Code/Continue
# für den Kidslab Ollama-Server auf kidslab.duckdns.org
#
# Ausführen (direkt aus dem Web — PowerShell als Admin nicht nötig):
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
$KIDSLAB_HOST        = "kidslab.duckdns.org"
$KIDSLAB_BASE        = "https://$KIDSLAB_HOST/api-ext"
$KIDSLAB_BASE_OPENAI = "$KIDSLAB_BASE/v1"
$DEFAULT_USER        = "kidslab"
$DEFAULT_MODEL       = "gemma4:31b"

# ── Hilfsfunktion: Base64 ─────────────────────────────────────────────────────
function ConvertTo-Base64Credentials {
    param([string]$user, [string]$password)
    [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("${user}:${password}"))
}

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

    # Bevorzugte Methode: npm
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        Write-Host "  Installiere OpenCode via npm..."
        npm install -g opencode-ai
        if ($LASTEXITCODE -eq 0) {
            Write-Ok "OpenCode via npm installiert"
            return
        }
        Write-Warn "npm-Installation fehlgeschlagen, versuche winget..."
    }

    # Fallback: winget (Windows 11 / aktuelles Windows 10)
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "  Installiere OpenCode via winget..."
        winget install opencode --silent --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -eq 0) {
            Write-Ok "OpenCode via winget installiert"
            return
        }
    }

    Write-Err "OpenCode konnte nicht automatisch installiert werden."
    Write-Err "Bitte OpenCode manuell installieren: https://opencode.ai"
    exit 1
}

# ══════════════════════════════════════════════════════════════════════════════
# Schritt 2: Zugangsdaten abfragen und kodieren
# ══════════════════════════════════════════════════════════════════════════════
function Get-KidslabCredentials {
    Write-Step "Zugangsdaten für $KIDSLAB_HOST"

    Write-Host ""
    $username = Read-Host "  Benutzername [$DEFAULT_USER]"
    if ([string]::IsNullOrEmpty($username)) { $username = $DEFAULT_USER }

    Write-Host ""
    $securePass = Read-Host "  Passwort" -AsSecureString
    $bstr       = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePass)
    $password   = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)

    if ([string]::IsNullOrEmpty($password)) {
        Write-Err "Passwort darf nicht leer sein."
        exit 1
    }

    $script:AUTH_B64 = ConvertTo-Base64Credentials $username $password

    # Verbindung testen
    Write-Host ""
    Write-Host "  Teste Verbindung zum Server..."
    try {
        $response = Invoke-WebRequest `
            -Uri "$KIDSLAB_BASE/api/tags" `
            -Headers @{ Authorization = "Basic $script:AUTH_B64" } `
            -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        Write-Ok "Zugangsdaten korrekt (HTTP $($response.StatusCode))"
    }
    catch {
        $code = $_.Exception.Response.StatusCode.value__
        if (-not $code) {
            Write-Warn "Server nicht erreichbar — Konfiguration wird trotzdem gespeichert."
        }
        else {
            Write-Err "Zugangsdaten ungültig oder Server-Fehler (HTTP $code)."
            Write-Host ""
            $confirm = Read-Host "  Trotzdem fortfahren? [j/N]"
            if ($confirm.ToLower() -ne "j") { exit 1 }
        }
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# Schritt 3: OpenCode konfigurieren
# ══════════════════════════════════════════════════════════════════════════════
function Set-OpenCodeConfig {
    Write-Step "OpenCode konfigurieren"

    # OpenCode nutzt auf allen Plattformen ~/.config/opencode (XDG-Konvention)
    $configDir  = Join-Path $HOME ".config\opencode"
    $configFile = Join-Path $configDir "config.json"

    New-Item -ItemType Directory -Force -Path $configDir | Out-Null

    if (Test-Path $configFile) {
        $backup = "$configFile.bak.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Copy-Item $configFile $backup
        Write-Warn "Bestehendes Backup: $backup"
    }

    @"
{
  "`$schema": "https://opencode.ai/config.json",
  "provider": {
    "kidslab": {
      "name": "Kidslab Ollama",
      "npm": "@ai-sdk/openai-compatible",
      "options": {
        "baseURL": "$KIDSLAB_BASE_OPENAI",
        "headers": {
          "Authorization": "Basic $script:AUTH_B64"
        }
      },
      "models": {
        "gemma4:31b": {
          "name": "Gemma 4 31B"
        },
        "qwen3.6:35b-a3b": {
          "name": "Qwen 3.6 35B MoE"
        },
        "qwen3-coder:30b": {
          "name": "Qwen3 Coder 30B"
        }
      }
    }
  },
  "model": "kidslab/$DEFAULT_MODEL"
}
"@ | Set-Content -Path $configFile -Encoding UTF8

    Write-Ok "OpenCode: $configFile"
}

# ══════════════════════════════════════════════════════════════════════════════
# Schritt 4: VS Code / Continue-Extension konfigurieren
# ══════════════════════════════════════════════════════════════════════════════
function Set-ContinueConfig {
    Write-Step "VS Code / Continue-Extension prüfen"

    $codeFound = $false
    if (Get-Command code          -ErrorAction SilentlyContinue) { $codeFound = $true }
    if (Get-Command code-insiders -ErrorAction SilentlyContinue) { $codeFound = $true }
    if (Test-Path (Join-Path $HOME ".vscode"))                    { $codeFound = $true }
    if (Test-Path (Join-Path $HOME ".continue"))                  { $codeFound = $true }

    if (-not $codeFound) {
        Write-Warn "VS Code nicht gefunden — überspringe VS Code-Konfiguration."
        return
    }

    $continueDir    = Join-Path $HOME ".continue"
    $continueConfig = Join-Path $continueDir "config.json"

    New-Item -ItemType Directory -Force -Path $continueDir | Out-Null

    if (Test-Path $continueConfig) {
        $backup = "$continueConfig.bak.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Copy-Item $continueConfig $backup
        Write-Warn "Bestehendes Backup: $backup"
    }

    @"
{
  "models": [
    {
      "title": "Gemma 4 31B (Kidslab)",
      "provider": "ollama",
      "model": "gemma4:31b",
      "apiBase": "$KIDSLAB_BASE",
      "requestOptions": {
        "headers": {
          "Authorization": "Basic $script:AUTH_B64"
        }
      }
    },
    {
      "title": "Qwen 3.6 35B MoE (Kidslab)",
      "provider": "ollama",
      "model": "qwen3.6:35b-a3b",
      "apiBase": "$KIDSLAB_BASE",
      "requestOptions": {
        "headers": {
          "Authorization": "Basic $script:AUTH_B64"
        }
      }
    },
    {
      "title": "Qwen3 Coder 30B (Kidslab)",
      "provider": "ollama",
      "model": "qwen3-coder:30b",
      "apiBase": "$KIDSLAB_BASE",
      "requestOptions": {
        "headers": {
          "Authorization": "Basic $script:AUTH_B64"
        }
      }
    }
  ],
  "tabAutocompleteModel": {
    "title": "Qwen3 Coder 30B (Kidslab)",
    "provider": "ollama",
    "model": "qwen3-coder:30b",
    "apiBase": "$KIDSLAB_BASE",
    "requestOptions": {
      "headers": {
        "Authorization": "Basic $script:AUTH_B64"
      }
    }
  }
}
"@ | Set-Content -Path $continueConfig -Encoding UTF8

    Write-Ok "Continue-Extension: $continueConfig"

    $codeCmd = $null
    if     (Get-Command code          -ErrorAction SilentlyContinue) { $codeCmd = "code" }
    elseif (Get-Command code-insiders -ErrorAction SilentlyContinue) { $codeCmd = "code-insiders" }

    if ($codeCmd) {
        Write-Host "  Installiere Continue-Extension..."
        & $codeCmd --install-extension continue.continue
        if ($LASTEXITCODE -eq 0) { Write-Ok "Continue-Extension installiert" }
        else { Write-Warn "Extension-Installation fehlgeschlagen — bitte manuell installieren" }
    }
    else {
        Write-Host ""
        Write-Host "  Falls Continue noch nicht installiert:"
        Write-Host "  VS Code → Extensions → 'Continue' (continue.dev) suchen und installieren"
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# Haupt-Ablauf
# ══════════════════════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "╔══════════════════════════════════════════╗"
Write-Host "║   Kidslab Ollama — Client-Setup          ║"
Write-Host "╚══════════════════════════════════════════╝"
Write-Host ""
Write-Host "  Betriebssystem : Windows"
Write-Host "  Server         : $KIDSLAB_HOST"
Write-Host "  Standard-Modell: $DEFAULT_MODEL"

Install-OpenCode
Get-KidslabCredentials
Set-OpenCodeConfig
Set-ContinueConfig

Write-Host ""
Write-Host "════════════════════════════════════════════" -ForegroundColor Green
Write-Ok "Setup abgeschlossen!"
Write-Host ""
Write-Host "  OpenCode starten:    opencode"
Write-Host "  Standard-Modell:     kidslab/$DEFAULT_MODEL"
Write-Host ""
Write-Host "  VS Code:             Continue-Extension (Ctrl+L)"
Write-Host ""
