extends RefCounted
## Object-free binary values; checksummed, compressed, same-directory publication.
const MAGIC := "FORMIC01"
const FORMAT := 1
const RULES := "garden-1"
const MAX_BYTES := 64 * 1024 * 1024
const HEADER := 52

static func digest(bytes: PackedByteArray) -> PackedByteArray:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256); hash.update(bytes)
	return hash.finish()

static func read_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {"error": "Save file is missing or unreadable."}
	if file.get_length() < HEADER or file.get_length() > MAX_BYTES: return {"error": "Save file is truncated or too large."}
	if file.get_buffer(8).get_string_from_ascii() != MAGIC: return {"error": "This is not a Formic save."}
	if file.get_32() != FORMAT: return {"error": "Unsupported save version; this match was not changed.", "unsupported": true}
	var raw_size := file.get_64()
	if raw_size <= 0 or raw_size > MAX_BYTES: return {"error": "Invalid saved data size."}
	var checksum := file.get_buffer(32)
	var compressed := file.get_buffer(file.get_length() - HEADER)
	if digest(compressed) != checksum: return {"error": "Save checksum failed; file may be incomplete."}
	var raw := compressed.decompress(raw_size, FileAccess.COMPRESSION_ZSTD)
	if raw.size() != raw_size: return {"error": "Save could not be decompressed."}
	var data = bytes_to_var(raw)
	if not data is Dictionary or data.get("rules", "") != RULES: return {"error": "Unsupported match rules; this match was not changed.", "unsupported": true}
	return {"data": data}

static func write_file(path: String, data: Dictionary) -> Dictionary:
	var start := Time.get_ticks_usec()
	var raw := var_to_bytes(data)
	if raw.is_empty() or raw.size() > MAX_BYTES: return {"error": "Match is too large to save."}
	var packed := raw.compress(FileAccess.COMPRESSION_ZSTD)
	var error := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if error != OK: return {"error": "Cannot create the save folder (%s)." % error_string(error)}
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null: return {"error": "Cannot write save (%s)." % error_string(FileAccess.get_open_error())}
	file.store_buffer(MAGIC.to_utf8_buffer()); file.store_32(FORMAT); file.store_64(raw.size())
	file.store_buffer(digest(packed)); file.store_buffer(packed); file.flush()
	error = file.get_error(); file.close()
	if error != OK: return {"error": "Save write failed; previous save retained."}
	if read_file(temp).has("error"): return {"error": "Written save did not verify; previous save retained."}
	# Never remove the live slot to publish. A corrupt current slot cannot
	# overwrite its previous-good backup. Stray temporary files are ignored.
	if FileAccess.file_exists(path) and not read_file(path).has("error"):
		error = DirAccess.copy_absolute(path, path + ".bak.tmp")
		if error == OK: error = DirAccess.rename_absolute(path + ".bak.tmp", path + ".bak")
		if error != OK: return {"error": "Could not preserve previous save; current save retained."}
	error = DirAccess.rename_absolute(temp, path)
	if error != OK: return {"error": "Could not publish save; current/previous saves retained (%s)." % error_string(error)}
	return {"bytes": HEADER + packed.size(), "write_ms": (Time.get_ticks_usec() - start) / 1000.0}
