extends ProgressBar

@export var player_path: NodePath
var player: Node2D

func _ready() -> void:
    player = get_node(player_path) if player_path else get_tree().get_first_node_in_group("player")
    set_process(true)

func _process(delta: float) -> void:
    if player and player.has_method("get_health"):
        max_value = 200
        value = player.get_health()
        visible = true  # Always show healthbar
