class_name BossIntentDatabase
extends RefCounted

const INTENTS := [
	{
		"id": "skull_storm",
		"name": "Schädelsturm",
		"icon": "☠",
		"target_mode": "all",
		"damage": 2,
		"healing": 0,
		"animation": "skull_swarm",
		"description": "Trifft alle lebenden Helden für 2 Schaden.",
	},
	{
		"id": "soul_lance",
		"name": "Seelenlanze",
		"icon": "✦",
		"target_mode": "single",
		"damage": 4,
		"healing": 0,
		"animation": "spell_blast",
		"description": "Trifft einen angekündigten Helden für 4 Schaden.",
	},
	{
		"id": "dark_ritual",
		"name": "Dunkles Ritual",
		"icon": "◈",
		"target_mode": "all",
		"damage": 1,
		"healing": 3,
		"animation": "energy_charge",
		"description": "Heilt Morvath um bis zu 3 LP und trifft alle Helden für 1 Schaden.",
	},
]


static func get_intent(intent_id: String) -> Dictionary:
	for intent: Dictionary in INTENTS:
		if intent["id"] == intent_id:
			return intent.duplicate(true)
	return {}


static func ordered_ids() -> Array[String]:
	var result: Array[String] = []
	for intent: Dictionary in INTENTS:
		result.append(intent["id"])
	return result


static func display_text(intent: Dictionary) -> String:
	var target_text := "ALLE"
	if intent.get("target_mode", "all") == "single":
		target_text = String(intent.get("target_display_name", "SPIELER")).to_upper()
	if int(intent.get("healing", 0)) > 0:
		return "%s %s · +%d LP · ALLE −%d" % [intent.get("icon", ""), String(intent.get("name", "")).to_upper(), int(intent.get("healing", 0)), int(intent.get("damage", 0))]
	return "%s %s → %s · %d SCHADEN" % [intent.get("icon", ""), String(intent.get("name", "")).to_upper(), target_text, int(intent.get("damage", 0))]
