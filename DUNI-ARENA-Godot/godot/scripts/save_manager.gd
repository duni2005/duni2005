class_name SaveManager
extends RefCounted
## One run slot. No game rules and no live battle serialization.
signal status_changed(result: SaveLoadResult)
const DEFAULT_PATH="user://saves/autosave.json"
const MAX_BYTES=8*1024*1024
var path: String
var last_result:=SaveLoadResult.new()
var save_id: String=""
var created_at: int=0
var run_id: String=""
var writes: int=0
var _pending: Dictionary={}
var _scheduled: bool=false
var background_enabled: bool=false
var _worker: Thread
var _writer: SaveManager
var _verified_text: String=""
var last_write_usec: int=0
func _init(save_path: String=DEFAULT_PATH,use_background: bool=false) -> void:
	path=save_path;background_enabled=use_background
func attach(controller: TowerController) -> void:controller.save_manager=self
func safe(controller: TowerController) -> bool:
	if controller==null or controller.guild==null or controller.guild.state.tower==null:return false
	if controller.guild.state.tower.phase not in SaveValidator.PHASES:return false
	if is_instance_valid(controller.battle) and controller.battle.started and not controller.battle.finished:return false
	if is_instance_valid(controller.prediction_battle) and controller.prediction_battle.started and not controller.prediction_battle.finished:return false
	return controller.content==null or controller.content.pending_completions.is_empty()
func snapshot(controller: TowerController,recovery: Dictionary={},formation: FormationState=null) -> SaveLoadResult:
	var captured: SaveLoadResult=_capture(controller,recovery,formation)
	return SaveValidator.validate(captured.document) if captured.ok() else captured
func _capture(controller: TowerController,recovery: Dictionary={},formation: FormationState=null) -> SaveLoadResult:
	if not safe(controller):return SaveLoadResult.failure(SaveLoadResult.Code.BUSY,"battle_or_transaction_running")
	if run_id!=controller.guild.state.run_id:
		run_id=controller.guild.state.run_id;save_id="save_"+Crypto.new().generate_random_bytes(16).hex_encode();created_at=int(Time.get_unix_time_from_system())
	return SaveSnapshotBuilder.capture(controller,save_id,created_at,recovery,formation)
func request_autosave(controller: TowerController) -> SaveLoadResult:
	var result: SaveLoadResult=_capture(controller,controller.recovery_checkpoint)
	if not result.ok():return publish(result)
	_pending=result.document
	if not _scheduled:_scheduled=true;call_deferred("_dispatch_autosave")
	return result
func _dispatch_autosave() -> void:
	_scheduled=false
	if _pending.is_empty() or _worker!=null:return
	if not background_enabled or OS.has_feature("web"):
		flush_autosave();return
	var document: Dictionary=_pending;_pending={};_start_write(document)
func _start_write(document: Dictionary) -> void:
	# Load static catalogs once on the main thread; validation only reads them.
	CharacterCatalog.all();ItemCatalog.all()
	_writer=SaveManager.new(path);_writer._verified_text=_verified_text
	_worker=Thread.new()
	var writer: SaveManager=_writer
	var code: Error=_worker.start(func():
		var began: int=Time.get_ticks_usec();var result: SaveLoadResult=writer.write_document(document)
		writer.last_write_usec=Time.get_ticks_usec()-began;return result)
	if code!=OK:
		_worker=null;_writer=null;publish(write_document(document));return
	_queue_poll()
func _queue_poll() -> void:
	var tree: SceneTree=Engine.get_main_loop() as SceneTree
	if tree!=null and not tree.process_frame.is_connected(_poll_write):tree.process_frame.connect(_poll_write,CONNECT_ONE_SHOT)
func _poll_write() -> void:
	if _worker==null:return
	if _worker.is_alive():_queue_poll();return
	_finish_write()
	if not _pending.is_empty():_dispatch_autosave()
func _finish_write() -> SaveLoadResult:
	if _worker==null:return last_result
	var result: SaveLoadResult=_worker.wait_to_finish()
	writes+=_writer.writes;last_write_usec=_writer.last_write_usec;_verified_text=_writer._verified_text
	_worker=null;_writer=null
	return publish(result)
func wait_for_idle() -> SaveLoadResult:
	var tree: SceneTree=Engine.get_main_loop() as SceneTree
	while _worker!=null or not _pending.is_empty():
		if _worker==null:_dispatch_autosave()
		if _worker!=null:await tree.process_frame
	return last_result
func flush_autosave() -> SaveLoadResult:
	_scheduled=false
	_finish_write()
	if _pending.is_empty():return last_result
	var document: Dictionary=_pending;_pending={}
	return publish(write_document(document))
func manual_save(controller: TowerController) -> SaveLoadResult:
	_finish_write()
	var result: SaveLoadResult=_capture(controller,controller.recovery_checkpoint)
	if not result.ok():return publish(result)
	_pending={};return publish(write_document(result.document))
func checkpoint(controller: TowerController,kind: String,seed: int,formation: FormationState=null) -> SaveLoadResult:
	_finish_write()
	var recovery: Dictionary={"kind":kind,"room_id":controller.guild.state.tower.selected_room_id,"seed":seed}
	var result: SaveLoadResult=_capture(controller,recovery,formation)
	if not result.ok():return publish(result)
	result=write_document(result.document)
	if result.ok():_pending={};controller.recovery_checkpoint=recovery
	return publish(result)
func checkpoint_async(controller: TowerController,kind: String,seed: int,formation: FormationState=null) -> SaveLoadResult:
	if not background_enabled or OS.has_feature("web"):return checkpoint(controller,kind,seed,formation)
	await wait_for_idle()
	var recovery: Dictionary={"kind":kind,"room_id":controller.guild.state.tower.selected_room_id,"seed":seed}
	var captured: SaveLoadResult=_capture(controller,recovery,formation)
	if not captured.ok():return publish(captured)
	_start_write(captured.document)
	var result: SaveLoadResult=await wait_for_idle()
	if result.ok():controller.recovery_checkpoint=recovery
	return result
func publish(result: SaveLoadResult) -> SaveLoadResult:
	# Do not retain load payloads: controller -> SaveManager -> result -> controller cycles.
	last_result=SaveLoadResult.new();last_result.code=result.code;last_result.detail=result.detail;last_result.from_backup=result.from_backup;last_result.metadata=result.metadata.duplicate(true)
	status_changed.emit(result);return result
func read_file(file_path: String) -> SaveLoadResult:
	if not FileAccess.file_exists(file_path):return SaveLoadResult.failure(SaveLoadResult.Code.FILE_NOT_FOUND,"missing_save")
	var file:=FileAccess.open(file_path,FileAccess.READ)
	if file==null:return SaveLoadResult.failure(SaveLoadResult.Code.IO_ERROR,"read_open")
	if file.get_length()>MAX_BYTES:return SaveLoadResult.failure(SaveLoadResult.Code.VALIDATION_ERROR,"save_too_large")
	var text: String=file.get_as_text();file.close()
	var parser:=JSON.new()
	if parser.parse(text)!=OK:return SaveLoadResult.failure(SaveLoadResult.Code.PARSE_ERROR,"json_line:%d"%parser.get_error_line())
	if not parser.data is Dictionary:return SaveLoadResult.failure(SaveLoadResult.Code.VALIDATION_ERROR,"document_required")
	return SaveValidator.validate(parser.data)
func read_document(allow_backup: bool=true) -> SaveLoadResult:
	var result: SaveLoadResult=read_file(path)
	# Never silently downgrade a future-schema save to an older backup.
	if not result.ok() and result.code!=SaveLoadResult.Code.UNSUPPORTED_VERSION and allow_backup:
		var backup: SaveLoadResult=read_file(path+".backup")
		if backup.ok():backup.from_backup=true;return backup
	return result
func metadata() -> SaveLoadResult:return read_document()
func load_controller() -> SaveLoadResult:
	flush_autosave()
	var read: SaveLoadResult=read_document()
	if not read.ok():return publish(read)
	var result: SaveLoadResult=SaveSnapshotLoader.restore(read.document)
	if not result.ok():return publish(result)
	result.from_backup=read.from_backup;run_id=result.run.run_id;save_id=result.document.save_id;created_at=int(result.document.created_at)
	_pending={};attach(result.controller);return publish(result)
func write_text(file_path: String,text: String) -> SaveLoadResult:
	var file:=FileAccess.open(file_path,FileAccess.WRITE)
	if file==null:return SaveLoadResult.failure(SaveLoadResult.Code.IO_ERROR,"temporary_open")
	file.store_string(text);file.flush();var code: Error=file.get_error();file.close()
	return SaveLoadResult.new() if code==OK else SaveLoadResult.failure(SaveLoadResult.Code.IO_ERROR,"temporary_write")
func write_document(document: Dictionary) -> SaveLoadResult:
	var validation: SaveLoadResult=SaveValidator.validate(document)
	if not validation.ok():return validation
	if not path.begins_with("user://") or ".." in path:return SaveLoadResult.failure(SaveLoadResult.Code.IO_ERROR,"user_path_required")
	var directory: String=ProjectSettings.globalize_path(path.get_base_dir())
	var ancestor: String=path.get_base_dir()
	while ancestor.begins_with("user://") and ancestor!="user://":
		if FileAccess.file_exists(ancestor) and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(ancestor)):return SaveLoadResult.failure(SaveLoadResult.Code.IO_ERROR,"directory_is_file")
		ancestor=ancestor.get_base_dir()
	if DirAccess.make_dir_recursive_absolute(directory)!=OK:return SaveLoadResult.failure(SaveLoadResult.Code.IO_ERROR,"directory")
	var text: String=JSON.stringify(document)
	var written: SaveLoadResult=write_text(path+".tmp",text)
	if not written.ok():return written
	return _commit_verified_temp(text,validation)
func commit_temp() -> SaveLoadResult:
	# This is also the fault-test boundary: invalid temporary files never replace a slot.
	var candidate: SaveLoadResult=read_file(path+".tmp")
	if not candidate.ok():return candidate
	return _commit_verified_temp(FileAccess.get_file_as_string(path+".tmp"),candidate)
func _commit_verified_temp(text: String,candidate: SaveLoadResult) -> SaveLoadResult:
	# Re-read exact bytes, parse and compare with the already validated payload.
	# This retains corruption detection without rebuilding all 120 rooms again.
	var actual: String=FileAccess.get_file_as_string(path+".tmp")
	var parser:=JSON.new()
	if actual!=text or parser.parse(actual)!=OK:return SaveLoadResult.failure(SaveLoadResult.Code.PARSE_ERROR,"temporary_verify")
	var previous_text: String=FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	var previous_ok: bool=not previous_text.is_empty() and previous_text==_verified_text
	if not previous_text.is_empty() and not previous_ok:previous_ok=read_file(path).ok()
	if previous_ok:
		var backup: SaveLoadResult=write_text(path+".backup.tmp",previous_text)
		if not backup.ok():return backup
		if FileAccess.get_file_as_string(path+".backup.tmp")!=previous_text:return SaveLoadResult.failure(SaveLoadResult.Code.IO_ERROR,"backup_verify")
		if DirAccess.rename_absolute(ProjectSettings.globalize_path(path+".backup.tmp"),ProjectSettings.globalize_path(path+".backup"))!=OK:return SaveLoadResult.failure(SaveLoadResult.Code.IO_ERROR,"backup_replace")
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(path+".tmp"),ProjectSettings.globalize_path(path))!=OK:return SaveLoadResult.failure(SaveLoadResult.Code.IO_ERROR,"atomic_replace")
	_verified_text=text;writes+=1;return candidate
