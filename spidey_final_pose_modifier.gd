extends SkeletonModifier3D

# Final stage of the main-game BRC traversal pipeline. Keeping this as a real
# SkeletonModifier3D guarantees it runs after the native TwoBoneIK3D children
# and while Godot's transient modified pose is still the pose sent to the skin.

var pose_controller: Node = null


func setup(controller: Node) -> void:
	pose_controller = controller


func _process_modification_with_delta(_delta: float) -> void:
	if pose_controller != null:
		pose_controller.call("apply_final_skeleton_pose")
