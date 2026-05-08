extends RefCounted
class_name UiTokens

# The Sundered Realms design tokens — single source of truth for color +
# spacing + radius. Spec: docs/ui_spec.md §3, §5.
#
# Tokens are class constants rather than a Resource so they're cheap to
# import everywhere without per-load overhead, and any typo at the call
# site is a parse error rather than a silent miss.

# ---- Surface & content (spec §3.1) ----
const SURFACE_DIM := Color("#0B0A0F")
const SURFACE := Color("#15131C")
const SURFACE_BRIGHT := Color("#221F2C")
const SURFACE_OVERLAY := Color("#2C2937")
const ON_SURFACE := Color("#E8E2D2")
const ON_SURFACE_MUTED := Color("#A39A85")
const ON_SURFACE_DISABLED := Color("#5A5345")
const OUTLINE := Color("#3A3445")
const OUTLINE_VARIANT := Color("#5C4A2E")
const SCRIM := Color(0, 0, 0, 0.7)

# ---- Brand & semantic (spec §3.2) ----
const PRIMARY := Color("#D4A24C")             # gold
const PRIMARY_PRESSED := Color("#A77F32")
const ON_PRIMARY := Color("#1A1208")
const SECONDARY := Color("#D4582C")           # ember
const TERTIARY := Color("#5A8FB3")            # rune-blue
const SUCCESS := Color("#6FA060")
const ERROR := Color("#A83232")
const WARNING := Color("#C8A030")

# ---- Rarity tiers (spec §3.3) ----
const RARITY_COMMON := Color("#B8B0A0")
const RARITY_UNCOMMON := Color("#6FA060")
const RARITY_RARE := Color("#5A8FB3")
const RARITY_EPIC := Color("#9966C8")
const RARITY_LEGENDARY := Color("#D4A24C")
const RARITY_ARTIFACT := Color("#D4582C")
const RARITY_MYTHIC := Color("#E8D2A0")

# ---- Spacing (spec §5.1, 8 dp grid) ----
const SPACE_2XS := 4
const SPACE_XS := 8
const SPACE_SM := 12
const SPACE_MD := 16
const SPACE_LG := 24
const SPACE_XL := 32
const SPACE_2XL := 48
const SPACE_3XL := 64

# ---- Radii (spec §5.2) ----
const RADIUS_XS := 4
const RADIUS_SM := 8
const RADIUS_MD := 12
const RADIUS_LG := 16
const RADIUS_XL := 24
const RADIUS_ROUND := 9999

# ---- Type-scale sp values (spec §4.2; multiply by font_scale at runtime) ----
const FS_DISPLAY_LG := 48
const FS_DISPLAY_MD := 36
const FS_HEADLINE_LG := 28
const FS_HEADLINE_SM := 22
const FS_TITLE_LG := 18
const FS_TITLE_MD := 16
const FS_BODY_LG := 16
const FS_BODY_MD := 14
const FS_BODY_SM := 12
const FS_LABEL_LG := 14
const FS_LABEL_MD := 12
const FS_LABEL_SM := 11
const FS_NUMERIC_LG := 32
const FS_NUMERIC_MD := 18

# Resolve a rarity color by string id ("common", "uncommon", ...).
static func rarity(id: String) -> Color:
    match id:
        "common": return RARITY_COMMON
        "uncommon": return RARITY_UNCOMMON
        "rare": return RARITY_RARE
        "epic": return RARITY_EPIC
        "legendary": return RARITY_LEGENDARY
        "artifact": return RARITY_ARTIFACT
        "mythic": return RARITY_MYTHIC
    return RARITY_COMMON
