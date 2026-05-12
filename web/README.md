# HEARTHKEEP — Web build

Pure HTML5 + Canvas. Wrap as APK via Capacitor.

## Play in browser

```bash
cd web
python3 -m http.server 8000
# open http://localhost:8000
```

## Build an APK

```bash
bash web/build-apk.sh
# produces web/Hearthkeep-web-debug.apk (~3.8 MB)
```

The script:
1. Stages assets into `web/dist/`
2. `npm install` if needed
3. `npx cap add android` if needed
4. `npx cap sync android`
5. `./gradlew assembleDebug` and copies the APK back out

Required tools (Homebrew on macOS):
```bash
brew install --cask zulu@17       # or any openjdk@17
brew install --cask android-commandlinetools
```

After first build, iterate with: edit JS → `bash web/build-apk.sh` (it
keeps `node_modules` + `android/` between runs).

## Files

- `index.html` — DOM shell + HUD layout
- `src/style.css` — design tokens + layout
- `src/state.js` — persisted state, milestones, XP
- `src/save.js` — localStorage persistence
- `src/game.js` — canvas game loop, hero, enemies, FX
- `src/main.js` — DOM-game glue, overlays, buttons

## Why this stack

Godot 4 had stability issues on the target Android device. Chrome WebView
(via Capacitor) is rock-solid for an incremental game with <100 entities on
screen and zero 3D. APK packaging is just a static bundle.
