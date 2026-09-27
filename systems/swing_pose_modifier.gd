extends SkeletonModifier3D

# Last bone writer, after AnimationPlayer. Only the selected arm is corrected;
# body/legs retain the authored state clip. No rest/bind changes.
var player: CharacterBody3D
var final_hand = Vector3.ZERO
var hand_valid = false
var reach_weight = 0.0

func _process_modification_with_delta(delta: float) -> void:
    var skeleton = get_skeleton()
    if skeleton == null or not is_instance_valid(player):
        return
    reach_weight = move_toward(reach_weight,1.0 if player.grappling else 0.0,delta*9.0)
    var side = player.swing_hand
    var upper = skeleton.find_bone(side+"Arm")
    var lower = skeleton.find_bone(side+"ForeArm")
    var hand = skeleton.find_bone(side+"Hand")
    if upper < 0 or lower < 0 or hand < 0:
        return
    if reach_weight > 0.001:
        var shoulder_pose = skeleton.get_bone_global_pose(upper)
        var elbow_pose = skeleton.get_bone_global_pose(lower)
        var wrist_pose = skeleton.get_bone_global_pose(hand)
        var shoulder = shoulder_pose.origin
        var l1 = shoulder.distance_to(elbow_pose.origin)
        var l2 = elbow_pose.origin.distance_to(wrist_pose.origin)
        var anchor = skeleton.to_local(player.grapple_point)
        var direction = (anchor-shoulder).normalized()
        var distance = (l1+l2)*.94
        var target = shoulder+direction*distance
        var pole = (elbow_pose.origin-shoulder).slide(direction)
        if pole.length_squared() < .0001:
            pole = Vector3.RIGHT.slide(direction)
        if pole.length_squared() < .0001:
            pole = Vector3.FORWARD.slide(direction)
        var along = (l1*l1-l2*l2+distance*distance)/(2*distance)
        var outward = sqrt(maxf(0,l1*l1-along*along))
        var elbow_target = shoulder+direction*along+pole.normalized()*outward
        _aim_bone(skeleton,upper,lower,elbow_target,reach_weight)
        _aim_bone(skeleton,lower,hand,target,reach_weight)
    final_hand = skeleton.global_transform * skeleton.get_bone_global_pose(hand).origin
    hand_valid = true

func _aim_bone(skeleton: Skeleton3D, bone: int, child: int, target: Vector3, weight: float):
    var pose = skeleton.get_bone_global_pose(bone)
    var from_direction = (skeleton.get_bone_global_pose(child).origin-pose.origin).normalized()
    var to_direction = (target-pose.origin).normalized()
    if from_direction.length_squared() < .5 or to_direction.length_squared() < .5:
        return
    var delta_rotation = Quaternion(from_direction,to_direction)
    var target_global = delta_rotation * pose.basis.get_rotation_quaternion()
    var parent = skeleton.get_bone_parent(bone)
    var parent_rotation = skeleton.get_bone_global_pose(parent).basis.get_rotation_quaternion() if parent >= 0 else Quaternion.IDENTITY
    var local_rotation = parent_rotation.inverse()*target_global
    skeleton.set_bone_pose_rotation(bone,skeleton.get_bone_pose_rotation(bone).slerp(local_rotation,weight).normalized())
