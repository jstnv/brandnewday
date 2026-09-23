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

	# A swing chooses the nearest valid zombie, even when both are in the aim arc.
	room.reset_room()
	await process_frame
	survivor = room.survivor
	survivor.aim_direction = Vector2.RIGHT
	room.zombies[0].state = Zombie.State.IDLE
	room.zombies[1].state = Zombie.State.IDLE
	room.zombies[0].position = survivor.position + Vector2(65.0, 0.0)
	room.zombies[1].position = survivor.position + Vector2(35.0, 8.0)
	survivor.try_melee()
	_check(room.zombies[0].health == 100 and room.zombies[1].health == 66, "melee damages only the closest zombie in the aim arc")

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
	var other_target := room.zombies[1]
	other_target.position = survivor.position + Vector2(55.0, 0.0)
	other_target.state = Zombie.State.PRONE
	var stamina_at_execution := survivor.stamina
	_check(survivor.begin_execute_input(), "seated zombie is execution eligible")
	_check(target.health == 42 and target.state == Zombie.State.PRONE, "seated execution first bash damages immediately and makes target prone")
	_check(other_target.health == 100, "execution selects only the closest eligible zombie")
	_check(is_equal_approx(survivor.execution_timer, CombatTuning.SEATED_FIRST_BASH_DELAY), "seated opening uses slower first-bash delay")
	var locked_position := survivor.position
	survivor.position += Vector2(19.0, 11.0) # Simulate collision/effect displacement.
	Input.action_press("move_left")
	Input.action_press("sprint")
	survivor._physics_process(0.1)
	Input.action_release("sprint")
	Input.action_release("move_left")
	_check(survivor.position.is_equal_approx(locked_position), "execution restores its exact anchor against input and external displacement")
	_check(not survivor.try_melee(), "execution prevents other attacks")
	_check(is_equal_approx(survivor.stamina, stamina_at_execution), "melee/execution do not consume stamina")
	other_target.position = survivor.position + Vector2(5.0, 0.0)
	survivor.execution_timer = 0.0
	survivor._physics_process(0.01)
	_check(target.health == 18 and other_target.health == 100 and is_equal_approx(survivor.execution_timer, CombatTuning.PRONE_BASH_DELAY), "later bashes stay bound to the original target even if another zombie becomes closer")
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
	_check(survivor.begin_execute_input(), "prone zombie is execution eligible")
	var health_after_bash := target.health
	_check(is_equal_approx(survivor.execution_timer, CombatTuning.PRONE_BASH_DELAY), "already-prone execution starts at faster cadence")
	survivor.receive_zombie_hit("Verifier Zombie")
	_check(not survivor.is_executing and target.health == health_after_bash and target.health == 46, "operator hit interrupts execution without reverting bash damage")

	# Semi-automatic pistol, health-state transitions, and target validity.
	room.reset_room()
	await process_frame
	survivor = room.survivor
	survivor.select_weapon(Survivor.Weapon.PISTOL)
	survivor.aim_direction = Vector2.RIGHT
	target = room.zombies[0]
	other_target = room.zombies[1]
	target.state = Zombie.State.IDLE
	target.position = survivor.position + Vector2(80.0, 0.0)
	other_target.position = survivor.position + Vector2(250.0, 180.0)
	var rounds_before := survivor.inserted_magazine.rounds
	_check(survivor.try_fire() and not survivor.try_fire() and survivor.inserted_magazine.rounds == rounds_before - 1, "semi-automatic pistol fires at most once during cadence after one press")
	_check(target.state == Zombie.State.SEATED and target.health == 62, "standing target becomes seated from remaining firearm health")
	survivor.firearm_cooldown = 0.0
	target.state = Zombie.State.IDLE
	target.health = 70
	survivor.try_fire()
	_check(target.state == Zombie.State.PRONE and target.health == 32, "standing target becomes prone at firearm health threshold")
	survivor.firearm_cooldown = 0.0
	target.state = Zombie.State.IDLE
	target.health = 30
	survivor.try_fire()
	_check(target.state == Zombie.State.DEAD, "firearm shot kills when damage reaches remaining health")
	survivor.firearm_cooldown = 0.0
	target.state = Zombie.State.SEATED
	target.health = 50
	survivor.try_fire()
	_check(target.state == Zombie.State.PRONE and target.health == 12, "shooting seated target makes it prone unless lethal")
	survivor.firearm_cooldown = 0.0
	target.state = Zombie.State.SEATED
	target.health = 30
	survivor.try_fire()
	_check(target.state == Zombie.State.DEAD, "shooting seated target kills when damage is lethal")
	survivor.firearm_cooldown = 0.0
	survivor.inserted_magazine.rounds = survivor.inserted_magazine.capacity
	target.state = Zombie.State.PRONE
	target.health = 40
	other_target.state = Zombie.State.IDLE
	other_target.health = 100
	target.position = survivor.position + Vector2(40.0, 0.0)
	other_target.position = survivor.position + Vector2(75.0, 0.0)
	survivor.try_fire()
	_check(target.health == 40 and other_target.health == 62, "prone target is skipped without shielding valid target behind it")
	survivor.firearm_cooldown = 0.0
	other_target.state = Zombie.State.WINDUP
	other_target.health = 100
	survivor.try_fire()
	_check(other_target.state == Zombie.State.SEATED, "pistol shot interrupts zombie windup")
	survivor.firearm_cooldown = 0.0
	other_target.state = Zombie.State.LUNGE
	other_target.health = 100
	survivor.try_fire()
	_check(other_target.state == Zombie.State.SEATED, "pistol shot interrupts active zombie lunge")
	survivor.firearm_cooldown = 0.0
	var expected_walk_speed := CombatTuning.WALK_SPEED
	Input.action_press("move_right")
	survivor._physics_process(0.05)
	Input.action_release("move_right")
	survivor.try_fire()
	_check(is_equal_approx(survivor.velocity.length(), expected_walk_speed), "aiming and firing preserve full current movement speed")

	# Firearm execution tap, hold, empty, prone, and interruption rules.
	room.reset_room()
	await process_frame
	survivor = room.survivor
	survivor.select_weapon(Survivor.Weapon.PISTOL)
	target = room.zombies[0]
	target.position = survivor.position + Vector2(35.0, 0.0)
	target.state = Zombie.State.SEATED
	rounds_before = survivor.inserted_magazine.rounds
	survivor.begin_execute_input()
	survivor.release_execute_input()
	_check(survivor.is_executing and survivor.execution_mode == Survivor.ExecutionMode.FIREARM and survivor.inserted_magazine.rounds == rounds_before, "tap commits only firearm execution and waits for shot moment")
	survivor.receive_zombie_hit("Verifier Zombie")
	_check(not survivor.is_executing and survivor.inserted_magazine.rounds == rounds_before and target.state == Zombie.State.SEATED, "interruption before firearm-execution shot spends no round and deals no damage")
	survivor.begin_execute_input()
	survivor.release_execute_input()
	survivor._physics_process(CombatTuning.FIREARM_EXECUTION_SHOT_DELAY + 0.01)
	_check(target.state == Zombie.State.DEAD and survivor.inserted_magazine.rounds == rounds_before - 1 and not survivor.is_executing, "firearm execution shot spends exactly one round and guarantees bound seated target death")
	survivor.receive_zombie_hit("Verifier Zombie")
	_check(target.state == Zombie.State.DEAD and survivor.inserted_magazine.rounds == rounds_before - 1, "interruption after firearm-execution shot cannot revert kill or spent round")

	room.reset_room()
	await process_frame
	survivor = room.survivor
	survivor.select_weapon(Survivor.Weapon.PISTOL)
	target = room.zombies[0]
	target.position = survivor.position + Vector2(35.0, 0.0)
	target.state = Zombie.State.SEATED
	target.health = 66
	rounds_before = survivor.inserted_magazine.rounds
	survivor.begin_execute_input()
	survivor._physics_process(CombatTuning.EXECUTION_HOLD_THRESHOLD + 0.01)
	_check(survivor.execution_mode == Survivor.ExecutionMode.PHYSICAL and target.state == Zombie.State.PRONE and target.health == 42 and survivor.inserted_magazine.rounds == rounds_before, "held seated execution chooses only bash and consumes no ammunition")
	survivor.receive_zombie_hit("Verifier Zombie")
	target.state = Zombie.State.SEATED
	target.health = 66
	survivor.inserted_magazine.rounds = 0
	survivor.begin_execute_input()
	_check(not survivor.release_execute_input() and not survivor.is_executing and target.health == 66, "empty-pistol tap gives no execution and does not silently bash")
	survivor.begin_execute_input()
	survivor._physics_process(CombatTuning.EXECUTION_HOLD_THRESHOLD + 0.01)
	_check(survivor.execution_mode == Survivor.ExecutionMode.PHYSICAL and target.health == 42, "empty-pistol hold deliberately starts bash execution")
	survivor.receive_zombie_hit("Verifier Zombie")
	target.state = Zombie.State.PRONE
	target.health = 50
	rounds_before = survivor.inserted_magazine.rounds
	survivor.begin_execute_input()
	_check(survivor.execution_mode == Survivor.ExecutionMode.PHYSICAL and target.health == 26 and survivor.inserted_magazine.rounds == rounds_before, "prone execution starts physical bash immediately without ammo or hold delay")

	# Individual magazine reload and loose-round loading behavior.
	room.reset_room()
	await process_frame
	survivor = room.survivor
	survivor.select_weapon(Survivor.Weapon.PISTOL)
	var original_mag := survivor.inserted_magazine
	var fullest_spare := survivor.spare_magazines[0]
	_check(original_mag.stable_id == "MAG-A" and fullest_spare.stable_id == "MAG-B" and original_mag.rounds == 5 and fullest_spare.rounds == 8, "magazines retain distinct stable identities and round counts")
	survivor.start_reload()
	var reload_start := survivor.position
	Input.action_press("move_right")
	survivor._physics_process(0.1)
	Input.action_release("move_right")
	_check(survivor.position.x > reload_start.x and survivor.is_reloading and survivor.inserted_magazine == original_mag and not survivor.try_fire(), "reload permits movement, blocks firing, and leaves original magazine inserted")
	survivor.select_weapon(Survivor.Weapon.MELEE)
	_check(not survivor.is_reloading and survivor.inserted_magazine == original_mag and survivor.spare_magazines.has(fullest_spare), "weapon switch cancels reload with no magazine swap")
	survivor.select_weapon(Survivor.Weapon.PISTOL)
	survivor.start_reload()
	survivor._physics_process(0.4)
	survivor.select_weapon(Survivor.Weapon.MELEE)
	survivor.select_weapon(Survivor.Weapon.PISTOL)
	survivor.start_reload()
	_check(is_equal_approx(survivor.reload_timer, CombatTuning.PISTOL_RELOAD_TIME), "retrying canceled reload restarts full timer")
	survivor._physics_process(CombatTuning.PISTOL_RELOAD_TIME + 0.01)
	_check(survivor.inserted_magazine == fullest_spare and survivor.spare_magazines.has(original_mag) and original_mag.rounds == 5, "reload chooses fullest compatible spare and retains partial original magazine")
	var load_mag := survivor.spare_magazines.filter(func(m: Magazine) -> bool: return m.stable_id == "MAG-C")[0] as Magazine
	survivor.magazine_load_target = load_mag
	var loose_before := survivor.loose_ammo
	survivor.start_magazine_loading()
	survivor._physics_process(CombatTuning.MAGAZINE_LOAD_ROUND_TIME + 0.01)
	_check(load_mag.rounds == 3 and survivor.loose_ammo == loose_before - 1, "stationary magazine loading inserts one round immediately per completed interval")
	Input.action_press("move_left")
	survivor._physics_process(0.05)
	Input.action_release("move_left")
	_check(not survivor.is_loading_magazine and load_mag.rounds == 3, "movement cancels magazine loading while preserving inserted rounds")
	var incompatible := Magazine.new("MAG-X", "incompatible", 0, 8)
	survivor.magazine_load_target = incompatible
	_check(not survivor.start_magazine_loading(), "incompatible magazine rejects loose ammunition")
	var full_mag := Magazine.new("MAG-FULL", CombatTuning.PISTOL_AMMO_CATEGORY, 8, 8)
	survivor.magazine_load_target = full_mag
	_check(not survivor.start_magazine_loading() and full_mag.rounds == 8, "magazine loading cannot exceed capacity")

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

	# Milestone 3 expedition persistence and bunker/deployment loop.
	var persistent_state := MissionState.new()
	persistent_state.begin_expedition()
	var expedition := load("res://scenes/combat_room.tscn").instantiate() as CombatRoom
	expedition.configure_mission(persistent_state)
	root.add_child(expedition)
	await process_frame
	_check(expedition.zombies.size() == 2 and not persistent_state.is_supply_collected(), "first expedition starts with core zombies and available bunker supply")
	_check(expedition.zombies[0].persistent_id == "depot_zombie_a" and expedition.zombies[1].persistent_id == "depot_zombie_b", "mission zombies use stable persistent identities")
	expedition.zombies[0].receive_melee(CombatTuning.ZOMBIE_MAX_HEALTH, Vector2.RIGHT)
	_check(persistent_state.is_zombie_dead("depot_zombie_a"), "zombie death is recorded immediately in mission state")
	expedition.survivor.position = expedition.supply_position
	_check(expedition.try_collect_supply() and persistent_state.is_supply_collected() and persistent_state.is_objective_complete(), "bunker supply collection and objective step persist immediately")
	var active_count := expedition.zombies.size()
	expedition._process(0.2)
	_check(expedition.zombies.size() == active_count and persistent_state.introduced_perimeter_zombie_ids.is_empty(), "no zombies are introduced during an active expedition")
	var extraction_result := [false, false]
	expedition.expedition_finished.connect(func(success: bool) -> void:
		extraction_result[0] = true
		extraction_result[1] = success)
	expedition.has_departed_entry = true
	expedition.survivor.position = expedition.extraction_area.get_center()
	expedition._process(0.01)
	_check(extraction_result[0] and extraction_result[1], "returning through outdoor extraction completes a secured objective")
	expedition.queue_free()
	await process_frame
	persistent_state.begin_expedition()
	var retry := load("res://scenes/combat_room.tscn").instantiate() as CombatRoom
	retry.configure_mission(persistent_state)
	root.add_child(retry)
	await process_frame
	var retry_ids: Array[String] = []
	for zombie in retry.zombies: retry_ids.append(zombie.persistent_id)
	_check(not retry_ids.has("depot_zombie_a"), "killed zombie remains dead on retry")
	_check(persistent_state.is_objective_complete() and persistent_state.is_supply_collected(), "collected supply stays gone and completed objective step remains complete")
	_check(retry_ids.has("perimeter_zombie_01") and retry.zombies.any(func(zombie: Zombie) -> bool: return zombie.persistent_id == "perimeter_zombie_01" and zombie.position.x >= 1100.0), "new zombie is introduced at the perimeter only between expeditions")
	retry.queue_free()
	await process_frame

	var retreat_state := MissionState.new()
	retreat_state.begin_expedition()
	var retreat_room := load("res://scenes/combat_room.tscn").instantiate() as CombatRoom
	retreat_room.configure_mission(retreat_state)
	root.add_child(retreat_room)
	await process_frame
	var retreat_result := [false, true]
	retreat_room.expedition_finished.connect(func(success: bool) -> void:
		retreat_result[0] = true
		retreat_result[1] = success)
	retreat_room.has_departed_entry = true
	retreat_room.survivor.position = retreat_room.extraction_area.get_center()
	retreat_room._process(0.01)
	retreat_state.record_extraction()
	_check(retreat_result[0] and not retreat_result[1] and retreat_state.retreats == 1, "returning before collection records a safe retreat")
	retreat_room.queue_free()
	await process_frame
	retreat_state.begin_expedition()
	_check(not retreat_state.is_objective_complete() and retreat_state.introduced_perimeter_zombie_ids.has("perimeter_zombie_01"), "retreat retry preserves incomplete objective and introduces perimeter zombie between expeditions")

	var flow := load("res://scenes/game_flow.tscn").instantiate() as GameFlow
	root.add_child(flow)
	await process_frame
	_check(flow.in_bunker and flow.active_expedition == null, "main game loop launches at bunker deployment screen")
	flow.deploy()
	await process_frame
	_check(not flow.in_bunker and flow.active_expedition != null and flow.mission_state.expedition_count == 1, "bunker deployment starts first handcrafted expedition")
	flow.queue_free()
	await process_frame

	print("VERIFICATION: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
