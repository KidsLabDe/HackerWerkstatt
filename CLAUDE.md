# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Projekt-Übersicht

HackerWerkstatt ist ein Kursformat von [KidsLab Augsburg](https://kidslab.de) für Jugendliche (12–18 Jahre). Dieses Repository enthält Setup-Scripts, Anleitungen und Projekte für den Kurs.

## Infrastruktur

- **KI-Provider**: [OpenRouter](https://openrouter.ai) — OpenAI-kompatible API
- **API-Endpunkt**: `https://openrouter.ai/api/v1`
- **Auth**: API-Key (für alle Teilnehmer gemeinsam). Der Key liegt **AES-256-CBC-verschlüsselt** unter `files/opencode.key.enc` im Repo und wird vom Setup-Script mit dem im Kurs bekanntgegebenen Passwort entschlüsselt.
- **Standard-Modell**: `google/gemma-4-26b-a4b-it`
- **Weitere Modelle**: `deepseek/deepseek-chat-v3.1`, `qwen/qwen3-coder-30b-a3b-instruct`, `mistralai/mistral-small-3.2-24b-instruct`

## Setup-Scripts

`setup-client.sh` (macOS/Linux) und `setup-client.ps1` (Windows) sind funktional identisch. Sie:

1. **Installieren OpenCode** — KI-Coding-Tool im Terminal (via `opencode.ai/install` oder npm)
2. **Entschlüsseln den API-Key** — laden `files/opencode.key.enc` und entschlüsseln ihn interaktiv per Passwort (`openssl enc -d -aes-256-cbc -pbkdf2 -base64`)
3. **Konfigurieren OpenCode** (`~/.config/opencode/config.json`) — Provider `kidslab` (OpenRouter) mit den o.g. Modellen
4. **Installieren den Mentor-Prompt** (`~/.config/opencode/AGENTS.md`) aus `files/opencode-mentor.md`

Ausführen:
```bash
# macOS / Linux
bash <(curl -fsSL https://raw.githubusercontent.com/kidslabde/HackerWerkstatt/main/setup-client.sh)

# Windows (PowerShell)
irm https://raw.githubusercontent.com/kidslabde/HackerWerkstatt/main/setup-client.ps1 | iex
```

Das Script fragt interaktiv nach dem **KidsLab-Passwort** (für die Key-Entschlüsselung) und legt bei bestehenden Configs automatisch Backups an (`.bak.YYYYMMDD_HHMMSS`).

## Verzeichnisstruktur

- `setup-client.sh` / `setup-client.ps1` — die zentralen Setup-Scripts
- `files/opencode.key.enc` — verschlüsselter OpenRouter-API-Key
- `files/opencode-mentor.md` — System-Prompt für den KidsLab Coding-Mentor (wird als `AGENTS.md` installiert)

Geplant (laut README, noch nicht angelegt):
- `anleitungen/` — Schritt-für-Schritt-Anleitungen zu den Projekten
- `scripts/` — Hilfreiche Scripts und Code-Vorlagen
- `projekte/` — Beispielprojekte und Lösungen

## Hinweise zur Weiterentwicklung

- Zielgruppe sind Jugendliche ohne Vorkenntnisse — Scripts und Anleitungen sollten entsprechend verständlich sein
- Die Scripts verwenden `set -euo pipefail` (bzw. `$ErrorActionPreference = 'Stop'`) — Fehlerbehandlung ist explizit und wichtig
- Vor Änderungen an den Setup-Scripts: Backup des Originals erstellen (gemäß globalem CLAUDE.md)
- **Nie** den entschlüsselten API-Key oder das Klartext-Passwort ins Repository einchecken — nur die verschlüsselte `.enc`-Datei gehört ins Repo
- Download-Pfade in `.sh` und `.ps1` zeigen auf `files/` — beide Scripts beim Verschieben von Dateien synchron halten
