class_name ItemInstance
extends RefCounted
var item_id: int
var kind: StringName
var equipped_to_member_id: String = ""
var consumed: bool = false
## Blacksmith enhancement level of a rare item, 0..ItemCatalog.MAX_ENHANCE.
var enhance: int = 0
## 0.95: the element a 프리즘 조각 rolled (&"" otherwise) and a growth stage (망고 씨앗 in 0.95;
## kept in saves, unused since 0.96).
var variant: StringName = &""
var growth: int = 0
