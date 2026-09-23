class_name GameFlow
extends Node2D

var mission_state := MissionState.new()
var active_expedition: CombatRoom
var _bunker_label: Label
var in_bunker := true
var last_result := "Ready to deploy"

func _ready() -> void:
	_build_bunker_ui()
	_show_bunker()

func _build_bunker_ui() -> void:
	_bunker_label = Label.new()
	_bunker_label.position = Vector2(175.0, 120.0)
	_bunker_label.add_theme_font_size_override("font_size", 24)
	_bunker_label.add_theme_color_override("font_color", Color("e7e4d8"))
	add_child(_bunker_label)

func _unhandled_input(event: InputEvent) -> void:
	if not in_bunker: return
	if event.is_action_pressed("deploy"):
		deploy()
	elif event.is_action_pressed("reset_campaign"):
		mission_state = MissionState.new()
		last_result = "Expedition persistence cleared for debug replay"
		_update_bunker_text()

func deploy() -> void:
	if not in_bunker: return
	mission_state.begin_expedition()
	active_expedition = load("res://scenes/combat_room.tscn").instantiate() as CombatRoom
	active_expedition.configure_mission(mission_state)
	active_expedition.expedition_finished.connect(_on_expedition_finished)
	add_child(active_expedition)
	in_bunker = false
	_bunker_label.visible = false
	queue_redraw()

func _on_expedition_finished(objective_complete: bool) -> void:
	mission_state.record_extraction()
	last_result = "Bunker supply secured and extracted" if objective_complete else "Retreated safely; mission progress preserved"
	active_expedition.queue_free()
	active_expedition = null
	_show_bunker()

func _show_bunker() -> void:
	in_bunker = true
	_bunker_label.visible = true
	_update_bunker_text()
	queue_redraw()

func _update_bunker_text() -> void:
	var objective := "COMPLETE — bunker supply recovered" if mission_state.is_objective_complete() else "ACTIVE — retrieve bunker supply"
	_bunker_label.text = "BRAND NEW DAY\nBUNKER / DEPLOYMENT\n\nObjective: %s\nExpeditions: %d   Successful returns: %d   Retreats: %d\nPersistent zombie kills: %d   Collected mission items: %d\n\nLast result: %s\n\nENTER — DEPLOY\nF6 — CLEAR MISSION PERSISTENCE (DEBUG)" % [objective, mission_state.expedition_count, mission_state.successful_extractions, mission_state.retreats, mission_state.dead_zombie_ids.size(), mission_state.collected_item_ids.size(), last_result]

func _draw() -> void:
	if not in_bunker: return
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280.0, 720.0)), Color("171d22"))
	draw_rect(Rect2(130.0, 85.0, 1020.0, 550.0), Color("29333b"))
	draw_rect(Rect2(130.0, 85.0, 1020.0, 550.0), Color("65717b"), false, 8.0)
	draw_string(ThemeDB.fallback_font, Vector2(900.0, 670.0), "Original placeholder bunker", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("9ca8b0"))
