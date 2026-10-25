class_name CardDatabase
extends RefCounted

const CARDS := [
	{
		"id": "ash_mage",
		"name": "Aschehexer",
		"artwork": "res://assets/cards/monsters/aschengeborene/kreatur_01/Aschehexer.png",
		"attack": 3,
		"rarity": "common",
	},
	{
		"id": "plague_undead",
		"name": "Seuchenuntoter",
		"artwork": "res://assets/cards/monsters/grabgeborene/Seuchenuntoter.png",
		"attack": 3,
		"rarity": "common",
	},
	{
		"id": "night_blade",
		"name": "Nachtklinge",
		"artwork": "res://assets/cards/monsters/schleierkinder/kreatur_02/Nachtklinge.png",
		"attack": 4,
		"rarity": "common",
	},
	{
		"id": "root_beast",
		"name": "Wurzelbestie",
		"artwork": "res://assets/cards/monsters/dorngebundene/kreatur_01/Wurzelbestie.png",
		"attack": 5,
		"rarity": "rare",
	},
	{
		"id": "stone_guardian",
		"name": "Steinwächter",
		"artwork": "res://assets/cards/monsters/steinerne/kreatur_03/Steinwächter.png",
		"attack": 5,
		"rarity": "rare",
	},
	{
		"id": "temple_guard",
		"name": "Tempelwache",
		"artwork": "res://assets/cards/monsters/sonnengeweihte/kreatur_03/Tempelwache.png",
		"attack": 6,
		"rarity": "epic",
	},
	{
		"id": "ember_butcher",
		"name": "Glutschlächter",
		"artwork": "res://assets/cards/monsters/aschengeborene/kreatur_02/Glutschlächter.png",
		"attack": 7,
		"rarity": "epic",
	},
	{
		"id": "sun_champion",
		"name": "Sonnenchampion",
		"artwork": "res://assets/cards/monsters/sonnengeweihte/kreatur_02/Sonnenchampion.png",
		"attack": 10,
		"rarity": "legendary",
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


static func draw_card(rng: RandomNumberGenerator) -> Dictionary:
	var rarity := _roll_rarity(rng)
	var candidates: Array[Dictionary] = []
	for card: Dictionary in CARDS:
		if card["rarity"] == rarity:
			candidates.append(card)
	return candidates[rng.randi_range(0, candidates.size() - 1)].duplicate(true)


static func get_card(card_id: String) -> Dictionary:
	for card: Dictionary in CARDS:
		if card["id"] == card_id:
			return card.duplicate(true)
	return {}


static func public_card(card: Dictionary) -> Dictionary:
	return {
		"id": card["id"],
		"name": card["name"],
		"attack": card["attack"],
		"rarity": card["rarity"],
		"rarity_label": RARITY_LABELS[card["rarity"]],
		"artwork_url": "/asset/" + card["id"],
	}


static func _roll_rarity(rng: RandomNumberGenerator) -> String:
	var roll := rng.randf() * 100.0
	if roll < 65.0:
		return "common"
	if roll < 90.0:
		return "rare"
	if roll < 99.0:
		return "epic"
	return "legendary"
