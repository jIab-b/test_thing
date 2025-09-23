extends CharacterBody2D

@export var move_speed: float = 70.0
@export var max_health: float = 20.0
@export var attack_range: float = 64.0
@export var attack_cooldown: float = 0.8

var current_health: float = 0.0
var player_ref: Node2D = null
var attack_cooldown_left: float = 0.0

const SlashScene := preload("res://scenes/Slash.tscn")

@onready var sprite: Sprite2D = $Sprite2D as Sprite2D

func _ready() -> void:
    current_health = max_health
    add_to_group("enemies")
    var img := Image.create(20, 20, false, Image.FORMAT_RGBA8)
    img.fill(Color(1.0, 0.2, 0.2, 1))
    var tex := ImageTexture.create_from_image(img)
    sprite.texture = tex

func _physics_process(delta: float) -> void:
    if player_ref == null or not is_instance_valid(player_ref):
        var n := get_tree().get_first_node_in_group("player")
        if n != null and n is Node2D:
            player_ref = n
    if player_ref != null:
        var dir := (player_ref.global_position - global_position).normalized()
        velocity = dir * move_speed
    else:
        velocity = Vector2.ZERO
    move_and_slide()
    if attack_cooldown_left > 0.0:
        attack_cooldown_left -= delta
    if player_ref != null and global_position.distance_to(player_ref.global_position) <= attack_range and attack_cooldown_left <= 0.0:
        _slash_attack()
        attack_cooldown_left = attack_cooldown

func take_damage(amount: float) -> void:
    current_health -= amount
    if current_health <= 0.0:
        queue_free()

func _slash_attack() -> void:
    var s := SlashScene.instantiate()
    s.hit_mask = 16
    s.damage = 15.0  # Enemy slash damage
    s.global_position = global_position
    s.setup((player_ref.global_position - global_position).normalized())
    get_parent().add_child(s)

