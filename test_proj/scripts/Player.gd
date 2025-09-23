extends CharacterBody2D

@export var move_speed: float = 320.0
@export var dash_speed: float = 1260.0
@export var dash_duration: float = 0.16
@export var dash_cooldown: float = 0.8
@export var attack_cooldown: float = 0.25
@export var max_health: float = 200.0

const SlashScene := preload("res://scenes/Slash.tscn")

var dash_time_left: float = 0.0
var dash_cooldown_left: float = 0.0
var attack_cooldown_left: float = 0.0
var invuln_time_left: float = 0.0
var health: float = max_health
var aim_direction: Vector2 = Vector2.RIGHT

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
    add_to_group("player")
    var img := Image.create(18, 18, false, Image.FORMAT_RGBA8)
    img.fill(Color(0.3, 1.0, 0.3, 1))
    var tex := ImageTexture.create_from_image(img)
    sprite.texture = tex

func _physics_process(delta: float) -> void:
    var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    if input_dir.length() > 0.0:
        aim_direction = input_dir
    if dash_time_left > 0.0:
        velocity = input_dir.normalized() * dash_speed
        dash_time_left -= delta
    else:
        velocity = input_dir.normalized() * move_speed
        if dash_cooldown_left > 0.0:
            dash_cooldown_left -= delta
    if invuln_time_left > 0.0:
        invuln_time_left -= delta
    move_and_slide()

func _process(delta: float) -> void:
    if attack_cooldown_left > 0.0:
        attack_cooldown_left -= delta
    if Input.is_action_just_pressed("dash") and dash_cooldown_left <= 0.0:
        dash_time_left = dash_duration
        dash_cooldown_left = dash_cooldown
        invuln_time_left = dash_duration
    if Input.is_action_pressed("attack") and attack_cooldown_left <= 0.0:
        _slash()
        attack_cooldown_left = attack_cooldown

func _slash() -> void:
    var s := SlashScene.instantiate()
    var dir := (get_global_mouse_position() - global_position).normalized()
    var distance := 40.0  # Move slash 40 pixels away from player
    var perp_dir := Vector2(dir.y, -dir.x)  # Opposite perpendicular direction for wider swing arc
    var offset := dir * distance + perp_dir * 30.0  # Offset along direction + less perpendicular for moderate swing arc
    s.global_position = global_position + offset
    s.setup(dir)
    get_parent().add_child(s)

func take_damage(amount: float) -> void:
    if invuln_time_left > 0.0:
        return
    health -= amount
    if health <= 0.0:
        health = 0.0
        # TODO: handle death
    modulate = Color(1, 0.5, 0.5, 1)
    await get_tree().create_timer(0.05).timeout
    modulate = Color(1, 1, 1, 1)

func get_health() -> float:
    return health

