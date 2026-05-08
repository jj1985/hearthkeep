@tool
extends EditorScript

func _run() -> void:
    print("===")
    var n: int = EditorExport.get_export_preset_count()
    for i in range(n):
        var preset: EditorExportPreset = EditorExport.get_export_preset(i)
        print("preset[", i, "]: name=", preset.get_name(), " platform=", preset.get_platform().get_name())
        var platform: EditorExportPlatform = preset.get_platform()
        var error: Array = []
        var err_packed: PackedStringArray = PackedStringArray()
        var ok: bool = platform.can_export(preset, err_packed)
        print("  can_export: ", ok)
        for e in err_packed:
            print("  REASON: ", e)
    print("===")
