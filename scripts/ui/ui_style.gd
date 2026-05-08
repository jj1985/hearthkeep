extends RefCounted
class_name UiStyle

# Build StyleBoxFlats from UiTokens. Each helper returns a fresh StyleBox
# so callers can mutate (e.g. tint by rarity) without poisoning a shared
# instance. Spec: docs/ui_spec.md §13.2.

const T := preload("res://scripts/ui/ui_tokens.gd")

# ---- Buttons --------------------------------------------------------------

static func btn_primary() -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = T.PRIMARY
    s.set_corner_radius_all(T.RADIUS_SM)
    s.content_margin_left = T.SPACE_LG
    s.content_margin_right = T.SPACE_LG
    s.content_margin_top = T.SPACE_SM
    s.content_margin_bottom = T.SPACE_SM
    s.shadow_color = Color(0, 0, 0, 0.4)
    s.shadow_size = 4
    s.shadow_offset = Vector2(0, 2)
    return s

static func btn_primary_pressed() -> StyleBoxFlat:
    var s := btn_primary()
    s.bg_color = T.PRIMARY_PRESSED
    s.shadow_size = 0
    s.shadow_offset = Vector2.ZERO
    return s

static func btn_primary_disabled() -> StyleBoxFlat:
    var s := btn_primary()
    s.bg_color = T.SURFACE_OVERLAY
    s.shadow_size = 0
    return s

static func btn_secondary() -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = T.SURFACE_BRIGHT
    s.border_color = T.OUTLINE
    s.set_border_width_all(1)
    s.set_corner_radius_all(T.RADIUS_SM)
    s.content_margin_left = T.SPACE_MD
    s.content_margin_right = T.SPACE_MD
    s.content_margin_top = T.SPACE_SM
    s.content_margin_bottom = T.SPACE_SM
    return s

static func btn_secondary_pressed() -> StyleBoxFlat:
    var s := btn_secondary()
    s.bg_color = T.SURFACE_OVERLAY
    s.border_color = T.PRIMARY
    return s

# ---- Cards ----------------------------------------------------------------

static func card_resting() -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = T.SURFACE_BRIGHT
    s.border_color = T.OUTLINE
    s.set_border_width_all(1)
    s.set_corner_radius_all(T.RADIUS_MD)
    s.content_margin_left = T.SPACE_MD
    s.content_margin_right = T.SPACE_MD
    s.content_margin_top = T.SPACE_MD
    s.content_margin_bottom = T.SPACE_MD
    s.shadow_color = Color(0, 0, 0, 0.3)
    s.shadow_size = 6
    s.shadow_offset = Vector2(0, 3)
    return s

static func card_pressed() -> StyleBoxFlat:
    var s := card_resting()
    s.bg_color = T.SURFACE_OVERLAY
    s.border_color = T.PRIMARY
    s.set_border_width_all(2)
    return s

static func card_rarity(rarity_id: String) -> StyleBoxFlat:
    var s := card_resting()
    s.border_color = T.rarity(rarity_id)
    s.set_border_width_all(2)
    return s

static func card_evolution() -> StyleBoxFlat:
    var s := card_resting()
    s.border_color = Color("#D4A24C")
    s.bg_color = Color("#221F2C")
    s.set_border_width_all(3)
    s.shadow_color = Color(0xD4 / 255.0, 0xA2 / 255.0, 0x4C / 255.0, 0.45)
    s.shadow_size = 12
    return s

# ---- Panels & modals ------------------------------------------------------

static func panel_modal() -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = T.SURFACE
    s.border_color = T.OUTLINE_VARIANT
    s.set_border_width_all(1)
    s.set_corner_radius_all(T.RADIUS_LG)
    s.content_margin_left = T.SPACE_LG
    s.content_margin_right = T.SPACE_LG
    s.content_margin_top = T.SPACE_LG
    s.content_margin_bottom = T.SPACE_LG
    return s

static func panel_bottom_sheet() -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = T.SURFACE
    s.border_color = T.OUTLINE_VARIANT
    s.border_width_top = 2
    s.corner_radius_top_left = T.RADIUS_XL
    s.corner_radius_top_right = T.RADIUS_XL
    s.content_margin_left = T.SPACE_MD
    s.content_margin_right = T.SPACE_MD
    s.content_margin_top = T.SPACE_LG
    s.content_margin_bottom = T.SPACE_MD
    return s

static func chip() -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = T.SURFACE_OVERLAY
    s.border_color = T.OUTLINE
    s.set_border_width_all(1)
    s.set_corner_radius_all(T.RADIUS_XS)
    s.content_margin_left = T.SPACE_SM
    s.content_margin_right = T.SPACE_SM
    s.content_margin_top = 4
    s.content_margin_bottom = 4
    return s

# ---- Apply primary-button look to an existing Button -----------------------

static func apply_primary(b: Button) -> void:
    b.add_theme_stylebox_override("normal", btn_primary())
    b.add_theme_stylebox_override("hover", btn_primary())
    b.add_theme_stylebox_override("pressed", btn_primary_pressed())
    b.add_theme_stylebox_override("disabled", btn_primary_disabled())
    b.add_theme_color_override("font_color", T.ON_PRIMARY)
    b.add_theme_color_override("font_pressed_color", T.ON_PRIMARY)
    b.add_theme_color_override("font_disabled_color", T.ON_SURFACE_DISABLED)
    b.add_theme_font_size_override("font_size", T.FS_LABEL_LG)

static func apply_secondary(b: Button) -> void:
    b.add_theme_stylebox_override("normal", btn_secondary())
    b.add_theme_stylebox_override("hover", btn_secondary())
    b.add_theme_stylebox_override("pressed", btn_secondary_pressed())
    b.add_theme_color_override("font_color", T.ON_SURFACE)
    b.add_theme_color_override("font_pressed_color", T.PRIMARY)
    b.add_theme_font_size_override("font_size", T.FS_LABEL_LG)
