class_name AbilityDatabase
extends RefCounted

const MAX_RANK := 3

const ABILITIES := [
	{
		"id": "ash_blade",
		"name": "Aschenklinge",
		"type": "damage",
		"rarity": "common",
		"weight": 100,
		"max_rank": MAX_RANK,
		"artwork": "res://assets/cards/monsters/schleierkinder/kreatur_02/Nachtklinge.png",
		"descriptions": ["+1 Angriff.", "+2 Angriff insgesamt.", "+3 Angriff insgesamt."],
		"effects": {"attack_bonus": [1, 2, 3]},
	},
	{
		"id": "life_steal",
		"name": "Lebensraub",
		"type": "healing",
		"rarity": "common",
		"weight": 100,
		"max_rank": MAX_RANK,
		"artwork": "res://assets/cards/monsters/grabgeborene/Seuchenuntoter.png",
		"descriptions": ["Heilt nach Angriff 1 LP.", "Heilt nach Angriff weiterhin 1 LP.", "Heilt nach Angriff 2 LP."],
		"effects": {"healing": [1, 1, 2]},
	},
	{
		"id": "bone_guard",
		"name": "Knochenschutz",
		"type": "defense",
		"rarity": "rare",
		"weight": 65,
		"max_rank": MAX_RANK,
		"artwork": "res://assets/cards/monsters/steinerne/kreatur_03/Steinwächter.png",
		"descriptions": ["Jeder 2. Bossangriff: −1 Schaden.", "Jeder 2. Bossangriff: −2 Schaden.", "Immer −1, jeder 2. Angriff insgesamt −2."],
		"effects": {"reduction": [1, 2, 2]},
	},
	{
		"id": "rune_bolt",
		"name": "Runenblitz",
		"type": "extra_attack",
		"rarity": "rare",
		"weight": 65,
		"max_rank": MAX_RANK,
		"artwork": "res://assets/cards/monsters/steinerne/kreatur_01/Reliktwerker.png",
		"descriptions": ["Alle 3 Runden +2 Schaden.", "Alle 3 Runden +3 Schaden.", "Alle 3 Runden +4 Schaden."],
		"effects": {"periodic_damage": [2, 3, 4], "interval": 3},
	},
	{
		"id": "blood_frenzy",
		"name": "Blutrausch",
		"type": "conditional_damage",
		"rarity": "epic",
		"weight": 35,
		"max_rank": MAX_RANK,
		"artwork": "res://assets/cards/monsters/aschengeborene/kreatur_02/Glutschlächter.png",
		"descriptions": ["Unter 50 % LP: +2 Angriff.", "Unter 50 % LP: +3 Angriff.", "Unter 50 % LP: +5 Angriff."],
		"effects": {"low_health_bonus": [2, 3, 5]},
	},
	{
		"id": "soul_fire",
		"name": "Seelenfeuer",
		"type": "rare_power",
		"rarity": "legendary",
		"weight": 5,
		"max_rank": MAX_RANK,
		"artwork": "res://assets/cards/monsters/sonnengeweihte/kreatur_02/Sonnenchampion.png",
		"descriptions": ["Jeder 3. Angriff: +4 Schaden.", "Jeder 3. Angriff: +7 Schaden.", "Jeder 3. Angriff: +10 Schaden."],
		"effects": {"periodic_damage": [4, 7, 10], "interval": 3},
	},
]

const RARITY_LABELS := {
	"common": "Gewöhnlich",
	"rare": "Selten",
	"epic": "Episch",
	"legendary": "Legendär",
}

const RARITY_COLORS := {
	"common": Color("55c271"),
	"rare": Color("4b91e2"),
	"epic": Color("a868e8"),
	"legendary": Color("e9b94c"),
}


static func get_ability(ability_id: String) -> Dictionary:
	for ability: Dictionary in ABILITIES:
		if ability["id"] == ability_id:
			return ability.duplicate(true)
	return {}


static func effect_value(ability_id: String, effect_name: String, rank: int) -> int:
	if rank <= 0:
		return 0
	var ability := get_ability(ability_id)
	if ability.is_empty():
		return 0
	var values: Array = ability.get("effects", {}).get(effect_name, [])
	if values.is_empty():
		return 0
	return int(values[clampi(rank, 1, values.size()) - 1])


static func make_offer(ability: Dictionary, current_rank: int) -> Dictionary:
	var next_rank := clampi(current_rank + 1, 1, int(ability["max_rank"]))
	return {
		"card_kind": "upgrade",
		"kind_label": "DAUERHAFTES UPGRADE",
		"id": ability["id"],
		"name": ability["name"],
		"type": ability["type"],
		"rarity": ability["rarity"],
		"rarity_label": RARITY_LABELS[ability["rarity"]],
		"artwork": ability["artwork"],
		"artwork_url": "/asset/" + ability["id"],
		"description": ability["descriptions"][next_rank - 1],
		"current_rank": current_rank,
		"next_rank": next_rank,
		"max_rank": ability["max_rank"],
		"rank_label": "NEU · RANG 1" if current_rank == 0 else "RANG %d → %d" % [current_rank, next_rank],
	}


static func draw_hand(rng: RandomNumberGenerator, ranks: Dictionary, round_number: int, hand_size: int = 3) -> Array[Dictionary]:
	var eligible: Array[Dictionary] = []
	var owned: Array[Dictionary] = []
	for definition: Dictionary in ABILITIES:
		var current_rank := int(ranks.get(definition["id"], 0))
		if current_rank >= int(definition["max_rank"]):
			continue
		eligible.append(definition)
		if current_rank > 0:
			owned.append(definition)

	var chosen: Array[Dictionary] = []
	if round_number >= 2 and not owned.is_empty():
		var stacked: Dictionary = owned[rng.randi_range(0, owned.size() - 1)]
		chosen.append(stacked)
		_remove_by_id(eligible, stacked["id"])

	while chosen.size() < hand_size and not eligible.is_empty():
		var picked := _weighted_pick(rng, eligible)
		chosen.append(picked)
		_remove_by_id(eligible, picked["id"])

	var offers: Array[Dictionary] = []
	for ability: Dictionary in chosen:
		offers.append(make_offer(ability, int(ranks.get(ability["id"], 0))))
	return offers


static func active_abilities(ranks: Dictionary, context: Dictionary = {}) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for ability: Dictionary in ABILITIES:
		var rank := int(ranks.get(ability["id"], 0))
		if rank <= 0:
			continue
		var entry := {
			"id": ability["id"],
			"name": ability["name"],
			"rank": rank,
			"max_rank": ability["max_rank"],
			"rarity": ability["rarity"],
			"rarity_label": RARITY_LABELS[ability["rarity"]],
			"effect_text": _active_effect_text(ability["id"], rank),
			"trigger_text": "",
			"condition_met": false,
		}
		var round_number := int(context.get("round", 1))
		var attack_count := int(context.get("hero_attack_count", 0))
		if ability["id"] == "rune_bolt":
			var next_round := round_number if round_number % 3 == 0 else round_number + (3 - round_number % 3)
			entry["trigger_text"] = "Nächste Auslösung: Runde %d" % next_round
		elif ability["id"] == "soul_fire":
			var attacks_remaining := 3 - attack_count % 3
			entry["trigger_text"] = "Nächste Auslösung in %d Angriff%s" % [attacks_remaining, "" if attacks_remaining == 1 else "en"]
		elif ability["id"] == "blood_frenzy":
			var hp := int(context.get("hp", 0))
			var max_hp := maxi(1, int(context.get("max_hp", 20)))
			var active := hp * 2 < max_hp
			entry["condition_met"] = active
			entry["trigger_text"] = "Bedingung momentan: %s" % ("AKTIV" if active else "nicht aktiv")
		result.append(entry)
	return result


static func _active_effect_text(ability_id: String, rank: int) -> String:
	match ability_id:
		"ash_blade":
			return "Dauerhaft +%d Angriff." % effect_value(ability_id, "attack_bonus", rank)
		"life_steal":
			return "Heilt bei jedem Angriff %d LP." % effect_value(ability_id, "healing", rank)
		"bone_guard":
			if rank == 1:
				return "Jeder 2. Bossangriff verursacht 1 Schaden weniger."
			if rank == 2:
				return "Jeder 2. Bossangriff verursacht 2 Schaden weniger."
			return "Jeder Bossangriff −1, jeder 2. insgesamt −2 Schaden."
		"rune_bolt":
			return "+%d Schaden alle 3 Runden." % effect_value(ability_id, "periodic_damage", rank)
		"blood_frenzy":
			return "Unter 50 %% LP: +%d Angriff." % effect_value(ability_id, "low_health_bonus", rank)
		"soul_fire":
			return "Jeder 3. Angriff verursacht +%d Schaden." % effect_value(ability_id, "periodic_damage", rank)
	return ""


static func _weighted_pick(rng: RandomNumberGenerator, candidates: Array[Dictionary]) -> Dictionary:
	var total_weight := 0
	for candidate: Dictionary in candidates:
		total_weight += int(candidate["weight"])
	var roll := rng.randi_range(1, total_weight)
	var cursor := 0
	for candidate: Dictionary in candidates:
		cursor += int(candidate["weight"])
		if roll <= cursor:
			return candidate
	return candidates.back()


static func _remove_by_id(candidates: Array[Dictionary], ability_id: String) -> void:
	for index in range(candidates.size() - 1, -1, -1):
		if candidates[index]["id"] == ability_id:
			candidates.remove_at(index)
