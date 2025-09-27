class_name FlagBeacon
extends Node2D

@export var radius: float = 320.0
@export var fill_color: Color = Color(0.2, 0.7, 1.0, 0.12)
@export var outline_color: Color = Color(0.2, 0.7, 1.0, 0.45)
@export var outline_width: float = 3.0
@export var faction: String = "player"

var circle_polygon: Polygon2D = null
var outline: Line2D = null

func _ready() -> void:
    z_index = -5
    _ensure_visuals()

func set_faction(new_faction: String) -> void:
    faction = new_faction
    _apply_faction_colors()

func set_radius(new_radius: float) -> void:
    radius = new_radius
    _ensure_visuals()

func get_radius() -> float:
    return radius

func contains_point(world_pos: Vector2) -> bool:
    return global_position.distance_to(world_pos) <= radius

func _ensure_visuals() -> void:
    if circle_polygon == null:
        circle_polygon = Polygon2D.new()
        add_child(circle_polygon)
    if outline == null:
        outline = Line2D.new()
        add_child(outline)
    var pts := _build_circle_points()
    circle_polygon.polygon = pts
    circle_polygon.position = Vector2.ZERO
    circle_polygon.color = fill_color
    outline.points = pts
    outline.width = outline_width
    outline.closed = true
    outline.default_color = outline_color
    _apply_faction_colors()

func _build_circle_points(segment_count: int = 48) -> PackedVector2Array:
    var pts := PackedVector2Array()
    for i in range(segment_count):
        var t := float(i) / float(segment_count) * TAU
        pts.append(Vector2(cos(t), sin(t)) * radius)
    return pts

func _apply_faction_colors() -> void:
    var base_col := fill_color
    var base_outline := outline_color
    if faction == "enemy":
        base_col = Color(1.0, 0.4, 0.35, fill_color.a)
        base_outline = Color(1.0, 0.35, 0.3, outline_color.a)
    circle_polygon.color = base_col
    outline.default_color = base_outline
