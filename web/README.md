# HEARTHKEEP — Web build

Pure HTML5 + Canvas. Wrap as APK via Capacitor.

## Play in browser

```bash
cd web
python3 -m http.server 8000
# open http://localhost:8000
```

## Build an APK (one-time setup)

```bash
cd web
npm install
npx cap add android
npx cap sync android
npx cap open android      # opens Android Studio — Build → APK
```

After that, iterate with: edit JS → `npx cap sync android` → rebuild in Android Studio.

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
