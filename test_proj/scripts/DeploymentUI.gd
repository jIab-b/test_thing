extends Control

const UnitDefs := preload("res://scripts/UnitDefinitions.gd")

@export var panel_path: NodePath
@export var points_label_path: NodePath
@export var unit_buttons_container_path: NodePath
@export var status_label_path: NodePath
@export var flag_button_path: NodePath
@export var game_controller_path: NodePath

var is_open: bool = false
var placing_flag: bool = false
var selected_unit_key: String = ""
var game_controller: Node = null
var player_faction: Node = null
var button_map: Dictionary = {}

func _get_player_faction_controller() -> Variant:
    if player_faction != null and is_instance_valid(player_faction):
        return player_faction
    return null

func _ready() -> void:
    visible = false
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    if game_controller_path != NodePath(""):
        game_controller = get_node_or_null(game_controller_path)
    _ensure_faction_reference()
    _build_unit_buttons()
    _refresh_points()
    _set_status_text("")
    set_process_unhandled_input(true)

func _ensure_faction_reference() -> void:
    if player_faction != null:
        return
    if game_controller == null or not game_controller.has_method("get_faction"):
        return
    player_faction = game_controller.get_faction("player")
    if player_faction != null:
        if player_faction.has_signal("points_changed"):
            player_faction.points_changed.connect(_on_points_changed)
        if player_faction.has_signal("flags_changed"):
            player_faction.flags_changed.connect(_on_flags_changed)
        _refresh_button_states()

func _build_unit_buttons() -> void:
    var container: Node = get_node_or_null(unit_buttons_container_path)
    if container == null:
        return
    _clear_children(container)
    button_map.clear()
    for unit_key in UnitDefs.list_player_units():
        var def: Dictionary = UnitDefs.get_player_unit(unit_key)
        if def.is_empty():
            continue
        var button := Button.new()
        var label := String(def.get("display_name", unit_key.capitalize()))
        var cost := float(def.get("cost", 0.0))
        button.text = "%s (%d)" % [label, int(round(cost))]
        button.toggle_mode = true
        button.toggled.connect(_on_unit_button_toggled.bind(unit_key, button))
        container.add_child(button)
        button_map[unit_key] = button
    var flag_button: Node = get_node_or_null(flag_button_path)
    if flag_button is Button:
        flag_button.pressed.connect(_on_flag_button_pressed)

func _on_unit_button_toggled(toggled_on: bool, unit_key: String, button: Button) -> void:
    if not is_open:
        button.button_pressed = false
        return
    placing_flag = false
    _clear_other_buttons(unit_key)
    if toggled_on:
        selected_unit_key = unit_key
        _set_status_text("Select a valid point within your flags to deploy.")
    else:
        selected_unit_key = ""
        _set_status_text("")

func _clear_other_buttons(active_key: String) -> void:
    for key in button_map.keys():
        if key != active_key:
            var btn: Button = button_map[key]
            if btn != null:
                btn.button_pressed = false

func _on_flag_button_pressed() -> void:
    if not is_open:
        return
    _clear_button_selection()
    placing_flag = true
    _set_status_text("Click on the map to place a flag.")

func _clear_button_selection() -> void:
    for btn in button_map.values():
        if btn != null:
            btn.button_pressed = false
    selected_unit_key = ""

func _on_points_changed(current_amount: float, _max_amount: float) -> void:
    _refresh_points()
    _refresh_button_states()

func _on_flags_changed() -> void:
    pass

func _refresh_points() -> void:
    var label: Node = get_node_or_null(points_label_path)
    var faction: Variant = _get_player_faction_controller()
    if label is Label and faction != null:
        label.text = "Points: %d / %d" % [int(round(faction.get_points())), int(round(faction.max_points))]

func _refresh_button_states() -> void:
    var faction: Variant = _get_player_faction_controller()
    if faction == null:
        return
    var available: float = faction.get_points()
    for unit_key in button_map.keys():
        var button: Button = button_map[unit_key]
        if button == null:
            continue
        var def: Dictionary = UnitDefs.get_player_unit(unit_key)
        var cost := float(def.get("cost", 0.0))
        button.disabled = available < cost
    var flag_button: Node = get_node_or_null(flag_button_path)
    if flag_button is Button:
        flag_button.disabled = not faction.can_afford(faction.flag_cost)

func _set_status_text(text: String) -> void:
    var label: Node = get_node_or_null(status_label_path)
    if label is Label:
        label.text = text

func toggle_open() -> void:
    _ensure_faction_reference()
    is_open = not is_open
    visible = is_open
    if not is_open:
        _clear_button_selection()
        placing_flag = false
        _set_status_text("")
    else:
        _refresh_points()
        _refresh_button_states()

func close() -> void:
    if not is_open:
        return
    is_open = false
    visible = false
    _clear_button_selection()
    placing_flag = false
    _set_status_text("")

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("toggle_deploy"):
        toggle_open()
        get_viewport().set_input_as_handled()
        return
    if not is_open:
        return
    if event is InputEventMouseButton and event.pressed:
        var mb := event as InputEventMouseButton
        if mb.button_index == MOUSE_BUTTON_RIGHT:
            placing_flag = false
            _clear_button_selection()
            _set_status_text("")
            return
        if mb.button_index != MOUSE_BUTTON_LEFT:
            return
        if _event_hits_ui(mb.position):
            return
        if placing_flag:
            _attempt_place_flag(mb.position)
        elif selected_unit_key != "":
            _attempt_spawn_unit(mb.position)

func _event_hits_ui(pos: Vector2) -> bool:
    var panel: Node = get_node_or_null(panel_path)
    if panel is Control:
        return panel.get_global_rect().has_point(pos)
    return false

func _attempt_place_flag(mouse_pos: Vector2) -> void:
    _ensure_faction_reference()
    if game_controller == null or player_faction == null:
        return
    var world: Vector2 = _screen_to_world(mouse_pos)
    if not game_controller.has_method("faction_can_place_flag") or not game_controller.has_method("request_flag"):
        return
    if not game_controller.faction_can_place_flag("player", world):
        _set_status_text("Cannot place flag here.")
        return
    var flag: Node2D = game_controller.request_flag("player", world)
    if flag != null:
        placing_flag = false
        _set_status_text("Flag deployed.")
        _refresh_button_states()

func _attempt_spawn_unit(mouse_pos: Vector2) -> void:
    if game_controller == null or selected_unit_key == "":
        return
    var world: Vector2 = _screen_to_world(mouse_pos)
    if not game_controller.has_method("spawn_unit"):
        return
    var spawned: Node2D = game_controller.spawn_unit("player", selected_unit_key, world)
    if spawned != null:
        _set_status_text("Unit deployed.")
        _refresh_button_states()
    else:
        _set_status_text("Cannot deploy there.")

func _screen_to_world(screen_pos: Vector2) -> Vector2:
    var viewport: Viewport = get_viewport()
    if viewport == null:
        return screen_pos
    var cam: Camera2D = viewport.get_camera_2d()
    if cam != null:
        return cam.screen_to_world(screen_pos)
    return get_global_mouse_position()

func _clear_children(container: Node) -> void:
    for child in container.get_children():
        child.queue_free()
