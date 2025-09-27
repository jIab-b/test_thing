extends Node2D

@export var duration: float = 0.4
@export var radius: float = 140.0
@export var knockback_force: float = 900.0

var elapsed: float = 0.0
var sprite: Sprite2D
var mat: ShaderMaterial

func _ready() -> void:
    sprite = Sprite2D.new()
    sprite.centered = true
    var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
    img.fill(Color(1, 1, 1, 1))
    var tex := ImageTexture.create_from_image(img)
    sprite.texture = tex
    mat = ShaderMaterial.new()
    mat.shader = Shader.new()
    mat.shader.code = "shader_type canvas_item; uniform float progress = 0.0; void fragment(){ vec2 uv = UV * 2.0 - 1.0; float r = length(uv); float ring = 1.0 - smoothstep(progress - 0.06, progress + 0.06, r); float core = smoothstep(0.0, 0.2, 1.0 - r); float a = clamp(ring * 0.9 + core * 0.4, 0.0, 1.0) * (1.0 - progress); COLOR = vec4(1.0, 0.85, 0.35, a); }"
    sprite.material = mat
    add_child(sprite)
    sprite.scale = Vector2.ONE * (radius / 128.0) * 0.6
    z_index = 999
    call_deferred("_apply_knockback")

func _process(delta: float) -> void:
    elapsed += delta
    var t: float = clamp(elapsed / duration, 0.0, 1.0)
    if mat != null:
        mat.set_shader_parameter("progress", t)
    var s: float = 0.6 + 0.8 * t
    sprite.scale = Vector2.ONE * (radius / 128.0) * s
    if elapsed >= duration:
        queue_free()

func _apply_knockback() -> void:
    var enemies := get_tree().get_nodes_in_group("enemies")
    for n in enemies:
        if n is Node2D:
            var enemy := n as Node2D
            var distance := enemy.global_position.distance_to(global_position)
            if distance <= radius:
                var dir: Vector2 = (enemy.global_position - global_position).normalized()
                var falloff: float = 1.0 - clamp(distance / max(radius, 0.001), 0.0, 1.0)
                var force: Vector2 = dir * knockback_force * falloff
                if enemy.has_method("apply_knockback"):
                    enemy.apply_knockback(force)
                elif enemy is CharacterBody2D:
                    (enemy as CharacterBody2D).velocity += force


