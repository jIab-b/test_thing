class_name UnitDefinitions
extends Object

const PLAYER_UNIT_TYPES := {
    "melee": {
        "id": "player_melee",
        "display_name": "Vanguard",
        "cost": 40,
        "scene": preload("res://scenes/Ally.tscn"),
        "combat_style": "melee",
        "stats": {
            "move_speed": 95.0,
            "max_health": 180.0,
            "attack_range": 46.0,
            "attack_cooldown": 1.15,
            "attack_damage": 28.0,
            "projectile_speed": 0.0
        }
    },
    "ranged": {
        "id": "player_ranged",
        "display_name": "Archer",
        "cost": 28,
        "scene": preload("res://scenes/Ally.tscn"),
        "combat_style": "ranged",
        "stats": {
            "move_speed": 110.0,
            "max_health": 95.0,
            "attack_range": 220.0,
            "attack_cooldown": 1.4,
            "attack_damage": 12.0,
            "projectile_speed": 420.0
        }
    }
}

const ENEMY_UNIT_TYPES := {
    "melee": {
        "id": "enemy_melee",
        "scene": preload("res://scenes/Enemy.tscn"),
        "combat_style": "melee",
        "cost": 32,
        "stats": {
            "move_speed": 90.0,
            "max_health": 160.0,
            "attack_range": 52.0,
            "attack_cooldown": 1.3,
            "attack_damage": 26.0,
            "projectile_speed": 0.0
        }
    },
    "ranged": {
        "id": "enemy_ranged",
        "scene": preload("res://scenes/Enemy.tscn"),
        "combat_style": "ranged",
        "cost": 26,
        "stats": {
            "move_speed": 115.0,
            "max_health": 80.0,
            "attack_range": 240.0,
            "attack_cooldown": 1.55,
            "attack_damage": 11.0,
            "projectile_speed": 440.0
        }
    }
}

static func get_player_unit(key: String) -> Dictionary:
    return PLAYER_UNIT_TYPES.get(key, {})

static func get_enemy_unit(key: String) -> Dictionary:
    return ENEMY_UNIT_TYPES.get(key, {})

static func list_player_units() -> Array:
    return PLAYER_UNIT_TYPES.keys()

static func list_enemy_units() -> Array:
    return ENEMY_UNIT_TYPES.keys()
