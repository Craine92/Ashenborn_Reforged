class_name TacticDatabase
extends RefCounted

const OFFER_CHANCE := 0.42

const TACTICS := [
	{
		"id": "defensive_stance",
		"name": "Abwehrhaltung",
		"rarity": "rare",
		"artwork": "res://assets/cards/monsters/steinerne/kreatur_03/Steinwächter.png",
		"description": "Reduziert deinen Boss-Schaden in dieser Runde um 3.",
		"risk_text": "",
	},
	{
		"id": "ritual_breaker",
		"name": "Ritualbrecher",
		"rarity": "epic",
		"artwork": "res://assets/cards/monsters/sonnengeweihte/kreatur_01/Sonnenpriesterin.png",
		"description": "Verhindert Morvaths Ritualheilung in dieser Runde.",
		"risk_text": "Der Ritualschaden bleibt bestehen.",
	},
	{
		"id": "storm_strike",
		"name": "Sturmstoß",
		"rarity": "legendary",
		"artwork": "res://assets/cards/monsters/aschengeborene/kreatur_02/Glutschlächter.png",
		"description": "+4 Schaden in dieser Runde.",
		"risk_text": "Risiko: Trifft Morvath dich, verursacht er +2 Schaden.",
	},
]


static func get_tactic(tactic_id: String) -> Dictionary:
	for tactic: Dictionary in TACTICS:
		if tactic["id"] == tactic_id:
			return tactic.duplicate(true)
	return {}


static func make_offer(tactic: Dictionary) -> Dictionary:
	return {
		"card_kind": "tactic",
		"kind_label": "NUR DIESE RUNDE",
		"id": tactic["id"],
		"name": tactic["name"],
		"type": "tactic",
		"rarity": tactic["rarity"],
		"rarity_label": "Taktik",
		"artwork": tactic["artwork"],
		"artwork_url": "/asset/" + String(tactic["id"]),
		"description": tactic["description"],
		"risk_text": tactic.get("risk_text", ""),
		"rank_label": "NUR DIESE RUNDE",
	}


static func eligible_tactics(intent: Dictionary, player_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var target_mode := String(intent.get("target_mode", "all"))
	var is_targeted := target_mode == "all" or String(intent.get("target_player_id", "")) == player_id
	if is_targeted:
		result.append(get_tactic("defensive_stance"))
	if intent.get("id", "") == "dark_ritual":
		result.append(get_tactic("ritual_breaker"))
	result.append(get_tactic("storm_strike"))
	return result
