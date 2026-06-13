#!/usr/bin/env bash
# setup-client.sh — Installiert und konfiguriert OpenCode für zu Hause
# Verwendet OpenRouter als KI-Provider (identisch zu KidsLab-Clients)
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
OPENROUTER_BASE="https://openrouter.ai/api/v1"
DEFAULT_MODEL="google/gemma-4-26b-a4b-it"
REPO_RAW="https://raw.githubusercontent.com/kidslabde/HackerWerkstatt/main"

# ── Betriebssystem erkennen ───────────────────────────────────────────────────
detect_os() {
  case "$OSTYPE" in
    darwin*)    echo "macos" ;;
    linux-gnu*) echo "linux" ;;
    *)
      err "Nicht unterstütztes Betriebssystem: $OSTYPE"
      exit 1
      ;;
  esac
}
OS=$(detect_os)

# ══════════════════════════════════════════════════════════════════════════════
# Schritt 1: OpenCode installieren
# ══════════════════════════════════════════════════════════════════════════════
install_opencode() {
  step "OpenCode installieren"

  if command -v opencode &>/dev/null; then
    ok "OpenCode bereits vorhanden ($(opencode version 2>/dev/null | head -1 || echo 'Version unbekannt'))"
    return 0
  fi

  if command -v curl &>/dev/null; then
    echo "  Lade OpenCode via Install-Script..."
    curl -fsSL https://opencode.ai/install | bash
    ok "OpenCode installiert"
    return 0
  fi

  if command -v npm &>/dev/null; then
    echo "  Installiere OpenCode via npm..."
    npm install -g opencode-ai
    ok "OpenCode via npm installiert"
    return 0
  fi

  err "Weder curl noch npm gefunden."
  err "Bitte OpenCode manuell installieren: https://opencode.ai"
  exit 1
}

# ══════════════════════════════════════════════════════════════════════════════
# Schritt 2: API-Key entschlüsseln
# ══════════════════════════════════════════════════════════════════════════════
get_api_key() {
  step "KidsLab-API-Key entschlüsseln"

  # Verschlüsselte Key-Datei: zuerst lokal suchen, sonst aus Repo laden
  local enc_file tmp_file=""
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || script_dir=""

  if [[ -n "$script_dir" && -f "$script_dir/opencode.key.enc" ]]; then
    enc_file="$script_dir/opencode.key.enc"
  else
    tmp_file=$(mktemp)
    trap "rm -f '$tmp_file'" EXIT
    echo "  Lade verschlüsselte Key-Datei..."
    curl -fsSL "${REPO_RAW}/files/opencode.key.enc" -o "$tmp_file"
    enc_file="$tmp_file"
  fi

  echo ""
  if read -rs -p "  KidsLab-Passwort: " VAULT_PASS 2>/dev/null; then
    echo ""
  else
    read -rp "  KidsLab-Passwort: " VAULT_PASS
  fi

  if [[ -z "$VAULT_PASS" ]]; then
    err "Passwort darf nicht leer sein."
    exit 1
  fi

  API_KEY=$(openssl enc -d -aes-256-cbc -pbkdf2 -base64 \
            -in "$enc_file" -pass pass:"$VAULT_PASS" 2>/dev/null || true)

  if [[ -z "$API_KEY" ]]; then
    err "Falsches Passwort — API-Key konnte nicht entschlüsselt werden."
    exit 1
  fi

  ok "API-Key entschlüsselt."
}

# ══════════════════════════════════════════════════════════════════════════════
# Schritt 3: OpenCode konfigurieren
# ══════════════════════════════════════════════════════════════════════════════
configure_opencode() {
  step "OpenCode konfigurieren"

  local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
  local config_file="$config_dir/config.json"
  mkdir -p "$config_dir"

  if [[ -f "$config_file" ]]; then
    local backup="${config_file}.bak.$(date +%Y%m%d_%H%M%S)"
    cp "$config_file" "$backup"
    warn "Backup erstellt: $backup"
  fi

  cat > "$config_file" << JSONEOF
{
  "\$schema": "https://opencode.ai/config.json",
  "provider": {
    "kidslab": {
      "name": "KidsLab AI",
      "npm": "@ai-sdk/openai-compatible",
      "options": {
        "baseURL": "${OPENROUTER_BASE}",
        "apiKey": "${API_KEY}"
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
  "model": "kidslab/${DEFAULT_MODEL}"
}
JSONEOF

  ok "OpenCode konfiguriert: $config_file"
}

# ══════════════════════════════════════════════════════════════════════════════
# Schritt 4: Mentor-Prompt installieren
# ══════════════════════════════════════════════════════════════════════════════
configure_mentor() {
  step "KidsLab Coding-Mentor installieren"

  local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
  local agents_file="$config_dir/AGENTS.md"
  mkdir -p "$config_dir"

  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || script_dir=""

  if [[ -n "$script_dir" && -f "$script_dir/files/opencode-mentor.md" ]]; then
    cp "$script_dir/files/opencode-mentor.md" "$agents_file"
  else
    curl -fsSL "${REPO_RAW}/files/opencode-mentor.md" -o "$agents_file"
  fi

  ok "Mentor-Prompt installiert: $agents_file"
}

# ══════════════════════════════════════════════════════════════════════════════
# Haupt-Ablauf
# ══════════════════════════════════════════════════════════════════════════════
main() {
  echo ""
  echo -e "${BOLD}╔══════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║   KidsLab — OpenCode Home-Setup          ║${NC}"
  echo -e "${BOLD}╚══════════════════════════════════════════╝${NC}"
  echo ""
  echo "  Betriebssystem : $OS"
  echo "  Provider       : OpenRouter (KidsLab AI)"
  echo "  Standard-Modell: ${DEFAULT_MODEL}"

  install_opencode
  get_api_key
  configure_opencode
  configure_mentor

  echo ""
  echo -e "${GREEN}${BOLD}════════════════════════════════════════════${NC}"
  ok "Setup abgeschlossen!"
  echo ""
  echo "  OpenCode starten:  opencode"
  echo "  Modell wechseln:   /model (nur KidsLab-Modelle verfügbar)"
  echo ""
}

main "$@"
