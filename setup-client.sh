#!/usr/bin/env bash
# setup-client.sh — Installiert und konfiguriert OpenCode + VS Code/Continue
# für den Kidslab Ollama-Server auf kidslab.duckdns.org
set -euo pipefail

# ── Farben ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

ok()   { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC} $*"; }
err()  { echo -e "${RED}✗${NC} $*" >&2; }
step() { echo -e "\n${BLUE}${BOLD}==> $*${NC}"; }

# ── Konstanten ────────────────────────────────────────────────────────────────
KIDSLAB_HOST="kidslab.duckdns.org"
KIDSLAB_BASE="https://${KIDSLAB_HOST}/api-ext"
KIDSLAB_BASE_OPENAI="${KIDSLAB_BASE}/v1"
DEFAULT_USER="kidslab"
DEFAULT_MODEL="qwen3.6:35b-a3b"

# ── Betriebssystem erkennen ───────────────────────────────────────────────────
detect_os() {
  case "$OSTYPE" in
    darwin*)      echo "macos" ;;
    linux-gnu*)   echo "linux" ;;
    *)
      err "Nicht unterstütztes Betriebssystem: $OSTYPE"
      exit 1
      ;;
  esac
}
OS=$(detect_os)

# ── Hilfsfunktion: Base64 ohne Zeilenumbruch ──────────────────────────────────
b64() { echo -n "$1" | base64 | tr -d '\n'; }

# ══════════════════════════════════════════════════════════════════════════════
# Schritt 1: OpenCode installieren
# ══════════════════════════════════════════════════════════════════════════════
install_opencode() {
  step "OpenCode installieren"

  if command -v opencode &>/dev/null; then
    ok "OpenCode bereits vorhanden ($(opencode version 2>/dev/null | head -1 || echo 'Version unbekannt'))"
    return 0
  fi

  # Bevorzugte Methode: offizielles Install-Script
  if command -v curl &>/dev/null; then
    echo "Lade OpenCode via Install-Script herunter..."
    curl -fsSL https://opencode.ai/install | bash
    ok "OpenCode installiert"
    return 0
  fi

  # Fallback: npm (falls curl fehlt)
  if command -v npm &>/dev/null; then
    echo "Installiere OpenCode via npm..."
    npm install -g opencode-ai
    ok "OpenCode via npm installiert"
    return 0
  fi

  err "Weder curl noch npm gefunden."
  err "Bitte OpenCode manuell installieren: https://opencode.ai"
  exit 1
}

# ══════════════════════════════════════════════════════════════════════════════
# Schritt 2 & 3: Zugangsdaten abfragen und kodieren
# ══════════════════════════════════════════════════════════════════════════════
get_credentials() {
  step "Zugangsdaten für ${KIDSLAB_HOST}"

  echo ""
  read -rp "  Benutzername [${DEFAULT_USER}]: " username
  username="${username:-$DEFAULT_USER}"

  echo ""
  # Passwort ohne Echo einlesen
  if read -rs -p "  Passwort: " password 2>/dev/null; then
    echo ""
  else
    # Fallback für Systeme ohne -s
    read -rp "  Passwort: " password
  fi

  if [[ -z "$password" ]]; then
    err "Passwort darf nicht leer sein."
    exit 1
  fi

  # HTTP Basic Auth: base64("user:password")
  AUTH_B64=$(b64 "${username}:${password}")

  # Verbindung testen
  echo ""
  echo "  Teste Verbindung zum Server..."
  local http_status
  http_status=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Basic ${AUTH_B64}" \
    "${KIDSLAB_BASE}/api/tags" 2>/dev/null || echo "000")

  if [[ "$http_status" == "200" ]]; then
    ok "Zugangsdaten korrekt (HTTP $http_status)"
  elif [[ "$http_status" == "000" ]]; then
    warn "Server nicht erreichbar — Konfiguration wird trotzdem gespeichert."
  else
    err "Zugangsdaten ungültig oder Server-Fehler (HTTP $http_status)."
    echo ""
    read -rp "  Trotzdem fortfahren? [j/N]: " confirm
    [[ "${confirm,,}" == "j" ]] || exit 1
  fi
}

# ══════════════════════════════════════════════════════════════════════════════
# Schritt 4: OpenCode konfigurieren
# ══════════════════════════════════════════════════════════════════════════════
configure_opencode() {
  step "OpenCode konfigurieren"

  # Konfig-Verzeichnis je nach OS
  if [[ "$OS" == "macos" ]]; then
    OPENCODE_CONFIG_DIR="$HOME/.config/opencode"
  else
    OPENCODE_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
  fi

  mkdir -p "$OPENCODE_CONFIG_DIR"

  local config_file="$OPENCODE_CONFIG_DIR/config.json"

  # Backup falls Datei bereits existiert
  if [[ -f "$config_file" ]]; then
    local backup="${config_file}.bak.$(date +%Y%m%d_%H%M%S)"
    cp "$config_file" "$backup"
    warn "Bestehendes Backup: $backup"
  fi

  cat > "$config_file" << JSONEOF
{
  "\$schema": "https://opencode.ai/config.json",
  "provider": {
    "kidslab": {
      "name": "Kidslab Ollama",
      "npm": "@ai-sdk/openai-compatible",
      "options": {
        "baseURL": "${KIDSLAB_BASE_OPENAI}",
        "headers": {
          "Authorization": "Basic ${AUTH_B64}"
        }
      },
      "models": {
        "qwen3.6:35b-a3b": {
          "name": "Qwen 3.6 35B MoE"
        },
        "gemma4:31b": {
          "name": "Gemma 4 31B"
        },
        "Mistral-Small:24b": {
          "name": "Mistral Small 24B"
        }
      }
    }
  },
  "model": "kidslab/${DEFAULT_MODEL}"
}
JSONEOF

  ok "OpenCode: $config_file"
}

# ══════════════════════════════════════════════════════════════════════════════
# Schritt 5: VS Code / Continue-Extension konfigurieren
# ══════════════════════════════════════════════════════════════════════════════
configure_vscode() {
  step "VS Code / Continue-Extension prüfen"

  # Prüfen ob VS Code installiert ist
  local code_found=false
  command -v code &>/dev/null      && code_found=true
  command -v code-insiders &>/dev/null && code_found=true
  [[ -d "/Applications/Visual Studio Code.app" ]] && code_found=true
  [[ -d "$HOME/.vscode" ]] && code_found=true
  [[ -d "$HOME/.continue" ]] && code_found=true  # Continue schon mal benutzt

  if [[ "$code_found" == "false" ]]; then
    warn "VS Code nicht gefunden — überspringe VS Code-Konfiguration."
    return 0
  fi

  local continue_dir="$HOME/.continue"
  local continue_config="$continue_dir/config.json"

  mkdir -p "$continue_dir"

  # Backup falls Datei bereits existiert
  if [[ -f "$continue_config" ]]; then
    local backup="${continue_config}.bak.$(date +%Y%m%d_%H%M%S)"
    cp "$continue_config" "$backup"
    warn "Bestehendes Backup: $backup"
  fi

  cat > "$continue_config" << JSONEOF
{
  "models": [
    {
      "title": "Qwen 3.6 35B MoE (Kidslab)",
      "provider": "ollama",
      "model": "qwen3.6:35b-a3b",
      "apiBase": "${KIDSLAB_BASE}",
      "requestOptions": {
        "headers": {
          "Authorization": "Basic ${AUTH_B64}"
        }
      }
    },
    {
      "title": "Gemma 4 31B (Kidslab)",
      "provider": "ollama",
      "model": "gemma4:31b",
      "apiBase": "${KIDSLAB_BASE}",
      "requestOptions": {
        "headers": {
          "Authorization": "Basic ${AUTH_B64}"
        }
      }
    },
    {
      "title": "Mistral Small 24B (Kidslab)",
      "provider": "ollama",
      "model": "Mistral-Small:24b",
      "apiBase": "${KIDSLAB_BASE}",
      "requestOptions": {
        "headers": {
          "Authorization": "Basic ${AUTH_B64}"
        }
      }
    }
  ],
  "tabAutocompleteModel": {
    "title": "Qwen 3.6 35B MoE (Kidslab)",
    "provider": "ollama",
    "model": "qwen3.6:35b-a3b",
    "apiBase": "${KIDSLAB_BASE}",
    "requestOptions": {
      "headers": {
        "Authorization": "Basic ${AUTH_B64}"
      }
    }
  }
}
JSONEOF

  ok "Continue-Extension: $continue_config"

  # Continue-Extension installieren falls code-Befehl verfügbar
  if command -v code &>/dev/null; then
    echo "  Installiere Continue-Extension..."
    code --install-extension continue.continue && ok "Continue-Extension installiert" || warn "Extension-Installation fehlgeschlagen — bitte manuell installieren"
  elif command -v code-insiders &>/dev/null; then
    echo "  Installiere Continue-Extension (Insiders)..."
    code-insiders --install-extension continue.continue && ok "Continue-Extension installiert" || warn "Extension-Installation fehlgeschlagen — bitte manuell installieren"
  else
    echo ""
    echo "  Falls Continue noch nicht installiert:"
    echo "  VS Code → Extensions → 'Continue' (continue.dev) suchen und installieren"
  fi
}

# ══════════════════════════════════════════════════════════════════════════════
# Haupt-Ablauf
# ══════════════════════════════════════════════════════════════════════════════
main() {
  echo ""
  echo -e "${BOLD}╔══════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║   Kidslab Ollama — Client-Setup          ║${NC}"
  echo -e "${BOLD}╚══════════════════════════════════════════╝${NC}"
  echo ""
  echo "  Betriebssystem : $OS"
  echo "  Server         : ${KIDSLAB_HOST}"
  echo "  Standard-Modell: ${DEFAULT_MODEL}"

  install_opencode
  get_credentials
  configure_opencode
  configure_vscode

  echo ""
  echo -e "${GREEN}${BOLD}════════════════════════════════════════════${NC}"
  ok "Setup abgeschlossen!"
  echo ""
  echo "  OpenCode starten:    opencode"
  echo "  Standard-Modell:     kidslab/${DEFAULT_MODEL}"
  echo ""
  echo "  VS Code:             Continue-Extension (Cmd+L / Ctrl+L)"
  echo ""
}

main "$@"
