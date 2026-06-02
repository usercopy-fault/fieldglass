# APDIF

APDIF is a shell-first Android Package & Debug Inspection Framework <----> [INSPECT WHAT'S UNDER]


<p align="center">
  <img src="docs/img/apdif-logo.png" alt="APDIF Logo" width="100%">
</p>


# APDIF

**Android Package & Device Inspection Framework**

       > **Motto:** **APDIF, inspect whats _under_**


APDIF is a focused Android security testing CLI for inspecting packages, triaging apps, and building assurance-style reports.

It currently works **best on rooted Android devices**.

---

## What it does

APDIF helps you:

<--- --> inspect Android packages and APK targets
 <---  <--- collect package and device details
  ---->    <--- triage installed apps or APK files
       --->  --> review storage, databases, files, and WebView-related artifacts
           <---->  <--> build final reports from collected case data

It is built for practical Android app security testing and local device inspection workflows.

-------------------------
{                             
## Requirements()                 };

APDIF currently works best with:

- **Rooted Android device**
- `adb`
- shell access
- basic Android utilities available on-device
- a Linux host is recommended for the smoothest workflow

> **Note:** Rooted workflows are the main supported path right now.

------------------------->

## Install

### Clone the repository

```bash
git clone https://github.com/YOUR_USERNAME/apdif.git
cd apdif


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
chmod +x apdif
mkdir -p ~/.local/bin
OPTIO--->NAL --add to $PATH
ln -sf "$PWD/apdif" ~/.local/bin/apdif
cd tui && go build ./...
```
<------------>VERIFY<---------><--or don't-->----<--->
`apdif --help`
     #CMD assist#
` apdif cheat list `
      ---#--->You good ? <---?--->
                 ` apdif device doctor
apdif device doctor --serial SERIAL `
              --- TRIAGE-WORKFLOW ---
`apdif triage run --pkg PKG --case NAME --profile PROFILE
apdif triage run --apk FILE --case NAME --profile PROFILE
apdif triage run --pkg PKG --case NAME --profile PROFILE --json
apdif triage run --pkg PKG --case NAME --profile PROFILE --serial SERIAL`

                 ---BUILD_FINAL_REPORT---
                  
`apdif report build --case NAME --pkg PKG --profile PROFILE
apdif report build --case NAME --pkg PKG --profile PROFILE --format md
apdif report build --case NAME --pkg PKG --profile PROFILE --format json `

