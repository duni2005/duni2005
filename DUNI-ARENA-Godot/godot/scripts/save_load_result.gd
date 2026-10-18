class_name SaveLoadResult
extends RefCounted
enum Code { OK, FILE_NOT_FOUND, PARSE_ERROR, UNSUPPORTED_VERSION, VALIDATION_ERROR, IO_ERROR, BUSY }
var code: Code=Code.OK
var detail: String=""
var document: Dictionary={}
var run: RunState
var controller: TowerController
var metadata: Dictionary={}
var from_backup: bool=false
func ok() -> bool:return code==Code.OK
static func failure(value: Code,message: String="") -> SaveLoadResult:
	var result:=SaveLoadResult.new();result.code=value;result.detail=message;return result
