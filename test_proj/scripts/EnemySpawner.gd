extends Node

@export var enemy_scene: PackedScene
@export var spawn_interval: float = 1.0

var time_since_spawn: float = 0.0
var difficulty_time: float = 0.0
var rng: RandomNumberGenerator = null

func _ready() -> void:
    rng = RandomNumberGenerator.new()
    rng.randomize()
    set_process(true)
    time_since_spawn = 9999.0
    call_deferred("_spawn_initial")

func _spawn_initial() -> void:
    await get_tree().process_frame
    _spawn_enemy()

func _process(delta: float) -> void:
    time_since_spawn += delta
    difficulty_time += delta
    var interval: float = max(0.2, spawn_interval - difficulty_time * 0.01)
    if time_since_spawn >= interval:
        time_since_spawn = 0.0
        _spawn_enemy()

func _spawn_enemy() -> void:
    if enemy_scene == null:
        return
    var player := get_tree().get_first_node_in_group("player")
    if player == null:
        return
    var screen: Vector2 = get_viewport().get_visible_rect().size
    var base_r: float = max(screen.x, screen.y) * 1.5
    var angle: float = rng.randf() * TAU
    var radius: float = rng.randf_range(base_r * 0.9, base_r * 1.1)
    var pos: Vector2 = player.global_position + Vector2(cos(angle), sin(angle)) * radius
    var e := enemy_scene.instantiate()
    e.global_position = pos
    get_parent().add_child(e)

