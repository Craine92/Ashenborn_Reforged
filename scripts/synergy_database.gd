class_name SynergyDatabase
extends RefCounted

const SYNERGIES := [
	{
		"id": "rune_blade",
		"name": "Runenklinge",
		"requirements": {"ash_blade": 1, "rune_bolt": 1},
		"requirements_text": "Aschenklinge Rang 1 + Runenblitz Rang 1",
		"effect_text": "Wenn Runenblitz auslöst: zusätzlich +2 Schaden.",
	},
	{
		"id": "blood_shield",
		"name": "Blutschild",
		"requirements": {"life_steal": 1, "bone_guard": 1},
		"requirements_text": "Lebensraub Rang 1 + Knochenschutz Rang 1",
		"effect_text": "Wenn Knochenschutz Schaden reduziert: heilt 1 LP.",
	},
]


static func get_synergy(synergy_id: String) -> Dictionary:
	for synergy: Dictionary in SYNERGIES:
		if synergy["id"] == synergy_id:
			return synergy.duplicate(true)
	return {}


static func is_active(synergy_id: String, ranks: Dictionary) -> bool:
	var synergy := get_synergy(synergy_id)
	if synergy.is_empty():
		return false
	for ability_id in synergy["requirements"]:
		if int(ranks.get(ability_id, 0)) < int(synergy["requirements"][ability_id]):
			return false
	return true


static func active_synergies(ranks: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for synergy: Dictionary in SYNERGIES:
		if is_active(synergy["id"], ranks):
			result.append({
				"id": synergy["id"],
				"name": synergy["name"],
				"requirements_text": synergy["requirements_text"],
				"effect_text": synergy["effect_text"],
			})
	return result
