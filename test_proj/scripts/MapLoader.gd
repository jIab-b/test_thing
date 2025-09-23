extends Node2D

const MapImporterRef = preload("res://scripts/MapImporter.gd")
const InputSetupRef = preload("res://scripts/InputSetup.gd")
@export var map_file: String = "res://maps/map.json"

func _enter_tree() -> void:
    InputSetupRef.ensure_actions()

func _ready() -> void:
    MapImporterRef.import_map(self, map_file)
    await get_tree().process_frame
    var size: Vector2 = get_meta("map_size_px", Vector2.ZERO)
    if size != Vector2.ZERO:
        var player := get_tree().get_first_node_in_group("player")
        if player != null and player is Node2D:
            player.global_position = size * 0.5

