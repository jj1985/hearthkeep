# Godot APK export — your help, please

I got the entire Android pipeline configured:

- ✅ JDK 17 installed at `/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home`
- ✅ Android SDK installed at `/opt/homebrew/share/android-commandlinetools` with `platform-tools`, `build-tools;34.0.0`, `platforms;android-34`
- ✅ Debug keystore generated at `~/.android/debug.keystore` (alias `androiddebugkey`, password `android`)
- ✅ Godot 4.6.2 export templates downloaded + extracted to `~/Library/Application Support/Godot/export_templates/4.6.2.stable/`
- ✅ `editor_settings-4.6.tres` configured with all four Android paths
- ✅ `export_presets.cfg` set to arm64-v8a, mobile renderer, debug-signed, package `com.hearthkeep.demo`, sensor orientation

**But:** `godot --headless --export-debug "Android" build/HearthkeepDemo-v0.0.1.apk` fails with the unhelpfully generic:

```
ERROR: Cannot export project with preset "Android" due to configuration errors:
ERROR: Project export for preset "Android" failed.
```

…and refuses to print which option is misconfigured.  I've tried filling `gradle_build/min_sdk=24`, `gradle_build/target_sdk=34`, copying editor settings between `editor_settings-4.tres` and `editor_settings-4.6.tres`, etc.

## What I need from you (60 seconds)

1. Open Godot:  `open -a /Applications/Godot.app /Users/user/norrath-roguelike`
2. Wait for Project Manager → click **Edit** on Hearthkeep Demo (or open `project.godot`).
3. **Project → Export…**
4. Click the **Android** preset on the left; the dialog will surface the specific config error(s) that's blocking export — usually one of:
   - "Java SDK path must be set" → it'll auto-detect from `editor_settings-4.6.tres`, but may need a re-confirm: Editor → Editor Settings → Export → Android, set the Java path to `/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home`.
   - "Android SDK path must be set" → Editor Settings, set Android SDK path to `/opt/homebrew/share/android-commandlinetools`.
   - "Debug keystore not found" → Editor Settings, point Debug keystore at `/Users/user/.android/debug.keystore` (user `androiddebugkey`, password `android`).
   - Sometimes it complains about the export-template — there should be a green checkmark next to "Android" in the export dialog header. If not, click "Manage Export Templates" and confirm `4.6.2.stable` is listed.
5. Once the export dialog has no warnings, click **Export Project** at the bottom, save as `build/HearthkeepDemo-v0.0.1.apk` in this repo.

**OR** quicker path — once the editor's surfaced the specific error:

```
cd /Users/user/norrath-roguelike
make apk
```

…will then succeed via the same headless command.

## Quicker still

If the GUI export works, please drop the APK at `build/HearthkeepDemo-v0.0.1.apk` and let me know.  I'll rebuild the docs around the working APK and continue.

If it doesn't work and the GUI surfaces a specific error, paste it back and I'll fix it.
