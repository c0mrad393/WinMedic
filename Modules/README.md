# Modules

New WinMedic code lives here, one concern per file. `WMT-GUI.ps1` dot-sources
every `*.ps1` in this folder in filename order at startup.

## Why not refactor the monolith first

`WMT-GUI.ps1` is ~44,000 lines and 630 functions inherited from upstream.
Splitting it wholesale would cost weeks, produce nothing a user can see, and
permanently break `git merge upstream/main`, which is still how this fork picks
up upstream bug fixes.

So the monolith is left alone. New work starts here, and an existing function
moves into a module when it has to be touched anyway. The split happens as a
side effect of doing real work rather than as a project of its own.

## Rules

- Filenames sort: `00-` loads before `10-`, and so on. Prefix accordingly when
  one module depends on another being loaded first.
- Define functions and script-scoped variables. Do not perform work at load
  time - the loader runs before the window exists.
- Modules may call into the monolith (`Get-WmtSettings`, `Get-Ctrl`, ...). Guard
  those calls; the loader also runs during linting, where they do not exist.
- CI holds this folder to a stricter bar than the rest of the repo: any
  PSScriptAnalyzer **warning** here fails the build, while the monolith is only
  gated on errors.

## Packaging

`PS2EXE/Build-Exe.ps1` inlines these files into the script before compiling, so
a single-file `.exe` behaves the same as running from a checkout. The loader
block in `WMT-GUI.ps1` is delimited by `WINMEDIC MODULE LOADER` markers - the
build replaces everything between them with the concatenated module source.
Do not remove those markers.
