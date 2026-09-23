extends SceneTree

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)

func _run() -> void:
	var packed := load("res://scenes/combat_room.tscn") as PackedScene
	var room := packed.instantiate() as CombatRoom
	root.add_child(room)
	await process_frame
	await physics_frame
	_check(room.survivor != null and room.zombies.size() == 2, "room launches with survivor and two zombies")

	# Movement modes and stamina: exercise the same input path used during play.
	var survivor := room.survivor
	var start := survivor.position
	Input.action_press("move_right")
	survivor._physics_process(0.1)
	Input.action_release("move_right")
	_check(survivor.position.x > start.x, "walking moves the survivor")
	start = survivor.position
	Input.action_press("move_right")
	Input.action_press("crouch")
	survivor._physics_process(0.1)
	Input.action_release("crouch")
	Input.action_release("move_right")
	_check(survivor.position.x - start.x <= CombatTuning.CROUCH_SPEED * 0.11, "crouching uses reduced speed")
	var stamina_before := survivor.stamina
	Input.action_press("move_right")
	Input.action_press("sprint")
	survivor._physics_process(0.2)
	Input.action_release("sprint")
	Input.action_release("move_right")
	_check(survivor.stamina < stamina_before, "sprint consumes stamina")

	# Both targets deliberately overlap. Only one may take damage/knockdown.
	room.reset_room()
	await process_frame
	survivor = room.survivor
	survivor.aim_direction = Vector2.RIGHT
	for zombie in room.zombies:
		zombie.state = Zombie.State.IDLE
		zombie.position = survivor.position + Vector2(45.0, 0.0)
	survivor.try_melee()
	var damaged := 0
	for zombie in room.zombies:
		if zombie.health < CombatTuning.ZOMBIE_MAX_HEALTH:
			damaged += 1
	_check(damaged == 1, "one melee swing damages/knocks down only one overlapping zombie")
	var target := room.zombies[0]
	_check(target.state == Zombie.State.SEATED and target.health == 66, "clean high-health hit creates seated knockdown")
	target.receive_melee(CombatTuning.MELEE_DAMAGE, Vector2.RIGHT)
	_check(target.state == Zombie.State.PRONE and target.health == 32, "follow-up ordinary hit moves seated zombie to prone")
	target.receive_melee(CombatTuning.MELEE_DAMAGE, Vector2.RIGHT)
	_check(target.state == Zombie.State.DEAD, "repeated ordinary melee can kill without execution")

	# Seated execution: immediate damage and forced prone first, then faster cadence.
	room.reset_room()
	await process_frame
	survivor = room.survivor
	target = room.zombies[0]
	target.position = survivor.position + Vector2(35.0, 0.0)
	target.state = Zombie.State.SEATED
	target.health = 66
	var stamina_at_execution := survivor.stamina
	_check(survivor.try_execute(), "seated zombie is execution eligible")
	_check(target.health == 42 and target.state == Zombie.State.PRONE, "seated execution first bash damages immediately and makes target prone")
	_check(is_equal_approx(survivor.execution_timer, CombatTuning.SEATED_FIRST_BASH_DELAY), "seated opening uses slower first-bash delay")
	var locked_position := survivor.position
	Input.action_press("move_left")
	survivor._physics_process(0.1)
	Input.action_release("move_left")
	_check(survivor.position.is_equal_approx(locked_position) and not survivor.try_melee(), "execution prevents movement and other attacks")
	_check(is_equal_approx(survivor.stamina, stamina_at_execution), "melee/execution do not consume stamina")
	survivor.execution_timer = 0.0
	survivor._physics_process(0.01)
	_check(target.health == 18 and is_equal_approx(survivor.execution_timer, CombatTuning.PRONE_BASH_DELAY), "continuing prone bash is immediate and uses faster cadence")
	survivor.execution_timer = 0.0
	survivor._physics_process(0.01)
	_check(target.state == Zombie.State.DEAD and not survivor.is_executing, "execution ends as soon as target dies")

	# Already-prone execution and interruption retain applied damage.
	room.reset_room()
	await process_frame
	survivor = room.survivor
	target = room.zombies[0]
	target.position = survivor.position + Vector2(35.0, 0.0)
	target.state = Zombie.State.PRONE
	target.health = 70
	_check(survivor.try_execute(), "prone zombie is execution eligible")
	var health_after_bash := target.health
	_check(is_equal_approx(survivor.execution_timer, CombatTuning.PRONE_BASH_DELAY), "already-prone execution starts at faster cadence")
	survivor.receive_zombie_hit("Verifier Zombie")
	_check(not survivor.is_executing and target.health == health_after_bash and target.health == 46, "operator hit interrupts execution without reverting bash damage")

	# Enemy windup, fixed-direction lunge, miss recovery, and both interrupt points.
	room.reset_room()
	await process_frame
	survivor = room.survivor
	target = room.zombies[0]
	target.position = survivor.position + Vector2(70.0, 0.0)
	target.state = Zombie.State.CHASE
	target._physics_process(0.01)
	_check(target.state == Zombie.State.WINDUP, "zombie telegraphs in windup")
	target.receive_melee(1, Vector2.RIGHT)
	_check(target.state == Zombie.State.SEATED, "ordinary melee interrupts windup")
	target.state = Zombie.State.WINDUP
	target.state_timer = 0.0
	target.position = survivor.position + Vector2(70.0, 0.0)
	target._physics_process(0.01)
	var committed_direction := target.lunge_direction
	survivor.position += Vector2(0.0, 120.0)
	target._physics_process(0.01)
	_check(target.state == Zombie.State.LUNGE and target.lunge_direction.is_equal_approx(committed_direction), "active lunge keeps committed nontracking direction")
	target.receive_melee(1, Vector2.RIGHT)
	_check(target.state == Zombie.State.SEATED, "ordinary melee interrupts active lunge")
	target.state = Zombie.State.LUNGE
	target.state_timer = 0.0
	target.position = Vector2(1000.0, 600.0)
	target.lunge_direction = Vector2.RIGHT
	target._physics_process(0.01)
	_check(target.state == Zombie.State.RECOVER, "missed lunge enters recovery")

	print("VERIFICATION: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
