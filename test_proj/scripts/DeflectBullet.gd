extends Area2D

@export var speed: float = 860.0
@export var lifetime: float = 1.4
@export var damage: float = 9999.0
@export var knockback: float = 520.0

var direction: Vector2 = Vector2.RIGHT
var elapsed: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D as Sprite2D

func _ready() -> void:
    body_entered.connect(_on_body_entered)
    if sprite != null and sprite.texture == null:
        var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
        img.fill(Color(1, 0.95, 0.5, 1))
        var tex := ImageTexture.create_from_image(img)
        sprite.texture = tex

func setup(dir: Vector2) -> void:
    if dir.length_squared() > 0.0:
        direction = dir.normalized()
    rotation = direction.angle()

func _physics_process(delta: float) -> void:
    global_position += direction * speed * delta
    elapsed += delta
    if elapsed >= lifetime:
        queue_free()

func _on_body_entered(body: Node) -> void:
    if not is_instance_valid(body):
        return
    if body.is_in_group("enemies"):
        if body.has_method("take_damage"):
            body.take_damage(damage)
        if body.has_method("apply_knockback"):
            body.apply_knockback(direction * knockback)
        elif body is CharacterBody2D:
            body.velocity += direction * knockback
        queue_free()
    else:
        queue_free()
