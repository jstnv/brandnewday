class_name Survivor
extends CharacterBody2D

signal event_reported(message: String)

enum Weapon { MELEE, PISTOL }
enum ExecutionMode { NONE, PHYSICAL, FIREARM }

var stamina := CombatTuning.MAX_STAMINA
var aim_direction := Vector2.RIGHT
var selected_weapon := Weapon.MELEE
var melee_cooldown := 0.0
var firearm_cooldown := 0.0
var stamina_recovery_delay := 0.0
var last_hit_report := "No survivor hits (injury deferred)"
var inserted_magazine: Magazine
var spare_magazines: Array[Magazine] = []
var loose_ammo := 0
var reload_target: Magazine
var reload_timer := 0.0
var is_reloading := false
var magazine_load_target: Magazine
var magazine_load_timer := 0.0
var is_loading_magazine := false
var is_executing := false
var execution_mode := ExecutionMode.NONE
var execution_target: Zombie
var execution_timer := 0.0
var execution_lock_position := Vector2.ZERO
var execution_choice_pending := false
var execution_choice_target: Zombie
var execution_hold_time := 0.0
var _room: CombatRoom

func setup(room: CombatRoom) -> void:
	_room = room
	_reset_inventory()
	queue_redraw()

func _reset_inventory() -> void:
	inserted_magazine = Magazine.new("MAG-A", CombatTuning.PISTOL_AMMO_CATEGORY, 5, CombatTuning.PISTOL_MAGAZINE_CAPACITY)
	spare_magazines = [
		Magazine.new("MAG-B", CombatTuning.PISTOL_AMMO_CATEGORY, 8, CombatTuning.PISTOL_MAGAZINE_CAPACITY),
		Magazine.new("MAG-C", CombatTuning.PISTOL_AMMO_CATEGORY, 2, CombatTuning.PISTOL_MAGAZINE_CAPACITY),
	]
	loose_ammo = 12
	magazine_load_target = spare_magazines[1]

func _physics_process(delta: float) -> void:
	melee_cooldown = maxf(0.0, melee_cooldown - delta)
	firearm_cooldown = maxf(0.0, firearm_cooldown - delta)
	_update_aim()
	if execution_choice_pending:
		velocity = Vector2.ZERO
		global_position = execution_lock_position
		execution_hold_time += delta
		if execution_hold_time >= CombatTuning.EXECUTION_HOLD_THRESHOLD:
			var held_target := execution_choice_target
			_clear_execution_choice()
			_start_physical_execution(held_target)
		global_position = execution_lock_position
		queue_redraw()
		return
	if is_executing:
		velocity = Vector2.ZERO
		global_position = execution_lock_position
		_update_execution(delta)
		global_position = execution_lock_position
		queue_redraw()
		return
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if is_loading_magazine and direction.length_squared() > 0.0:
		_cancel_magazine_loading("Magazine loading canceled by movement; inserted rounds kept")
	_update_reload(delta)
	_update_magazine_loading(delta)
	var speed := CombatTuning.WALK_SPEED
	var sprinting := Input.is_action_pressed("sprint") and direction.length_squared() > 0.0 and stamina > 0.0
	if Input.is_action_pressed("crouch"):
		speed = CombatTuning.CROUCH_SPEED
		sprinting = false
	elif sprinting:
		speed = CombatTuning.SPRINT_SPEED
		stamina = maxf(0.0, stamina - CombatTuning.SPRINT_DRAIN_PER_SECOND * delta)
		stamina_recovery_delay = CombatTuning.STAMINA_RECOVERY_DELAY
	if not sprinting:
		_recover_stamina(delta)
	velocity = direction * speed
	move_and_slide()
	global_position.x = clampf(global_position.x, CombatTuning.ROOM_ORIGIN.x + 24.0, CombatTuning.ROOM_ORIGIN.x + CombatTuning.ROOM_SIZE.x - 24.0)
	global_position.y = clampf(global_position.y, CombatTuning.ROOM_ORIGIN.y + 24.0, CombatTuning.ROOM_ORIGIN.y + CombatTuning.ROOM_SIZE.y - 24.0)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("primary_attack"):
		if selected_weapon == Weapon.PISTOL: try_fire()
		else: try_melee()
	elif event.is_action_pressed("melee") and selected_weapon == Weapon.MELEE: try_melee()
	elif event.is_action_pressed("execute"): begin_execute_input()
	elif event.is_action_released("execute"): release_execute_input()
	elif event.is_action_pressed("reload"): start_reload()
	elif event.is_action_pressed("load_magazine"): start_magazine_loading()
	elif event.is_action_pressed("cycle_magazine"): cycle_magazine_load_target()
	elif event.is_action_pressed("select_melee"): select_weapon(Weapon.MELEE)
	elif event.is_action_pressed("select_pistol"): select_weapon(Weapon.PISTOL)

func _recover_stamina(delta: float) -> void:
	if stamina_recovery_delay > 0.0: stamina_recovery_delay = maxf(0.0, stamina_recovery_delay - delta)
	else: stamina = minf(CombatTuning.MAX_STAMINA, stamina + CombatTuning.STAMINA_RECOVERY_PER_SECOND * delta)

func _update_aim() -> void:
	var mouse_vector := get_global_mouse_position() - global_position
	if mouse_vector.length() > 8.0: aim_direction = mouse_vector.normalized()

func select_weapon(weapon: Weapon) -> void:
	if is_executing or execution_choice_pending or selected_weapon == weapon: return
	if is_reloading: _cancel_reload("Reload canceled by weapon switch; magazines unchanged")
	if is_loading_magazine: _cancel_magazine_loading("Magazine loading canceled by weapon switch; inserted rounds kept")
	selected_weapon = weapon
	event_reported.emit("Selected %s" % weapon_name())

func try_melee() -> bool:
	if selected_weapon != Weapon.MELEE or is_executing or execution_choice_pending or melee_cooldown > 0.0: return false
	melee_cooldown = CombatTuning.MELEE_COOLDOWN
	var target := _room.find_melee_target(global_position, aim_direction)
	if target != null:
		target.receive_melee(CombatTuning.MELEE_DAMAGE, aim_direction)
		event_reported.emit("Melee hit %s for %d — exactly one target" % [target.display_name, CombatTuning.MELEE_DAMAGE])
	else: event_reported.emit("Melee missed")
	return true

func try_fire() -> bool:
	if selected_weapon != Weapon.PISTOL or is_executing or execution_choice_pending or is_reloading or is_loading_magazine or firearm_cooldown > 0.0: return false
	if not inserted_magazine.consume_round():
		event_reported.emit("PISTOL DRY — %s is empty" % inserted_magazine.stable_id)
		return false
	firearm_cooldown = CombatTuning.PISTOL_FIRE_COOLDOWN
	var shot_direction := aim_direction.rotated(deg_to_rad(randf_range(-CombatTuning.PISTOL_SPREAD_DEGREES, CombatTuning.PISTOL_SPREAD_DEGREES)))
	var target := _room.find_firearm_target(global_position, shot_direction)
	if target != null:
		target.receive_firearm(CombatTuning.PISTOL_DAMAGE, shot_direction)
		event_reported.emit("Pistol hit %s for %d — %s %d/%d" % [target.display_name, CombatTuning.PISTOL_DAMAGE, inserted_magazine.stable_id, inserted_magazine.rounds, inserted_magazine.capacity])
	else: event_reported.emit("Pistol missed — debug sound event — %s %d/%d" % [inserted_magazine.stable_id, inserted_magazine.rounds, inserted_magazine.capacity])
	return true

func start_reload() -> bool:
	if selected_weapon != Weapon.PISTOL or is_executing or execution_choice_pending or is_reloading or is_loading_magazine: return false
	var candidate := _best_reload_magazine()
	if candidate == null:
		event_reported.emit("No compatible loaded spare magazine")
		return false
	is_reloading = true
	reload_target = candidate
	reload_timer = CombatTuning.PISTOL_RELOAD_TIME
	event_reported.emit("Reloading with %s; %s remains inserted until completion" % [candidate.summary(), inserted_magazine.summary()])
	return true

func _best_reload_magazine() -> Magazine:
	var compatible: Array[Magazine] = []
	for magazine in spare_magazines:
		if magazine.is_compatible(CombatTuning.PISTOL_AMMO_CATEGORY) and magazine.rounds > 0: compatible.append(magazine)
	compatible.sort_custom(func(a: Magazine, b: Magazine) -> bool:
		if a.rounds == b.rounds: return a.stable_id < b.stable_id
		return a.rounds > b.rounds)
	return compatible[0] if not compatible.is_empty() else null

func _update_reload(delta: float) -> void:
	if not is_reloading: return
	reload_timer -= delta
	if reload_timer > 0.0: return
	var old_inserted := inserted_magazine
	spare_magazines.erase(reload_target)
	inserted_magazine = reload_target
	spare_magazines.append(old_inserted)
	is_reloading = false
	reload_target = null
	reload_timer = 0.0
	event_reported.emit("Reload complete — inserted %s; retained %s" % [inserted_magazine.summary(), old_inserted.summary()])

func _cancel_reload(message: String) -> void:
	is_reloading = false
	reload_target = null
	reload_timer = 0.0
	event_reported.emit(message)

func cycle_magazine_load_target() -> void:
	if is_executing or execution_choice_pending: return
	if is_loading_magazine: _cancel_magazine_loading("Magazine loading stopped; inserted rounds kept")
	var magazines := all_magazines_sorted()
	var current_index := magazines.find(magazine_load_target)
	magazine_load_target = magazines[(current_index + 1) % magazines.size()]
	event_reported.emit("Loose-round load target: %s" % magazine_load_target.summary())

func all_magazines_sorted() -> Array[Magazine]:
	var magazines: Array[Magazine] = [inserted_magazine]
	magazines.append_array(spare_magazines)
	magazines.sort_custom(func(a: Magazine, b: Magazine) -> bool: return a.stable_id < b.stable_id)
	return magazines

func start_magazine_loading() -> bool:
	if is_executing or execution_choice_pending or is_reloading: return false
	if is_loading_magazine:
		_cancel_magazine_loading("Magazine loading stopped; inserted rounds kept")
		return false
	if loose_ammo <= 0:
		event_reported.emit("No loose %s ammunition" % CombatTuning.PISTOL_AMMO_CATEGORY)
		return false
	if magazine_load_target == null or not magazine_load_target.is_compatible(CombatTuning.PISTOL_AMMO_CATEGORY):
		event_reported.emit("Selected magazine is incompatible")
		return false
	if not magazine_load_target.can_accept_round():
		event_reported.emit("%s is already full" % magazine_load_target.stable_id)
		return false
	is_loading_magazine = true
	magazine_load_timer = CombatTuning.MAGAZINE_LOAD_ROUND_TIME
	velocity = Vector2.ZERO
	event_reported.emit("Loading loose rounds into %s — stand still" % magazine_load_target.summary())
	return true

func _update_magazine_loading(delta: float) -> void:
	if not is_loading_magazine: return
	magazine_load_timer -= delta
	if magazine_load_timer > 0.0: return
	if loose_ammo <= 0 or not magazine_load_target.insert_round():
		_cancel_magazine_loading("Magazine loading complete")
		return
	loose_ammo -= 1
	event_reported.emit("Inserted one round — %s; loose %d" % [magazine_load_target.summary(), loose_ammo])
	if loose_ammo <= 0 or not magazine_load_target.can_accept_round(): _cancel_magazine_loading("Magazine loading complete")
	else: magazine_load_timer = CombatTuning.MAGAZINE_LOAD_ROUND_TIME

func _cancel_magazine_loading(message: String) -> void:
	is_loading_magazine = false
	magazine_load_timer = 0.0
	event_reported.emit(message)

func begin_execute_input() -> bool:
	if is_executing or execution_choice_pending or is_reloading or is_loading_magazine: return false
	var target := _room.find_execution_target(global_position)
	if target == null:
		event_reported.emit("No seated/prone zombie in execution range")
		return false
	if selected_weapon == Weapon.MELEE or target.state == Zombie.State.PRONE:
		_start_physical_execution(target)
		return true
	execution_choice_pending = true
	execution_choice_target = target
	execution_hold_time = 0.0
	execution_lock_position = global_position
	velocity = Vector2.ZERO
	event_reported.emit("Tap E: firearm execution | Hold E: bash (%.2f s)" % CombatTuning.EXECUTION_HOLD_THRESHOLD)
	return true

func release_execute_input() -> bool:
	if not execution_choice_pending: return false
	var target := execution_choice_target
	_clear_execution_choice()
	if inserted_magazine.rounds <= 0:
		event_reported.emit("EMPTY — tap firearm execution unavailable; hold E to bash")
		return false
	_start_firearm_execution(target)
	return true

func _clear_execution_choice() -> void:
	execution_choice_pending = false
	execution_choice_target = null
	execution_hold_time = 0.0

func _start_physical_execution(target: Zombie) -> void:
	is_executing = true
	execution_mode = ExecutionMode.PHYSICAL
	execution_target = target
	execution_lock_position = global_position
	velocity = Vector2.ZERO
	event_reported.emit("Physical execution committed on %s" % target.display_name)
	_apply_execution_bash()

func _start_firearm_execution(target: Zombie) -> void:
	is_executing = true
	execution_mode = ExecutionMode.FIREARM
	execution_target = target
	execution_lock_position = global_position
	execution_timer = CombatTuning.FIREARM_EXECUTION_SHOT_DELAY
	velocity = Vector2.ZERO
	event_reported.emit("Firearm execution committed on %s — shot pending" % target.display_name)

func _update_execution(delta: float) -> void:
	if not is_instance_valid(execution_target) or execution_target.state == Zombie.State.DEAD:
		_finish_execution("Execution complete")
		return
	execution_timer -= delta
	if execution_timer > 0.0: return
	if execution_mode == ExecutionMode.FIREARM: _apply_firearm_execution_shot()
	else: _apply_execution_bash()

func _apply_firearm_execution_shot() -> void:
	if not inserted_magazine.consume_round():
		_finish_execution("Firearm execution failed: pistol empty before shot")
		return
	execution_target.receive_firearm_execution()
	event_reported.emit("Firearm execution shot — one round spent; %s killed" % execution_target.display_name)
	_finish_execution("Firearm execution complete")

func _apply_execution_bash() -> void:
	if not is_instance_valid(execution_target):
		_finish_execution("Execution target lost")
		return
	var was_seated := execution_target.state == Zombie.State.SEATED
	execution_target.receive_execution_bash(CombatTuning.EXECUTION_DAMAGE_PER_BASH)
	event_reported.emit("Execution bash: immediate %d damage; target HP %d" % [CombatTuning.EXECUTION_DAMAGE_PER_BASH, execution_target.health])
	if execution_target.state == Zombie.State.DEAD: _finish_execution("Execution ended on death")
	else: execution_timer = CombatTuning.SEATED_FIRST_BASH_DELAY if was_seated else CombatTuning.PRONE_BASH_DELAY

func receive_zombie_hit(source_name: String) -> void:
	last_hit_report = "HIT by %s at %.2f s — survivor injury deferred" % [source_name, Time.get_ticks_msec() / 1000.0]
	if execution_choice_pending:
		_clear_execution_choice()
		event_reported.emit("Execution choice interrupted before commitment; no shot or bash")
	if is_executing: _finish_execution("Execution interrupted by zombie hit; applied damage/ammo state persisted")
	event_reported.emit(last_hit_report)

func _finish_execution(reason: String) -> void:
	is_executing = false
	execution_mode = ExecutionMode.NONE
	execution_target = null
	execution_timer = 0.0
	event_reported.emit(reason)

func weapon_name() -> String:
	return "PISTOL" if selected_weapon == Weapon.PISTOL else "MELEE"

func action_status() -> String:
	if execution_choice_pending: return "EXECUTE CHOICE %.2f/%.2f" % [execution_hold_time, CombatTuning.EXECUTION_HOLD_THRESHOLD]
	if is_executing: return "EXECUTING %s" % ExecutionMode.keys()[execution_mode]
	if is_reloading: return "RELOADING %.2f s -> %s" % [maxf(0.0, reload_timer), reload_target.stable_id]
	if is_loading_magazine: return "LOADING %s %.2f s" % [magazine_load_target.stable_id, maxf(0.0, magazine_load_timer)]
	return "READY"

func get_movement_state() -> String:
	if is_executing or execution_choice_pending: return "LOCKED"
	if Input.is_action_pressed("crouch"): return "CROUCH"
	if Input.is_action_pressed("sprint") and velocity.length() > CombatTuning.WALK_SPEED: return "SPRINT"
	return "WALK"

func _draw() -> void:
	draw_circle(Vector2.ZERO, 19.0, Color("53b7ff"))
	draw_circle(Vector2.ZERO, 19.0, Color("d9f2ff"), false, 3.0)
	draw_line(Vector2.ZERO, aim_direction * 38.0, Color.WHITE, 4.0)
	if selected_weapon == Weapon.PISTOL: draw_circle(aim_direction * 24.0, 5.0, Color("c8ccd0"))
	if is_executing or execution_choice_pending: draw_arc(Vector2.ZERO, 27.0, 0.0, TAU, 32, Color("ffd166"), 4.0)
