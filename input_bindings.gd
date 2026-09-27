extends RefCounted

# Mouse-web preset follows the current brief; F2 restores the original layout.
static var mouse_web = true

static func setup():
    var keys = {"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D, "jump": KEY_SPACE, "grapple": KEY_SHIFT, "zip": KEY_Q, "restart": KEY_R, "attack": KEY_J, "special_attack": KEY_K, "glide": KEY_E, "dive": KEY_CTRL, "skyline_challenge": KEY_H, "patrol": KEY_C, "dodge": KEY_ALT}
    for action in keys:
        if not InputMap.has_action(action):
            InputMap.add_action(action)
        var event = InputEventKey.new()
        event.physical_keycode = keys[action]
        if not InputMap.action_has_event(action, event):
            InputMap.action_add_event(action, event)
    apply_mouse_preset()

static func apply_mouse_preset():
    for action in ["grapple", "zip", "attack", "special_attack"]:
        for event in InputMap.action_get_events(action):
            if event is InputEventMouseButton:
                InputMap.action_erase_event(action, event)
    for index in 2:
        var action = (["grapple", "zip"] if mouse_web else ["attack", "special_attack"])[index]
        var event = InputEventMouseButton.new()
        event.button_index = MOUSE_BUTTON_LEFT if index == 0 else MOUSE_BUTTON_RIGHT
        InputMap.action_add_event(action, event)

static func hint() -> String:
    return "LMB web / RMB zip / J,K combat" if mouse_web else "Shift web / Q zip / LMB,RMB combat"
