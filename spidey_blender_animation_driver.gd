extends Node

# Blender owns the visible run cycle.
# player.gd still owns real movement, collision, swing physics and combat.

const RUN_ANIMATION_BASENAME: String = "Run_FromReference_01"
const RUN_REFERENCE_SPEED: float = 17.0
const RUN_START_SPEED: float = 0.9
const RUN_STOP_SPEED: float = 0.45
const MIN_PLAYBACK_SPEED: float = 0.72
const MAX_PLAYBACK_SPEED: float = 1.55
const SPEED_BLEND: float = 7.5

var animation_player: AnimationPlayer = null
var player: CharacterBody3D = null
var run_animation: StringName = &""
var run_active: bool = false


func setup(
    target_animation_player: AnimationPlayer,
    target_player: Node
) -> void:
    animation_player = target_animation_player
    player = target_player as CharacterBody3D
    process_priority = 110

    if animation_player == null or player == null:
        push_error(
            "[SPIDEY BLENDER] Missing AnimationPlayer or CharacterBody3D."
        )
        set_process(false)
        return

    run_animation = _resolve_run_animation()
    if run_animation == &"":
        push_error(
            "[SPIDEY BLENDER] Run animation not found. Available: "
            + str(animation_player.get_animation_list())
        )
        set_process(false)
        return

    var animation: Animation = animation_player.get_animation(run_animation)
    if animation != null:
        animation.loop_mode = Animation.LOOP_LINEAR

    animation_player.speed_scale = 1.0
    print("[SPIDEY BLENDER] Run animation ready: ", run_animation)


func _process(delta: float) -> void:
    if animation_player == null or player == null or run_animation == &"":
        return

    var horizontal_speed: float = Vector2(
        player.velocity.x,
        player.velocity.z
    ).length()

    var traversal_busy: bool = (
        bool(player.get("grappling"))
        or bool(player.get("wall_riding"))
        or float(player.get("zip_pose_time")) > 0.0
    )

    var speed_threshold: float = (
        RUN_STOP_SPEED if run_active else RUN_START_SPEED
    )
    var should_run: bool = (
        player.is_on_floor()
        and not traversal_busy
        and horizontal_speed > speed_threshold
    )

    if should_run:
        var target_speed_scale: float = clampf(
            horizontal_speed / RUN_REFERENCE_SPEED,
            MIN_PLAYBACK_SPEED,
            MAX_PLAYBACK_SPEED
        )
        animation_player.speed_scale = move_toward(
            animation_player.speed_scale,
            target_speed_scale,
            SPEED_BLEND * delta
        )

        if animation_player.current_animation != run_animation:
            animation_player.play(run_animation, 0.10)
        elif not animation_player.is_playing():
            # Resume from the pose where the previous run was paused.
            animation_player.play()

        run_active = true
        return

    if run_active and animation_player.is_playing():
        # Until we author separate Blender idle/jump/swing clips, keep the
        # last authored pose instead of snapping to the rest/T-pose.
        animation_player.pause()

    run_active = false


func _resolve_run_animation() -> StringName:
    if animation_player == null:
        return &""

    var animation_names: PackedStringArray = (
        animation_player.get_animation_list()
    )

    # Prefer the exact Blender Action name.
    for clip_name: String in animation_names:
        if clip_name == RUN_ANIMATION_BASENAME:
            return StringName(clip_name)

    # Godot/glTF may prefix a clip with a library/object name.
    for clip_name: String in animation_names:
        if clip_name.to_lower().contains(
            RUN_ANIMATION_BASENAME.to_lower()
        ):
            return StringName(clip_name)

    # Last-resort fallback if the importer shortened the Action name.
    for clip_name: String in animation_names:
        var lowered: String = clip_name.to_lower()
        if lowered.contains("run") and lowered != "reset":
            return StringName(clip_name)

    return &""
