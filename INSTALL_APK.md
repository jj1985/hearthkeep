# HEARTHKEEP — Sideload the APK

This is a debug-signed APK for sideload onto your own Android phone.  It is not on the Play Store.  You will see "unknown developer" warnings when you install — that's expected.

## Path A — over USB cable (fastest if you have adb)

1. **On your phone:** Settings → About phone → tap "Build number" 7 times to enable Developer Options.  Then Settings → Developer Options → enable **USB Debugging**.
2. **Plug your phone into the Mac** with a USB cable.  Approve the "Allow USB Debugging" prompt on the phone.
3. **From this repo:**
   ```
   adb devices                                 # confirm phone is listed
   adb install -r build/HearthkeepDemo-v0.0.1.apk
   ```
4. App will appear in your launcher as **HEARTHKEEP Demo**.

If `adb` is not installed: `brew install --cask android-platform-tools`.

## Path B — file transfer (no cable required)

1. Upload `build/HearthkeepDemo-v0.0.1.apk` to Google Drive / Dropbox / iCloud / email it to yourself.
2. Open the file on your phone.
3. Phone will warn "Install unknown apps" — toggle the source (your browser / file manager) to allow this once.
4. Tap install.

## Building the APK yourself

If the APK at `build/HearthkeepDemo-v0.0.1.apk` is missing or stale, rebuild:

```
make apk
```

This requires the Android export pipeline configured (see below).

## Android export pipeline setup (one-time)

The first time you build the APK on this Mac, you need:

1. **Java JDK 17+** — `brew install --cask temurin`
2. **Android cmdline-tools** — `brew install --cask android-commandlinetools`
3. **Set ANDROID_HOME**:
   ```
   echo 'export ANDROID_HOME="$HOME/Library/Android/sdk"' >> ~/.zshrc
   echo 'export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"' >> ~/.zshrc
   source ~/.zshrc
   ```
   (cmdline-tools brew cask installs to `/opt/homebrew/share/android-commandlinetools/cmdline-tools/latest/` on Apple Silicon — adjust ANDROID_HOME accordingly; verify with `brew --prefix android-commandlinetools`).
4. **Accept Android SDK licenses + install required packages**:
   ```
   yes | sdkmanager --licenses
   sdkmanager "platform-tools" "build-tools;34.0.0" "platforms;android-34"
   ```
5. **Point Godot to JDK + SDK**: launch Godot Editor → Editor → Editor Settings → Export → Android.  Set the Java path (e.g. `/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home`) and the SDK path (your ANDROID_HOME).
6. **Download Godot Android export templates** for engine version `4.6.2`.  Editor → Manage Export Templates → Download.  These land at `~/Library/Application Support/Godot/export_templates/4.6.2.stable/`.
7. **Build:**
   ```
   make apk
   ```

## Troubleshooting

- **"export templates not found"** — finish step 6 above.
- **"keystore not found"** — Godot will auto-generate a debug keystore; if it doesn't, do `keytool -genkey -v -keystore ~/.android/debug.keystore -storepass android -alias androiddebugkey -keypass android -dname "CN=Android Debug,O=Android,C=US" -validity 10000` and point Godot's Editor Settings → Export → Android → Debug Keystore at it.
- **Install fails on phone with INSTALL_FAILED_USER_RESTRICTED** — the phone has unknown-source installs locked down; toggle it in Settings → Apps → Special access → Install unknown apps.
- **APK is huge (>100MB)** — Mobile renderer + arm64-only should produce ~30-60MB; if it's bigger, check `architectures/*` in `export_presets.cfg` and disable everything except `arm64-v8a`.
