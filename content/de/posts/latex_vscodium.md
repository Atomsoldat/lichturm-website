---
title: "20241014_latex_vscodium"
date: 2024-10-14T08:58:10+02:00
draft: true
tags: [Typographie, LaTeX]
---

Wenn du noch keine Entwicklungsumgebung für Latex gefunden hast, die dir gefällt, könnte das Folgende für dich einen Versuch wert sein.
Am Ende der Anleitung werden wir eine vollwertige Entwicklungsumgebung mit automatischer Dokumentenerstellung, Autovervollständigung und
Synctex-Unterstützung haben, um zwischen Quelltext und den entsprechenden Stellen im Dokument zu wechseln.


VSCodium mit LaTeX-Erweiterung

https://vscodium.com/
https://github.com/James-Yu/LaTeX-Workshop
Zuerst einmal müssen wir VSCodium installieren. und die Erweiterung LaTeX-Workshop wird auch gebraucht. 

*VSCodium basiert auf dem Quellcode von VSCode, aber beinhaltet keine proprietären Komponenten und deaktiviter standardmäßig Telemetrie. Wer will, kann aber auch VSCode verwenden.*

## LaTeX VSCodium Plugin Stuff
The Latex Plugin basically defines a tool, that tool gets used in a recipe, and that recipe is then selected e.g. by setting it as the default recipe.
Thats as deep as i felt like reading into the docs for now.
See [here](https://github.com/James-Yu/LaTeX-Workshop/wiki/), if we need to go deeper into the rabbit hole.


### Multifile setup
Falls
The plugin will think that the file containing the document class is the main file

This comment helps with that. There are also other ways to configure this, see [here](https://github.com/James-Yu/LaTeX-Workshop/wiki/Compile#multi-file-projects)
```
% !TeX root = main.tex
```

### Building
I added configuration to build the project both with latexmk (magic black box wrapper script that tries to be smart and only compiles what is needed) and lualatex (for when things break and you just want to see where it goes wrong without any extra layers of weirdness). `lualatex` seems to be working fine for the time being, but just in case we need it later, its there.


### Synctex
Other pdf viewers are supported, so [take a look at the docs](https://github.com/James-Yu/LaTeX-Workshop/wiki/View#synctex) in case you want to give a different one a try.
Using Synctex, we can jump back and forth between our IDE and the pdf viewer to the element underneath our cursor. 

- Jumping from VSCodium to the pdf  is done via  `CTRL + ALT + J`. Our `.vscode/settings.json` contains the necessary config
- Jumping from Okular to VSCodium requires some configuration in Okular itself.
  - Under `Settings > Configure Okular... > Editor` configure a custom editor and set its command to `codium -r --goto %f:%l` (or code, in case you use VSCode)
  - Now you can enter Browsing Mode (`Tools > Browse` or `CTRL + 1`) and navigate back to your Latex code using `SHIFT + LMOUSE`



## Build Configuration

## Synctex
Synctex erlaubt es, zwischen Elementen im Quellcode und im kompilierten PDF hin- und herzuspringen. Wenn man größere Dateien, wie ein Buch, bearbeitet,
hilft das sehr bei der Fehlerbehebung, oder wenn man die entsprechende Stelle einfach mal in der fertigen Ausführung sehen möchte.

Damit wir es benutzen können müssen wir:
  - Unsere Entwicklungsumgebung so konfigurieren, dass sie etwas mit Synctex anfangen kann
  - Unseren PDF-Leser konfigurieren, damit er etwas mit Synctex anfangen kann
  - In unserem Bauprozess die  `--synctex` Option an LaTeX übergeben.

Die meisten üblichen PDF-Leser auf Linux werden unterstützt. Ich habe in diesem Fall Okular genommen.

Mit der Tastenkombination `abc` springen wir dann aus dem Quellcode in das Dokument, und mit `def` wieder zurück.

### Configuring the PDF reader
