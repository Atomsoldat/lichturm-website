---
title: "LaTeX-Entwicklung mit VSCodium"
date: 2024-10-14T08:58:10+02:00
tags: [Typographie, LaTeX]
---

Wenn der geneigte Leser noch keine Entwicklungsumgebung für Latex gefunden hat, die ihm gefällt, könnte das Folgende einen Versuch wert sein.
Am Ende der Anleitung werden wir eine vollwertige Entwicklungsumgebung mit automatischer Dokumentenerstellung, Autovervollständigung und
Synctex-Unterstützung haben, um zwischen Quelltext und den entsprechenden Stellen im generierten Dokument zu wechseln.

Zuerst einmal müssen wir [VSCodium](https://vscodium.com/) installieren. Die Erweiterung [LaTeX-Workshop](https://github.com/James-Yu/LaTeX-Workshop) wird ebenso gebraucht (das funktioniert wie sonst auch über den Menüpunkt für Erweiterungen). 

*VSCodium basiert auf dem Quellcode von VSCode, aber beinhaltet keine proprietären Komponenten und deaktiviert standardmäßig Telemetrie. Wer damit glücklicher ist, kann aber auch VSCode verwenden.*

## Konfiguration der LaTeX-Erweiterung für VSCodium
In der Konfiguration für die Erweiterung definieren wir unter `latex-workshop.latex.recipes` ein "Rezept", welches wir aufrufen wollen. Zu jedem Rezept gehört eine Liste aus Werkzeugen, die darin verwendert werden.
Diese  Werkzeuge werden unter `latex-workshop.latex.tools` in Form von Kommandos und Argumenten definiert.
Das Ganze ähnelt in dieser Hinsicht dem altbekannten make sehr.
Zum Schluss gibt es dann noch einige weitere Optionen, die wir definieren, zum Beispiel, dass wir Okular zum Anzeigen unseres Dokumentes verwenden wollen, oder wann, und wie oft unser Dokument neu generiert werden soll.
Je nachdem,

- was man für ein Dokument bearbeitet (es ist sicherlich nicht hilfreich alle paar Sekunden einen neuen Bauprozess anzustoßen, wenn dieser sehr lange dauert)
- welchen PDF-Leser man verwendet, und wie dieser aufgerufen werden soll

werden sich diese unterscheiden. Es sei also auf die [sehr ausführliche Dokumentation](https://github.com/James-Yu/LaTeX-Workshop/wiki/) verwiesen.

```JSON
{
    "latex-workshop.latex.recipes": [
        {
            "name": "lualatex",
            "tools": [
                "lualatex"
            ]
        }
    ],
    "latex-workshop.latex.tools": [
        {
            "name": "lualatex",
            "command": "lualatex",
            "args": [
                "-synctex=1",
                "-halt-on-error",
                "-file-line-error",
                "-output-directory=%OUTDIR%",
                "%DOC%"
            ],
            "env": {}
        }
    ],
    "latex-workshop.latex.recipe.default": "lualatex",
    "latex-workshop.latex.outDir": "../build",
    "latex-workshop.latex.autoBuild.run": "onSave",
    "latex-workshop.latex.autoBuild.interval": 10000,
    "latex-workshop.latex.autoBuild.cleanAndRetry.enabled": false,

    "latex-workshop.synctex.afterBuild.enabled": true,
    "latex-workshop.view.pdf.viewer": "external",
    "latex-workshop.view.pdf.external.viewer.command": "okular",
    "latex-workshop.view.pdf.external.viewer.args": [
        "--unique",
        "%PDF%"
],
"latex-workshop.view.pdf.external.synctex.command": "okular",
"latex-workshop.view.pdf.external.synctex.args": [
    "--unique",
    "%PDF%#src:%LINE%%TEX%"
],
}
```

### Arbeiten mit Dokumenten aus mehreren Dateien
Die LaTeX-Erweiterung geht davon aus, dass die Datei mit dem `\documentclass{...}`-Kommando die Hauptdatei ist, die kompiliert werden soll. Es gibt eine Rangfolge an Dateien,
die abgefragt werden um diese Datei zu finden. Falls der Automatismus nicht funktioniert, gibt es [hier](https://github.com/James-Yu/LaTeX-Workshop/wiki/Compile#multi-file-projects) verschiedene Möglichkeiten, darauf Einfluss zu nehmen.

### Dokumentenerstellung
In diesem Beispiel wird lualatex zum Erstellen des PDF-Dokumentes verwendet, aber man kann natürlich das Werkzeug seiner Wahl einsetzen. Um den Bauprozess manuell zu starten, drückt man `STRG+ALT+B`. In der oben angegebenen Konfiguration wird
das Dokument auch jedes Mal, wenn man den Quelltext speichert, neu erstellt.

### Synctex
Nun geht es  darum, dass wir zwischen Stellen im Quelltext und den entsprechenden Stellen im erstellen Dokument hin- und herwechseln. Das ist sehr hilfreich, wenn man  lange Dokumente bearbeitet,
weil das Aufsuchen der interessanten Stelle entfällt. In unserer obigen Konfiguration wird dazu Okular verwendet, aber andere Programme [können auch genutzt werden](https://github.com/James-Yu/LaTeX-Workshop/wiki/View#synctex).
Das Wechseln funktioniert wie folgt:

- Um von VSCodium in das PDF zu springen, drückt man `STRG + ALT + J`. 
- Um von Okular zurück in VSCodium zu springen, muss noch etwas Konfiguration erfolgen:
  - Unter `Einstellungen > Okular einrichten ... > Editor` wählen wir einen benutzerdefinierten Editor und setzen das Kommando auf `codium -r --goto %f:%l` (oder `code`, im Falle von VSCode)
  - Jetzt wechselt man in den "Durchsuchen" Modus (`Extras > Durchsuchen` oder `STRG + 1`) und  springt zurück in  den Quelltext durch `UMSCHALT + Linksklick`


Und damit haben wir nun eine  sehr komfortable Umgebung, um an unseren LaTeX-Dokumenten zu arbeiten.
