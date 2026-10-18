class_name SaveValueCodec
extends RefCounted
## JSON-safe values only. Integer-keyed receipt maps and int64 values are lossless.
var error: String = ""
func fail(message: String) -> Variant:
	if error.is_empty():error=message
	return null
func encode(value: Variant,depth: int=0) -> Variant:
	if depth>32:return fail("value_depth")
	match typeof(value):
		TYPE_NIL,TYPE_BOOL,TYPE_STRING:return value
		TYPE_STRING_NAME:return String(value)
		TYPE_INT:return {"$int64":str(value)} if absf(float(value))>9007199254740991 else value
		TYPE_FLOAT:return value if is_finite(value) else fail("nonfinite")
		TYPE_VECTOR2:return {"x":value.x,"y":value.y} if value.is_finite() else fail("nonfinite_position")
		TYPE_ARRAY:
			var array: Array=[]
			for entry in value:array.append(encode(entry,depth+1))
			return array
		TYPE_DICTIONARY:
			var wrapped: bool=value.has("$pairs") or value.has("$int64")
			for key in value:
				if not key is String and not key is StringName and not key is int:return fail("invalid_dictionary_key")
				if key is int:wrapped=true
			if wrapped:
				var pairs: Array=[]
				for key in value:pairs.append([("i:" if key is int else "s:")+str(key),encode(value[key],depth+1)])
				return {"$pairs":pairs}
			var dictionary: Dictionary={}
			for key in value:dictionary[String(key)]=encode(value[key],depth+1)
			return dictionary
	return fail("object_or_runtime_value")
func decode(value: Variant,depth: int=0) -> Variant:
	if depth>32:return fail("value_depth")
	match typeof(value):
		TYPE_NIL,TYPE_BOOL,TYPE_STRING,TYPE_INT:return value
		TYPE_FLOAT:
			if not is_finite(value):return fail("nonfinite")
			return int(value) if value==floor(value) and absf(value)<=9007199254740991 else value
		TYPE_ARRAY:
			var array: Array=[]
			for entry in value:array.append(decode(entry,depth+1))
			return array
		TYPE_DICTIONARY:
			if value.has("$int64"):
				if value.size()!=1 or not valid_int64(value["$int64"]):return fail("invalid_int64")
				return int(value["$int64"])
			var dictionary: Dictionary={}
			if value.has("$pairs"):
				if value.size()!=1 or not value["$pairs"] is Array:return fail("invalid_pairs")
				for pair in value["$pairs"]:
					if not pair is Array or pair.size()!=2 or not pair[0] is String:return fail("invalid_pair")
					var key: Variant
					if pair[0].begins_with("i:") and valid_int64(pair[0].substr(2)):key=int(pair[0].substr(2))
					elif pair[0].begins_with("s:"):key=pair[0].substr(2)
					else:return fail("invalid_pair_key")
					if dictionary.has(key):return fail("duplicate_pair_key")
					dictionary[key]=decode(pair[1],depth+1)
			else:
				for key in value:
					if not key is String:return fail("invalid_key")
					dictionary[key]=decode(value[key],depth+1)
			return dictionary
	return fail("non_json_value")
static func valid_int64(value: Variant) -> bool:
	return value is String and value.is_valid_int() and str(int(value))==value
static func integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and absf(float(value))<=9007199254740991
