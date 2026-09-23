class_name MissionState
extends RefCounted

const SUPPLY_ID := "bunker_supply_01"
const CORE_ZOMBIE_IDS := ["depot_zombie_a", "depot_zombie_b"]

var expedition_count := 0
var dead_zombie_ids: Dictionary = {}
var collected_item_ids: Dictionary = {}
var completed_objective_steps: Dictionary = {}
var introduced_perimeter_zombie_ids: Array[String] = []
var successful_extractions := 0
var retreats := 0

func begin_expedition() -> void:
	expedition_count += 1
	if expedition_count > 1:
		var perimeter_id := "perimeter_zombie_%02d" % (expedition_count - 1)
		if not introduced_perimeter_zombie_ids.has(perimeter_id):
			introduced_perimeter_zombie_ids.append(perimeter_id)

func mark_zombie_dead(zombie_id: String) -> void:
	dead_zombie_ids[zombie_id] = true

func is_zombie_dead(zombie_id: String) -> bool:
	return dead_zombie_ids.has(zombie_id)

func collect_supply() -> bool:
	if collected_item_ids.has(SUPPLY_ID):
		return false
	collected_item_ids[SUPPLY_ID] = true
	completed_objective_steps["supply_secured"] = true
	return true

func is_supply_collected() -> bool:
	return collected_item_ids.has(SUPPLY_ID)

func is_objective_complete() -> bool:
	return completed_objective_steps.has("supply_secured")

func record_extraction() -> void:
	if is_objective_complete(): successful_extractions += 1
	else: retreats += 1

func living_zombie_ids_for_expedition() -> Array[String]:
	var result: Array[String] = []
	for zombie_id in CORE_ZOMBIE_IDS:
		if not is_zombie_dead(zombie_id): result.append(zombie_id)
	for zombie_id in introduced_perimeter_zombie_ids:
		if not is_zombie_dead(zombie_id): result.append(zombie_id)
	return result
