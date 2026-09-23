class_name CombatRoom
extends Node2D

const SurvivorScene := preload("res://scripts/survivor.gd")
const ZombieScene := preload("res://scripts/zombie.gd")

var survivor: Survivor
var zombies: Array[Zombie] = []
var event_lines: Array[String] = []
var debug_visible := true
var _hud: Label

func _ready() -> void:
	_build_room()
	reset_room()

func _process(_delta: float) -> void:
	_update_hud()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_room"):
		reset_room()
	elif event.is_action_pressed("toggle_debug"):
		debug_visible = not debug_visible
		_hud.visible = debug_visible

func _build_room() -> void:
	_hud = Label.new()
	_hud.position = Vector2(18.0, 14.0)
	_hud.add_theme_font_size_override("font_size", 17)
	_hud.add_theme_color_override("font_color", Color("f4f1de"))
	_hud.add_theme_color_override("font_shadow_color", Color("181818"))
	_hud.add_theme_constant_override("shadow_offset_x", 2)
	_hud.add_theme_constant_override("shadow_offset_y", 2)
	add_child(_hud)

func reset_room() -> void:
	if is_instance_valid(survivor):
		survivor.queue_free()
	for zombie in zombies:
		if is_instance_valid(zombie):
			zombie.queue_free()
	zombies.clear()
	survivor = SurvivorScene.new()
	survivor.position = Vector2(380.0, 360.0)
	add_child(survivor)
	survivor.setup(self)
	survivor.event_reported.connect(_report_event)
	_spawn_zombie(Vector2(720.0, 320.0), "Zombie A")
	_spawn_zombie(Vector2(790.0, 405.0), "Zombie B")
	event_lines = ["Room reset — two standard zombies ready"]

func _spawn_zombie(position_value: Vector2, label: String) -> void:
	var zombie: Zombie = ZombieScene.new()
	zombie.position = position_value
	add_child(zombie)
	zombie.setup(survivor, label)
	zombie.event_reported.connect(_report_event)
	zombies.append(zombie)

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
	lines.append("BRAND NEW DAY — MILESTONE 2 FIREARM SLICE")
	lines.append("WASD move | Shift sprint | Ctrl/C crouch | Mouse aim | 1 melee | 2 pistol")
	lines.append("LMB use weapon | Space melee | E tap/hold execute | R reload | L load | Q cycle mag | F5 reset | F1 HUD")
	lines.append("")
	lines.append("Survivor: %s  Stamina: %3d/100  Weapon: %s  Action: %s" % [survivor.get_movement_state(), roundi(survivor.stamina), survivor.weapon_name(), survivor.action_status()])
	lines.append("Inserted: %s  |  Loose %s: %d  |  Load target: %s" % [survivor.inserted_magazine.summary(), CombatTuning.PISTOL_AMMO_CATEGORY, survivor.loose_ammo, survivor.magazine_load_target.summary()])
	var spare_text := PackedStringArray()
	for magazine in survivor.spare_magazines:
		spare_text.append(magazine.summary())
	lines.append("Spares: " + ", ".join(spare_text))
	lines.append("Injury system: DEFERRED    %s" % survivor.last_hit_report)
	for zombie in zombies:
		lines.append("%s: %-8s HP %3d" % [zombie.display_name, zombie.state_name(), zombie.health])
	lines.append("")
	lines.append("EVENTS")
	for message in event_lines:
		lines.append("• " + message)
	_hud.text = "\n".join(lines)

func _draw() -> void:
	draw_rect(Rect2(CombatTuning.ROOM_ORIGIN, CombatTuning.ROOM_SIZE), Color("30353b"))
	for x in range(110, 1180, 50):
		draw_line(Vector2(x, 70), Vector2(x, 650), Color("343a41"), 1.0)
	for y in range(70, 650, 50):
		draw_line(Vector2(110, y), Vector2(1170, y), Color("343a41"), 1.0)
	draw_rect(Rect2(CombatTuning.ROOM_ORIGIN, CombatTuning.ROOM_SIZE), Color("69717a"), false, 20.0)
	draw_string(ThemeDB.fallback_font, Vector2(900, 690), "Original placeholder visuals", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("aab2ba"))
