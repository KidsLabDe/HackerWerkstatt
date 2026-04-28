# HackerWerkstatt 🔧

**Technik verstehen, nicht nur benutzen.**

Dieses Repository ist der zentrale Sammelpunkt für alle Materialien der HackerWerkstatt – Anleitungen, Scripts, Projekte und alles, was Teilnehmer brauchen.

---

## Was ist die HackerWerkstatt?

Die HackerWerkstatt ist ein praxisorientiertes Kursformat von [KidsLab Augsburg](https://kidslab.de) für junge Menschen ab 12 Jahren. Hier wird gebaut, programmiert und experimentiert – immer mit dem Ziel, Technik wirklich zu verstehen.

**Kein Vorwissen nötig. Nur Neugier.**

## Für wen?

- Alter: 12–18 Jahre
- Vorkenntnisse: keine erforderlich
- Motto: Machen statt konsumieren

## Themen & Inhalte

Die HackerWerkstatt läuft in Blöcken von 4–6 Wochen, jeweils mit einem Schwerpunktthema, zum Beispiel:

- Hardware & Mikrocontroller (z. B. LED-Pixel-Art)
- Künstliche Intelligenz & Programmierung
- Web-Entwicklung

## Infos zum Kurs

| | |
|---|---|
| **Zeit** | Freitags 15:00–16:30 Uhr |
| **Ort** | KidsLab Augsburg, Herrenhäuser 17 |
| **Kosten** | 120 € pro Block (Ermäßigung: 60 €, auf Anfrage kostenlos) |
| **Materialien** | werden gestellt – eigener Laptop kann mitgebracht werden |

Mehr Infos und Anmeldung: [kidslab.de/kurse/hackerwerkstatt](https://kidslab.de/kurse/hackerwerkstatt/)

---

## Inhalt dieses Repositories

```
HackerWerkstatt/
├── anleitungen/    # Schritt-für-Schritt-Anleitungen zu den Projekten
├── scripts/        # Hilfreiche Scripts und Code-Vorlagen
└── projekte/       # Beispielprojekte und Lösungen
```

## Mitmachen

Du hast etwas gebaut oder eine Anleitung verbessert? Pull Requests sind willkommen!

---

## Coding-Tools einrichten

Diese Scripts installieren und konfigurieren **OpenCode** und die VS-Code-Extension **Continue** für den KidsLab-Ollama-Server. Du brauchst dein KidsLab-Passwort (bekommst du im Kurs).

### macOS / Linux

Terminal öffnen und diesen Einzeiler eingeben:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/kidslabde/HackerWerkstatt/main/setup-client.sh)
```

### Windows

**PowerShell** öffnen (Suche → `powershell` → Enter) und diesen Einzeiler eingeben:

```powershell
irm https://raw.githubusercontent.com/kidslabde/HackerWerkstatt/main/setup-client.ps1 | iex
```

> **Hinweis:** Falls eine Fehlermeldung zu Ausführungsrichtlinien erscheint, diesen Befehl zuerst ausführen:
> ```powershell
> Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
> ```

### Was passiert beim Setup?

1. **OpenCode** wird installiert (KI-Coding-Assistent im Terminal)
2. **Continue** (VS Code Extension) wird installiert und konfiguriert
3. Beide Tools werden mit dem KidsLab-Server verbunden

Vorhandene Konfigurationsdateien werden automatisch gesichert (`.bak`-Datei).

---

[KidsLab Augsburg](https://kidslab.de) | [Kurs-Seite](https://kidslab.de/kurse/hackerwerkstatt/)
