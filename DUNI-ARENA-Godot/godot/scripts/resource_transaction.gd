class_name ResourceTransaction
extends RefCounted
static func can_spend(run: RunState,gold: int,tokens: int,receipt: String) -> bool:
	return run!=null and not run.game_over and gold>=0 and tokens>=0 and run.gold>=gold and run.tokens>=tokens and not receipt.is_empty() and not run.transaction_receipts.has(receipt)
static func spend(run: RunState,gold: int,tokens: int,receipt: String) -> bool:
	if not can_spend(run,gold,tokens,receipt):return false
	run.gold-=gold;run.tokens-=tokens;run.transaction_receipts[receipt]={"gold":gold,"tokens":tokens};return true
