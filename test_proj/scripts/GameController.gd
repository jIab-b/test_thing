class_name GameController
extends Node

const UnitDefs := preload("res://scripts/UnitDefinitions.gd")

@export var player_faction_path: NodePath
@export var enemy_faction_path: NodePath

var player_faction: Node = null
var enemy_faction: Node = null
var cached_map_size: Vector2 = Vector2.ZERO
var player_spawn_points: Array = []
var enemy_spawn_points: Array = []

func _ready() -> void:
    if player_faction_path != NodePath(""):
        player_faction = get_node_or_null(player_faction_path)
    if enemy_faction_path != NodePath(""):
        enemy_faction = get_node_or_null(enemy_faction_path)
    _apply_map_size_to_factions()

func _apply_map_size_to_factions(root: Node = null) -> void:
    var map_holder: Node = root if root != null else get_parent()
    if map_holder == null:
        return
    var map_size: Vector2 = map_holder.get_meta("map_size_px", Vector2.ZERO)
    if map_size == Vector2.ZERO:
        return
    cached_map_size = map_size
    var factions: Array = [_get_faction("player"), _get_faction("enemy")]
    for faction in factions:
        if faction != null and faction.has_method("set_map_size"):
            faction.set_map_size(map_size)

func request_flag(faction_id: String, world_pos: Vector2) -> Node2D:
    var faction: Node = _get_faction(faction_id)
    if faction != null and faction.has_method("place_flag"):
        return faction.place_flag(world_pos)
    return null

func faction_can_place_flag(faction_id: String, world_pos: Vector2) -> bool:
    var faction: Node = _get_faction(faction_id)
    if faction == null:
        return false
    if not faction.has_method("is_position_valid_for_flag"):
        return false
    if not faction.has_method("can_afford"):
        return false
    var cost_v: Variant = faction.get("flag_cost")
    var flag_cost: float = 0.0
    if typeof(cost_v) == TYPE_FLOAT or typeof(cost_v) == TYPE_INT:
        flag_cost = float(cost_v)
    else:
        return false
    if not faction.is_position_valid_for_flag(world_pos):
        return false
    return faction.can_afford(flag_cost)

func get_faction(faction_id: String) -> Node:
    return _get_faction(faction_id)

func get_spawn_points(faction_id: String) -> Array:
    if faction_id == "enemy":
        return enemy_spawn_points.duplicate()
    if faction_id == "player":
        return player_spawn_points.duplicate()
    return []

func spawn_unit(faction_id: String, unit_key: String, world_pos: Vector2) -> Node2D:
    var faction: Node = _get_faction(faction_id)
    if faction == null:
        return null
    var def: Dictionary = _get_unit_definition(faction_id, unit_key)
    if def.is_empty():
        return null
    var cost := float(def.get("cost", 0.0))
    if faction_id == "player" and not _position_allows_spawn("player", world_pos):
        return null
    if faction_id == "enemy" and not _position_allows_spawn("enemy", world_pos):
        return null
    if cost > 0.0 and (not faction.has_method("spend_points") or not faction.spend_points(cost)):
        return null
    var scene_variant: Variant = def.get("scene", null)
    if not (scene_variant is PackedScene):
        if cost > 0.0 and faction.has_method("add_points"):
            faction.add_points(cost)
        return null
    var scene: PackedScene = scene_variant
    var parent: Node = get_parent()
    if parent == null:
        if cost > 0.0 and faction.has_method("add_points"):
            faction.add_points(cost)
        return null
    var spawn_pos: Vector2 = _clamp_within_map(world_pos)
    var unit: Node = scene.instantiate()
    parent.add_child(unit)
    if unit is Node2D:
        unit.global_position = spawn_pos
    if unit.has_method("configure_from_definition"):
        unit.configure_from_definition(def)
    return unit

func _position_allows_spawn(faction_id: String, world_pos: Variant) -> bool:
    var faction: Node = _get_faction(faction_id)
    if faction == null:
        return false
    if not faction.has_method("position_within_influence"):
        return false
    if world_pos is Vector2:
        return faction.position_within_influence(world_pos)
    return false

func notify_map_loaded(root: Node) -> void:
    _apply_map_size_to_factions(root)
    player_spawn_points.clear()
    enemy_spawn_points.clear()
    var blue_meta: Variant = root.get_meta("spawns_blue", [])
    if blue_meta is Array:
        player_spawn_points.append_array(blue_meta)
    var red_meta: Variant = root.get_meta("spawns_red", [])
    if red_meta is Array:
        enemy_spawn_points.append_array(red_meta)
    _ensure_starting_flags()

func _ensure_starting_flags() -> void:
    var player_fc: Node = _get_faction("player")
    if player_fc != null and player_fc.has_method("list_flags") and player_fc.list_flags().is_empty():
        if player_spawn_points.size() > 0:
            var first: Variant = player_spawn_points[0]
            if first is Vector2:
                player_fc.establish_flag(first)
    var enemy_fc: Node = _get_faction("enemy")
    if enemy_fc != null and enemy_fc.has_method("list_flags") and enemy_fc.list_flags().is_empty():
        if enemy_spawn_points.size() > 0:
            var first_e: Variant = enemy_spawn_points[0]
            if first_e is Vector2:
                enemy_fc.establish_flag(first_e)

func _clamp_within_map(world_pos: Vector2) -> Vector2:
    if cached_map_size == Vector2.ZERO:
        return world_pos
    return Vector2(clamp(world_pos.x, 0.0, cached_map_size.x), clamp(world_pos.y, 0.0, cached_map_size.y))

func _get_faction(faction_id: String) -> Node:
    if faction_id == "enemy" and enemy_faction != null:
        return enemy_faction
    if faction_id == "player" and player_faction != null:
        return player_faction
    return null

func _get_unit_definition(faction_id: String, unit_key: String) -> Dictionary:
    if faction_id == "player":
        return UnitDefs.get_player_unit(unit_key)
    return UnitDefs.get_enemy_unit(unit_key)
