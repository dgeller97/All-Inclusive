extends SceneTree

## Regenerate distribution notices from the exact Godot binary used to build.
func _initialize() -> void:
	var output := FileAccess.open("res://THIRD_PARTY_NOTICES.txt", FileAccess.WRITE)
	if output == null:
		push_error("Cannot write THIRD_PARTY_NOTICES.txt")
		quit(1)
		return
	output.store_string("ALL INCLUSIVE — ENGINE AND THIRD-PARTY NOTICES\n\n")
	output.store_string("Generated from Godot %s.\nhttps://godotengine.org/license/\n\n" % Engine.get_version_info().get("string", ""))
	output.store_string("GODOT ENGINE\n\n" + Engine.get_license_text() + "\n\n")
	output.store_string("COMPONENT COPYRIGHT INFORMATION\n\n")
	output.store_string(JSON.stringify(Engine.get_copyright_info(), "  ") + "\n\n")
	output.store_string("THIRD-PARTY LICENSE TEXTS\n\n")
	var licenses := Engine.get_license_info()
	var names := licenses.keys()
	names.sort()
	for license_name in names:
		output.store_string("=== %s ===\n\n%s\n\n" % [license_name, licenses[license_name]])
	output.close()
	print("Wrote THIRD_PARTY_NOTICES.txt")
	quit(0)
