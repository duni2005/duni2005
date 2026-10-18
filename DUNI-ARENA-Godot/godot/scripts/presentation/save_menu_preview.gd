class_name SaveMenuPreview
extends RefCounted
## Header-only display: no domain constructors, new run/map or RNG calls.
## Continue remains disabled until SaveManager's full validation completes.
static func read(path: String) -> SaveLoadResult:
	var result: SaveLoadResult=read_header(path)
	if not result.ok() and result.code!=SaveLoadResult.Code.UNSUPPORTED_VERSION:
		var backup: SaveLoadResult=read_header(path+".backup")
		if backup.ok():backup.from_backup=true;return backup
	return result
static func read_header(path: String) -> SaveLoadResult:
	if not FileAccess.file_exists(path):return SaveLoadResult.failure(SaveLoadResult.Code.FILE_NOT_FOUND,"missing_save")
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null:return SaveLoadResult.failure(SaveLoadResult.Code.IO_ERROR,"read_open")
	if file.get_length()>SaveManager.MAX_BYTES:return SaveLoadResult.failure(SaveLoadResult.Code.VALIDATION_ERROR,"save_too_large")
	var parser:=JSON.new();var source: String=file.get_as_text();file.close()
	if parser.parse(source)!=OK:return SaveLoadResult.failure(SaveLoadResult.Code.PARSE_ERROR,"header_parse")
	if not parser.data is Dictionary:return SaveLoadResult.failure(SaveLoadResult.Code.VALIDATION_ERROR,"header_required")
	var doc: Dictionary=parser.data
	if doc.get("schema_version")!=1:return SaveLoadResult.failure(SaveLoadResult.Code.UNSUPPORTED_VERSION,"schema")
	if not doc.get("metadata") is Dictionary:return SaveLoadResult.failure(SaveLoadResult.Code.VALIDATION_ERROR,"metadata_required")
	var m: Dictionary=doc.metadata
	for key in ["chapter","floor","player_hp","gold","tokens","guild_count","living_guild_count","timestamp"]:
		if not m.get(key) is float and not m.get(key) is int or not is_finite(float(m.get(key,0))):return SaveLoadResult.failure(SaveLoadResult.Code.VALIDATION_ERROR,"metadata_number")
	if not m.get("phase") is String or not m.get("tower_conquered") is bool:return SaveLoadResult.failure(SaveLoadResult.Code.VALIDATION_ERROR,"metadata_fields")
	var result:=SaveLoadResult.new();result.metadata=m.duplicate(true);return result
