class_name BossIntentDatabase
extends RefCounted

const PHASES := {
	1: {
		"name": "Der Aschenkönig",
		"short_name": "PHASE 1",
		"overlay": "",
	},
	2: {
		"name": "Zorn der Asche",
		"short_name": "PHASE 2",
		"overlay": "res://assets/bosses/morvath/phase_2_overlay1.png",
	},
}

const INTENTS := [
	{
		"id": "skull_storm",
		"name": "Schädelsturm",
		"icon": "☠",
		"target_mode": "all",
		"phase_values": {1: {"damage": 2, "healing": 0}, 2: {"damage": 3, "healing": 0}},
		"animation": "skull_swarm",
		"description": "Trifft alle lebenden Helden für 2 Schaden.",
	},
	{
		"id": "soul_lance",
		"name": "Seelenlanze",
		"icon": "✦",
		"target_mode": "single",
		"phase_values": {1: {"damage": 4, "healing": 0}, 2: {"damage": 6, "healing": 0}},
		"animation": "spell_blast",
		"description": "Trifft einen angekündigten Helden für 4 Schaden.",
	},
	{
		"id": "dark_ritual",
		"name": "Dunkles Ritual",
		"icon": "◈",
		"target_mode": "all",
		"phase_values": {1: {"damage": 1, "healing": 3}, 2: {"damage": 2, "healing": 4}},
		"animation": "energy_charge",
		"description": "Heilt Morvath um bis zu 3 LP und trifft alle Helden für 1 Schaden.",
	},
]


static func get_intent(intent_id: String, boss_phase: int = 1) -> Dictionary:
	for intent: Dictionary in INTENTS:
		if intent["id"] == intent_id:
			var result := intent.duplicate(true)
			var values: Dictionary = result.get("phase_values", {}).get(clampi(boss_phase, 1, 2), {})
			result["damage"] = int(values.get("damage", 0))
			result["healing"] = int(values.get("healing", 0))
			result["boss_phase"] = clampi(boss_phase, 1, 2)
			return result
	return {}


static func get_phase(boss_phase: int) -> Dictionary:
	return Dictionary(PHASES.get(clampi(boss_phase, 1, 2), PHASES[1])).duplicate(true)


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
