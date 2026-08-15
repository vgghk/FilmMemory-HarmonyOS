# FilmMemory HarmonyOS

This repository contains the native HarmonyOS edition of FilmMemory, a local-first app for recording film rolls and their developed photos.

## Stack

- ArkTS, ArkUI, and the Stage model.
- Package name: `com.example.filmmemory`.
- Main source: `entry/src/main/ets/`.
- App resources: `entry/src/main/resources/`.

## Product conventions

- Keep all user data on-device. Do not add account, network, cloud-sync, or social features by default.
- The only roll statuses are `拍摄中` and `冲洗完`.
- Confirm before deleting a roll or a photo.
- Preserve the warm off-white, white-card, soft-green film aesthetic.

## Git workflow — required

- Every intentional modification to source code, configuration, or tracked documentation must be committed to Git before handing work back.
- Keep commits focused and use a concise, descriptive message.
- Never commit local dependencies, IDE state, build outputs, signing materials, debug captures, layout exports, or screenshots.
- Before each commit, inspect `git status` and stage only files belonging to the intended change.
- At the start of every conversation, before changing any file, create a recoverable backup of that file. Prefer the current Git revision or a timestamped backup under `.git`; do not place backup copies in source directories.
- After each intentional change, commit the focused diff and push this HarmonyOS repository to GitHub before handing work back.
- Android and HarmonyOS are separate repositories. Only sync HarmonyOS changes from this directory; never add Android files or nested-repository metadata.

## Build

Run from the repository root:

```powershell
& 'F:\HuaweiHarmony\DevEco Studio\tools\hvigor\bin\hvigorw.bat' --mode module -p product=default -p module=entry@default -p buildMode=debug assembleHap
```
