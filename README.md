# APDIF

APDIF is a shell-first Android Permissions Debugging & Information Framework with a bundled Bubble Tea operator TUI.

## Repo Layout

- `bin/apdif` - primary launcher
- `bin/apdif-menu` - rofi-driven launcher
- `bin/apdif-tui` - direct TUI launcher
- `share/apdif` - shell plugins, collectors, renderers, schemas, tests
- `tui` - bundled Go TUI source
- `contrib` - original overlay/TUI/inthecloset source artifacts preserved from `~/Downloads`

## Common Commands

```bash
./bin/apdif --help
./bin/apdif cheat list
./bin/apdif parser manifest --apk target.apk
./bin/apdif tui build
./bin/apdif tui run
./bin/apdif -intC
```

## Verification

```bash
./share/apdif/tests/run.sh
cd tui && go build ./...
```
