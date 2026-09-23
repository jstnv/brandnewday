class_name Magazine
extends RefCounted

var stable_id: String
var ammo_category: String
var rounds: int
var capacity: int

func _init(id_value: String, category_value: String, rounds_value: int, capacity_value: int) -> void:
	stable_id = id_value
	ammo_category = category_value
	capacity = capacity_value
	rounds = clampi(rounds_value, 0, capacity)

func is_compatible(category_value: String) -> bool:
	return ammo_category == category_value

func can_accept_round() -> bool:
	return rounds < capacity

func insert_round() -> bool:
	if not can_accept_round():
		return false
	rounds += 1
	return true

func consume_round() -> bool:
	if rounds <= 0:
		return false
	rounds -= 1
	return true

func summary() -> String:
	return "%s %d/%d" % [stable_id, rounds, capacity]
