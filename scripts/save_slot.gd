extends RefCounted

const PATH := "user://all_inclusive.sav"
const TEMP_PATH := "user://all_inclusive.tmp"
const BACKUP_PATH := "user://all_inclusive.bak"
const HASH_LENGTH := 32
const MAX_LENGTH := 16 * 1024 * 1024


static func exists() -> bool:
	return FileAccess.file_exists(PATH) or FileAccess.file_exists(BACKUP_PATH)


static func write(data: Dictionary) -> bool:
	var payload := var_to_bytes(data)
	if payload.size() + HASH_LENGTH > MAX_LENGTH:
		return false
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if not file:
		return false
	file.store_buffer(_digest(payload))
	file.store_buffer(payload)
	file.flush()
	var ok := file.get_error() == OK
	file.close()
	if not ok:
		return false
	if FileAccess.file_exists(PATH):
		if FileAccess.file_exists(BACKUP_PATH) and DirAccess.remove_absolute(BACKUP_PATH) != OK:
			return false
		if DirAccess.rename_absolute(PATH, BACKUP_PATH) != OK:
			return false
	if DirAccess.rename_absolute(TEMP_PATH, PATH) != OK:
		if FileAccess.file_exists(BACKUP_PATH):
			DirAccess.rename_absolute(BACKUP_PATH, PATH)
		return false
	if FileAccess.file_exists(BACKUP_PATH):
		DirAccess.remove_absolute(BACKUP_PATH)
	return true


static func read() -> Dictionary:
	var file := FileAccess.open(PATH if FileAccess.file_exists(PATH) else BACKUP_PATH, FileAccess.READ)
	if not file or file.get_length() <= HASH_LENGTH or file.get_length() > MAX_LENGTH:
		return {}
	var expected := file.get_buffer(HASH_LENGTH)
	var payload := file.get_buffer(file.get_length() - HASH_LENGTH)
	if _digest(payload) != expected:
		return {}
	var data: Variant = bytes_to_var(payload)
	return data if data is Dictionary else {}


static func _digest(payload: PackedByteArray) -> PackedByteArray:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(payload)
	return context.finish()
