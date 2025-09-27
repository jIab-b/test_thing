extends CharacterBody2D

@export var move_speed: float = 80.0
@export var max_health: float = 120.0
@export var attack_range: float = 64.0
@export var attack_cooldown: float = 1.2
@export var attack_windup: float = 0.2
@export var attack_flash_lead_time: float = 0.12
@export var attack_flash_duration: float = 0.42
@export var attack_damage: float = 15.0
@export var projectile_speed: float = 420.0
@export var combat_style: String = "melee"

var current_health: float = 0.0
var target_ref: Node2D = null
var attack_cooldown_left: float = 0.0
var is_winding_up: bool = false
var base_modulate: Color = Color(1, 1, 1, 1)
var knockback_velocity: Vector2 = Vector2.ZERO
var target_reacquire_time: float = 0.0

@export var knockback_friction: float = 9.0

const SlashScene := preload("res://scenes/Slash.tscn")
const ProjectileScene := preload("res://scenes/Projectile.tscn")

@onready var sprite: Sprite2D = $Sprite2D as Sprite2D

func _ready() -> void:
    current_health = max_health
    add_to_group("enemies")
    add_to_group("enemy_units")
    var img := Image.create(20, 20, false, Image.FORMAT_RGBA8)
    img.fill(Color(1.0, 0.2, 0.2, 1))
    var tex := ImageTexture.create_from_image(img)
    sprite.texture = tex
    var enemy_path := ProjectSettings.globalize_path("res://../assets/enemy.png")
    var eimg := Image.new()
    if eimg.load(enemy_path) == OK:
        var nw := int(max(1, eimg.get_width() / 15))
        var nh := int(max(1, eimg.get_height() / 15))
        eimg.resize(nw, nh)
        var etex := ImageTexture.create_from_image(eimg)
        if etex != null:
            sprite.texture = etex
    base_modulate = sprite.modulate
    if combat_style == "ranged" and sprite != null:
        sprite.modulate = Color(1.0, 0.55, 0.55, 1.0)

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
    attack_cooldown_left = randf_range(0.15, attack_cooldown)
    if sprite != null:
        sprite.modulate = Color(1.0, 0.55, 0.55, 1.0) if combat_style == "ranged" else base_modulate

func _physics_process(delta: float) -> void:
    _refresh_target(delta)
    var move_dir := Vector2.ZERO
    if target_ref != null and is_instance_valid(target_ref):
        var to_target := target_ref.global_position - global_position
        var dist := to_target.length()
        if dist > 0.0:
            var dir := to_target / dist
            if combat_style == "ranged":
                var retreat := attack_range * 0.65
                if dist > attack_range * 0.92:
                    move_dir = dir
                elif dist < retreat:
                    move_dir = -dir
            else:
                move_dir = dir
    velocity = move_dir.normalized() * move_speed + knockback_velocity
    move_and_slide()
    if knockback_velocity.length_squared() > 0.001:
        var t: float = clamp(knockback_friction * delta, 0.0, 1.0)
        knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, t)
    else:
        knockback_velocity = Vector2.ZERO
    if attack_cooldown_left > 0.0:
        attack_cooldown_left -= delta
    if target_ref != null and is_instance_valid(target_ref):
        var dist_now := global_position.distance_to(target_ref.global_position)
        if dist_now <= attack_range and attack_cooldown_left <= 0.0 and not is_winding_up:
            _perform_attack(target_ref)
            attack_cooldown_left = attack_cooldown

func _refresh_target(delta: float) -> void:
    target_reacquire_time -= delta
    if target_ref != null and is_instance_valid(target_ref):
        return
    if target_reacquire_time > 0.0:
        return
    target_reacquire_time = 0.5
    target_ref = _find_target()

func _find_target() -> Node2D:
    var best: Node2D = null
    var best_dist := INF
    var candidates := []
    candidates.append_array(get_tree().get_nodes_in_group("player_units"))
    var player_node := get_tree().get_first_node_in_group("player")
    if player_node != null:
        candidates.append(player_node)
    for node in candidates:
        if node is Node2D and is_instance_valid(node):
            var dist := global_position.distance_squared_to(node.global_position)
            if dist < best_dist:
                best_dist = dist
                best = node
    return best

func take_damage(amount: float) -> void:
    current_health -= amount
    if current_health <= 0.0:
        queue_free()
        return
    if sprite != null:
        sprite.modulate = Color(1.0, 0.3, 0.3, 1.0)
        await get_tree().create_timer(0.12).timeout
        if is_instance_valid(self) and sprite != null:
            sprite.modulate = Color(1.0, 0.55, 0.55, 1.0) if combat_style == "ranged" else base_modulate

func _perform_attack(target: Node2D) -> void:
    if combat_style == "ranged":
        _fire_projectile(target)
    else:
        await _melee_attack(target)

func _melee_attack(target: Node2D) -> void:
    if is_winding_up:
        return
    is_winding_up = true
    var windup: float = max(attack_windup, 0.0)
    if windup > 0.0:
        _play_attack_warning(windup)
        await get_tree().create_timer(windup).timeout
        if not is_instance_valid(self):
            is_winding_up = false
            return
    if target == null or not is_instance_valid(target):
        is_winding_up = false
        return
    var dir := (target.global_position - global_position)
    if dir.length_squared() <= 0.001:
        dir = Vector2.RIGHT
    var dir_norm := dir.normalized()
    if SlashScene != null:
        var s := SlashScene.instantiate()
        s.damage = 0.0
        s.hit_mask = 0
        s.from_enemy = true
        var forward_offset := 48.0
        var perp := Vector2(-dir_norm.y, dir_norm.x)
        var offset := dir_norm * forward_offset + perp * 22.0
        s.global_position = global_position + offset
        s.setup(dir_norm, global_position, true)
        var parent := get_parent()
        if parent != null:
            parent.add_child(s)
    if target.has_method("take_damage"):
        target.take_damage(attack_damage)
    if target.has_method("apply_knockback"):
        target.apply_knockback(dir_norm * attack_damage * 2.0)
    is_winding_up = false

func _fire_projectile(target: Node2D) -> void:
    if ProjectileScene == null:
        return
    var p := ProjectileScene.instantiate()
    var parent := get_parent()
    if parent != null:
        parent.add_child(p)
    p.global_position = global_position
    var dir := (target.global_position - global_position).normalized()
    p.launch(dir, attack_damage, projectile_speed, ["player", "player_units"], "enemies")

func _play_attack_warning(duration: float) -> void:
    if sprite == null:
        return
    sprite.modulate = base_modulate if combat_style != "ranged" else Color(1.0, 0.55, 0.55, 1.0)
    var lead_time: float = clamp(attack_flash_lead_time, 0.05, duration)
    var start_delay: float = max(duration - lead_time, 0.0)
    var total_flash_time: float = max(attack_flash_duration, 0.05)
    var warn_tween := create_tween()
    warn_tween.tween_interval(start_delay)
    var flash_color := Color(1.0, 0.2, 0.2, 1.0)
    warn_tween.tween_property(sprite, "modulate", flash_color, total_flash_time * 0.45)
    warn_tween.tween_property(sprite, "modulate", base_modulate if combat_style != "ranged" else Color(1.0, 0.55, 0.55, 1.0), max(total_flash_time * 0.55, 0.01))

func apply_knockback(force: Vector2) -> void:
    knockback_velocity += force

func reset_visuals() -> void:
    if sprite != null:
        sprite.modulate = base_modulate if combat_style != "ranged" else Color(1.0, 0.55, 0.55, 1.0)
