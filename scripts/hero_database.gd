class_name HeroDatabase
extends RefCounted

const ASH_KNIGHT := {
	"id": "ash_knight",
	"name": "Aschenritter",
	"max_hp": 20,
	"base_attack": 4,
	"artwork": "res://assets/cards/monsters/sonnengeweihte/kreatur_04/Ordensritter.png",
}


static func default_hero() -> Dictionary:
	return ASH_KNIGHT.duplicate(true)


static func get_hero(hero_id: String) -> Dictionary:
	if hero_id == ASH_KNIGHT["id"]:
		return default_hero()
	return {}
