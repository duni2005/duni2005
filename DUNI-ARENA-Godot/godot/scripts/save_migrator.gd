class_name SaveMigrator
extends RefCounted
## v1 only. Future migration steps belong here, never in combat/domain objects.
const CURRENT_VERSION=1
static func prepare(value: Variant) -> SaveLoadResult:
	if not value is Dictionary or not SaveValueCodec.integer(value.get("schema_version")):
		return SaveLoadResult.failure(SaveLoadResult.Code.VALIDATION_ERROR,"schema_required")
	if int(value.schema_version)!=CURRENT_VERSION:return SaveLoadResult.failure(SaveLoadResult.Code.UNSUPPORTED_VERSION,"unsupported_schema")
	var result:=SaveLoadResult.new();result.document=value;return result
