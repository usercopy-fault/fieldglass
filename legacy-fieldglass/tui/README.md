# APDIF TUI starter

This is a Bubble Tea v2 starter for **APDIF**: Android Permissions Debugging & Information Framework.

It is structured as an operator console rather than a toy demo:

- left pane: workflow navigator
- middle pane: device inventory table
- right pane: markdown-rendered workflow details and command sketches
- bottom pane: operator notes with on-disk persistence
- modal APK picker: intake step for `.apk`, `.apks`, `.xapk`, `.apkm`

## Charm stack used

Runtime:

- `charm.land/bubbletea/v2`
- `charm.land/bubbles/v2/list`
- `charm.land/bubbles/v2/table`
- `charm.land/bubbles/v2/viewport`
- `charm.land/bubbles/v2/textarea`
- `charm.land/bubbles/v2/filepicker`
- `charm.land/bubbles/v2/help`
- `charm.land/bubbles/v2/key`
- `charm.land/bubbles/v2/spinner`
- `charm.land/lipgloss/v2`
- `charm.land/glamour/v2`

Recommended adjacent Charm tooling for the next pass:

- `huh` for a first-run APDIF configuration wizard
- `wish/v2` to expose APDIF over SSH for remote operator access
- `vhs` to record reproducible demos for the repo
- `gum` for shell-side wrappers around APDIF launch and evidence workflows

## Bootstrap

```bash
go mod tidy
go get charm.land/bubbletea/v2@latest
go get charm.land/bubbles/v2@latest
go get charm.land/lipgloss/v2@latest
go get charm.land/glamour/v2@latest
go run .
```

## Current keybinds

- `tab` / `shift+tab` — rotate focus
- `x` — run a canned APDIF workflow step
- `f` — open APK picker
- `ctrl+s` — save notes to `~/.config/apdif/notes.md`
- `r` — refresh demo state
- `?` — toggle help
- `q` — quit

## Next engineering steps

1. Replace mock device rows with a real `adb devices -l` collector.
2. Add package tables for `pm list packages -U -f` output.
3. Add split-APK awareness and package-name extraction.
4. Add Frida hook bundle selectors.
5. Add evidence export and session manifests.
6. Add command runner abstraction so each APDIF workflow produces structured logs.
7. Add a `cmd/apdif-wish` entrypoint for SSH-served TUI sessions.
8. Add `cmd/apdif-init` using `huh` for first-run setup.

## Operator note

This starter deliberately separates:

- **workflow selection**
- **target selection**
- **artifact intake**
- **operator notes**
- **command preview / evidence log**

That separation is what keeps a security TUI from turning into an unstructured terminal skin.
