class_name RunState
extends RefCounted
## Run-owned guild/resources with separate TowerRunState progression. No save files.

var run_id: String = "run_" + Crypto.new().generate_random_bytes(16).hex_encode()
var guild_members: Dictionary = {} # member_id -> GuildMemberState
var next_member_number: int = 1
var settled_battle_ids: Dictionary = {} # result ID -> true; run-scoped idempotency

var last_formation := FormationState.new() # Successful starting placement only.

# Web newTowerState hp/maxHp = 100. Separate from individual unit HP.
var player_max_hp: float = 100.0
var player_hp: float = 100.0:
	set(value):
		if not is_finite(value):
			return
		player_hp = clampf(value, 0, player_max_hp)
		if player_hp <= 0:
			game_over = true
			game_over_reason = GameOverReason.PLAYER_HP
var game_over: bool = false
enum GameOverReason { NONE, PLAYER_HP, NO_LIVING_MEMBERS, ABANDON }
var game_over_reason: GameOverReason = GameOverReason.NONE
var death_losses_by_result_id: Dictionary = {} # live death-event receipts, ID -> member -> nominal loss

# Run-owned individual cards; actual acquisition/shop content is Phase10.
var strategy_cards: Array[StrategyCardInstance] = []
var next_strategy_card_number: int = 1
var strategy_progress := StrategyProgressContext.new()
var strategy_use_receipts: Dictionary = {}
func give_strategy_card(kind: StringName) -> StrategyCardInstance:
	if StrategyCardCatalog.get_card(kind) == null: return null
	var card := StrategyCardInstance.new()
	card.card_id = next_strategy_card_number
	next_strategy_card_number += 1
	card.kind = kind
	strategy_cards.append(card)
	return card
func get_strategy_card(id: int) -> StrategyCardInstance:
	for card in strategy_cards:
		if card.card_id == id: return card
	return null

# Tower progression/economy; inventory is run-owned. No save files.
var gold: int = 0
var tokens: int = 0
var tower: TowerRunState

# Phase10 ownership and transaction receipts; no file persistence.
var inventory: Array[ItemInstance] = []
var next_item_number: int = 1
var inventory_receipts: Dictionary = {}
var transaction_receipts: Dictionary = {}
var content_receipts: Dictionary = {}
