extends Control

signal completed(rating)

var points: Array[Vector2] = []
var stroke: PackedVector2Array = PackedVector2Array()
var drawing := false
var reached_index := 0
var mistakes := 0
var ideal_length := 1.0
var drawn_length := 0.0

func configure(pattern_index: int) -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    focus_mode = Control.FOCUS_ALL
    points = _pattern(pattern_index)
    stroke = PackedVector2Array()
    drawing = false
    reached_index = 0
    mistakes = 0
    drawn_length = 0.0
    ideal_length = 0.0
    for i in range(1, points.size()):
        ideal_length += points[i - 1].distance_to(points[i])
    queue_redraw()

func _pattern(index: int) -> Array[Vector2]:
    var w: float = maxf(size.x, 760.0)
    var h: float = maxf(size.y, 420.0)
    var patterns = [
        [
            Vector2(0.12,0.72), Vector2(0.24,0.28), Vector2(0.36,0.66),
            Vector2(0.48,0.24), Vector2(0.60,0.70), Vector2(0.72,0.34),
            Vector2(0.86,0.58)
        ],
        [
            Vector2(0.12,0.54), Vector2(0.26,0.24), Vector2(0.40,0.72),
            Vector2(0.52,0.30), Vector2(0.66,0.68), Vector2(0.84,0.28)
        ],
        [
            Vector2(0.15,0.30), Vector2(0.28,0.70), Vector2(0.42,0.34),
            Vector2(0.56,0.72), Vector2(0.70,0.28), Vector2(0.86,0.58)
        ]
    ]
    var normalized: Array = patterns[index % patterns.size()]
    var result: Array[Vector2] = []
    for p in normalized:
        result.append(Vector2(p.x * w, p.y * h))
    return result

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        drawing = event.pressed
        if event.pressed:
            stroke = PackedVector2Array()
            reached_index = 0
            drawn_length = 0.0
            _try_reach(event.position)
        else:
            if reached_index < points.size():
                mistakes += 1
        queue_redraw()
        accept_event()
        return

    if event is InputEventMouseMotion and drawing:
        if stroke.size() > 0:
            drawn_length += stroke[stroke.size() - 1].distance_to(event.position)
        stroke.append(event.position)
        _try_reach(event.position)
        queue_redraw()
        accept_event()

func _try_reach(mouse_pos: Vector2) -> void:
    if reached_index >= points.size():
        return
    if mouse_pos.distance_to(points[reached_index]) <= 34.0:
        reached_index += 1
        if reached_index >= points.size():
            drawing = false
            var ratio: float = drawn_length / maxf(ideal_length, 1.0)
            var rating := "MESSY"
            if mistakes == 0 and ratio <= 1.35:
                rating = "PERFECT"
            elif mistakes <= 1 and ratio <= 1.75:
                rating = "CLEAN"
            completed.emit(rating)

func _draw() -> void:
    var panel := Rect2(Vector2.ZERO, size)
    draw_rect(panel, Color(0.025, 0.03, 0.055, 0.97), true)
    draw_rect(panel.grow(-6), Color("#4fd9c8"), false, 3.0)

    if stroke.size() > 1:
        draw_polyline(stroke, Color("#ff4f9a"), 11.0, true)
        draw_polyline(stroke, Color("#fff2bb"), 3.0, true)

    for i in range(points.size()):
        var reached := i < reached_index
        var active := i == reached_index
        var radius := 22.0 if active else 16.0
        var color := Color("#45f0d0") if reached else (Color("#ffd34e") if active else Color("#556078"))
        draw_circle(points[i], radius, color)
        draw_circle(points[i], radius - 6.0, Color("#10131d"))
        draw_string(
            ThemeDB.fallback_font,
            points[i] + Vector2(-6, 7),
            str(i + 1),
            HORIZONTAL_ALIGNMENT_LEFT,
            -1,
            18,
            color
        )
