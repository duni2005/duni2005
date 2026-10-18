class_name ShopOffer
extends RefCounted
## Each stock copy is a separate offer, even when kind is identical.
var offer_id: String
var category: StringName
var kind: StringName
var gold_price: int
var purchased: bool = false
