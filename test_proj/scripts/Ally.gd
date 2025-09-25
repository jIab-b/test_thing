extends CharacterBody2D

@export var move_speed: float = 80.0
@export var attack_range: float = 56.0
@export var attack_cooldown: float = 0.9

@onready var sprite: Sprite2D = $Sprite2D as Sprite2D

const SlashScene := preload("res://scenes/Slash.tscn")

var target_ref: Node2D = null
var attack_cooldown_left: float = 0.0
var printed_missing_monument: bool = false

func _ready() -> void:
	add_to_group("allies")
	if sprite.texture == null:
		var img := Image.create(18, 18, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.4, 0.8, 1.0, 1))
		var tex := ImageTexture.create_from_image(img)
		sprite.texture = tex
	sprite.z_index = 5

func _physics_process(delta: float) -> void:
	if target_ref == null or not is_instance_valid(target_ref):
		var n := get_tree().get_first_node_in_group("enemy_monument")
		if n != null and n is Node2D:
			target_ref = n
		elif not printed_missing_monument:
			printed_missing_monument = true
			print("No enemy monument found")
	if target_ref != null:
		var dir := (target_ref.global_position - global_position).normalized()
		velocity = dir * move_speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	if attack_cooldown_left > 0.0:
		attack_cooldown_left -= delta
	if target_ref != null and global_position.distance_to(target_ref.global_position) <= attack_range and attack_cooldown_left <= 0.0:
		_slash_attack()
		attack_cooldown_left = attack_cooldown

func _slash_attack() -> void:
	var s := SlashScene.instantiate()
	s.hit_mask = 65536
	s.damage = 20.0
	s.global_position = global_position
	var dir := target_ref.global_position - global_position if target_ref != null else Vector2.RIGHT
	s.setup(dir.normalized())
	get_parent().add_child(s)
