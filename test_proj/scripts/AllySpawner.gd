extends Node

@export var ally_scene: PackedScene
@export var spawn_interval: float = 1.0

var time_since_spawn: float = 0.0
var difficulty_time: float = 0.0
var rng: RandomNumberGenerator = null
var spawn_rate_multiplier: float = 1.0
var boost_time_left: float = 0.0

func _ready() -> void:
	rng = RandomNumberGenerator.new()
	rng.randomize()
	set_process(true)
	time_since_spawn = 9999.0
	call_deferred("_spawn_initial")

func _spawn_initial() -> void:
	await get_tree().process_frame
	_spawn_ally()

func _process(delta: float) -> void:
	time_since_spawn += delta
	difficulty_time += delta
	if boost_time_left > 0.0:
		boost_time_left -= delta
		if boost_time_left <= 0.0:
			spawn_rate_multiplier = 1.0
	var interval: float = max(0.2, (spawn_interval - difficulty_time * 0.01)) / max(0.1, spawn_rate_multiplier)
	if time_since_spawn >= interval:
		time_since_spawn = 0.0
		_spawn_ally()

func _spawn_ally() -> void:
	if ally_scene == null:
		return
	var blues: Array = get_parent().get_meta("spawns_blue", [])
	if blues is Array and blues.size() > 0:
		var idx := int(floor(rng.randf() * blues.size()))
		idx = clamp(idx, 0, blues.size() - 1)
		var posv = blues[idx]
		if posv is Vector2:
			var a1 := ally_scene.instantiate()
			a1.global_position = posv
			get_parent().add_child(a1)
			return
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var map_size: Vector2 = get_parent().get_meta("map_size_px", Vector2.ZERO)
	if map_size == Vector2.ZERO:
		return
	var tile_size: int = get_parent().get_meta("tile_size", 32)
	var margin := float(tile_size) * 3.0
	var min_r: float = min(map_size.x, map_size.y) * 0.2
	var max_r: float = min(map_size.x, map_size.y) * 0.4
	for _attempt in range(10):
		var angle: float = rng.randf() * TAU
		var radius: float = rng.randf_range(min_r, max_r)
		var pos: Vector2 = player.global_position + Vector2(cos(angle), sin(angle)) * radius
		if pos.x >= margin and pos.y >= margin and pos.x < map_size.x - margin and pos.y < map_size.y - margin:
			var a := ally_scene.instantiate()
			a.global_position = pos
			get_parent().add_child(a)
			return

func apply_spawn_rate_boost(mult: float, duration: float = 10.0) -> void:
	spawn_rate_multiplier = max(1.0, mult)
	boost_time_left = max(boost_time_left, duration)
