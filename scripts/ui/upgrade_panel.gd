extends Control

# Building upgrade modal. Shows current tier per villa building, lets
# the player spend gold to upgrade. Reachable from the Villa as a 9th
# building marker.

const T := preload("res://scripts/ui/ui_tokens.gd")
const UiStyle_ := preload("res://scripts/ui/ui_style.gd")
const UiAnim_ := preload("res://scripts/ui/ui_anim.gd")

# Building upgrade catalogue:
#  id matches GameState.buildings keys; benefit_at[T] describes what tier T grants.
const BUILDINGS := [
    {"id":"forge",         "name":"Forge",
     "benefit_at":["Built. Crafting at skill 1.","+1 craft skill ceiling.","+2 craft skill, recipe page unlocked.","Master tier — masterworks at +33% odds."],
     "costs":[0, 1500, 4000, 9000]},
    {"id":"stash",         "name":"Treasury",
     "benefit_at":["Default 9 chests, 240 cap each.","Chest cap 320.","Chest cap 480.","Chest cap 720, search-all unlocked."],
     "costs":[0, 1200, 3500, 8000]},
    {"id":"tavern",        "name":"Tavern",
     "benefit_at":["1 rumor at a time.","2 rumors + small mead buff.","3 rumors + recruitable mercs (1 slot).","4 rumors + 2 merc slots, faction-quest hooks."],
     "costs":[0, 1000, 3000, 7000]},
    {"id":"wizard_tower",  "name":"Wizard's Study",
     "benefit_at":["Locked.","Built. Talent allocator usable.","+1 enchant slot per gear.","+2 slots, scroll research unlocked."],
     "costs":[0, 2200, 5500, 12000]},
    {"id":"shrine",        "name":"Shrine",
     "benefit_at":["Locked.","Built. Daily blessing buff.","Faction altars (3 factions).","All 5 factions + ritual pool."],
     "costs":[0, 1800, 4500, 10000]},
    {"id":"gambling_den",  "name":"Snikkit's Den",
     "benefit_at":["Built.","Stake cap raised to 10k.","Triple-or-nothing unlocked.","Mythic-tier items in pool."],
     "costs":[0, 1400, 3800, 8500]},
    {"id":"dye_vendor",    "name":"Dye Vendor",
     "benefit_at":["Common dyes available.","Rare dyes weekly stock.","Epic dyes + dye-mixing.","Mythic dyes + custom shaders."],
     "costs":[0, 1300, 3600, 8200]},
]

@onready var bg: ColorRect = $Bg
@onready var safe_area: MarginContainer = $SafeArea
@onready var headline: Label = $SafeArea/V/Headline
@onready var balance: Label = $SafeArea/V/Balance
@onready var building_list: VBoxContainer = $SafeArea/V/Scroll/List
@onready var close_btn: Button = $SafeArea/V/Footer/Close

func _ready() -> void:
    bg.color = T.SURFACE_DIM
    headline.add_theme_font_size_override("font_size", T.FS_HEADLINE_LG)
    headline.add_theme_color_override("font_color", T.PRIMARY)
    headline.text = "VILLA UPGRADES"
    balance.add_theme_font_size_override("font_size", T.FS_TITLE_LG)
    balance.add_theme_color_override("font_color", T.PRIMARY)
    UiStyle_.apply_secondary(close_btn)
    UiAnim_.bind_press_feedback(close_btn)
    close_btn.pressed.connect(_on_close)
    _refresh()

func _refresh() -> void:
    balance.text = "Gold:  %d" % GameState.gold
    for c in building_list.get_children():
        c.queue_free()
    for b in BUILDINGS:
        building_list.add_child(_make_card(b))

func _make_card(b: Dictionary) -> Control:
    var bid: String = String(b["id"])
    var tier: int = GameState.building_tier(bid)
    var max_tier: int = (b["costs"] as Array).size() - 1
    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override("panel", UiStyle_.card_resting())
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 6)
    panel.add_child(v)
    var head := HBoxContainer.new()
    v.add_child(head)
    var title := Label.new()
    title.text = "%s  ·  Tier %d / %d" % [String(b["name"]), tier, max_tier]
    title.add_theme_font_size_override("font_size", T.FS_TITLE_LG)
    title.add_theme_color_override("font_color", T.PRIMARY)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    head.add_child(title)
    if tier < max_tier:
        var next_cost: int = int((b["costs"] as Array)[tier + 1])
        var btn := Button.new()
        btn.text = "UPGRADE  (%d g)" % next_cost
        btn.custom_minimum_size = Vector2(180, 40)
        var afford: bool = GameState.gold >= next_cost
        UiStyle_.apply_primary(btn) if afford else UiStyle_.apply_secondary(btn)
        btn.disabled = not afford
        if afford:
            UiAnim_.bind_press_feedback(btn)
            btn.pressed.connect(_upgrade.bind(bid, next_cost))
        head.add_child(btn)
    else:
        var maxed := Label.new()
        maxed.text = "MAXED"
        maxed.add_theme_color_override("font_color", T.SECONDARY)
        maxed.add_theme_font_size_override("font_size", T.FS_LABEL_LG)
        head.add_child(maxed)
    var benefits: Array = b["benefit_at"]
    var current_blurb := Label.new()
    current_blurb.text = "Current:  %s" % String(benefits[clampi(tier, 0, benefits.size() - 1)])
    current_blurb.add_theme_color_override("font_color", T.ON_SURFACE)
    current_blurb.add_theme_font_size_override("font_size", T.FS_BODY_MD)
    current_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    v.add_child(current_blurb)
    if tier < max_tier:
        var next_blurb := Label.new()
        next_blurb.text = "Next:  %s" % String(benefits[tier + 1])
        next_blurb.add_theme_color_override("font_color", T.ON_SURFACE_MUTED)
        next_blurb.add_theme_font_size_override("font_size", T.FS_BODY_SM)
        next_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        v.add_child(next_blurb)
    return panel

func _upgrade(building_id: String, cost: int) -> void:
    if GameState.gold < cost:
        return
    GameState.add_gold(-cost)
    GameState.upgrade_building(building_id)
    SfxBus.play("levelup", -3.0)
    EventBus.floating_text.emit("UPGRADED — %s tier %d" % [building_id, GameState.building_tier(building_id)],
        Vector2.ZERO, T.PRIMARY)
    _refresh()

func _on_close() -> void:
    SaveSystem.save()
    get_tree().change_scene_to_file("res://scenes/villa/villa.tscn")
