class_name MapImporter
extends Node

static func import_map(parent: Node, json_path: String) -> void:
    var tile_size := 32
    var gw := 120
    var gh := 68
    var blocks := []
    var pickups := []
    var f := FileAccess.open(json_path, FileAccess.READ)
    if f != null:
        var txt := f.get_as_text()
        f.close()
        var data = JSON.parse_string(txt)
        if typeof(data) == TYPE_DICTIONARY:
            tile_size = int(data.get("tile_size", tile_size))
            gw = int(data.get("grid_width", gw))
            gh = int(data.get("grid_height", gh))
            blocks = data.get("visual_blocks", []) if data.has("visual_blocks") else []
            pickups = data.get("pickups", []) if data.has("pickups") else []
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
    parent.move_child(background, 0)
    var poly := Polygon2D.new()
    poly.polygon = PackedVector2Array([Vector2(0,0), Vector2(width_px,0), Vector2(width_px,height_px), Vector2(0,height_px)])
    poly.color = Color(0.18, 0.24, 0.38, 1.0)
    poly.z_index = -1
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

    var old := parent.get_node_or_null("Blocks")
    if old != null:
        old.queue_free()
    var blocks_node := Node2D.new()
    blocks_node.name = "Blocks"
    blocks_node.z_index = 0
    parent.add_child(blocks_node)
    var img := Image.create(tile_size, tile_size, false, Image.FORMAT_RGBA8)
    img.fill(Color(0.45, 0.45, 0.45, 1.0))
    var tex := ImageTexture.create_from_image(img)
    for p in blocks:
        if p is Array and len(p) == 2:
            var x := int(p[0])
            var y := int(p[1])
            var body := StaticBody2D.new()
            body.collision_layer = 1
            var shape := CollisionShape2D.new()
            var rect := RectangleShape2D.new()
            rect.size = Vector2(tile_size, tile_size)
            shape.shape = rect
            body.add_child(shape)
            body.position = Vector2((x + 0.5) * tile_size, (y + 0.5) * tile_size)
            blocks_node.add_child(body)
            var sprite := Sprite2D.new()
            sprite.texture = tex
            sprite.z_index = 1
            sprite.position = Vector2((x + 0.5) * tile_size, (y + 0.5) * tile_size)
            blocks_node.add_child(sprite)

    var tileset := {} if data == null or typeof(data) != TYPE_DICTIONARY else data.get("tileset", {})
    var tile_indices := [] if data == null or typeof(data) != TYPE_DICTIONARY else data.get("tile_indices", [])
    if typeof(tileset) == TYPE_DICTIONARY and tile_indices is Array and tile_indices.size() > 0:
        var file := String(tileset.get("file", ""))
        var tw := int(tileset.get("tile_w", tile_size))
        var th := int(tileset.get("tile_h", tile_size))
        var cols := int(tileset.get("columns", 1))
        if file != "" and tw > 0 and th > 0 and cols > 0:
            var atlas: Texture2D = load(file)
            if atlas != null:
                var tiles_node := Node2D.new()
                tiles_node.name = "Tiles"
                tiles_node.z_index = 1
                parent.add_child(tiles_node)
                for t in tile_indices:
                    if t is Array and t.size() >= 3:
                        var tx := int(t[0])
                        var ty := int(t[1])
                        var idx := int(t[2])
                        var at := AtlasTexture.new()
                        at.atlas = atlas
                        var rx := (idx % cols) * tw
                        var ry := int(idx / cols) * th
                        at.region = Rect2(rx, ry, tw, th)
                        var s := Sprite2D.new()
                        s.texture = at
                        s.position = Vector2((tx + 0.5) * tile_size, (ty + 0.5) * tile_size)
                        tiles_node.add_child(s)

    var center_pos := Vector2(width_px * 0.4, height_px * 0.4)
    var timer := parent.get_tree().create_timer(0.01)
    timer.timeout.connect(func():
        var player := parent.get_tree().get_first_node_in_group("player")
        if player != null and player is Node2D:
            player.global_position = center_pos
    )

