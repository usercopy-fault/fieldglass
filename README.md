# APDIF

APDIF is the Android Permissions Debugging & Information Framework: a standalone Python CLI for Android application security triage. It collects adb evidence, APK artifacts, static indicators, dynamic runtime snapshots, findings, confidence scoring, and Markdown/JSON reports.

Command grammar: `(cmd){options}[flags]`

Example: `apdif triage run {--pkg PKG --case CASE} [--profile deep --json --serial SERIAL]`

## Requirements

Required: Python 3.10+, adb / android-tools, strings.

Recommended: aapt, jadx, frida-tools, jq, ripgrep, sqlite.

Arch examples:

    sudo pacman -S android-tools android-sdk-build-tools jq ripgrep fd sqlite
    yay -S jadx-bin
    python -m pip install --user frida-tools

## Install

Development:

    git clone https://github.com/<your-user>/apdif.git
    cd apdif
    python -m pip install -e .

User install:

    cd apdif
    python -m pip install .

PATH note:

    export PATH="$HOME/.local/bin:$PATH"

## Usage examples

    apdif --help
    apdif doctor
    apdif device --json
    apdif case create --case demo
    apdif app permissions --pkg com.example.app --case demo
    apdif app pull-apk --pkg com.example.app --case demo
    apdif static ~/cases/android/demo/apk/com.example.app.apk --case demo --json
    apdif dynamic all --pkg com.example.app --case demo
    apdif intent hints --pkg com.example.app
    apdif triage run --pkg com.example.app --case demo --profile baseline
    apdif report --case demo
    apdif confidence --case demo --json

## Case directory layout

    ~/cases/android/<case>/
      apk/ static/ dynamic/ evidence/ frida/ notes/ reports/
      case.json controls.json findings.jsonl

## Development

    cd ~/apdif
    python -m pip install -e .
    python -m pip install pytest
    python -m compileall apdif
    python -m pytest -q

## Troubleshooting

- adb not found: install android-tools and ensure adb is on PATH.
- No devices listed: run adb devices -l and authorize the host on the device.
- aapt/jadx/frida not found: those integrations are skipped until installed.
- apdif command not found: install the package or add $HOME/.local/bin to PATH.
