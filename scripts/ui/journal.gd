extends Control

# Combined Journal — Quest log + Lore codex behind a 2-tab segmented control.
# Reached from the Villa "War Room" / "Library" buildings or via inventory hotkey.

const T := preload("res://scripts/ui/ui_tokens.gd")
const UiStyle_ := preload("res://scripts/ui/ui_style.gd")
const UiAnim_ := preload("res://scripts/ui/ui_anim.gd")

const CATEGORY_ORDER := ["region", "dragons", "creatures", "pantheon", "history", "items", "npc", "cosmology", "magic", "mystery"]

@onready var bg: ColorRect = $Bg
@onready var safe_area: MarginContainer = $SafeArea
@onready var headline: Label = $SafeArea/V/Headline
@onready var tab_quests: Button = $SafeArea/V/Tabs/Quests
@onready var tab_codex: Button = $SafeArea/V/Tabs/Codex
@onready var tab_realm: Button = $SafeArea/V/Tabs/Realm
@onready var quests_pane: ScrollContainer = $SafeArea/V/QuestsPane
@onready var quests_list: VBoxContainer = $SafeArea/V/QuestsPane/List
@onready var codex_pane: HBoxContainer = $SafeArea/V/CodexPane
@onready var codex_categories: VBoxContainer = $SafeArea/V/CodexPane/Categories/Inner
@onready var codex_entries: VBoxContainer = $SafeArea/V/CodexPane/Detail/Entries
@onready var realm_pane: ScrollContainer = $SafeArea/V/RealmPane
@onready var realm_list: VBoxContainer = $SafeArea/V/RealmPane/List
@onready var tab_stats: Button = $SafeArea/V/Tabs/Stats
@onready var stats_pane: ScrollContainer = $SafeArea/V/StatsPane
@onready var stats_list: VBoxContainer = $SafeArea/V/StatsPane/List
@onready var close_btn: Button = $SafeArea/V/Footer/Close

var current_tab: String = "quests"
var current_category: String = "region"

func _ready() -> void:
    bg.color = T.SURFACE_DIM
    headline.add_theme_font_size_override("font_size", T.FS_HEADLINE_LG)
    headline.add_theme_color_override("font_color", T.PRIMARY)
    UiStyle_.apply_secondary(close_btn)
    UiStyle_.apply_secondary(tab_quests)
    UiStyle_.apply_secondary(tab_codex)
    UiStyle_.apply_secondary(tab_realm)
    UiStyle_.apply_secondary(tab_stats)
    UiAnim_.bind_press_feedback(close_btn)
    UiAnim_.bind_press_feedback(tab_quests)
    UiAnim_.bind_press_feedback(tab_codex)
    UiAnim_.bind_press_feedback(tab_realm)
    UiAnim_.bind_press_feedback(tab_stats)
    tab_quests.pressed.connect(_select_tab.bind("quests"))
    tab_codex.pressed.connect(_select_tab.bind("codex"))
    tab_realm.pressed.connect(_select_tab.bind("realm"))
    tab_stats.pressed.connect(_select_tab.bind("stats"))
    close_btn.pressed.connect(_on_close)
    _select_tab(current_tab)
    _populate_codex_categories()

func _select_tab(tab: String) -> void:
    current_tab = tab
    UiStyle_.apply_secondary(tab_quests)
    UiStyle_.apply_secondary(tab_codex)
    UiStyle_.apply_secondary(tab_realm)
    UiStyle_.apply_secondary(tab_stats)
    quests_pane.visible = false
    codex_pane.visible = false
    realm_pane.visible = false
    stats_pane.visible = false
    if tab == "quests":
        UiStyle_.apply_primary(tab_quests)
        quests_pane.visible = true
        _populate_quests()
    elif tab == "codex":
        UiStyle_.apply_primary(tab_codex)
        codex_pane.visible = true
    elif tab == "realm":
        UiStyle_.apply_primary(tab_realm)
        realm_pane.visible = true
        _populate_realm()
    else:
        UiStyle_.apply_primary(tab_stats)
        stats_pane.visible = true
        _populate_stats()

func _populate_stats() -> void:
    for c in stats_list.get_children():
        c.queue_free()
    _add_stats_section("PROGRESS", [
        ["Runs played",        _fmt(GameState.run_count)],
        ["Deepest floor",      _fmt(GameState.deepest_floor)],
        ["Dragons defeated",   "%d / 3 (%s)" % [GameState.defeated_dragons.size(), ", ".join(GameState.defeated_dragons)]],
        ["Krrik III defeated", "yes" if GameState.krrik_defeated else "no"],
        ["Triple-class unlocked", "yes" if bool(GameState.meta_unlocks.get("triple_class", false)) else "no"],
    ])
    _add_stats_section("COMBAT", [
        ["Lifetime kills",       _fmt(GameState.lifetime_kills)],
        ["Lifetime legendaries", _fmt(GameState.lifetime_legendaries)],
    ])
    _add_stats_section("ECONOMY", [
        ["Gold",               _fmt(GameState.gold) + " g"],
        ["Run count",          _fmt(GameState.run_count)],
    ])
    _add_stats_section("CHARACTER", [
        ["Talent points (unspent)", _fmt(RunState.talent_points)],
        ["Talents allocated",       _fmt(RunState.allocated_talents.size())],
        ["Trophies collected",      _fmt(TrophyManager.collected.size())],
        ["Active trophy buffs",     "%d / %d" % [TrophyManager.active_buff_ids.size(), TrophyManager.active_cap]],
        ["Dye colors unlocked",     _fmt(GameState.unlocked_dye_colors.size())],
    ])
    if RunState.active:
        var classes_line: String = _run_classes_line()
        var hyb_line: String = _run_hybrids_line()
        var run_rows: Array = [
            ["Classes", classes_line],
            ["Level", _fmt(RunState.player_level)],
            ["Floor", _fmt(RunState.floor_index)],
            ["Perks taken", _fmt(RunState.perks_taken.size())],
        ]
        if hyb_line != "":
            run_rows.append(["Hybrid prestige", hyb_line])
        _add_stats_section("CURRENT RUN", run_rows)
    if not GameState.lifetime_kills_by_type.is_empty():
        _add_stats_section_header("KILLS BY TYPE")
        var sorted_keys := GameState.lifetime_kills_by_type.keys()
        sorted_keys.sort_custom(func(a, b):
            return int(GameState.lifetime_kills_by_type[a]) > int(GameState.lifetime_kills_by_type[b]))
        for k in sorted_keys:
            var n: int = int(GameState.lifetime_kills_by_type[k])
            stats_list.add_child(_stat_row(String(k).replace("_", " ").capitalize(), _fmt(n)))

func _run_classes_line() -> String:
    var parts: Array = []
    for cid in [RunState.class_primary, RunState.class_secondary, RunState.class_tertiary]:
        if cid == "":
            continue
        parts.append(String(Classes.get_class_def(cid).get("name", cid)))
    return " / ".join(parts)

func _run_hybrids_line() -> String:
    var hs: Array = RunState.all_hybrid_prestiges()
    if hs.is_empty():
        return ""
    var names: Array = []
    for h in hs:
        names.append(String(h.get("name", "")))
    return " + ".join(names)

func _add_stats_section(title: String, rows: Array) -> void:
    _add_stats_section_header(title)
    for row in rows:
        stats_list.add_child(_stat_row(String(row[0]), String(row[1])))

func _add_stats_section_header(title: String) -> void:
    var hdr := Label.new()
    hdr.text = title
    hdr.add_theme_font_size_override("font_size", T.FS_HEADLINE_SM)
    hdr.add_theme_color_override("font_color", T.PRIMARY)
    stats_list.add_child(hdr)

func _fmt(n: int) -> String:
    # Thousands separators: 12345 → "12,345"
    var s: String = str(n)
    if s.length() <= 3:
        return s
    var out: String = ""
    var c: int = 0
    for i in range(s.length() - 1, -1, -1):
        out = s[i] + out
        c += 1
        if c % 3 == 0 and i > 0:
            out = "," + out
    return out

func _stat_row(label: String, value: String) -> Control:
    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override("panel", UiStyle_.card_resting())
    var h := HBoxContainer.new()
    h.add_theme_constant_override("separation", 12)
    panel.add_child(h)
    var l := Label.new()
    l.text = label
    l.add_theme_color_override("font_color", T.ON_SURFACE)
    l.add_theme_font_size_override("font_size", T.FS_BODY_LG)
    l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    h.add_child(l)
    var v := Label.new()
    v.text = value
    v.add_theme_color_override("font_color", T.PRIMARY)
    v.add_theme_font_size_override("font_size", T.FS_TITLE_MD)
    h.add_child(v)
    return panel

func _populate_realm() -> void:
    for c in realm_list.get_children():
        c.queue_free()
    var towns: Array = Towns.all_towns()
    for t in towns:
        realm_list.add_child(_town_card(t))

func _town_card(town) -> Control:
    var s: Dictionary = town.summary()
    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override("panel", UiStyle_.card_resting())
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 6)
    panel.add_child(v)
    var name_label := Label.new()
    name_label.text = "%s  ·  %s" % [String(s["name"]), String(s["region"])]
    name_label.add_theme_font_size_override("font_size", T.FS_TITLE_LG)
    name_label.add_theme_color_override("font_color", T.PRIMARY)
    v.add_child(name_label)
    var ruler := Label.new()
    ruler.text = "%s, %s" % [String(s["ruler_name"]), String(s["ruler_title"])]
    ruler.add_theme_color_override("font_color", T.ON_SURFACE)
    ruler.add_theme_font_size_override("font_size", T.FS_BODY_MD)
    v.add_child(ruler)
    var stats := Label.new()
    stats.text = "Population %d  ·  Mood: %s  ·  Lean: %s" % [int(s["population"]), String(s["mood_label"]), String(s["faction_lean"])]
    stats.add_theme_color_override("font_color", T.ON_SURFACE_MUTED)
    stats.add_theme_font_size_override("font_size", T.FS_BODY_SM)
    v.add_child(stats)
    if String(s.get("recent_event", "")) != "":
        var evt := Label.new()
        evt.text = "—  %s" % String(s["recent_event"])
        evt.add_theme_color_override("font_color", T.SECONDARY)
        evt.add_theme_font_size_override("font_size", T.FS_BODY_SM)
        evt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        v.add_child(evt)
    return panel

# ---- Quest log ----

func _populate_quests() -> void:
    for c in quests_list.get_children():
        c.queue_free()
    var actives: Array = QuestSystem.get_active_list()
    var completed: Array = QuestSystem.completed
    var bounties: Array = QuestSystem.bounty_board().filter(func(b):
        return not QuestSystem.active.has(b["id"]) and not QuestSystem.completed.has(b["id"]))
    if not actives.is_empty():
        quests_list.add_child(_section_header("ACTIVE", T.PRIMARY))
        for q in actives:
            quests_list.add_child(_quest_card(q, true))
    if not bounties.is_empty():
        quests_list.add_child(_section_header("BOUNTY BOARD", T.SECONDARY))
        for b in bounties:
            quests_list.add_child(_bounty_card(b))
    if not completed.is_empty():
        quests_list.add_child(_section_header("COMPLETED", T.ON_SURFACE_MUTED))
        for qid in completed:
            var q: Dictionary = QuestSystem.registry.get(qid, {"id": qid, "title": qid, "objectives": []})
            quests_list.add_child(_quest_card(q, false))
    if actives.is_empty() and completed.is_empty() and bounties.is_empty():
        var empty := Label.new()
        empty.text = "No quests yet. The world watches."
        empty.add_theme_color_override("font_color", T.ON_SURFACE_MUTED)
        empty.add_theme_font_size_override("font_size", T.FS_BODY_LG)
        quests_list.add_child(empty)

func _bounty_card(b: Dictionary) -> Control:
    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override("panel", UiStyle_.card_resting())
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 6)
    panel.add_child(v)
    var head := HBoxContainer.new()
    v.add_child(head)
    var title := Label.new()
    title.text = String(b.get("title", b.get("id", "?")))
    title.add_theme_font_size_override("font_size", T.FS_TITLE_LG)
    title.add_theme_color_override("font_color", T.SECONDARY)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    head.add_child(title)
    var btn := Button.new()
    btn.text = "ACCEPT (%d g)" % int(b.get("reward_gold", 0))
    btn.custom_minimum_size = Vector2(160, 40)
    UiStyle_.apply_primary(btn)
    UiAnim_.bind_press_feedback(btn)
    btn.pressed.connect(func():
        if QuestSystem.accept_bounty(String(b["id"])):
            EventBus.floating_text.emit("Bounty accepted: %s" % String(b["title"]), Vector2.ZERO, T.SUCCESS)
            _populate_quests())
    head.add_child(btn)
    var desc := Label.new()
    desc.text = String(b.get("desc", ""))
    desc.add_theme_font_size_override("font_size", T.FS_BODY_MD)
    desc.add_theme_color_override("font_color", T.ON_SURFACE_MUTED)
    desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    v.add_child(desc)
    return panel

func _section_header(text: String, color: Color) -> Label:
    var lbl := Label.new()
    lbl.text = text
    lbl.add_theme_font_size_override("font_size", T.FS_HEADLINE_SM)
    lbl.add_theme_color_override("font_color", color)
    return lbl

func _quest_card(q: Dictionary, is_active: bool) -> Control:
    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override("panel", UiStyle_.card_resting())
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 6)
    panel.add_child(v)
    var title := Label.new()
    title.text = String(q.get("title", q.get("id", "?")))
    title.add_theme_font_size_override("font_size", T.FS_TITLE_LG)
    title.add_theme_color_override("font_color", T.PRIMARY if is_active else T.ON_SURFACE_MUTED)
    v.add_child(title)
    if q.has("desc"):
        var desc := Label.new()
        desc.text = String(q["desc"])
        desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        desc.add_theme_font_size_override("font_size", T.FS_BODY_MD)
        desc.add_theme_color_override("font_color", T.ON_SURFACE_MUTED)
        v.add_child(desc)
    var objectives: Array = q.get("objectives", [])
    var progress: Dictionary = QuestSystem.active.get(q.get("id", ""), {})
    for obj in objectives:
        var line := Label.new()
        var oid: String = obj.get("id", "")
        var done: int = int(progress.get(oid, 0))
        var need: int = int(obj.get("count", 1))
        var mark := "✓" if done >= need else "—"
        line.text = "  %s  %s  (%d/%d)" % [mark, obj.get("text", oid), done, need]
        line.add_theme_font_size_override("font_size", T.FS_BODY_MD)
        line.add_theme_color_override("font_color", T.SUCCESS if done >= need else T.ON_SURFACE)
        v.add_child(line)
    return panel

# ---- Lore codex ----

func _populate_codex_categories() -> void:
    for c in codex_categories.get_children():
        c.queue_free()
    var seen: Array[String] = []
    for entry in LoreCodex.ENTRIES:
        var cat: String = entry.get("cat", "misc")
        if not seen.has(cat):
            seen.append(cat)
    seen.sort()
    for cat in seen:
        var b := Button.new()
        b.text = cat.to_upper()
        b.set_meta("cat", cat)
        b.alignment = HORIZONTAL_ALIGNMENT_LEFT
        b.custom_minimum_size = Vector2(0, 48)
        UiStyle_.apply_secondary(b)
        UiAnim_.bind_press_feedback(b)
        b.pressed.connect(_on_category_picked.bind(cat))
        codex_categories.add_child(b)
    if not seen.is_empty():
        _on_category_picked(seen[0])

func _on_category_picked(cat: String) -> void:
    current_category = cat
    for c in codex_categories.get_children():
        var btn: Button = c as Button
        if btn == null:
            continue
        var is_active: bool = String(btn.get_meta("cat")) == cat
        if is_active:
            UiStyle_.apply_primary(btn)
        else:
            UiStyle_.apply_secondary(btn)
    _populate_codex_entries(cat)

func _populate_codex_entries(cat: String) -> void:
    for c in codex_entries.get_children():
        c.queue_free()
    var entries: Array = LoreCodex.by_category(cat)
    if entries.is_empty():
        var empty := Label.new()
        empty.text = "Nothing recorded yet."
        empty.add_theme_color_override("font_color", T.ON_SURFACE_MUTED)
        codex_entries.add_child(empty)
        return
    for entry in entries:
        codex_entries.add_child(_lore_card(entry))

func _lore_card(entry: Dictionary) -> Control:
    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override("panel", UiStyle_.card_resting())
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 8)
    panel.add_child(v)
    var title := Label.new()
    title.text = String(entry.get("title", "?"))
    title.add_theme_font_size_override("font_size", T.FS_TITLE_LG)
    title.add_theme_color_override("font_color", T.PRIMARY)
    v.add_child(title)
    var body := Label.new()
    body.text = String(entry.get("text", ""))
    body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    body.add_theme_font_size_override("font_size", T.FS_BODY_MD)
    body.add_theme_color_override("font_color", T.ON_SURFACE)
    v.add_child(body)
    return panel

func _on_close() -> void:
    get_tree().change_scene_to_file("res://scenes/villa/villa.tscn")
