extends Node

# AnimationPlayer owns every bone. Gameplay owns physics and visual-root lean.
# Portable GLB preserves the source run and adds original traversal state clips.
const RUN_ANIMATION_BASENAME = "RunFlow"
var animation_player: AnimationPlayer
var player: CharacterBody3D
var skeleton: Skeleton3D
var current_state = ""
var run_active = false
var seen_attack_sequence = 0
var clips: Dictionary = {}
var swing_modifier: SkeletonModifier3D
var trick_pivot: Node3D
var ground_pose = ""
var ground_pose_time = 0.0
var previous_speed = 0.0
var seen_landing_sequence = 0
const EXTRA_STATES = ["DodgeLeft", "DodgeRight", "PunchLeft", "Finisher","Vault","StartRun", "StopRun", "LandRun", "HardLand", "WallJumpLeft", "WallJumpRight", "AirJumpLeft", "AirJumpRight"]

func reset_transition_state():
    ground_pose = ""
    ground_pose_time = 0.0
    previous_speed = 0.0
    seen_landing_sequence = player.landing_sequence if player != null else 0

func _update_ground_transition(delta: float, speed: float, grounded: bool, wants_move: bool):
    ground_pose_time = maxf(0.0, ground_pose_time-delta)
    if (ground_pose == "StopRun" and wants_move) or (ground_pose == "StartRun" and not wants_move):
        ground_pose_time = 0.0
        ground_pose = ""
    if not grounded:
        ground_pose_time = 0.0
        ground_pose = ""
    elif player.landing_sequence != seen_landing_sequence:
        ground_pose = "LandRun" if player.landing_travel_speed > 5.0 else ("HardLand" if player.landing_impact_speed > 24.0 else "Land")
        ground_pose_time = .26 if ground_pose == "LandRun" else (.48 if ground_pose == "HardLand" else .30)
    elif ground_pose_time <= 0.0:
        ground_pose = ""
        if wants_move and previous_speed < 1.0 and speed > 1.0:
            ground_pose = "StartRun"
            ground_pose_time = .24
        elif not wants_move and previous_speed > 8.0 and speed < previous_speed-.15 and current_state != "StopRun":
            ground_pose = "StopRun"
            ground_pose_time = .28
    seen_landing_sequence = player.landing_sequence
    previous_speed = speed

func setup(target_animation_player: AnimationPlayer, target_player: Node, target_skeleton: Skeleton3D = null) -> void:
    animation_player = target_animation_player
    player = target_player as CharacterBody3D
    skeleton = target_skeleton
    process_priority = 110
    if animation_player == null or player == null:
        set_process(false)
        return
    for state in ["Idle", "Walk", "Run", "Jump", "Fall", "Land", "SwingLeft", "SwingRight", "Zip", "WallRun", "SwingTuckLeft", "SwingTuckRight", "Release", "Dive", "Punch", "WallClimb", "Glide"] + EXTRA_STATES:
        var wanted = RUN_ANIMATION_BASENAME if state == "Run" else state
        for clip in animation_player.get_animation_list():
            if clip == wanted or clip.ends_with("/" + wanted):
                clips[state] = clip
                var animation = animation_player.get_animation(clip)
                animation.loop_mode = Animation.LOOP_NONE if state in ["Jump", "Land", "Zip", "Release", "Punch"] + EXTRA_STATES else Animation.LOOP_LINEAR
                break
        if not clips.has(state):
            push_error("Missing traversal animation: " + state)
    if skeleton != null:
        swing_modifier = preload("res://systems/swing_pose_modifier.gd").new()
        swing_modifier.player = player
        skeleton.add_child(swing_modifier)
    trick_pivot = get_parent().get_node_or_null("BlenderTraversalPivot")
    _play_state("Idle", 1.0)

func _process(delta: float) -> void:
    if player == null or animation_player == null:
        return
    var speed = Vector2(player.velocity.x, player.velocity.z).length()
    _update_ground_transition(delta,speed,player.is_on_floor(),player._get_camera_relative_input().length() > .05)
    var state = "Idle"
    var rate = 1.0
    if player.dodge_time > 0:
        state = "Dodge"+player.dodge_side
    elif float(player.get("attack_pose_time")) > 0:
        state = "Finisher" if player.combo_step == 3 else ("PunchLeft" if player.combo_step == 2 else "Punch")
        if seen_attack_sequence != player.attack_sequence:
            animation_player.stop(true)
            current_state = ""
            seen_attack_sequence = player.attack_sequence
    elif player.get("grappling"):
        var tuck = player.velocity.y > 3.0 or (absf(player.velocity.y) < 4 and speed > 22)
        state = ("SwingTuck" if tuck else "Swing") + str(player.get("swing_hand"))
    elif float(player.get("zip_pose_time")) > 0.0:
        state = "Zip"
    elif player.gliding:
        state = "Glide"
    elif not player.is_on_floor() and not player.wall_riding and not player.wall_climbing and player.vault_pose_time > 0:
        state = "Vault"
    elif player.get("wall_climbing"):
        state = "WallClimb"
    elif player.get("wall_riding"):
        state = "WallRun"
        rate = clampf(speed / 17.0, 0.75, 1.6)
    elif not player.is_on_floor() and player.wall_jump_pose_time > 0:
        state = "WallJumpLeft" if player.wall_ride_normal.dot(player.visual_root.global_basis.x) > 0 else "WallJumpRight"
    elif not player.is_on_floor() and player.double_jump_pose_time > 0:
        state = "AirJumpLeft" if player.double_jump_sequence % 2 == 0 else "AirJumpRight"
    elif float(player.get("swing_release_pose_time")) > 0:
        state = "Release"
    elif not player.is_on_floor():
        state = "Dive" if player.velocity.y < -15.0 else ("Jump" if player.velocity.y > 0.5 else "Fall")
    elif ground_pose_time > 0.0:
        state = ground_pose
    elif speed > (0.45 if run_active else 0.9):
        # Hysteresis prevents clip flapping near the walk/run boundary.
        state = "Walk" if speed < (4.5 if current_state == "Run" else 5.5) else "Run"
        rate = clampf(speed / (4.0 if state == "Walk" else 17.0), 0.5, 1.6)
    run_active = state == "Run"
    _play_state(state, rate, delta)
    if trick_pivot != null:
        var remaining: float = player.release_trick_time
        if remaining > 0:
            var progress = 1.0-remaining/player.release_trick_duration
            # One complete barrel roll on its own presentation pivot. The
            # collision body and camera remain upright; all actions interrupt.
            trick_pivot.rotation.z = smoothstep(0.0,1.0,progress)*TAU*player.release_trick_sign
        else:
            trick_pivot.rotation.z = lerp_angle(trick_pivot.rotation.z,0.0,1.0-exp(-18.0*delta))

func _play_state(state: String, rate: float, delta: float = 1.0) -> void:
    if not clips.has(state):
        return
    if state != current_state:
        var locomotion_transition = current_state in ["Walk", "Run"] and state in ["Walk", "Run"]
        var phase = 0.0
        if locomotion_transition and animation_player.current_animation_length > 0:
            phase = fposmod(animation_player.current_animation_position / animation_player.current_animation_length, 1.0)
        var blend = .20 if state in ["Idle", "Walk", "Run"] else .12
        if state in ["Land", "LandRun", "HardLand"]:
            blend = .07
        animation_player.play(clips[state], blend)
        if locomotion_transition:
            animation_player.seek(phase * animation_player.get_animation(clips[state]).length, false)
        current_state = state
    animation_player.speed_scale = move_toward(animation_player.speed_scale, rate, 7.5 * delta)

func get_web_origin() -> Vector3:
    if is_instance_valid(swing_modifier) and swing_modifier.hand_valid:
        return swing_modifier.final_hand
    if skeleton != null:
        var index = skeleton.find_bone(str(player.get("swing_hand")) + "Hand")
        if index >= 0:
            return skeleton.global_transform * skeleton.get_bone_global_pose(index).origin
    return player.global_position + Vector3.UP * 0.72
