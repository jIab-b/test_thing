extends Area2D

@export var damage: float = 10.0
@export var duration: float = 0.18
@export var knockback: float = 140.0
@export var hit_mask: int = 8
@export var from_enemy: bool = false

@export var visual_offset_distance: float = 12.0
@export var visual_perp_offset: float = -88.0
@export var visual_start_scale: float = 0.12
@export var visual_overshoot_scale: float = 1.22
@export var visual_spring_duration: float = 0.22
@export var visual_rotation_offset: float = -2

var elapsed: float = 0.0
var hit: Dictionary = {}

var slash_material: ShaderMaterial = null
var sprite: Sprite2D = null
var attack_dir: Vector2 = Vector2.RIGHT
var origin_point: Vector2 = Vector2.ZERO
var face_origin_requested: bool = false
var spawn_tween_started: bool = false
var sprite_base_scale: Vector2 = Vector2.ONE
var sprite_base_scale_set: bool = false

func _ready() -> void:
    _ensure_sprite()
    body_entered.connect(_on_body_entered)
    if slash_material != null:
        slash_material.set_shader_parameter("progress", 0.0)
    if sprite != null and sprite.texture == null:
        var img: Image = Image.create(128, 128, false, Image.FORMAT_RGBA8)
        img.fill(Color(1, 1, 1, 1))
        var tex: ImageTexture = ImageTexture.create_from_image(img)
        sprite.texture = tex
    collision_mask = hit_mask
    set_process(true)
    _refresh_visuals()
    _start_spawn_tween()

func _ensure_sprite() -> bool:
    if sprite == null:
        sprite = get_node_or_null("Sprite2D")
    if sprite != null and slash_material == null and sprite.material is ShaderMaterial:
        slash_material = sprite.material as ShaderMaterial
    if sprite != null and not sprite_base_scale_set:
        sprite_base_scale = sprite.scale
        sprite_base_scale_set = true
    return sprite != null

func setup(dir: Vector2, origin: Vector2 = Vector2.ZERO, face_origin: bool = false) -> void:
    if dir.length_squared() > 0.0:
        attack_dir = dir.normalized()
    else:
        attack_dir = Vector2.RIGHT
    origin_point = origin
    face_origin_requested = face_origin
    rotation = attack_dir.angle()
    _refresh_visuals()

func _refresh_visuals() -> void:
    if not _ensure_sprite():
        return
    _apply_visual_offset()
    _update_sprite_orientation()

func _apply_visual_offset() -> void:
    if sprite == null:
        return
    sprite.position = Vector2(visual_offset_distance, visual_perp_offset)

func _update_sprite_orientation() -> void:
    if sprite == null:
        return
    if not face_origin_requested:
        sprite.rotation = 0.0
        return
    var inward: Vector2 = origin_point - global_position
    if inward.length_squared() <= 0.0001:
        inward = -attack_dir
    sprite.global_rotation = inward.angle() + visual_rotation_offset

func _start_spawn_tween() -> void:
    if sprite == null or spawn_tween_started:
        return
    spawn_tween_started = true
    var base_scale := sprite_base_scale
    sprite.scale = base_scale * visual_start_scale
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(sprite, "scale", base_scale * visual_overshoot_scale, visual_spring_duration * 0.55)
    tween.tween_property(sprite, "scale", base_scale, visual_spring_duration * 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

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
    if body is Node2D:
        var dir: Vector2 = (body.global_position - global_position).normalized()
        var force := dir * knockback
        if body.has_method("apply_knockback"):
            body.apply_knockback(force)
        elif body is CharacterBody2D:
            body.velocity += force
