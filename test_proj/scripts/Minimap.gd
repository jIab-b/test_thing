extends Control

@export var player_group: String = "player"
@export var enemy_group: String = "enemies"
@export var size_px: Vector2i = Vector2i(200, 120)

var map_size_px: Vector2 = Vector2.ZERO

func _ready() -> void:
    custom_minimum_size = Vector2(size_px)
    size = Vector2(size_px)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_process(true)

func _process(delta: float) -> void:
    var root := get_tree().current_scene
    if root != null and map_size_px == Vector2.ZERO:
        map_size_px = root.get_meta("map_size_px", Vector2.ZERO)
    queue_redraw()

func _draw() -> void:
    var inner: Vector2 = size - Vector2(16,16)
    var rect := Rect2(Vector2(8,8), inner)
    draw_rect(rect, Color(0,0,0,0.5), true)
    draw_rect(rect, Color(1,1,1,0.2), false, 1.0)
    if map_size_px == Vector2.ZERO:
        return
    var player := get_tree().get_first_node_in_group(player_group)
    if player != null:
        var p: Vector2 = (player.global_position / map_size_px) * inner + Vector2(8,8)
        draw_circle(p, 3.0, Color(1,1,1,1))
    for e in get_tree().get_nodes_in_group(enemy_group):
        if e is Node2D:
            var ep: Vector2 = (e.global_position / map_size_px) * inner + Vector2(8,8)
            draw_circle(ep, 2.0, Color(1,0.2,0.2,1))

