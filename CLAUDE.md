# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Projekt-Übersicht

HackerWerkstatt ist ein Kursformat von [KidsLab Augsburg](https://kidslab.de) für Jugendliche (12–18 Jahre). Dieses Repository enthält Setup-Scripts, Anleitungen und Projekte für den Kurs.

## Infrastruktur

- **KidsLab-Ollama-Server**: `kidslab.duckdns.org` — stellt LLM-Modelle via OpenAI-kompatibler API bereit
- **API-Endpunkt**: `https://kidslab.duckdns.org/api-ext/v1` (OpenAI-kompatibel)
- **Auth**: HTTP Basic Auth (Base64-kodiert)
- **Modelle**: `qwen3.6:35b-a3b` (Standard), `gemma4:31b`, `Mistral-Small:24b`

## setup-client.sh

Das zentrale Script. Es installiert und konfiguriert auf macOS und Linux:

1. **OpenCode** (`~/.config/opencode/config.json`) — KI-Coding-Tool im Terminal
2. **VS Code Continue-Extension** (`~/.continue/config.json`) — KI-Assistent in VS Code

Ausführen:
```bash
bash setup-client.sh
# oder remote:
bash <(curl -fsSL https://raw.githubusercontent.com/kidslabde/HackerWerkstatt/main/setup-client.sh)
```

Das Script fragt interaktiv nach Benutzername und Passwort, testet die Verbindung und legt bei bestehenden Configs automatisch Backups an (`.bak.YYYYMMDD_HHMMSS`).

## Geplante Verzeichnisstruktur

Laut README (noch nicht angelegt):
- `anleitungen/` — Schritt-für-Schritt-Anleitungen zu den Projekten
- `scripts/` — Hilfreiche Scripts und Code-Vorlagen
- `projekte/` — Beispielprojekte und Lösungen

## Hinweise zur Weiterentwicklung

- Zielgruppe sind Jugendliche ohne Vorkenntnisse — Scripts und Anleitungen sollten entsprechend verständlich sein
- Das Script verwendet `set -euo pipefail` — Fehlerbehandlung ist explizit und wichtig
- Vor Änderungen an `setup-client.sh`: Backup des Original-Scripts erstellen (gemäß globalem CLAUDE.md)
- Konfigurationsdateien enthalten Auth-Credentials (Base64) — nie ins Repository einchecken
