class_name MapImporter
extends Node

static func import_map(parent: Node, json_path: String) -> void:
    var tile_size := 32
    var gw := 120
    var gh := 68
    var f := FileAccess.open(json_path, FileAccess.READ)
    if f != null:
        var txt := f.get_as_text()
        f.close()
        var data = JSON.parse_string(txt)
        if typeof(data) == TYPE_DICTIONARY:
            tile_size = int(data.get("tile_size", tile_size))
            gw = int(data.get("grid_width", gw))
            gh = int(data.get("grid_height", gh))
    var width_px := gw * tile_size
    var height_px := gh * tile_size
    parent.set_meta("map_size_px", Vector2(width_px, height_px))
    parent.set_meta("map_grid", Vector2i(gw, gh))
    parent.set_meta("tile_size", tile_size)

    for n in ["Background", "Bounds"]:
        var old := parent.get_node_or_null(n)
        if old != null:
            old.queue_free()

    var background := Node2D.new()
    background.name = "Background"
    background.z_index = -1000
    parent.add_child(background)
    var poly := Polygon2D.new()
    poly.polygon = PackedVector2Array([Vector2(0,0), Vector2(width_px,0), Vector2(width_px,height_px), Vector2(0,height_px)])
    poly.color = Color(0.18, 0.24, 0.38, 1.0)
    background.add_child(poly)

    var bounds := Node2D.new()
    bounds.name = "Bounds"
    parent.add_child(bounds)
    var thickness := float(tile_size) * 2.0
    var sides := [
        {"pos": Vector2(width_px * 0.5, -thickness * 0.5), "size": Vector2(width_px + thickness * 2.0, thickness)},
        {"pos": Vector2(width_px * 0.5, height_px + thickness * 0.5), "size": Vector2(width_px + thickness * 2.0, thickness)},
        {"pos": Vector2(-thickness * 0.5, height_px * 0.5), "size": Vector2(thickness, height_px + thickness * 2.0)},
        {"pos": Vector2(width_px + thickness * 0.5, height_px * 0.5), "size": Vector2(thickness, height_px + thickness * 2.0)},
    ]
    for sdata in sides:
        var body := StaticBody2D.new()
        body.collision_layer = 1
        var shape := CollisionShape2D.new()
        var rect := RectangleShape2D.new()
        rect.size = sdata["size"]
        shape.shape = rect
        body.add_child(shape)
        body.position = sdata["pos"]
        bounds.add_child(body)

    var cam := parent.find_child("Camera2D", true, false)
    if cam != null and cam is Camera2D:
        cam.limit_left = 0
        cam.limit_top = 0
        cam.limit_right = width_px
        cam.limit_bottom = height_px

    var center_pos := Vector2(width_px * 0.5, height_px * 0.5)
    var timer := parent.get_tree().create_timer(0.01)
    timer.timeout.connect(func():
        var player := parent.get_tree().get_first_node_in_group("player")
        if player != null and player is Node2D:
            player.global_position = center_pos
    )

