extends Control

# Megabonk-style perk card overlay. Pause-the-world, pick 1 of N cards.

@onready var grid: HFlowContainer = $Margin/Scroll/Panel/Grid
@onready var title: Label = $Margin/Scroll/Panel/Title

var on_pick: Callable

func show_offers(offers: Array, cb: Callable) -> void:
    on_pick = cb
    title.text = "LEVEL %d  —  CHOOSE A PERK" % RunState.player_level
    for c in grid.get_children():
        c.queue_free()
    for offer in offers:
        var card := _make_card(offer)
        grid.add_child(card)

func _make_card(offer: Dictionary) -> Control:
    var card := PanelContainer.new()
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.15, 0.10, 0.20, 0.95)
    sb.border_color = Color(0.85, 0.65, 0.30) if not offer.get("evolution", false) else Color(1, 0.4, 1)
    sb.border_width_left = 4
    sb.border_width_right = 4
    sb.border_width_top = 4
    sb.border_width_bottom = 4
    sb.corner_radius_top_left = 8
    sb.corner_radius_top_right = 8
    sb.corner_radius_bottom_left = 8
    sb.corner_radius_bottom_right = 8
    card.add_theme_stylebox_override("panel", sb)
    card.custom_minimum_size = Vector2(220, 180)

    var v := VBoxContainer.new()
    v.custom_minimum_size = Vector2(200, 160)
    card.add_child(v)

    var name := Label.new()
    if offer.get("evolution", false):
        name.text = "★ EVOLUTION ★\n" + offer["name"]
        name.modulate = Color(1, 0.6, 1)
    else:
        name.text = offer["name"]
        name.modulate = Color(1, 0.85, 0.4)
    name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    name.add_theme_font_size_override("font_size", 18)
    v.add_child(name)

    var desc := Label.new()
    desc.text = offer["desc"]
    desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    desc.modulate = Color(0.95, 0.95, 0.95)
    desc.add_theme_font_size_override("font_size", 13)
    v.add_child(desc)

    var spacer := Control.new()
    spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
    v.add_child(spacer)

    var btn := Button.new()
    btn.text = "TAKE"
    btn.add_theme_font_size_override("font_size", 18)
    btn.pressed.connect(func(): on_pick.call(offer))
    v.add_child(btn)

    return card
