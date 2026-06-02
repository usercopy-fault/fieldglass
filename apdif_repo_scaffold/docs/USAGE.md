# APDIF Usage

## Basic flow

```bash
apdif device doctor
apdif cheat list
apdif triage run --pkg PKG --case NAME --profile PROFILE
apdif report build --case NAME --pkg PKG --profile PROFILE --format md
```

## Command grammar

```text
apdif cheat list{}[]
apdif device doctor{}[--serial SERIAL]
apdif triage run{--pkg PKG | --apk FILE --case NAME --profile PROFILE}[--json --serial SERIAL]
apdif report build{--case NAME --pkg PKG --profile PROFILE}[--format md|json]
```

## Notes

APDIF works best with root at this stage. Non-root workflows may produce partial output depending on Android version, package permissions, and device policy.
