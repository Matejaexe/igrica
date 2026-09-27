extends Control
var player: CharacterBody3D
func _ready():
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func _process(_delta):
    visible = is_instance_valid(player) and player.active and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
    if visible:
        queue_redraw()
func _draw():
    if not is_instance_valid(player):
        return
    var available = not player.grapple_preview.is_empty()
    var center = get_viewport_rect().size*.5
    var color = Color("64ead1") if available else Color(1,1,1,.35)
    draw_arc(center,9,0,TAU,24,color,1.5,true)
    if available:
        var point: Vector3 = player.grapple_preview.position
        if not player.camera.is_position_behind(point):
            var screen = player.camera.unproject_position(point)
            if get_viewport_rect().grow(-20).has_point(screen):
                draw_polyline(PackedVector2Array([screen+Vector2(0,-5),screen+Vector2(5,0),screen+Vector2(0,5),screen+Vector2(-5,0),screen+Vector2(0,-5)]),color,1.5,true)
