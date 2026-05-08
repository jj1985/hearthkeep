extends GutTest

# OrientationMgr — bucket detection + per-bucket scalars (spec §1.3, §1.4).
# Headless tests run with whatever bucket the test environment lands in
# (usually COMPACT given a tiny default window), so we exercise the
# bucket-keyed helpers across all three Bucket values explicitly.

func test_bucket_changed_signal_present() -> void:
    assert_true(OrientationMgr.has_signal("bucket_changed"))
    assert_true(OrientationMgr.has_signal("safe_area_changed"))

func test_base_viewport_constant() -> void:
    assert_eq(OrientationMgr.BASE_VIEWPORT, Vector2i(720, 1280),
        "Spec §1.2 mandates 720×1280 base viewport for the portrait-default ARPG")

func test_legacy_orient_enum_preserved_for_back_compat() -> void:
    # Existing code may still import Orient — keep the values stable.
    assert_eq(OrientationMgr.Orient.LANDSCAPE_PHONE, 0)
    assert_eq(OrientationMgr.Orient.PORTRAIT_PHONE, 1)
    assert_eq(OrientationMgr.Orient.DESKTOP, 4)

func test_compact_token_values() -> void:
    OrientationMgr.bucket = OrientationMgr.Bucket.COMPACT
    assert_almost_eq(OrientationMgr.font_scale(), 1.0, 0.001)
    assert_almost_eq(OrientationMgr.padding_scale(), 1.0, 0.001)
    assert_eq(OrientationMgr.min_touch_target_dp(), 48)
    assert_eq(OrientationMgr.primary_btn_min_h_dp(), 56)
    assert_eq(OrientationMgr.combat_skill_btn_dp(), 72)
    assert_eq(OrientationMgr.perk_cards_per_row(), 2)
    assert_eq(OrientationMgr.class_grid_cols(), 1)

func test_medium_token_values() -> void:
    OrientationMgr.bucket = OrientationMgr.Bucket.MEDIUM
    assert_almost_eq(OrientationMgr.font_scale(), 1.10, 0.001)
    assert_almost_eq(OrientationMgr.padding_scale(), 1.25, 0.001)
    assert_eq(OrientationMgr.min_touch_target_dp(), 48)
    assert_eq(OrientationMgr.primary_btn_min_h_dp(), 64)
    assert_eq(OrientationMgr.combat_skill_btn_dp(), 88)
    assert_eq(OrientationMgr.perk_cards_per_row(), 2)
    assert_eq(OrientationMgr.class_grid_cols(), 2)

func test_expanded_token_values() -> void:
    OrientationMgr.bucket = OrientationMgr.Bucket.EXPANDED
    assert_almost_eq(OrientationMgr.font_scale(), 1.15, 0.001)
    assert_almost_eq(OrientationMgr.padding_scale(), 1.50, 0.001)
    assert_eq(OrientationMgr.min_touch_target_dp(), 56)
    assert_eq(OrientationMgr.primary_btn_min_h_dp(), 72)
    assert_eq(OrientationMgr.combat_skill_btn_dp(), 96)
    assert_eq(OrientationMgr.perk_cards_per_row(), 4)
    assert_eq(OrientationMgr.class_grid_cols(), 3)

func test_bucket_name_helper() -> void:
    OrientationMgr.bucket = OrientationMgr.Bucket.COMPACT
    assert_eq(OrientationMgr.bucket_name(), "compact")
    OrientationMgr.bucket = OrientationMgr.Bucket.MEDIUM
    assert_eq(OrientationMgr.bucket_name(), "medium")
    OrientationMgr.bucket = OrientationMgr.Bucket.EXPANDED
    assert_eq(OrientationMgr.bucket_name(), "expanded")

func test_ui_tokens_palette_present() -> void:
    var T = preload("res://scripts/ui/ui_tokens.gd")
    assert_eq(T.PRIMARY, Color("#D4A24C"), "Sundered Realms gold")
    assert_eq(T.SECONDARY, Color("#D4582C"), "ember")
    assert_eq(T.TERTIARY, Color("#5A8FB3"), "rune-blue")
    assert_eq(T.RARITY_LEGENDARY, Color("#D4A24C"))
    assert_eq(T.SPACE_MD, 16)
    assert_eq(T.RADIUS_MD, 12)

func test_ui_tokens_rarity_lookup() -> void:
    var T = preload("res://scripts/ui/ui_tokens.gd")
    assert_eq(T.rarity("legendary"), Color("#D4A24C"))
    assert_eq(T.rarity("artifact"), Color("#D4582C"))
    assert_eq(T.rarity("unknown"), Color("#B8B0A0"), "unknown rarities fall back to common")

func test_ui_style_builds_distinct_styleboxes() -> void:
    var UiStyle_ = preload("res://scripts/ui/ui_style.gd")
    var a := UiStyle_.btn_primary()
    var b := UiStyle_.btn_primary()
    assert_ne(a, b, "Each call must return a fresh StyleBox so callers can mutate without aliasing")
    assert_true(a is StyleBoxFlat)
