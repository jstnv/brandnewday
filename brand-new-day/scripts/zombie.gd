class_name Zombie
extends CharacterBody2D

enum State { IDLE, CHASE, WINDUP, LUNGE, RECOVER, SEATED, PRONE, DEAD }

signal event_reported(message: String)

var state := State.IDLE
var health := CombatTuning.ZOMBIE_MAX_HEALTH
var state_timer := 0.0
var lunge_direction := Vector2.ZERO
var survivor: Survivor
var display_name := "Zombie"

func setup(target: Survivor, label: String) -> void:
	survivor = target
	display_name = label
	queue_redraw()

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	state_timer = maxf(0.0, state_timer - delta)
	var offset := survivor.global_position - global_position
	match state:
		State.IDLE:
			velocity = Vector2.ZERO
			if offset.length() <= CombatTuning.ZOMBIE_DETECTION_RANGE:
				_set_state(State.CHASE)
		State.CHASE:
			if offset.length() <= CombatTuning.ZOMBIE_WINDUP_RANGE:
				velocity = Vector2.ZERO
				state_timer = CombatTuning.ZOMBIE_WINDUP_TIME
				_set_state(State.WINDUP)
			else:
				velocity = offset.normalized() * CombatTuning.ZOMBIE_SPEED
		State.WINDUP:
			velocity = Vector2.ZERO
			if state_timer <= 0.0:
				lunge_direction = offset.normalized()
				state_timer = CombatTuning.ZOMBIE_LUNGE_TIME
				_set_state(State.LUNGE)
		State.LUNGE:
			velocity = lunge_direction * CombatTuning.ZOMBIE_LUNGE_SPEED
			if offset.length() <= CombatTuning.ZOMBIE_HIT_RADIUS + 18.0:
				survivor.receive_zombie_hit(display_name)
				state_timer = CombatTuning.ZOMBIE_RECOVERY_TIME
				_set_state(State.RECOVER)
			elif state_timer <= 0.0:
				state_timer = CombatTuning.ZOMBIE_RECOVERY_TIME
				_set_state(State.RECOVER)
				event_reported.emit("%s missed lunge and entered recovery" % display_name)
		State.RECOVER:
			velocity = Vector2.ZERO
			if state_timer <= 0.0:
				_set_state(State.CHASE)
		State.SEATED, State.PRONE:
			velocity = Vector2.ZERO
			if state_timer <= 0.0:
				_set_state(State.CHASE)
				event_reported.emit("%s recovered from knockdown" % display_name)
	move_and_slide()
	queue_redraw()

func receive_melee(damage: int, knock_direction: Vector2) -> void:
	if state == State.DEAD:
		return
	var interrupted := state == State.WINDUP or state == State.LUNGE
	var was_seated := state == State.SEATED
	health = maxi(0, health - damage)
	if health <= 0:
		_set_state(State.DEAD)
		event_reported.emit("%s killed by ordinary melee" % display_name)
		return
	global_position += knock_direction * 18.0
	state_timer = CombatTuning.ZOMBIE_KNOCKDOWN_RECOVERY
	if was_seated or health <= CombatTuning.ZOMBIE_PRONE_THRESHOLD:
		_set_state(State.PRONE)
	else:
		_set_state(State.SEATED)
	if interrupted:
		event_reported.emit("%s attack interrupted by melee" % display_name)

func receive_execution_bash(damage: int) -> void:
	if state != State.SEATED and state != State.PRONE:
		return
	var was_seated := state == State.SEATED
	health = maxi(0, health - damage)
	if health <= 0:
		_set_state(State.DEAD)
	else:
		state_timer = CombatTuning.ZOMBIE_KNOCKDOWN_RECOVERY
		if was_seated:
			_set_state(State.PRONE)

func is_execution_eligible() -> bool:
	return state == State.SEATED or state == State.PRONE

func state_name() -> String:
	return State.keys()[state].capitalize()

func _set_state(next_state: State) -> void:
	state = next_state
	queue_redraw()

func _draw() -> void:
	var color := Color("8bc34a")
	match state:
		State.WINDUP: color = Color("ffb347")
		State.LUNGE: color = Color("ff4d4d")
		State.RECOVER: color = Color("8b6d5c")
		State.SEATED: color = Color("d8c85a")
		State.PRONE: color = Color("9a7d43")
		State.DEAD: color = Color("3b4035")
	if state == State.PRONE or state == State.DEAD:
		_draw_flat_body(Vector2.ZERO, Vector2(27.0, 12.0), color)
	else:
		draw_circle(Vector2.ZERO, 18.0, color)
	draw_arc(Vector2.ZERO, 19.0, 0.0, TAU, 24, Color("1b2616"), 3.0)
	if state != State.DEAD:
		draw_rect(Rect2(-25.0, -31.0, 50.0, 5.0), Color("321c1c"))
		draw_rect(Rect2(-25.0, -31.0, 50.0 * float(health) / CombatTuning.ZOMBIE_MAX_HEALTH, 5.0), Color("e85d5d"))

func _draw_flat_body(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 32:
		var angle := TAU * float(i) / 32.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
