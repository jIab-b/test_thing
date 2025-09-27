extends Node2D

@export var duration: float = 0.22
@export var height_scale: float = 1.0

const DeflectParryShader := preload("res://shaders/deflect_parry.gdshader")

var elapsed: float = 0.0
var sprite: Sprite2D
var shader_mat: ShaderMaterial
var texture: Texture2D

func _ready() -> void:
    sprite = Sprite2D.new()
    sprite.centered = false
    texture = _create_texture()
    sprite.texture = texture
    var base_scale: float = 0.45
    sprite.scale = Vector2(base_scale, height_scale * base_scale)
    var width: float = float(texture.get_width()) * sprite.scale.x
    var height: float = float(texture.get_height()) * sprite.scale.y
    sprite.position = Vector2(-width * 0.5, -height)
    sprite.z_index = 950
    shader_mat = ShaderMaterial.new()
    shader_mat.shader = DeflectParryShader
    shader_mat.set_shader_parameter("progress", 0.0)
    sprite.material = shader_mat
    add_child(sprite)
    set_process(true)

func setup(direction: Vector2) -> void:
    if direction.length_squared() > 0.0:
        rotation = direction.angle() + PI * 0.5

func _process(delta: float) -> void:
    elapsed += delta
    var t: float = clamp(elapsed / max(duration, 0.0001), 0.0, 1.0)
    if shader_mat != null:
        shader_mat.set_shader_parameter("progress", t)
    if elapsed >= duration:
        queue_free()

func _create_texture() -> Texture2D:
    var img := Image.create(128, 48, false, Image.FORMAT_RGBA8)
    img.fill(Color(1, 1, 1, 1))
    return ImageTexture.create_from_image(img)

func set_duration(value: float) -> void:
    duration = max(value, 0.05)
    elapsed = 0.0
