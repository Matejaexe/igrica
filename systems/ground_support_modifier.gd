extends SkeletonModifier3D

# Presentation only: AnimationTree -> ground support -> swing arm IK -> skinning.
# Ground rays run on the physics tick; the modifier never queries a locked space.
# Slow grounded poses only. Running feet, wall traversal and airborne clips keep
# their authored trajectories. No physics body, bone rest or bind changes.
const SUPPORT_STATES = ["Idle", "Punch", "PunchLeft", "Finisher"]
const MAX_CORRECTION = .22
var player: CharacterBody3D
var driver: Node
var support_weight = 0.0
var pelvis_drop = 0.0
var contacts: Array[Dictionary] = [{}, {}]
var previous_body_position = Vector3.INF
var last_ankles: Array[Vector3] = []
var last_soles: Array[Vector3] = []

func _ready():
    process_physics_priority = 120

func supports_current_pose() -> bool:
    return is_instance_valid(player) and is_instance_valid(driver) and player.is_on_floor() \
        and driver.current_state in SUPPORT_STATES and not player.grappling \
        and not player.wall_riding and not player.wall_climbing and player.dodge_time <= 0 \
        and player.zip_pose_time <= 0 and player.velocity.y <= .5 \
        and Vector2(player.velocity.x,player.velocity.z).length() < 1.6

func _can_fade_on_ground() -> bool:
    return is_instance_valid(player) and player.is_on_floor() and not player.grappling \
        and not player.wall_riding and not player.wall_climbing and player.zip_pose_time <= 0 \
        and player.dodge_time <= 0 and player.velocity.y <= .5

func _apply_pelvis_drop(skeleton: Skeleton3D):
    var hips = skeleton.find_bone("Hips")
    var parent = skeleton.get_bone_parent(hips)
    var parent_basis = skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
    var local_offset = parent_basis.inverse() * (skeleton.global_basis.inverse() * Vector3.UP*pelvis_drop*support_weight)
    skeleton.set_bone_pose_position(hips,skeleton.get_bone_pose_position(hips)+local_offset)

func _fade_support(skeleton: Skeleton3D, delta: float):
    contacts = [{}, {}]
    last_ankles.clear()
    last_soles.clear()
    if not _can_fade_on_ground():
        reset_support()
        return
    # Release leg IK immediately, but fade the small vertical presentation offset
    # through ground-to-ground transitions so starting to run does not pop upward.
    support_weight = move_toward(support_weight,0.0,delta*12.0)
    _apply_pelvis_drop(skeleton)
    if support_weight <= 0.0: reset_support()

func reset_support():
    contacts = [{}, {}]
    support_weight = 0.0
    pelvis_drop = 0.0
    last_ankles.clear()
    last_soles.clear()
    previous_body_position = Vector3.INF

func _physics_process(_delta):
    var skeleton = get_skeleton()
    if skeleton == null: return
    if not supports_current_pose():
        contacts = [{}, {}]
        if not _can_fade_on_ground(): reset_support()
        return
    if previous_body_position.is_finite() and player.global_position.distance_to(previous_body_position) > .8:
        reset_support()
    previous_body_position = player.global_position
    for i in 2:
        var foot = skeleton.find_bone(["LeftFoot", "RightFoot"][i])
        if foot < 0: continue
        var ankle = skeleton.to_global(skeleton.get_bone_global_pose(foot).origin)
        var query = PhysicsRayQueryParameters3D.create(ankle+Vector3.UP*.45,ankle-Vector3.UP*.7,1,[player.get_rid()])
        var hit = player.get_world_3d().direct_space_state.intersect_ray(query)
        contacts[i] = hit if not hit.is_empty() and hit.normal.dot(Vector3.UP) > .7 else {}

func _process_modification_with_delta(delta: float):
    var skeleton = get_skeleton()
    if skeleton == null: return
    if not supports_current_pose():
        _fade_support(skeleton,delta)
        return
    var valid = not contacts[0].is_empty() or not contacts[1].is_empty()
    if not valid:
        _fade_support(skeleton,delta)
        return
    support_weight = move_toward(support_weight,1.0,delta*12.0)
    var targets: Array[Vector3] = []
    var drop = 0.0
    for i in 2:
        var foot = skeleton.find_bone(["LeftFoot","RightFoot"][i])
        var ankle = skeleton.to_global(skeleton.get_bone_global_pose(foot).origin)
        # Mesh soles are at source z=0; ankle height was measured in Blender.
        var sole_height = skeleton.get_bone_global_rest(foot).origin.y * skeleton.global_basis.get_scale().y
        var target = ankle
        if not contacts[i].is_empty():
            target.y = contacts[i].position.y + sole_height / contacts[i].normal.y
            if absf(target.y-ankle.y) > MAX_CORRECTION:
                contacts[i] = {} # A ledge cannot stretch the leg toward a distant floor.
                target = ankle
            else:
                drop = minf(drop,target.y-ankle.y)
        targets.append(target)
    pelvis_drop = move_toward(pelvis_drop,drop,delta*1.5)
    _apply_pelvis_drop(skeleton)
    last_ankles.clear()
    last_soles.clear()
    for i in 2:
        var side = ["Left","Right"][i]
        var foot = skeleton.find_bone(side+"Foot")
        if not contacts[i].is_empty():
            _solve_leg(skeleton,side,skeleton.to_local(targets[i]),support_weight)
            var pose = skeleton.get_bone_global_pose(foot)
            var rest_up = skeleton.get_bone_global_rest(foot).basis.inverse()*Vector3.UP
            var current_up = (pose.basis*rest_up).normalized()
            var normal = (skeleton.global_basis.inverse()*contacts[i].normal).normalized()
            var desired = Quaternion(current_up,normal)*pose.basis.get_rotation_quaternion()
            var parent_rotation = skeleton.get_bone_global_pose(skeleton.get_bone_parent(foot)).basis.get_rotation_quaternion()
            skeleton.set_bone_pose_rotation(foot,skeleton.get_bone_pose_rotation(foot).slerp(parent_rotation.inverse()*desired,support_weight).normalized())
        var final_ankle = skeleton.to_global(skeleton.get_bone_global_pose(foot).origin)
        last_ankles.append(final_ankle)
        var height = skeleton.get_bone_global_rest(foot).origin.y*skeleton.global_basis.get_scale().y
        var normal = contacts[i].normal if not contacts[i].is_empty() else Vector3.UP
        last_soles.append(final_ankle-normal*height)

func _solve_leg(s: Skeleton3D, side: String, target: Vector3, weight: float):
    var upper = s.find_bone(side+"UpLeg")
    var lower = s.find_bone(side+"Leg")
    var foot = s.find_bone(side+"Foot")
    var hip = s.get_bone_global_pose(upper).origin
    var knee = s.get_bone_global_pose(lower).origin
    var ankle = s.get_bone_global_pose(foot).origin
    var a = hip.distance_to(knee)
    var b = knee.distance_to(ankle)
    var direction = (target-hip).normalized()
    var distance = clampf(hip.distance_to(target),absf(a-b)+.001,a+b-.001)
    var pole = (knee-hip).slide(direction)
    if pole.length_squared() < .00001: pole = Vector3.FORWARD.slide(direction)
    if pole.length_squared() < .00001: pole = Vector3.RIGHT.slide(direction)
    var along = (a*a-b*b+distance*distance)/(2*distance)
    var bend = sqrt(maxf(0,a*a-along*along))
    _aim(s,upper,lower,hip+direction*along+pole.normalized()*bend,weight)
    _aim(s,lower,foot,hip+direction*distance,weight)

func _aim(s: Skeleton3D, bone: int, child: int, target: Vector3, weight: float):
    var pose = s.get_bone_global_pose(bone)
    var before = (s.get_bone_global_pose(child).origin-pose.origin).normalized()
    var after = (target-pose.origin).normalized()
    var desired = Quaternion(before,after)*pose.basis.get_rotation_quaternion()
    var parent_rotation = s.get_bone_global_pose(s.get_bone_parent(bone)).basis.get_rotation_quaternion()
    s.set_bone_pose_rotation(bone,s.get_bone_pose_rotation(bone).slerp(parent_rotation.inverse()*desired,weight).normalized())
