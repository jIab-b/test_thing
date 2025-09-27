class_name FactionController
extends Node2D

@export var faction_name: String = "player"
@export var max_points: float = 120.0
@export var starting_points: float = 60.0
@export var points_regen_per_second: float = 8.0
@export var flag_cost: float = 35.0
@export var flag_radius: float = 300.0
@export var flag_scene: PackedScene = preload("res://scenes/FlagBeacon.tscn")
@export var flag_min_spacing: float = 200.0

var current_points: float = 0.0
var map_size: Vector2 = Vector2.ZERO
var flags: Array[Node2D] = []
var influence_dirty: bool = true

signal points_changed(new_amount: float, max_amount: float)
signal flags_changed()

func _ready() -> void:
    current_points = clamp(starting_points, 0.0, max_points)
    set_process(true)
    emit_signal("points_changed", current_points, max_points)

func _process(delta: float) -> void:
    if points_regen_per_second <= 0.0:
        return
    if current_points >= max_points:
        return
    current_points = clamp(current_points + points_regen_per_second * delta, 0.0, max_points)
    emit_signal("points_changed", current_points, max_points)

func set_map_size(size: Vector2) -> void:
    map_size = size

func get_points() -> float:
    return current_points

func get_points_ratio() -> float:
    if max_points <= 0.0:
        return 0.0
    return clamp(current_points / max_points, 0.0, 1.0)

func can_afford(cost: float) -> bool:
    return current_points >= cost

func spend_points(cost: float) -> bool:
    if not can_afford(cost):
        return false
    current_points -= cost
    emit_signal("points_changed", current_points, max_points)
    return true

func add_points(amount: float) -> void:
    current_points = clamp(current_points + amount, 0.0, max_points)
    emit_signal("points_changed", current_points, max_points)

func position_within_influence(world_pos: Vector2) -> bool:
    for flag in flags:
        if flag != null and is_instance_valid(flag):
            var flag_script := flag as Object
            if flag_script.has_method("contains_point") and flag_script.contains_point(world_pos):
                return true
    return false

func get_nearest_flag(world_pos: Vector2) -> Node2D:
    var best: Node2D = null
    var best_dist := INF
    for flag in flags:
        if flag != null and is_instance_valid(flag):
            var dist := world_pos.distance_squared_to(flag.global_position)
            if dist < best_dist:
                best_dist = dist
                best = flag
    return best

func place_flag(world_pos: Vector2) -> Node2D:
    if flag_scene == null:
        return null
    if not spend_points(flag_cost):
        return null
    if not _is_position_valid_for_flag(world_pos):
        add_points(flag_cost)  # refund on invalid placement
        return null
    return establish_flag(world_pos)

func establish_flag(world_pos: Vector2) -> Node2D:
    if flag_scene == null:
        return null
    if not _is_position_valid_for_flag(world_pos):
        return null
    var flag := flag_scene.instantiate()
    flag.global_position = _clamp_to_map(world_pos)
    if flag.has_method("set_radius"):
        flag.set_radius(flag_radius)
    if flag.has_method("set_faction"):
        flag.set_faction(faction_name)
    add_child(flag)
    flags.append(flag)
    influence_dirty = true
    emit_signal("flags_changed")
    return flag

func clear_flag(flag: Node2D) -> void:
    if flag == null:
        return
    flags.erase(flag)
    if is_instance_valid(flag):
        flag.queue_free()
    influence_dirty = true
    emit_signal("flags_changed")

func list_flags() -> Array[Node2D]:
    var alive: Array[Node2D] = []
    for flag in flags:
        if flag != null and is_instance_valid(flag):
            alive.append(flag)
    flags = alive
    return flags

func is_position_valid_for_flag(world_pos: Vector2) -> bool:
    return _is_position_valid_for_flag(world_pos)

func _is_position_valid_for_flag(world_pos: Vector2) -> bool:
    if map_size != Vector2.ZERO:
        if world_pos.x < 0.0 or world_pos.y < 0.0 or world_pos.x > map_size.x or world_pos.y > map_size.y:
            return false
    for flag in flags:
        if flag != null and is_instance_valid(flag):
            if world_pos.distance_to(flag.global_position) < flag_min_spacing:
                return false
    return true

func _clamp_to_map(world_pos: Vector2) -> Vector2:
    if map_size == Vector2.ZERO:
        return world_pos
    return Vector2(clamp(world_pos.x, 0.0, map_size.x), clamp(world_pos.y, 0.0, map_size.y))
