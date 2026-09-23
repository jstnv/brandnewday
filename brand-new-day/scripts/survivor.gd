class_name Survivor
extends CharacterBody2D

signal event_reported(message: String)

var stamina := CombatTuning.MAX_STAMINA
var aim_direction := Vector2.RIGHT
var is_executing := false
var execution_target: Zombie
var execution_timer := 0.0
var execution_lock_position := Vector2.ZERO
var melee_cooldown := 0.0
var stamina_recovery_delay := 0.0
var last_hit_report := "No survivor hits (injury deferred)"
var _room: CombatRoom

func setup(room: CombatRoom) -> void:
	_room = room
	queue_redraw()

func _physics_process(delta: float) -> void:
	melee_cooldown = maxf(0.0, melee_cooldown - delta)
	_update_aim()
	if is_executing:
		velocity = Vector2.ZERO
		global_position = execution_lock_position
		_update_execution(delta)
		# Keep the operator fixed even if another body or future effect displaces it.
		global_position = execution_lock_position
		queue_redraw()
		return

	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
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
	if event.is_action_pressed("melee"):
		try_melee()
	elif event.is_action_pressed("execute"):
		try_execute()

func _recover_stamina(delta: float) -> void:
	if stamina_recovery_delay > 0.0:
		stamina_recovery_delay = maxf(0.0, stamina_recovery_delay - delta)
	else:
		stamina = minf(CombatTuning.MAX_STAMINA, stamina + CombatTuning.STAMINA_RECOVERY_PER_SECOND * delta)

func _update_aim() -> void:
	var mouse_vector := get_global_mouse_position() - global_position
	if mouse_vector.length() > 8.0:
		aim_direction = mouse_vector.normalized()

func try_melee() -> bool:
	if is_executing or melee_cooldown > 0.0:
		return false
	melee_cooldown = CombatTuning.MELEE_COOLDOWN
	var target := _room.find_melee_target(global_position, aim_direction)
	if target != null:
		target.receive_melee(CombatTuning.MELEE_DAMAGE, aim_direction)
		event_reported.emit("Melee hit %s for %d — exactly one target" % [target.display_name, CombatTuning.MELEE_DAMAGE])
	else:
		event_reported.emit("Melee missed")
	return true

func try_execute() -> bool:
	if is_executing:
		return false
	var target := _room.find_execution_target(global_position)
	if target == null:
		event_reported.emit("No seated/prone zombie in execution range")
		return false
	is_executing = true
	execution_target = target
	execution_lock_position = global_position
	velocity = Vector2.ZERO
	event_reported.emit("Execution committed on %s" % target.display_name)
	_apply_execution_bash()
	return true

func _update_execution(delta: float) -> void:
	if not is_instance_valid(execution_target) or execution_target.state == Zombie.State.DEAD:
		_finish_execution("Execution complete")
		return
	execution_timer -= delta
	if execution_timer <= 0.0:
		_apply_execution_bash()

func _apply_execution_bash() -> void:
	if not is_instance_valid(execution_target):
		_finish_execution("Execution target lost")
		return
	var was_seated := execution_target.state == Zombie.State.SEATED
	execution_target.receive_execution_bash(CombatTuning.EXECUTION_DAMAGE_PER_BASH)
	event_reported.emit("Execution bash: immediate %d damage; target HP %d" % [CombatTuning.EXECUTION_DAMAGE_PER_BASH, execution_target.health])
	if execution_target.state == Zombie.State.DEAD:
		_finish_execution("Execution ended on death")
	else:
		execution_timer = CombatTuning.SEATED_FIRST_BASH_DELAY if was_seated else CombatTuning.PRONE_BASH_DELAY

func receive_zombie_hit(source_name: String) -> void:
	last_hit_report = "HIT by %s at %.2f s — survivor injury deferred" % [source_name, Time.get_ticks_msec() / 1000.0]
	if is_executing:
		_finish_execution("Execution interrupted by zombie hit; prior bash damage persisted")
	event_reported.emit(last_hit_report)

func _finish_execution(reason: String) -> void:
	is_executing = false
	execution_target = null
	execution_timer = 0.0
	event_reported.emit(reason)

func get_movement_state() -> String:
	if is_executing:
		return "EXECUTING (movement/attacks locked)"
	if Input.is_action_pressed("crouch"):
		return "CROUCH"
	if Input.is_action_pressed("sprint") and velocity.length() > CombatTuning.WALK_SPEED:
		return "SPRINT"
	return "WALK"

func _draw() -> void:
	draw_circle(Vector2.ZERO, 19.0, Color("53b7ff"))
	draw_circle(Vector2.ZERO, 19.0, Color("d9f2ff"), false, 3.0)
	draw_line(Vector2.ZERO, aim_direction * 38.0, Color.WHITE, 4.0)
	if is_executing:
		draw_arc(Vector2.ZERO, 27.0, 0.0, TAU, 32, Color("ffd166"), 4.0)
