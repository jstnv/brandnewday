class_name CombatRoom
extends Node2D

signal expedition_finished(objective_complete: bool)

const SurvivorScene := preload("res://scripts/survivor.gd")
const ZombieScene := preload("res://scripts/zombie.gd")

var survivor: Survivor
var zombies: Array[Zombie] = []
var event_lines: Array[String] = []
var debug_visible := true
var _hud: Label
var mission_state: MissionState
var mission_mode := false
var has_departed_entry := false
var supply_position := Vector2(1080.0, 560.0)
var extraction_area := Rect2(105.0, 285.0, 105.0, 155.0)

func configure_mission(state: MissionState) -> void:
	mission_state = state
	mission_mode = true

func _ready() -> void:
	_build_room()
	if mission_state == null:
		reset_room()
	else:
		_spawn_current_expedition()

func _process(_delta: float) -> void:
	if mission_mode:
		_check_extraction()
	_update_hud()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and mission_mode:
		try_collect_supply()
	elif event.is_action_pressed("reset_room") and not mission_mode:
		reset_room()
	elif event.is_action_pressed("toggle_debug"):
		debug_visible = not debug_visible
		_hud.visible = debug_visible

func _build_room() -> void:
	_add_wall_collision(Rect2(520.0, 185.0, 35.0, 310.0))
	_add_wall_collision(Rect2(755.0, 95.0, 35.0, 265.0))
	_add_wall_collision(Rect2(755.0, 465.0, 35.0, 180.0))
	_hud = Label.new()
	_hud.position = Vector2(18.0, 14.0)
	_hud.add_theme_font_size_override("font_size", 17)
	_hud.add_theme_color_override("font_color", Color("f4f1de"))
	_hud.add_theme_color_override("font_shadow_color", Color("181818"))
	_hud.add_theme_constant_override("shadow_offset_x", 2)
	_hud.add_theme_constant_override("shadow_offset_y", 2)
	add_child(_hud)

func _add_wall_collision(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func reset_room() -> void:
	mission_state = MissionState.new()
	mission_state.begin_expedition()
	mission_mode = false
	_spawn_current_expedition()

func _spawn_current_expedition() -> void:
	if is_instance_valid(survivor):
		survivor.queue_free()
	for zombie in zombies:
		if is_instance_valid(zombie):
			zombie.queue_free()
	zombies.clear()
	survivor = SurvivorScene.new()
	survivor.position = Vector2(245.0, 360.0)
	add_child(survivor)
	survivor.setup(self)
	survivor.event_reported.connect(_report_event)
	if not mission_state.is_zombie_dead("depot_zombie_a"):
		_spawn_zombie(Vector2(675.0, 300.0), "Depot Zombie A", "depot_zombie_a")
	if not mission_state.is_zombie_dead("depot_zombie_b"):
		_spawn_zombie(Vector2(875.0, 455.0), "Depot Zombie B", "depot_zombie_b")
	for index in mission_state.introduced_perimeter_zombie_ids.size():
		var zombie_id := mission_state.introduced_perimeter_zombie_ids[index]
		if mission_state.is_zombie_dead(zombie_id):
			continue
		var perimeter_position := Vector2(1140.0, 145.0 + float((index * 135) % 430))
		_spawn_zombie(perimeter_position, "Perimeter Zombie %d" % (index + 1), zombie_id)
	has_departed_entry = false
	event_lines = ["Expedition %d began — mission state restored" % mission_state.expedition_count]

func _spawn_zombie(position_value: Vector2, label: String, zombie_id: String = "") -> void:
	var zombie: Zombie = ZombieScene.new()
	zombie.position = position_value
	add_child(zombie)
	zombie.setup(survivor, label, zombie_id)
	zombie.event_reported.connect(_report_event)
	zombie.died.connect(_on_zombie_died)
	zombies.append(zombie)

func _on_zombie_died(zombie_id: String) -> void:
	if zombie_id.is_empty(): return
	mission_state.mark_zombie_dead(zombie_id)
	_report_event("Persistent kill recorded: %s" % zombie_id)

func try_collect_supply() -> bool:
	if mission_state.is_supply_collected():
		_report_event("Bunker supply already secured on an earlier expedition")
		return false
	if survivor.global_position.distance_to(supply_position) > 58.0:
		_report_event("Move closer to the bunker supply")
		return false
	mission_state.collect_supply()
	_report_event("BUNKER SUPPLY SECURED — return to outdoor extraction")
	queue_redraw()
	return true

func _check_extraction() -> void:
	if not is_instance_valid(survivor): return
	if survivor.global_position.x > 390.0:
		has_departed_entry = true
	if has_departed_entry and extraction_area.has_point(survivor.global_position):
		set_process(false)
		set_process_unhandled_input(false)
		expedition_finished.emit(mission_state.is_objective_complete())

func find_melee_target(origin: Vector2, direction: Vector2) -> Zombie:
	var best: Zombie
	var best_distance := INF
	for zombie in zombies:
		if zombie.state == Zombie.State.DEAD:
			continue
		var offset := zombie.global_position - origin
		var distance := offset.length()
		if distance > CombatTuning.MELEE_RANGE:
			continue
		if distance > 0.0 and direction.dot(offset / distance) < CombatTuning.MELEE_ARC_DOT:
			continue
		# One winner only: the closest living zombie inside the aimed melee arc.
		if distance < best_distance:
			best_distance = distance
			best = zombie
	return best

func find_execution_target(origin: Vector2) -> Zombie:
	var best: Zombie
	var best_distance := INF
	for zombie in zombies:
		if not zombie.is_execution_eligible():
			continue
		var distance := zombie.global_position.distance_to(origin)
		if distance <= CombatTuning.EXECUTION_RANGE and distance < best_distance:
			best_distance = distance
			best = zombie
	return best

func find_firearm_target(origin: Vector2, direction: Vector2) -> Zombie:
	var best: Zombie
	var best_distance := INF
	var aim_threshold := cos(deg_to_rad(CombatTuning.PISTOL_SPREAD_DEGREES + 7.0))
	for zombie in zombies:
		if not zombie.is_firearm_target():
			continue
		var offset := zombie.global_position - origin
		var distance := offset.length()
		if distance <= 0.0 or distance > CombatTuning.PISTOL_RANGE:
			continue
		if direction.dot(offset / distance) < aim_threshold:
			continue
		if distance < best_distance:
			best_distance = distance
			best = zombie
	return best

func _report_event(message: String) -> void:
	event_lines.push_front(message)
	if event_lines.size() > 6:
		event_lines.resize(6)
	print(message)

func _update_hud() -> void:
	if not is_instance_valid(survivor):
		return
	var lines := PackedStringArray()
	lines.append("BRAND NEW DAY — MILESTONE 3 RETRIEVAL EXPEDITION")
	lines.append("WASD move | Shift sprint | Ctrl/C crouch | Mouse aim | 1 melee | 2 pistol")
	lines.append("LMB weapon | Space melee | E execute | R reload | L load | Q cycle mag | F interact | F1 HUD")
	lines.append("")
	lines.append("Survivor: %s  Stamina: %3d/100  Weapon: %s  Action: %s" % [survivor.get_movement_state(), roundi(survivor.stamina), survivor.weapon_name(), survivor.action_status()])
	lines.append("Inserted: %s  |  Loose %s: %d  |  Load target: %s" % [survivor.inserted_magazine.summary(), CombatTuning.PISTOL_AMMO_CATEGORY, survivor.loose_ammo, survivor.magazine_load_target.summary()])
	var spare_text := PackedStringArray()
	for magazine in survivor.spare_magazines:
		spare_text.append(magazine.summary())
	lines.append("Spares: " + ", ".join(spare_text))
	lines.append("Injury system: DEFERRED    %s" % survivor.last_hit_report)
	if mission_mode:
		var objective := "SECURED — return to extraction" if mission_state.is_objective_complete() else "Retrieve bunker supply at east depot (F)"
		lines.append("Objective: %s | Exit: green outdoor approach at west | Departed: %s" % [objective, str(has_departed_entry)])
	for zombie in zombies:
		lines.append("%s: %-8s HP %3d" % [zombie.display_name, zombie.state_name(), zombie.health])
	lines.append("")
	lines.append("EVENTS")
	for message in event_lines:
		lines.append("• " + message)
	_hud.text = "\n".join(lines)

func _draw() -> void:
	draw_rect(Rect2(CombatTuning.ROOM_ORIGIN, CombatTuning.ROOM_SIZE), Color("30353b"))
	draw_rect(Rect2(100.0, 275.0, 145.0, 175.0), Color("263c32"))
	draw_rect(extraction_area, Color("4d9b69", 0.55))
	for x in range(110, 1180, 50):
		draw_line(Vector2(x, 70), Vector2(x, 650), Color("343a41"), 1.0)
	for y in range(70, 650, 50):
		draw_line(Vector2(110, y), Vector2(1170, y), Color("343a41"), 1.0)
	draw_rect(Rect2(CombatTuning.ROOM_ORIGIN, CombatTuning.ROOM_SIZE), Color("69717a"), false, 20.0)
	draw_rect(Rect2(520.0, 185.0, 35.0, 310.0), Color("60676d"))
	draw_rect(Rect2(755.0, 95.0, 35.0, 265.0), Color("60676d"))
	draw_rect(Rect2(755.0, 465.0, 35.0, 180.0), Color("60676d"))
	draw_string(ThemeDB.fallback_font, Vector2(112.0, 470.0), "OUTDOOR EXTRACTION", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("78d49b"))
	if mission_state != null and not mission_state.is_supply_collected():
		draw_circle(supply_position, 22.0, Color("e4c65a"))
		draw_rect(Rect2(supply_position - Vector2(26.0, 26.0), Vector2(52.0, 52.0)), Color("fff0a3"), false, 3.0)
		draw_string(ThemeDB.fallback_font, supply_position + Vector2(-54.0, -36.0), "BUNKER SUPPLY [F]", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("fff0a3"))
	draw_string(ThemeDB.fallback_font, Vector2(900, 690), "Original placeholder visuals", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("aab2ba"))
