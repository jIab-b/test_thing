class_name InputSetup
extends Node

static func ensure_actions() -> void:
    _ensure_action_with_keys("move_left", [KEY_A, KEY_LEFT])
    _ensure_action_with_keys("move_right", [KEY_D, KEY_RIGHT])
    _ensure_action_with_keys("move_up", [KEY_W, KEY_UP])
    _ensure_action_with_keys("move_down", [KEY_S, KEY_DOWN])
    _ensure_action_with_keys("dash", [KEY_SPACE, KEY_SHIFT])
    _ensure_action_mouse("attack", MOUSE_BUTTON_LEFT)
    _ensure_action_mouse("block", MOUSE_BUTTON_RIGHT)

static func _ensure_action_with_keys(name: String, keys: Array) -> void:
    if not InputMap.has_action(name):
        InputMap.add_action(name)
    for k in keys:
        var ev := InputEventKey.new()
        ev.keycode = k
        if not _action_has_event(name, ev):
            InputMap.action_add_event(name, ev)

static func _ensure_action_mouse(name: String, button: int) -> void:
    if not InputMap.has_action(name):
        InputMap.add_action(name)
    var ev := InputEventMouseButton.new()
    ev.button_index = button
    if not _action_has_event(name, ev):
        InputMap.action_add_event(name, ev)

static func _action_has_event(name: String, ev: InputEvent) -> bool:
    for e in InputMap.action_get_events(name):
        if e.as_text() == ev.as_text():
            return true
    return false

