class_name Projectile
extends Area2D

@export var speed: float = 420.0
@export var lifetime: float = 2.5
@export var damage: float = 10.0
@export var knockback: float = 90.0

var velocity: Vector2 = Vector2.ZERO
var target_groups: Array = []
var source_group: String = ""
var sprite: Sprite2D = null

func _ready() -> void:
    body_entered.connect(_on_body_entered)
    sprite = get_node_or_null("Sprite2D")
    if sprite != null and sprite.texture == null:
        var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
        img.fill(Color(1.0, 0.8, 0.2, 1.0))
        var tex := ImageTexture.create_from_image(img)
        sprite.texture = tex
    set_process(true)

func launch(direction: Vector2, new_damage: float, new_speed: float, targets: Array, from_group: String = "") -> void:
    var dir: Vector2 = direction.normalized()
    if dir.length_squared() <= 0.0:
        dir = Vector2.RIGHT
    target_groups = targets.duplicate()
    source_group = from_group
    damage = new_damage
    speed = new_speed
    velocity = dir * speed

func _process(delta: float) -> void:
    global_position += velocity * delta
    lifetime -= delta
    if lifetime <= 0.0:
        queue_free()

func _on_body_entered(body: Node) -> void:
    if source_group != "" and body.is_in_group(source_group):
        return
    if target_groups.size() == 0:
        _apply_damage(body)
        return
    for group_name in target_groups:
        if body.is_in_group(String(group_name)):
            _apply_damage(body)
            return

func _apply_damage(body: Node) -> void:
    if body.has_method("take_damage"):
        body.take_damage(damage)
    if body.has_method("apply_knockback") and body is Node2D:
        var node2d := body as Node2D
        var dir_vec: Vector2 = (node2d.global_position - global_position).normalized()
        body.apply_knockback(dir_vec * knockback)
    queue_free()
