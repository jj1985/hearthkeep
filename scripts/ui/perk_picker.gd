extends Control

# Megabonk-style perk-pick overlay. Spec: docs/ui_spec.md §9.
#
# Layout:
#   Compact / Medium → 2-column GridContainer, cards 312×200 dp.
#   Expanded         → 1-row HBox, cards 240×220 dp.
# Cards have rarity-colored 2-px top stripe + a 1-px outline border.
# Evolution cards swap to ember-tinted bg + Cinzel Black title + ⚜ glyph.

const T := preload("res://scripts/ui/ui_tokens.gd")
const UiStyle_ := preload("res://scripts/ui/ui_style.gd")

@onready var dim: ColorRect = $Dim
@onready var sheet: PanelContainer = $BottomSheet
@onready var title_label: Label = $BottomSheet/Margin/V/Title
@onready var grid: GridContainer = $BottomSheet/Margin/V/Scroll/Grid

var on_pick: Callable

func _ready() -> void:
    dim.color = T.SCRIM
    sheet.add_theme_stylebox_override("panel", UiStyle_.panel_bottom_sheet())
    title_label.add_theme_font_size_override("font_size", T.FS_HEADLINE_SM)
    title_label.add_theme_color_override("font_color", T.PRIMARY)
    if Engine.has_singleton("OrientationMgr"):
        OrientationMgr.bucket_changed.connect(_on_bucket_changed)
    _apply_bucket()

func _on_bucket_changed(_b) -> void:
    _apply_bucket()

func _apply_bucket() -> void:
    var cols: int = OrientationMgr.perk_cards_per_row() if Engine.has_singleton("OrientationMgr") else 2
    grid.columns = cols
    grid.add_theme_constant_override("h_separation", T.SPACE_MD)
    grid.add_theme_constant_override("v_separation", T.SPACE_MD)

func show_offers(offers: Array, cb: Callable) -> void:
    on_pick = cb
    title_label.text = "LEVEL %d  —  CHOOSE A PERK" % RunState.player_level
    for c in grid.get_children():
        c.queue_free()
    var stagger := 0.0
    for offer in offers:
        var card := _make_card(offer)
        grid.add_child(card)
        # Card-in stagger (spec §9.4): fade + slide-up 24 dp, 80 ms each, 320 ms total.
        card.modulate.a = 0.0
        card.position.y += 24
        var tw := create_tween().set_parallel(true)
        tw.tween_interval(stagger)
        tw.chain().tween_property(card, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
        tw.tween_property(card, "position:y", card.position.y - 24, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        stagger += 0.08

# ---- Card construction ----

func _make_card(offer: Dictionary) -> Control:
    var is_evo: bool = offer.get("evolution", false)
    var rarity: String = offer.get("rarity", "common")

    var card := PanelContainer.new()
    card.add_theme_stylebox_override("panel",
        UiStyle_.card_evolution() if is_evo else UiStyle_.card_rarity(rarity))
    card.custom_minimum_size = _card_min_size()

    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", T.SPACE_SM)
    card.add_child(v)

    # Top stripe (rarity tell): a 4-px ColorRect always rendered at the top of the inner pad.
    var stripe := ColorRect.new()
    stripe.custom_minimum_size = Vector2(0, 4)
    stripe.color = T.rarity(rarity)
    v.add_child(stripe)

    # Title row
    var head := HBoxContainer.new()
    head.add_theme_constant_override("separation", T.SPACE_XS)
    v.add_child(head)
    var name_label := Label.new()
    name_label.text = offer.get("name", "")
    name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    name_label.add_theme_font_size_override("font_size", T.FS_TITLE_LG)
    name_label.add_theme_color_override("font_color",
        T.PRIMARY if is_evo else T.ON_SURFACE)
    name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    head.add_child(name_label)
    if is_evo:
        var glyph := Label.new()
        glyph.text = "⚜"
        glyph.add_theme_color_override("font_color", T.PRIMARY)
        glyph.add_theme_font_size_override("font_size", T.FS_TITLE_LG)
        head.add_child(glyph)

    # Rarity caps label
    var rarity_caps := Label.new()
    rarity_caps.text = ("EVOLUTION" if is_evo else rarity.to_upper())
    rarity_caps.add_theme_font_size_override("font_size", T.FS_LABEL_MD)
    rarity_caps.add_theme_color_override("font_color",
        T.SECONDARY if is_evo else T.rarity(rarity))
    v.add_child(rarity_caps)

    # Description body
    var desc := Label.new()
    desc.text = offer.get("desc", "")
    desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    desc.add_theme_font_size_override("font_size", T.FS_BODY_MD)
    desc.add_theme_color_override("font_color", T.ON_SURFACE_MUTED)
    desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
    v.add_child(desc)

    # TAKE button
    var btn := Button.new()
    btn.text = "TAKE"
    btn.custom_minimum_size = Vector2(0, 48)
    UiStyle_.apply_primary(btn)
    btn.pressed.connect(func(): _take(offer, card))
    v.add_child(btn)

    return card

func _card_min_size() -> Vector2:
    if Engine.has_singleton("OrientationMgr") and OrientationMgr.bucket == OrientationMgr.Bucket.EXPANDED:
        return Vector2(240, 220)
    return Vector2(312, 200)

# ---- Take confirmation animation (spec §9.4) ----

func _take(offer: Dictionary, chosen: Control) -> void:
    var tw := create_tween().set_parallel(true)
    tw.tween_property(chosen, "scale", Vector2(1.08, 1.08), 0.18)
    for c in grid.get_children():
        if c != chosen:
            tw.tween_property(c, "modulate:a", 0.4, 0.24)
    await tw.finished
    if on_pick.is_valid():
        on_pick.call(offer)
