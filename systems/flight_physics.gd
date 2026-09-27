extends RefCounted

# Simple energy-losing glide: steering redirects earned horizontal momentum.
# Diving trades altitude for speed; gliding never provides positive vertical thrust.
static func step(velocity: Vector3, desired: Vector3, diving: bool, delta: float) -> Vector3:
    var horizontal = Vector3(velocity.x,0,velocity.z)
    var speed = horizontal.length()
    var heading = horizontal.normalized() if speed > .1 else Vector3.FORWARD
    if desired.length_squared() > .01:
        var target = desired.normalized()
        var turn = heading.signed_angle_to(target,Vector3.UP)
        heading = heading.rotated(Vector3.UP,clampf(turn,-1.8*delta,1.8*delta))
    speed = clampf(speed + (7.0 if diving else -.22)*delta,0,44)
    var sink = -18.0 if diving else -2.2-maxf(0,12-speed)*.3
    var vertical = move_toward(velocity.y,sink,(27.5 if velocity.y > 0 else 9.0)*delta)
    return heading*speed+Vector3.UP*vertical
