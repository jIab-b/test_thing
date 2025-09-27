class_name EnemySpawner
extends Node

const UnitDefinitions := preload("res://scripts/UnitDefinitions.gd")

@export var spawn_interval: float = 4.0
@export var flag_interval: float = 12.0
@export var max_flags: int = 4
@export var melee_weight: float = 0.6
@export var ranged_weight: float = 0.4
@export var min_units_per_wave: int = 1
@export var max_units_per_wave: int = 3

var spawn_timer: float = 0.0
var flag_timer: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var game_controller: Node = null
var spawn_rate_multiplier: float = 1.0
var spawn_rate_boost_time: float = 0.0

func _ready() -> void:
    rng.randomize()
    var parent := get_parent()
    if parent != null:
        game_controller = parent.get_node_or_null("GameController")
    set_process(true)
    spawn_timer = spawn_interval
    flag_timer = flag_interval * 0.5

func _process(delta: float) -> void:
    var faction := _get_enemy_faction()
    if faction == null or game_controller == null:
        return
    spawn_timer += delta
    flag_timer += delta
    if spawn_rate_boost_time > 0.0:
        spawn_rate_boost_time -= delta
        if spawn_rate_boost_time <= 0.0:
            spawn_rate_multiplier = 1.0
    if flag_timer >= flag_interval:
        flag_timer = 0.0
        _try_place_flag(faction)
    var effective_spawn_interval: float = max(0.5, spawn_interval / max(spawn_rate_multiplier, 0.1))
    if spawn_timer >= effective_spawn_interval:
        spawn_timer = 0.0
        _spawn_wave(faction)

func _try_place_flag(faction: Node) -> void:
    if not faction.has_method("list_flags"):
        return
    var current_flags: Array = faction.list_flags()
    if current_flags.size() >= max_flags:
        return
    if not faction.has_method("can_afford"):
        return
    var cost_v: Variant = faction.get("flag_cost")
    var flag_cost: float = 0.0
    if typeof(cost_v) == TYPE_FLOAT or typeof(cost_v) == TYPE_INT:
        flag_cost = float(cost_v)
    else:
        return
    if not faction.can_afford(flag_cost):
        return
    var candidate: Variant = _choose_flag_position(faction, current_flags)
    if candidate == null or not (candidate is Vector2):
        return
    if not game_controller.has_method("faction_can_place_flag"):
        return
    if not game_controller.faction_can_place_flag("enemy", candidate):
        return
    game_controller.request_flag("enemy", candidate)

func _choose_flag_position(faction: Node, flags: Array) -> Variant:
    var focus_variant: Variant = _get_player_focus_position()
    if flags.is_empty():
        return focus_variant
    var anchor_index: int = clamp(rng.randi_range(0, flags.size() - 1), 0, flags.size() - 1)
    var anchor_flag: Variant = flags[anchor_index]
    if anchor_flag == null or not (anchor_flag is Node2D) or not is_instance_valid(anchor_flag):
        return null
    var anchor_pos: Vector2 = anchor_flag.global_position
    var focus_pos: Vector2 = anchor_pos
    if focus_variant is Vector2:
        focus_pos = focus_variant
    else:
        focus_pos = anchor_pos + Vector2(rng.randf_range(-200.0, 200.0), rng.randf_range(-200.0, 200.0))
    var dir: Vector2 = focus_pos - anchor_pos
    if dir.length_squared() < 0.01:
        dir = Vector2.RIGHT
    var radius: float = 280.0
    var radius_v: Variant = faction.get("flag_radius")
    if typeof(radius_v) == TYPE_FLOAT or typeof(radius_v) == TYPE_INT:
        radius = float(radius_v)
    if anchor_flag.has_method("get_radius"):
        radius = anchor_flag.get_radius()
    var distance: float = radius * 1.4
    var candidate: Vector2 = anchor_pos + dir.normalized() * distance
    candidate += Vector2(rng.randf_range(-64.0, 64.0), rng.randf_range(-64.0, 64.0))
    return candidate

func _get_player_focus_position() -> Variant:
    var player := get_tree().get_first_node_in_group("player")
    if player is Node2D:
        return player.global_position
    if game_controller != null and game_controller.has_method("get_spawn_points"):
        var points: Array = game_controller.get_spawn_points("player")
        if points.size() > 0 and points[0] is Vector2:
            return points[0]
    return null

func _spawn_wave(faction: Node) -> void:
    var attempts: int = rng.randi_range(min_units_per_wave, max_units_per_wave)
    for _i in range(attempts):
        var unit_key: String = _choose_unit_type()
        var cost: float = _get_enemy_unit_cost(unit_key)
        if cost > _get_points(faction):
            break
        var spawn_pos_variant: Variant = _pick_spawn_position(faction)
        if spawn_pos_variant == null or not (spawn_pos_variant is Vector2):
            break
        var spawn_pos: Vector2 = spawn_pos_variant as Vector2
        var spawned: Node2D = game_controller.spawn_unit("enemy", unit_key, spawn_pos)
        if spawned == null:
            break

func _choose_unit_type() -> String:
    var total := melee_weight + ranged_weight
    if total <= 0.0:
        return "melee"
    var roll := rng.randf() * total
    if roll <= melee_weight:
        return "melee"
    return "ranged"

func _get_enemy_unit_cost(unit_key: String) -> float:
    var def := UnitDefinitions.get_enemy_unit(unit_key)
    if def.is_empty():
        return 0.0
    return float(def.get("cost", 0.0))

func _pick_spawn_position(faction: Node) -> Variant:
    if not faction.has_method("list_flags") or not faction.has_method("position_within_influence"):
        return null
    var flags: Array = faction.list_flags()
    if flags.size() == 0:
        if game_controller != null and game_controller.has_method("get_spawn_points"):
            var fallback: Array = game_controller.get_spawn_points("enemy")
            if fallback.size() > 0 and fallback[0] is Vector2:
                return fallback[0]
        return null
    var flag: Variant = flags[rng.randi_range(0, flags.size() - 1)]
    if flag == null or not (flag is Node2D) or not is_instance_valid(flag):
        return null
    var radius: float = 300.0
    var radius_v: Variant = faction.get("flag_radius")
    if typeof(radius_v) == TYPE_FLOAT or typeof(radius_v) == TYPE_INT:
        radius = float(radius_v)
    if flag.has_method("get_radius"):
        radius = flag.get_radius()
    var attempts := 6
    while attempts > 0:
        attempts -= 1
        var dir: Vector2 = Vector2(cos(rng.randf() * TAU), sin(rng.randf() * TAU))
        var dist: float = rng.randf_range(radius * 0.2, radius * 0.9)
        var candidate: Vector2 = flag.global_position + dir * dist
        if faction.position_within_influence(candidate):
            return candidate
    return flag.global_position

func apply_spawn_rate_boost(mult: float, duration: float = 10.0) -> void:
    spawn_rate_multiplier = max(1.0, mult)
    spawn_rate_boost_time = max(spawn_rate_boost_time, duration)

func _get_enemy_faction() -> Node:
    if game_controller != null and game_controller.has_method("get_faction"):
        return game_controller.get_faction("enemy")
    return null

func _get_points(faction: Node) -> float:
    if faction != null and faction.has_method("get_points"):
        return float(faction.get_points())
    return 0.0
