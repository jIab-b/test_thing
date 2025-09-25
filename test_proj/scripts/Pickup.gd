extends Area2D

@export var kind: String = "attack"

@onready var sprite: Sprite2D = $Sprite2D as Sprite2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if sprite.texture == null:
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		var col := Color(1, 0.72, 0.27) if kind == "attack" else Color(0.27, 1, 0.54)
		img.fill(col)
		var tex := ImageTexture.create_from_image(img)
		sprite.texture = tex

func _on_body_entered(body: Node) -> void:
	var root := get_tree().current_scene
	if kind == "attack":
		if body.is_in_group("player"):
			var sp = root.get_node_or_null("AllySpawner")
			if sp != null and sp.has_method("apply_spawn_rate_boost"):
				sp.apply_spawn_rate_boost(2.0)
			queue_free()
		elif body.is_in_group("enemies"):
			var esp = root.get_node_or_null("EnemySpawner")
			if esp != null and esp.has_method("apply_spawn_rate_boost"):
				esp.apply_spawn_rate_boost(2.0)
			queue_free()
	elif kind == "health":
		queue_free()
