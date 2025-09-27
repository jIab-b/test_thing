extends CharacterBody2D

@export var move_speed: float = 90.0
@export var attack_range: float = 64.0
@export var attack_cooldown: float = 1.2
@export var attack_damage: float = 20.0
@export var max_health: float = 150.0
@export var projectile_speed: float = 400.0
@export var combat_style: String = "melee"  # melee or ranged

@onready var sprite: Sprite2D = $Sprite2D as Sprite2D

const SlashScene := preload("res://scenes/Slash.tscn")
const ProjectileScene := preload("res://scenes/Projectile.tscn")

var target_ref: Node2D = null
var attack_cooldown_left: float = 0.0
var current_health: float = 0.0
var knockback_velocity: Vector2 = Vector2.ZERO
var target_reacquire_time: float = 0.0
var base_color: Color = Color(1, 1, 1, 1)

func _ready() -> void:
    add_to_group("allies")
    add_to_group("player_units")
    if sprite.texture == null:
        var img := Image.create(18, 18, false, Image.FORMAT_RGBA8)
        img.fill(Color(0.4, 0.8, 1.0, 1))
        var tex := ImageTexture.create_from_image(img)
        sprite.texture = tex
    sprite.z_index = 5
    base_color = sprite.modulate
    current_health = max_health

func configure_from_definition(def: Dictionary) -> void:
    combat_style = String(def.get("combat_style", combat_style))
    var stats: Dictionary = def.get("stats", {})
    move_speed = float(stats.get("move_speed", move_speed))
    max_health = float(stats.get("max_health", max_health))
    attack_range = float(stats.get("attack_range", attack_range))
    attack_cooldown = float(stats.get("attack_cooldown", attack_cooldown))
    attack_damage = float(stats.get("attack_damage", attack_damage))
    projectile_speed = float(stats.get("projectile_speed", projectile_speed))
    current_health = max_health
    attack_cooldown_left = randf_range(0.1, attack_cooldown)
    if sprite != null:
        if combat_style == "ranged":
            sprite.modulate = Color(0.65, 0.85, 1.0, 1.0)
        else:
            sprite.modulate = base_color

func _physics_process(delta: float) -> void:
    _refresh_target(delta)
    var move_vec := Vector2.ZERO
    if target_ref != null and is_instance_valid(target_ref):
        var to_target := target_ref.global_position - global_position
        var dist := to_target.length()
        if dist > 0.0:
            var dir := to_target / dist
            if combat_style == "ranged":
                var desired := attack_range * 0.82
                var retreat_threshold := attack_range * 0.66
                if dist > attack_range * 0.95:
                    move_vec = dir
                elif dist < retreat_threshold:
                    move_vec = -dir
                else:
                    move_vec = Vector2.ZERO
            else:
                move_vec = dir
    velocity = move_vec.normalized() * move_speed + knockback_velocity
    move_and_slide()
    if knockback_velocity.length_squared() > 0.001:
        knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, clamp(delta * 5.0, 0.0, 1.0))
    else:
        knockback_velocity = Vector2.ZERO
    if attack_cooldown_left > 0.0:
        attack_cooldown_left -= delta
    if target_ref != null and is_instance_valid(target_ref):
        var dist_now := global_position.distance_to(target_ref.global_position)
        if dist_now <= attack_range and attack_cooldown_left <= 0.0:
            _perform_attack(target_ref)
            attack_cooldown_left = attack_cooldown

func _refresh_target(delta: float) -> void:
    target_reacquire_time -= delta
    if target_ref != null and is_instance_valid(target_ref):
        return
    if target_reacquire_time > 0.0:
        return
    target_reacquire_time = 0.45
    target_ref = _find_target()

func _find_target() -> Node2D:
    var best: Node2D = null
    var best_dist := INF
    var enemy_nodes := get_tree().get_nodes_in_group("enemies")
    for n in enemy_nodes:
        if n is Node2D and is_instance_valid(n):
            var dist := global_position.distance_squared_to(n.global_position)
            if dist < best_dist:
                best_dist = dist
                best = n
    if best != null:
        return best
    var monuments := get_tree().get_nodes_in_group("enemy_monument")
    for m in monuments:
        if m is Node2D and is_instance_valid(m):
            return m
    return null

func _perform_attack(target: Node2D) -> void:
    if combat_style == "ranged":
        _fire_projectile(target)
    else:
        _melee_attack(target)

func _melee_attack(target: Node2D) -> void:
    if SlashScene == null:
        return
    var dir := (target.global_position - global_position)
    if dir.length_squared() <= 0.0001:
        dir = Vector2.RIGHT
    var dir_norm := dir.normalized()
    var s := SlashScene.instantiate()
    s.damage = 0.0
    s.hit_mask = 0
    s.global_position = global_position + dir_norm * 42.0
    s.setup(dir_norm, global_position, true)
    get_parent().add_child(s)
    if target.has_method("take_damage"):
        target.take_damage(attack_damage)
    if target.has_method("apply_knockback"):
        target.apply_knockback(dir_norm * attack_damage * 2.2)

func _fire_projectile(target: Node2D) -> void:
    if ProjectileScene == null:
        return
    var proj := ProjectileScene.instantiate()
    get_parent().add_child(proj)
    proj.global_position = global_position
    var dir := (target.global_position - global_position).normalized()
    proj.launch(dir, attack_damage, projectile_speed, ["enemies"], "player_units")

func take_damage(amount: float) -> void:
    current_health -= amount
    if current_health <= 0.0:
        queue_free()
        return
    if sprite != null:
        sprite.modulate = Color(1.0, 0.6, 0.6, 1.0)
        await get_tree().create_timer(0.12).timeout
        if is_instance_valid(self) and sprite != null:
            sprite.modulate = base_color if combat_style != "ranged" else Color(0.65, 0.85, 1.0, 1.0)

func apply_knockback(force: Vector2) -> void:
    knockback_velocity += force
