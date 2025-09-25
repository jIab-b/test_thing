extends Node2D

const MapImporterRef = preload("res://scripts/MapImporter.gd")
const InputSetupRef = preload("res://scripts/InputSetup.gd")
@export var map_file: String = "res://maps/map_01.json"

func _enter_tree() -> void:
    InputSetupRef.ensure_actions()

func _ready() -> void:
    var chosen := map_file
    var args := OS.get_cmdline_args()
    for i in args.size():
        var a := String(args[i])
        if a.begins_with("--map="):
            var m := a.substr(6, a.length() - 6)
            if m != "":
                chosen = _map_path_from_number(m)
        elif a == "--map" and i + 1 < args.size():
            var m2 := String(args[i + 1])
            if m2 != "":
                chosen = _map_path_from_number(m2)
    MapImporterRef.import_map(self, chosen)
    await get_tree().process_frame
    var blues: Array = get_meta("spawns_blue", [])
    var player := get_tree().get_first_node_in_group("player")
    if player != null and player is Node2D:
        if blues.size() > 0 and blues[0] is Vector2:
            player.global_position = blues[0]
        else:
            var size: Vector2 = get_meta("map_size_px", Vector2.ZERO)
            if size != Vector2.ZERO:
                player.global_position = size * 0.5

func _map_path_from_number(num_str: String) -> String:
    var digits := num_str.strip_edges()
    if digits.is_valid_int():
        var n := int(digits)
        var padded := String.num_int64(n).pad_zeros(2)
        return "res://maps/map_" + padded + ".json"
    return map_file

