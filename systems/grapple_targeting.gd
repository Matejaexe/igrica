extends RefCounted

# A small camera-space fan searches only real collidable surfaces. Each result
# is rechecked from the player's chest so aim assistance cannot shoot through a wall.
const OFFSETS = [Vector2.ZERO, Vector2(0,.20), Vector2(-.18,.20), Vector2(.18,.20), Vector2(0,.43), Vector2(-.35,.38), Vector2(.35,.38), Vector2(-.58,.60), Vector2(.58,.60), Vector2(0,.75), Vector2(-.25,.75), Vector2(.25,.75)]

static func find_anchor(player: CharacterBody3D, zip_mode: bool) -> Dictionary:
    var camera: Camera3D = player.camera
    if camera == null:
        return {}
    var space = player.get_world_3d().direct_space_state
    var origin = player.global_position + Vector3.UP * .72
    var forward = -camera.global_basis.z
    var right = camera.global_basis.x
    var up = camera.global_basis.y
    var velocity_direction = player.velocity.normalized()
    var best: Dictionary = {}
    var best_score = -INF
    for offset in OFFSETS:
        var direction = (forward + right * offset.x + up * offset.y).normalized()
        var query = PhysicsRayQueryParameters3D.create(camera.global_position,camera.global_position+direction*player.GRAPPLE_RANGE,1,[player.get_rid()])
        var hit = space.intersect_ray(query)
        if hit.is_empty():
            continue
        var point: Vector3 = hit.position
        var distance = origin.distance_to(point)
        if distance < 3.0 or distance > player.GRAPPLE_RANGE:
            continue
        if not zip_mode and (point.y < origin.y + 1.5 or (hit.normal.y > .75 and point.y < origin.y + 5)):
            continue
        var clearance = PhysicsRayQueryParameters3D.create(origin,point,1,[player.get_rid()])
        var obstruction = space.intersect_ray(clearance)
        if not obstruction.is_empty() and obstruction.position.distance_to(point) > .3:
            continue
        if zip_mode and offset == Vector2.ZERO:
            return hit
        var to_point = (point-origin).normalized()
        var score = direction.dot(forward)*4 + to_point.dot(velocity_direction)*.65 + clampf((point.y-origin.y)/40,0,1)*.6 - distance*.003
        if score > best_score:
            best_score = score
            best = hit
    return best
