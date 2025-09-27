extends Node

@export var enemy_scene: PackedScene
@export var spawn_interval: float = 1.0

var time_since_spawn: float = 0.0
var difficulty_time: float = 0.0
var rng: RandomNumberGenerator = null
var spawn_rate_multiplier: float = 1.0
var boost_time_left: float = 0.0
var spawn_dirs: Array[Vector2] = []
var next_spawn_index: int = 0

func get_base_interval() -> float:
    return spawn_interval

func _ready() -> void:
    rng = RandomNumberGenerator.new()
    rng.randomize()
    _initialize_spawn_dirs()
    set_process(true)
    time_since_spawn = 9999.0
    call_deferred("_spawn_initial")

func _spawn_initial() -> void:
    await get_tree().process_frame
    _spawn_enemy()

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
        _spawn_enemy()

func _spawn_enemy() -> void:
    if enemy_scene == null:
        return
    var player := get_tree().get_first_node_in_group("player")
    if player == null:
        return
    var map_size: Vector2 = get_parent().get_meta("map_size_px", Vector2.ZERO)
    if map_size == Vector2.ZERO:
        return
    var tile_size: int = get_parent().get_meta("tile_size", 32)
    var margin := float(tile_size) * 2.0
    if spawn_dirs.size() == 0:
        _initialize_spawn_dirs()
    var view_size: Vector2 = _get_viewport_size()
    var radius: float = max(view_size.x, view_size.y) * 0.5 + margin
    var dir: Vector2 = spawn_dirs[next_spawn_index]
    next_spawn_index = (next_spawn_index + 1) % spawn_dirs.size()
    var pos: Vector2 = player.global_position + dir * radius
    pos.x = clamp(pos.x, margin, map_size.x - margin)
    pos.y = clamp(pos.y, margin, map_size.y - margin)
    var e := enemy_scene.instantiate()
    e.global_position = pos
    get_parent().add_child(e)

func apply_spawn_rate_boost(mult: float, duration: float = 10.0) -> void:
    spawn_rate_multiplier = max(1.0, mult)
    boost_time_left = max(boost_time_left, duration)

func _initialize_spawn_dirs() -> void:
    spawn_dirs.clear()
    for i in range(6):
        var angle := float(i) / 6.0 * TAU
        spawn_dirs.append(Vector2(cos(angle), sin(angle)))
    next_spawn_index = 0

func _get_viewport_size() -> Vector2:
    var viewport := get_viewport()
    if viewport != null:
        var rect := viewport.get_visible_rect()
        if rect.size != Vector2.ZERO:
            return rect.size
    var w := float(ProjectSettings.get_setting("display/window/size/viewport_width", 1280))
    var h := float(ProjectSettings.get_setting("display/window/size/viewport_height", 720))
    return Vector2(w, h)

