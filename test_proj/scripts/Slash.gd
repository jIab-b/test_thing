extends Area2D

@export var damage: float = 10.0
@export var duration: float = 0.18
@export var knockback: float = 140.0
@export var hit_mask: int = 8
@export var from_enemy: bool = false

var elapsed: float = 0.0
var hit: Dictionary = {}

@onready var slash_material: ShaderMaterial = $Sprite2D.material as ShaderMaterial
@onready var sprite: Sprite2D = $Sprite2D as Sprite2D

func _ready() -> void:
    body_entered.connect(_on_body_entered)
    if slash_material != null:
        slash_material.set_shader_parameter("progress", 0.0)
    if sprite.texture == null:
        var img: Image = Image.create(128, 128, false, Image.FORMAT_RGBA8)
        img.fill(Color(1, 1, 1, 1))
        var tex: ImageTexture = ImageTexture.create_from_image(img)
        sprite.texture = tex
    collision_mask = hit_mask

func setup(dir: Vector2) -> void:
    rotation = dir.angle()

func _process(delta: float) -> void:
    elapsed += delta
    var t: float = clamp(elapsed / duration, 0.0, 1.0)
    if slash_material != null:
        slash_material.set_shader_parameter("progress", t)
    if elapsed >= duration:
        queue_free()

func _on_body_entered(body: Node) -> void:
    if hit.has(body):
        return
    hit[body] = true
    if from_enemy and body.is_in_group("player") and body.has_method("attempt_deflect"):
        if body.attempt_deflect(self):
            queue_free()
            return
    if body.has_method("take_damage"):
        body.take_damage(damage)
    if body is CharacterBody2D:
        var dir: Vector2 = (body.global_position - global_position).normalized()
        body.velocity += dir * knockback


