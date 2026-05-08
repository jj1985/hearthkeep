# HEARTHKEEP — UI Specification

**Status:** authoritative. Engineers implement directly from this; deviations need a written reason.
**Target engine:** Godot 4.6 stable, Forward+ renderer.
**Reference device:** Pixel 9 Pro XL — 6.8" OLED, 2992×1344 native, 482 ppi, 20:9, 1.0× display zoom (`560 dpi` / density bucket `xxxhdpi-ish`).
**Floor:** any Android phone ≥ 360 dp width, Android 14 (API 34) minSdk, Android 16 (API 36) targetSdk.
**Orientation:** portrait-default, landscape-supported (Villa & menus only — combat is portrait-locked, see §13).

The unit `dp` (density-independent pixel) and `sp` (scaled pixel) below are Material's units; in Godot they map 1 dp = 1 px in the **base viewport** when the stretch system is configured per §1. All "px" numbers in this doc are **base-viewport px**, identical to dp by construction.

---

## 1. Density buckets & responsive system

### 1.1 Breakpoints (Material 3 width window-size classes)

| Class | Width (dp) | Hearthkeep example device |
|---|---|---|
| **Compact** | < 600 dp | Phone portrait (Pixel 9 XL portrait ≈ 412 dp) |
| **Medium** | 600–839 dp | 7–8" tablet portrait, Pixel Fold inner portrait, phone landscape on big devices |
| **Expanded** | 840–1199 dp | 10"+ tablet, phone landscape on Pixel 9 XL (≈ 915 dp) |
| Large / X-Large | ≥ 1200 dp | Not supported in v1 — clamp layout to Expanded |

Source: <https://m3.material.io/foundations/layout/applying-layout/window-size-classes>.

### 1.2 Base viewport & stretch (Godot)

```ini
# project.godot — [display] section, replace existing
window/size/viewport_width=720
window/size/viewport_height=1280
window/size/window_width_override=0
window/size/window_height_override=0
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
window/stretch/scale=1.0
window/stretch/scale_mode="fractional"
window/handheld/orientation=1   # 1 = portrait
```

**Justification — base resolution 720×1280 portrait:**
- The game is portrait-default. Authoring at 720×1280 makes 1 px = 1 dp on a 360-dp-wide phone at 2× and on a 480-dp phone at 1.5×. Both feel native.
- 1280 dp tall gives generous room for two full-width perk cards on the typical 412×915-dp phone (still fits when scaled ~0.57×, see §6).
- `canvas_items` stretch is the right pick for non-pixel-art 2D HUD layered on a 3D world; UI text stays crisp at any scale.
- `aspect = expand` means taller phones (20:9 like Pixel 9 XL) reveal extra vertical space rather than letterboxing. Anchor HUD elements to **screen edges minus safe area**, never to fixed Y-offsets (this is the bug class the current build has).
- `scale_mode = fractional` is required — `integer` would letterbox aggressively on most phones.

The Godot docs explicitly recommend 720×1080 for portrait mobile games using `canvas_items` (https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html). We pick 720×1280 because the modern phone aspect is 20:9 (≈ 720×1600), and 1280 height is the conservative authoring target — the extra 320 px on a 20:9 device shows as bonus space, never as cropped content.

### 1.3 Bucket detection at runtime

Add `OrientationMgr` (already an autoload) with a single source of truth:

```gdscript
# scripts/ui/orientation_manager.gd
extends Node

enum Bucket { COMPACT, MEDIUM, EXPANDED }

signal bucket_changed(bucket: Bucket)
signal safe_area_changed(rect: Rect2i)

const BASE_VIEWPORT := Vector2i(720, 1280)

var bucket: Bucket = Bucket.COMPACT
var safe_area: Rect2i = Rect2i()
var dp_scale: float = 1.0   # 1 dp = dp_scale * (window px)

func _ready() -> void:
	get_tree().root.size_changed.connect(_recompute)
	_recompute()

func _recompute() -> void:
	var win := DisplayServer.window_get_size()
	var screen_idx := DisplayServer.window_get_current_screen()
	var dpi := max(160, DisplayServer.screen_get_dpi(screen_idx))
	dp_scale = 160.0 / float(dpi)
	var width_dp := int(round(win.x * dp_scale))
	var new_bucket := Bucket.COMPACT
	if width_dp >= 840: new_bucket = Bucket.EXPANDED
	elif width_dp >= 600: new_bucket = Bucket.MEDIUM
	if new_bucket != bucket:
		bucket = new_bucket
		bucket_changed.emit(bucket)
	var sa := DisplayServer.get_display_safe_area()
	if sa != safe_area:
		safe_area = sa
		safe_area_changed.emit(safe_area)
```

`DisplayServer.screen_get_dpi()` returns the system-reported density. On Pixel 9 XL native 1.0× zoom this is ~560; at default user zoom it's ~480. Trust it; do not hand-tune.

### 1.4 Per-bucket overrides

Layouts read from `OrientationMgr.bucket` and apply these multipliers:

| Token | Compact | Medium | Expanded |
|---|---|---|---|
| `font_scale` | 1.00 | 1.10 | 1.15 |
| `padding_scale` | 1.00 | 1.25 | 1.50 |
| `min_touch_target` | 48 dp | 48 dp | 56 dp |
| `primary_btn_min_h` | 56 dp | 64 dp | 72 dp |
| `combat_skill_btn` | 72 dp | 88 dp | 96 dp |
| `perk_cards_per_row` | 2 (2×2 grid) | 2 (2×2 grid) | 4 (1×4 row) |
| `class_grid_cols` | 1 (list) | 2 | 3 |

Implement once as a `Theme` variant per bucket (§13.1), not as ad-hoc `if` branches.

---

## 2. Safe areas & edge-to-edge (Android 14 / 15 / 16)

Android 15 made edge-to-edge mandatory for `targetSdk ≥ 35`. The status/nav bars draw transparent over your content; you must inset interactive UI. Source: <https://developer.android.com/develop/ui/views/layout/edge-to-edge>, <https://medium.com/androiddevelopers/insets-handling-tips-for-android-15s-edge-to-edge-enforcement-872774e8839b>.

### 2.1 Manifest / export presets

In `export_presets.cfg` (Android preset):

```
package/min_sdk=34
package/target_sdk=36
screen/immersive_mode=true
screen/support_small=true
screen/support_normal=true
screen/support_large=true
screen/support_xlarge=true
```

Project setting:
```
display/window/handheld/display_cutout=2   # 2 = SHORT_EDGES (cuts allowed on top/bottom in portrait)
```

(In Godot 4.6 this maps to `android:windowLayoutInDisplayCutoutMode="shortEdges"`; without it, the system letterboxes around the punch-hole.)

### 2.2 Safe-area pattern

Every fullscreen scene root is a `Control` with anchors `0,0 → 1,1`. Wrap UI chrome in a single `MarginContainer` named `SafeArea`, driven from `OrientationMgr`:

```gdscript
# scripts/ui/safe_area_margin.gd
extends MarginContainer

@export var extra_padding_dp: int = 0  # additional design-padding ON TOP OF safe area

func _ready() -> void:
	OrientationMgr.safe_area_changed.connect(_apply)
	get_tree().root.size_changed.connect(_apply.call_deferred.bind(OrientationMgr.safe_area))
	_apply(OrientationMgr.safe_area)

func _apply(sa: Rect2i) -> void:
	var win := DisplayServer.window_get_size()
	if win == Vector2i.ZERO: return
	var vp := get_viewport_rect().size
	# Convert safe-area screen rect to viewport-space px
	var sx := float(vp.x) / float(win.x)
	var sy := float(vp.y) / float(win.y)
	var l = int(sa.position.x * sx) + extra_padding_dp
	var t = int(sa.position.y * sy) + extra_padding_dp
	var r = int((win.x - sa.position.x - sa.size.x) * sx) + extra_padding_dp
	var b = int((win.y - sa.position.y - sa.size.y) * sy) + extra_padding_dp
	add_theme_constant_override("margin_left", l)
	add_theme_constant_override("margin_top", t)
	add_theme_constant_override("margin_right", r)
	add_theme_constant_override("margin_bottom", b)
```

### 2.3 Per-screen rules

| Screen | Background bleed | Interactive bleed |
|---|---|---|
| Combat HUD (`hud.tscn`) | Full-bleed (3D world behind everything) | All buttons inside `SafeArea`. Bottom buttons get **+24 dp extra** above the gesture-nav strip. |
| Title screen | Full-bleed parallax hero art | "Tap to begin" + menu live inside `SafeArea`. |
| Class select | Full-bleed dark background | Card list + Begin button inside `SafeArea`. |
| Perk-pick overlay | Full-bleed scrim (rgba 0,0,0,0.78) | Cards + take buttons inside `SafeArea` with **+16 dp**. |
| Villa / Inventory | Full-bleed | Sort/filter top bar inside `SafeArea`; grid scrolls under top bar with `clip_contents = true`. |
| Codex / settings | Full-bleed | Everything inside `SafeArea`. |

### 2.4 Pixel-9-class system bars (reference for art briefs)

- Status bar (top): typically **24 dp** in portrait, hosting punch-hole camera.
- 3-button nav: 48 dp at bottom. Gesture nav: 24 dp gesture pill at bottom + 16 dp side gesture-back zones (left/right).
- The combat skill cluster (§7) lands in the bottom-right thumb arc, so the gesture pill is the dominant constraint — the bottom-most skill button's bottom edge sits **at safe-area bottom + 24 dp**, never closer.

---

## 3. Color tokens — the Sundered Realms palette

Dark fantasy ARPG: oil-painted dusk, ember firelight, parchment-and-gold UI chrome, rune-blue magical accents. **Opt out of Material You / dynamic color** — a fantasy game's brand identity must not shift with the user's wallpaper. Hand-curated palette only.

### 3.1 Surface & content tokens (dark theme is default and only theme for v1)

| Token | Hex | Use |
|---|---|---|
| `surface_dim` | `#0B0A0F` | App background, fullscreen scrims |
| `surface` | `#15131C` | Default panel fill |
| `surface_bright` | `#221F2C` | Card fill, raised dialog |
| `surface_overlay` | `#2C2937` | Pressed / hovered card fill |
| `on_surface` | `#E8E2D2` | Primary text on dark surface (warm parchment) |
| `on_surface_muted` | `#A39A85` | Secondary text, captions |
| `on_surface_disabled` | `#5A5345` | Disabled text |
| `outline` | `#3A3445` | 1-px borders on all containers |
| `outline_variant` | `#5C4A2E` | Brass-tinted divider (panel headers) |
| `scrim` | `#000000@B3` | Modal scrim (alpha 70%) |

### 3.2 Brand & semantic tokens

| Token | Hex | Use |
|---|---|---|
| `primary` (gold) | `#D4A24C` | Primary buttons, brand chrome, "Begin" CTA |
| `primary_pressed` | `#A77F32` | Pressed state for primary |
| `on_primary` | `#1A1208` | Text/icons on gold |
| `secondary` (ember) | `#D4582C` | Damage flash, fire skills, low-HP pulse |
| `tertiary` (rune-blue) | `#5A8FB3` | Mana, magical highlights, rune glyphs |
| `success` (verdant) | `#6FA060` | Quest-complete tick, heal numbers |
| `error` (blood) | `#A83232` | Errors, dangerous actions, "low HP" bar fill |
| `warning` (sulfur) | `#C8A030` | Cautions, tutorial highlights |

### 3.3 Rarity tiers (used on item/perk borders + label text)

| Token | Hex | Glow color (additive 30%) |
|---|---|---|
| `rarity_common` | `#B8B0A0` | none |
| `rarity_uncommon` | `#6FA060` | `#6FA060@4D` |
| `rarity_rare` | `#5A8FB3` | `#5A8FB3@66` |
| `rarity_epic` | `#9966C8` | `#9966C8@7F` |
| `rarity_legendary` | `#D4A24C` | `#D4A24C@99` |
| `rarity_artifact` | `#D4582C` | `#D4582C@B3` |
| `rarity_mythic` | `#E8D2A0` (with animated chromatic shimmer) | rainbow shader |

Rarity colors are **non-negotiable accessibility constants** — also encode rarity via icon shape (dot, square, diamond, star, flame, sun, prism) for color-blind users.

### 3.4 Token resource location

`art/theme/tokens.tres` (Resource extending custom `UiTokens`); read via `Theme.get_color(name, "Tokens")`.

---

## 4. Typography scale

### 4.1 Fonts

- **Display / Headline / Title:** **Cinzel** (Google Fonts, OFL). Roman-inscriptional caps; reads as "stone-cut fantasy" without going LARP. Weights used: 500 (Medium), 600 (SemiBold), 700 (Bold), 900 (Black).
- **Body / Label:** **Inter** (OFL). Hyper-legible at small sizes on OLED, neutral. Weights: 400, 500, 600.
- **Numerals (HP / DPS floaters / inventory counts):** **Inter** with `tnum` (tabular figures) on; in Godot, set `OpenType` features `tnum=1, lnum=1` on the `FontVariation`.
- **Lore italics (item flavor):** Cinzel Italic 500 — used sparingly, only for ≤2-line flavor strings.

Why not Cormorant: too narrow at small mobile sizes, falls apart under <14 sp.
Why not Eczar: warmer/Indic feel, beautiful but lacks the Roman-caps authority for a Diablo-lineage brand.
Both Cinzel and Inter are OFL-1.1 — drop them in `art/fonts/`, reference from theme.

### 4.2 Type scale (sp at compact bucket; multiply by `font_scale` for larger buckets)

Material 3 baseline scale (https://m3.material.io/styles/typography/type-scale-tokens), adapted — we drop unused styles (Display Small, Headline Medium) to keep the renderer cache lean.

| Token | Font | Size (sp) | Line-height | Weight | Letter-spacing | Use |
|---|---|---|---|---|---|---|
| `display_lg` | Cinzel | 48 | 56 | 700 | +0.6 px (caps) | "HEARTHKEEP" splash |
| `display_md` | Cinzel | 36 | 44 | 700 | +0.4 px | Boss intro card, act title |
| `headline_lg` | Cinzel | 28 | 36 | 600 | +0.2 px | Screen headers (e.g. "CHOOSE YOUR HERO") |
| `headline_sm` | Cinzel | 22 | 28 | 600 | +0.1 px | Section headers ("Treasury", "Trophies") |
| `title_lg` | Cinzel | 18 | 24 | 600 | 0 | Card titles (perk name, class name) |
| `title_md` | Cinzel | 16 | 22 | 500 | 0 | Inline group labels |
| `body_lg` | Inter | 16 | 24 | 400 | 0 | Paragraph copy, lore codex body |
| `body_md` | Inter | 14 | 20 | 400 | 0 | Default UI body, card descriptions |
| `body_sm` | Inter | 12 | 16 | 400 | 0 | Tooltips, captions |
| `label_lg` | Inter | 14 | 20 | 600 | +0.5 px (caps) | Buttons (primary/secondary) |
| `label_md` | Inter | 12 | 16 | 600 | +0.5 px | Chip labels, tag labels |
| `label_sm` | Inter | 11 | 16 | 600 | +0.5 px | Badge labels, hotkey hints |
| `numeric_lg` | Inter (tnum) | 32 | 36 | 700 | 0 | HP/MP big numbers, damage floaters (crits) |
| `numeric_md` | Inter (tnum) | 18 | 22 | 600 | 0 | Damage floaters (normal hits), inventory stacks |

Rules:
- **Caps headers** (`display_*`, `headline_*`, `label_*`) always render via `text.to_upper()` in the layout, not via baked-in casing — supports localization.
- **Body line-length cap**: 60 characters max per line; on compact bucket this means body copy panels are ≤ 480 px wide.

---

## 5. Spacing, radii, elevation

### 5.1 Spacing tokens (8 dp grid)

| Token | dp |
|---|---|
| `space_2xs` | 4 |
| `space_xs` | 8 |
| `space_sm` | 12 |
| `space_md` | 16 |
| `space_lg` | 24 |
| `space_xl` | 32 |
| `space_2xl` | 48 |
| `space_3xl` | 64 |

Rules:
- Inside a card: 16 dp padding (`space_md`).
- Between unrelated panels: 24 dp (`space_lg`).
- Touch-target inner padding: 12 dp (`space_sm`).
- Section vertical rhythm: 32 dp (`space_xl`).
- Never use 6, 10, 14, 18, 20, 28 dp — non-grid values are a smell.

### 5.2 Radii

| Token | dp | Use |
|---|---|---|
| `radius_xs` | 4 | Tag chips, inline badges |
| `radius_sm` | 8 | Buttons (default), input fields |
| `radius_md` | 12 | Cards (perk, class, item) |
| `radius_lg` | 16 | Modals, large dialogs |
| `radius_xl` | 24 | Sheet bottom-corners on bottom sheets |
| `radius_round` | 9999 | Avatars, virtual stick base, circle skill buttons |

### 5.3 Elevation (no hard drop shadows — fantasy interiors don't have CSS shadows)

Replace M3 shadows with **inner glow + brass key-line + subtle dark vignette**:

| Level | Use | Treatment |
|---|---|---|
| `elev_0` | Page background | flat `surface_dim`, no border |
| `elev_1` | Resting card | fill `surface`, 1-px border `outline`, optional 8 dp inner top-light gradient (`#FFFFFF@08` → transparent over 20% of card height) |
| `elev_2` | Raised card / pressed | fill `surface_bright`, 1-px border `outline_variant` (brass), 12-px outer glow `primary@1A` |
| `elev_3` | Modal | fill `surface_bright`, 1-px border `outline_variant`, 24 dp scrim drop (rendered as a `ColorRect` behind the modal, not as a shadow) |
| `elev_4` | Tooltip / popover | fill `surface_overlay`, 1-px border `outline`, no glow |

Implement as named `StyleBoxFlat` resources in the theme (`art/theme/styles/`); never inline.

---

## 6. Touch target sizes

Material minimum is 48 dp; we exceed it for combat-critical controls.

| Element | Min dimension | Rationale |
|---|---|---|
| Any tappable | 48 × 48 dp | Material accessibility floor |
| Secondary button | 48 dp height, 96 dp min width | Compact bucket |
| Primary button (CTA) | 56 dp h × 160 dp min w (compact) / 64 × 200 (medium) / 72 × 240 (expanded) | Reaches "satisfying tap" threshold |
| Combat skill button | 72 × 72 dp (compact); 88 × 88 (medium); 96 × 96 (expanded) | Held continuously under thumb |
| Virtual stick base | 144 dp diameter (compact); 168 (med); 192 (exp) | Diameter, not radius |
| Virtual stick knob | 56 dp diameter; bigger feels mushy | |
| Tab bar item | 48 dp h × 88 dp min w | |
| Inventory grid cell | 64 × 64 dp (compact); 72 (med); 80 (exp) | Plus 4 dp gutter |
| Perk card | **2 cards/row, 1×2 grid stacked into 2×2 — see §9** | |
| Class card (compact) | 100% width × 88 dp h (vertical list) | |

Spacing between adjacent tappables: **min 8 dp** (12 dp preferred). Skill cluster spacing: 16 dp between skill buttons so a thumb roll doesn't double-fire.

---

## 7. Combat HUD (in-run)

### 7.1 Anatomy (portrait, 720×1280 base; values are dp at compact)

```
┌─────────────────────────────────────┐
│  HP/MP cluster (top-left, 16,16)    │ Minimap (top-right, 16,16)
│  [hp bar 240×12]                    │ [128×128 round, alpha 0.85]
│  [mp bar 240×8]                     │
│  Lvl • XP bar (120×6 below)         │
│  ─                                  │
│                                     │
│        (3D world fully visible)     │
│                                     │
│  Buff icons row (16, top+96)        │ Quest tracker chip
│  [32×32 each, max 8 visible]        │ (top-right, 16, top+160, max 240w)
│                                     │
│  Damage floaters spawn here         │
│                                     │
│                                     │
│                                     │
│  Lore-zone-name fade-in (centered, top+220, body_md, 1.5s fade in/out)
│                                     │
│                                     │
│  ┌─────────────────────────────┐    │
│  │     [Pause/Menu] (top-right corner duplicate)   │
│  │     pos: top+16, right-16, 48×48│
│  └─────────────────────────────┘    │
│                                     │
│ ── ABOVE THIS LINE: thumb-info zone │
│                                     │
│ ── BELOW THIS LINE: thumb-action zone (lower 38% of screen)
│                                     │
│  Virt. stick                        │  Skill cluster (right)
│  center @                           │  arc/grid layout:
│  (16+72, bottom-(16+72))            │
│  144 dp base                        │   [Sk2]  [Sk3]
│                                     │       [Sk1]  ← primary, 88×88
│                                     │   [Sk4]  [Sk5]
│                                     │   each 72×72, 16 dp gaps
│                                     │   center of cluster:
│                                     │   right-(16+108), bottom-(24+108)
│                                     │
│  Potion shortcuts (centered between stick and skills)
│  HP-pot 56×56 + MP-pot 56×56, 12 dp gap, bottom-(16+28)
│                                     │
│  Dodge button: bottom-right corner BELOW skill cluster,
│   72×72, right-16, bottom-(16+24); doubles as gesture-aware
│                                     │
└─────────────────────────────────────┘
```

### 7.2 Thumb-zone analysis

Right-handed reference (default; mirrorable via Settings):
- **Lower 38 % of screen** (≈ 487 px on 1280-base) = green zone, action only.
- **Top 33 %** = info-only, never tappable except corner pause/menu (fall-back left-handed).
- **Middle 29 %** = secondary tappables (buff dispel, quest-pin, hold-to-look).

Reference: <https://parachutedesign.ca/blog/thumb-zone-ux/>.

### 7.3 Tap-to-move alternative

A toggle in Settings → "Movement → Tap to move" replaces the virtual stick with:
- Tap an empty world tile → walk there (Diablo-classic).
- Tap an enemy → engage with primary skill.
- Hold-and-drag → continuous move toward drag-target.

When this mode is on, the stick base is hidden and the bottom-left thumb-zone is reclaimed by **2 utility slots** (consumables, town portal).

### 7.4 Damage / crit floaters

| Type | Token | Color | Animation |
|---|---|---|---|
| Normal hit (player→enemy) | `numeric_md` | `on_surface` (warm parchment) | rise 60 dp / 0.7 s, fade-out last 0.3 s |
| Crit | `numeric_lg` | `secondary` ember + 2-px gold outline | scale 1.0→1.4→1.0 over 0.25 s, then rise 80 dp / 0.9 s |
| Damage to player | `numeric_md` | `error` | shake 4 dp x-axis 0.15 s, then rise |
| Heal | `numeric_md` | `success` | rise straight, no shake |
| Mana / resource | `numeric_md` | `tertiary` | rise straight |

Floaters use `Tween` with `Tween.TRANS_QUAD, Tween.EASE_OUT`. Pool 32 floaters as a `MultiMesh` of textured quads driven from `VFX` autoload — never instance-per-hit.

### 7.5 Comparison to genre exemplars

| Game | Pattern we adopt | Pattern we reject |
|---|---|---|
| Diablo Immortal | Diamond-cluster skill layout (1 primary surrounded by 4 actives), HP orb on left | Pay-walled gem socket UI nudges |
| Genshin Impact | Four-skill bottom-right cluster scaled by ergonomics | Ultra-wide elemental-resonance bar — too cluttered |
| Punishing: Gray Raven | Gesture-flick dodge from skill area | Three-character-swap UI — single-class game |
| Wild Rift | Floating combat-text with damage pooling | MOBA-specific score panels |
| Eternal Strands (mobile-style HUD) | Cinematic full-bleed when zone-name fades | — |

---

## 8. Class select / character creator

### 8.1 Why the current screen overflows

7 + 7 + 1 = 15 buttons rendered as a flat HBox/VBox always loses on compact portrait. Solution: **paginated single-column list with sticky preview header**.

### 8.2 Layout pattern (compact portrait — the canonical case)

```
┌─────────────────────────────────────┐ SafeArea inset
│  HEADLINE_LG: "CHOOSE YOUR HERO"   │ centered, top+16
│                                     │
│  ┌─ PREVIEW PANE (sticky) ─────┐    │ height = 320 dp
│  │ [3D portrait, 240×240]      │    │ idle-anim
│  │ [class name • title_lg]     │    │
│  │ [3-line role pitch • body_md]│    │
│  │ tag chips: [DEX] [BLEED] [HYBRID-READY]
│  └─────────────────────────────┘    │
│                                     │
│  ── Tabs: PRIMARY • SECONDARY ──    │ M3 segmented control, 48 dp
│                                     │
│  ┌─ class scroll list ─────────┐    │ VBox in ScrollContainer
│  │ [icon] Knight    >          │    │ each row 88 dp h, full-w
│  │ [icon] Rogue     >          │    │ tap row → swap preview
│  │ [icon] Mage      >          │    │ active row: gold left-border
│  │ ...                         │    │
│  └─────────────────────────────┘    │
│                                     │
│  ┌──────────────────────────┐      │ pinned bottom (above safe-area)
│  │  BEGIN AS [PRIMARY]+[SEC]│      │ primary button, 56 dp h, full-w-32
│  └──────────────────────────┘      │ disabled until both selected
└─────────────────────────────────────┘
```

The Begin button reads dynamically: e.g. `BEGIN AS KNIGHT/ROGUE` (uppercase via `label_lg`). When the recognized hybrid pair is selected, a **prestige callout** slides up from the Begin button (12 dp tall, gold border, ember inner glow):

> ⚜ BLADEDANCER — Hybrid prestige unlocked

Animation: slide + fade 250 ms, M3 emphasized easing. The prestige glow color matches the matched `rarity_legendary`.

### 8.3 Medium / expanded layouts

- **Medium:** preview pane on left (50 % width), class list on right; tabs become two-row (primary above, secondary below).
- **Expanded:** three-pane: preview | primary list | secondary list, all visible simultaneously. Begin button bottom-center, 240 dp wide.

### 8.4 Class portraits (placeholder strategy)

Until real CC0 art lands:
- Each class gets a 240×240 `art/portraits/<class>_silhouette.png` — a 1-bit silhouette over a class-tinted gradient (e.g. Knight = `#A39A85` over `#3A3445`).
- Generate the 14 silhouettes from open-license sources: Game-icons.net (CC-BY 3.0) silhouettes filtered through a single shader `art/shaders/portrait_emboss.gdshader` that adds the gold edge-light + soft drop-vignette.
- Real art replaces the textures only — no UI rework.

---

## 9. Perk pick overlay (Megabonk-style)

### 9.1 Why the current 4-card HBox at 220×180 fails

On 720-px-wide portrait at compact bucket: 4 × 220 + 3 × 16 (gaps) + 2 × 16 (margins) = 928 px → overflow by 208 px. Cards must wrap.

### 9.2 The pattern: **2×2 grid for compact, 1×4 row for expanded**

Compact / medium: `GridContainer` with `columns = 2`. Each card is **312 × 200 dp** (fits 2 × 312 + 16 gap + 32 side-pad = 672 px on 720-base).

Expanded landscape: switch to 1×4 row, each card 240 × 220.

Carousel pattern is **rejected** — extra friction on level-up, and obscures comparison.

### 9.3 Card anatomy

```
┌── 312 × 200 ──────────────────────┐
│ rarity border 2-px (top edge)     │ ← rarity_<tier> color, glow at elev_2
│ ┌─ icon area, 80×80 ──┐           │
│ │  [icon]              │  TITLE_LG│ ← perk name (1-2 lines, ellipsize)
│ └──────────────────────┘  label_md│ ← rarity name uppercase, color = rarity
│                                   │
│ body_md description (3 lines max) │
│ "Crits leave a bleed for 4s."     │
│                                   │
│ ┌───────────────────────────────┐ │
│ │     TAKE                      │ │ ← primary 48 dp button, full-width
│ └───────────────────────────────┘ │
└───────────────────────────────────┘
```

- Card BG: `surface_bright`, radius `radius_md`.
- Border: 1 px `outline` always; rarity 2-px top stripe acts as the rarity tell.
- Hover/pressed: card lifts (translates -4 dp on Y) and border becomes 2-px `rarity_<tier>` (full perimeter), 200 ms `EASE_OUT`.

### 9.4 Animations

- **Card-in stagger:** cards fade + slide up from y+24 dp; stagger 80 ms each, total 320 ms. M3 spec recommends 200–300 ms for medium components; the staggered total stays inside that perceptual window per-card. (https://m3.material.io/styles/motion/easing-and-duration)
- **Pressed:** scale 1.0 → 0.97 over 80 ms in, 120 ms out, `EASE_OUT`.
- **Take confirmation:** the chosen card scales 1.0 → 1.08 with gold inner-glow flash 180 ms, the others fade to 0.4 alpha and slide off-screen 240 ms.

### 9.5 Common vs. evolution-card distinction

- **Common perk:** standard card as drawn above; rarity bar is `rarity_common` / `_uncommon` / `_rare`.
- **Evolution card:** card BG swaps to a **subtle ember-radial gradient** behind the icon (`secondary @ 0.15` center → transparent edge), the title font becomes Cinzel **Black 900** (vs. SemiBold 600), and a small ⚜ glyph appears top-right. The icon area gets a slow pulsing glow (1.5 s loop, 0.85 → 1.0 alpha).

---

## 10. Villa / inventory / chest view

### 10.1 Inventory grid

- Compact: 5 columns of 64 × 64 dp cells, 4 dp gutter → grid is 320 + 16 = 336 dp wide; centered, leaving 192 dp of side margins (used for sort chips on small phones).
- Medium: 7 columns × 72 dp.
- Expanded: 10 columns × 80 dp.
- Cells use `radius_sm`, fill `surface`, 1-px `outline`. Occupied cells overlay the item icon + a rarity 2-px **bottom** stripe (not full border — keeps the grid quiet).
- Tap a cell → tooltip popover (`elev_4`) anchored to the cell's right edge in compact (auto-flip to left near right edge); long-press → drag mode.
- **Drag-vs-tap rule:** 200 ms hold + 8 dp move threshold = drag; otherwise tap = open tooltip.

### 10.2 Sort/filter chips

Top of inventory screen: `HBox` of M3 filter chips, 32 dp h, `radius_round`, `label_md`. Slots: `[ALL] [WEAPONS] [ARMOR] [POTIONS] [DYES] [TROPHIES] [JUNK]` then `[Sort: rarity ▾]` (split chip → bottom sheet).

Search bar: 48 dp h text input, `radius_sm`, leading `magnifier` icon, placeholder `"Search by name…"`. Hidden by default, swipe-down on the grid reveals it (M3 search pattern).

### 10.3 Chest entry

- **Treasury chests are 3D meshes in the Villa.** Tapping a chest fires a 600 ms cinematic dolly-in to the chest, then opens **a fullscreen modal sheet** (not a partial bottom sheet — chests need the 7-column grid + side stash filters).
- Modal anatomy: top app bar 56 dp ("Treasury — Chest 3 of 7", brass bottom-divider) ⇒ filter chips ⇒ 2-pane below (left = chest contents, right = player bag) on medium+; stacked tabs on compact.
- Drag-to-transfer between panes; double-tap = transfer one stack.

### 10.4 Trophy Hall display slot picker

The Trophy Hall has **N** physical pedestals (fixed by villa scene). UI to assign a trophy:
- Tap a pedestal → fullscreen modal "Display a Trophy" → grid of unlocked trophies (3 cols compact, 4 medium, 6 expanded) at 96 dp tile, with set icon + set-progress chip (`2/4`).
- Filter chips at top: `[ALL] [SET A: DRAGON HUNT] [SET B: GOBLIN BANE] …`.
- Selecting a trophy shows a confirm toast at bottom: `"Display Vyxhasis Tooth here? • [Confirm]"`. Confirm → scene plays a 400 ms place-on-pedestal anim and the buff toast slides in.

---

## 11. Title screen & boot sequence

### 11.1 Sequence

1. **Engine splash** (Godot's, hidden — `boot_splash/show_image=false` already set; `bg_color=#0B0A0F` matches surface_dim).
2. **Brand splash** (1.2 s, skippable on tap): centered `display_lg` "HEARTHKEEP" in gold, subtitle `headline_sm` "of the Sundered Realms" in `on_surface_muted`. Fade in 400 ms, hold 600 ms, fade-out 200 ms over a slow ember-particle rise.
3. **Title screen** with parallax hero art:
   - Background: 3-layer parallax — far mountains + storm sky (slowest), midground keep silhouette (medium), foreground brazier embers (fastest, animated). Movement driven by `Time.get_ticks_msec()` sine, ±8 dp range.
   - Centered: `display_md` "HEARTHKEEP" (smaller than splash to leave breathing room), subtitle below, then **"TAP TO BEGIN"** (`label_lg`, gentle 1.4-s opacity pulse 0.6 → 1.0).
   - A single tap anywhere advances to the menu state.
4. **Menu state:** the title text shrinks 20 % to top-third; menu buttons fade in below: `[CONTINUE]` (only if save exists), `[NEW RUN]`, `[VILLA]`, `[CODEX]`, `[SETTINGS]`. Stacked vertical, 56 dp h, full-width-minus-32, 12 dp gap. M3 emphasized motion 280 ms.
5. **Loading screen** during scene swap: full-bleed dark, brazier loop in center (32-frame Spine or sprite atlas), single-line lore tip cycling every 4 s (`body_md`, fades 240 ms in/out), bottom-right small "rotating runes" indeterminate spinner.

### 11.2 Loading-screen content rotation

- 60 % gameplay tips ("Hold a skill button to charge for +30 % damage").
- 25 % class lore stingers (`headline_sm` class name, `body_md` 1-line teaser).
- 15 % world lore ("The Sundering shattered Aerathis into seven realms; you walk what remains.").

Source from `LoreCodex` autoload; never repeat the same tip twice in 5 consecutive loads.

---

## 12. Animations & micro-interactions

Material 3 emphasized easing & durations: <https://m3.material.io/styles/motion/easing-and-duration>. We adopt this with names below.

### 12.1 Tween durations

| Token | ms | Use |
|---|---|---|
| `dur_xs` | 100 | Tooltip show, color tint |
| `dur_sm` | 180 | Button press, chip select |
| `dur_md` | 240 | Card lift, modal open |
| `dur_lg` | 320 | Screen transition, perk-pick stagger total |
| `dur_xl` | 480 | Cinematic camera dolly to chest |

Easing curves (Godot equivalents):
- **Standard:** `Tween.TRANS_CUBIC, Tween.EASE_OUT` — default.
- **Emphasized in:** `Tween.TRANS_BACK, Tween.EASE_OUT` — cards arriving.
- **Emphasized out:** `Tween.TRANS_CUBIC, Tween.EASE_IN` — cards leaving.

### 12.2 Button press feedback

Two-phase: **scale + tint pulse**, no Material ripple (visually too modern for the brand).

```gdscript
# pseudo
press_in:  scale 1.0 -> 0.97 (dur_sm, EASE_OUT) + modulate * primary_pressed
release:   scale -> 1.0 (dur_sm, EASE_OUT) + modulate -> normal
```

Add a one-frame `"thunk"` SFX (low-dB anvil tap) on press-in for primary buttons only.

### 12.3 Screen transitions

| From → To | Transition |
|---|---|
| Title → Menu | Crossfade, `dur_lg` |
| Menu → Class select | Slide-up + fade (160 dp), `dur_lg` |
| Class select → Combat | 600 ms blade-wipe shader (radial reveal), then full-bleed |
| Combat → Game-over | Desaturate to monochrome over 800 ms, then "YOU FELL" `display_md` fade-in |
| Combat ↔ Menu (pause) | Background blur 8 px (over 200 ms) + scrim @ 70 %, menu modal slide-up |

### 12.4 Empty states

Every list/grid that can be empty has personality:
- Empty inventory: silhouette of an empty sack + `body_md` "Even crows pick at richer lots." + `[FIND LOOT]` button → closes to combat.
- Empty Trophy Hall: silhouette of a bare pedestal + `body_md` "The first dragon will not slay itself." + `[VIEW BESTIARY]`.
- No saved game: title screen `[CONTINUE]` is omitted entirely (don't show disabled).

Empty-state copy lives in `data/empty_states.tres` so writers can iterate without code changes.

---

## 13. Implementation in Godot 4.6

### 13.1 Theme organization

```
art/theme/
  hearthkeep_base.tres        # the canonical theme; all type/color tokens
  hearthkeep_compact.tres     # extends base; overrides for compact
  hearthkeep_medium.tres      # extends base; overrides for medium
  hearthkeep_expanded.tres    # extends base; overrides for expanded
  styles/
    btn_primary.tres          # StyleBoxFlat
    btn_secondary.tres
    card_resting.tres
    card_pressed.tres
    panel_modal.tres
    panel_tooltip.tres
    chip.tres
  fonts/
    cinzel_variation.tres     # FontVariation, weight + spacing axes
    inter_variation.tres
    inter_tnum_variation.tres
  tokens.tres                 # the UiTokens resource holding hex strings + dp ints
```

The base theme defines every named StyleBox + every type style (`Theme.set_font_size("title_lg", "Label", 18)` etc). Bucket variants override only what changes (font sizes ×`font_scale`, padding constants ×`padding_scale`).

Apply via:
```gdscript
# scripts/ui/orientation_manager.gd
func _apply_theme():
	var path := {
		Bucket.COMPACT: "res://art/theme/hearthkeep_compact.tres",
		Bucket.MEDIUM:  "res://art/theme/hearthkeep_medium.tres",
		Bucket.EXPANDED:"res://art/theme/hearthkeep_expanded.tres",
	}[bucket]
	get_tree().root.theme = load(path)
```

### 13.2 StyleBox vs. nine-patch

- **All UI chrome → `StyleBoxFlat`** (corner radius + border + bg color + optional inner-shadow gradient via `bg_color` modulation). Vector-resolution-independent, theme-able.
- **Ornate UI flourishes (corner brass-fittings on modals)** → 9-patch `StyleBoxTexture` only when the visual demands it; use `axis_stretch_horizontal/vertical = STRETCH_TILE_FIT`.
- **Never** mix StyleBoxFlat + StyleBoxTexture on the same `Control` — it doubles draw calls and tears with mipmaps.

### 13.3 Layout containers

| Use case | Container |
|---|---|
| Perk-pick 2×2 / 1×4 | `GridContainer` with `columns` set per bucket (cheaper than HFlow; deterministic layout) |
| Inventory grid | `GridContainer` (fixed cols per bucket); for very long inventories wrap in `ScrollContainer` |
| Buff icon row | `HBoxContainer` with `add_theme_constant_override("separation", 8)` |
| Class list (compact) | `VBoxContainer` inside `ScrollContainer` |
| Tab content swap | `TabContainer` with `tabs_visible = false` + custom `SegmentedControl` driving `current_tab` |
| Combat HUD root | `Control` with hand-anchored children (no container — explicit anchors are the right pattern for HUD) |

`HFlowContainer` is rejected for cards: re-layout cost is non-trivial and we want deterministic 2×2 vs 1×4 by bucket, not "whatever fits."

### 13.4 Orientation flip / runtime scale change

`get_tree().root.size_changed` fires on rotation, fold/unfold, and split-screen resize. `OrientationMgr._recompute()` re-runs:
1. Recompute bucket → swap theme if changed.
2. Recompute `dp_scale` and `safe_area` → emit signals.
3. `SafeArea` margin containers reapply.

Combat scene is **portrait-locked**: in `combat.tscn` `_ready()`:
```gdscript
DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
```
On scene exit (back to Villa or menu), restore:
```gdscript
DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR)
```

### 13.5 No addons

Resist the temptation. The widgets we need (segmented control, filter chip, bottom sheet, tooltip popover) are 80–150 lines of GDScript each on top of `Control`/`Button`/`Panel`. Addons drag in unmaintained Godot-3 idioms and inflate build size. Allowed exception: a font-fallback addon if Cinzel coverage gaps appear for non-Latin locales — re-evaluate post-EN-only v1.

### 13.6 Project setting diff (apply now)

```
[display]
window/size/viewport_width=720
window/size/viewport_height=1280
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
window/stretch/scale_mode="fractional"
window/handheld/orientation=1
window/handheld/display_cutout=2
[rendering]
textures/canvas_textures/default_texture_filter=1   # linear, for crisp HUD scaling
```

---

## 14. References

### Material 3
- Window size classes — <https://m3.material.io/foundations/layout/applying-layout/window-size-classes>
- Type scale & tokens — <https://m3.material.io/styles/typography/type-scale-tokens>
- Motion easing & duration — <https://m3.material.io/styles/motion/easing-and-duration>
- Color roles — <https://m3.material.io/styles/color/roles>
- Touch targets / accessibility — <https://m3.material.io/foundations/accessible-design/accessibility-basics>
- Material 3 Adaptive 1.2.0 stable (Oct 2025) — <https://android-developers.googleblog.com/2025/10/material-3-adaptive-120-is-stable.html>

### Android edge-to-edge / insets / cutouts
- Edge-to-edge in Views (canonical) — <https://developer.android.com/develop/ui/views/layout/edge-to-edge>
- Android 15 enforcement migration — <https://medium.com/androiddevelopers/insets-handling-tips-for-android-15s-edge-to-edge-enforcement-872774e8839b>
- Practical guide A14→A15 — <https://medium.com/@mickcolai/from-android-14-to-15-a-practical-guide-to-adapting-the-legacy-view-system-for-edge-to-edge-a0232d7aea30>
- Display cutout modes — <https://developer.android.com/develop/ui/views/layout/display-cutout>

### Godot 4
- Multiple resolutions / stretch modes — <https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html>
- Exporting for Android — <https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html>
- DisplayServer API — <https://docs.godotengine.org/en/stable/classes/class_displayserver.html>
- Known issue: `get_display_safe_area` clipping on some Androids — <https://github.com/godotengine/godot/issues/105462> (mitigation: clamp to `DisplayServer.get_display_cutouts()` if zero/negative inset detected).

### Mobile ARPG / HUD design references
- Diablo Immortal settings & layout teardown — <https://game8.co/games/Diablo-Immortal/archives/376937>
- Diablo Immortal alpha developer-feedback dissection — <https://echohack.medium.com/diablo-immortal-technical-alpha-in-depth-developer-feedback-8f3a35bf1707>
- Thumb-zone primer — <https://parachutedesign.ca/blog/thumb-zone-ux/>

### Fonts
- Cinzel (OFL) — <https://fonts.google.com/specimen/Cinzel>
- Inter (OFL) — <https://fonts.google.com/specimen/Inter>

---

**Implementation order (suggested):**
1. Apply §13.6 project-setting diff + create `OrientationMgr` per §1.3 + `SafeArea` per §2.2. Verify on Pixel 9 XL portrait and landscape with `adb shell wm size` overrides.
2. Author `tokens.tres` + base `Theme` per §3, §4, §5, §13.1.
3. Rebuild title screen per §11 — smallest scene, validates the type/spacing system.
4. Rebuild perk-pick overlay per §9 — validates 2×2 grid, card rendering, animations.
5. Rebuild class select per §8 — validates list pattern + sticky preview.
6. Rebuild combat HUD per §7 — biggest payoff, depends on 1–4.
7. Inventory / chest / Trophy Hall per §10.
