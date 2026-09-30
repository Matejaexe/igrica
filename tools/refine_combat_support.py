"""One-time targeted combat support pass on the existing editable Blender rig.
Run with Blender --background --factory-startup --python-exit-code 1 --python tools/refine_combat_support.py.
Keeps other actions, mesh, rests and names; backs up before saving. Normal subsequent exports use export_character_animations.py.
"""
import bpy
import math
import shutil
import time
from pathlib import Path
from mathutils import Vector, Quaternion
ROOT = Path(__file__).resolve().parents[1]
working = ROOT/'assets/characters/spidey/blender/spidey_animation_working.blend'
bpy.ops.wm.open_mainfile(filepath=str(working))
rig = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
if rig.get('combat_support_pass', 0) >= 1:
    raise RuntimeError('Support pass already applied. Edit the working actions; do not stack this migration.')
backup = ROOT.parent/'backups'/('spidey-before-support-%d.blend' % time.time_ns())
backup.parent.mkdir(exist_ok=True)
shutil.copy2(working, backup)
scene = bpy.context.scene
original_action = rig.animation_data.action
original_slot = rig.animation_data.action_slot
# Keep even unassigned reference actions when Blender purges unused data.
for action in bpy.data.actions: action.use_fake_user = True

def update(): bpy.context.view_layer.update()
def aim(bone_name, child_name, target):
    bone = rig.pose.bones[bone_name]
    direction = rig.pose.bones[child_name].head-bone.head
    rotation = direction.rotation_difference(target-bone.head)
    matrix = (rotation @ bone.matrix.to_quaternion()).to_matrix().to_4x4()
    matrix.translation = bone.head.copy()
    bone.matrix = matrix
    update()

def solve_leg(side, target):
    hip, knee, ankle = [rig.pose.bones[side+n].head.copy() for n in ('UpLeg','Leg','Foot')]
    a, b = (knee-hip).length, (ankle-knee).length
    direction = (target-hip).normalized()
    distance = min((target-hip).length, a+b-.0001)
    pole = knee-hip-direction*(knee-hip).dot(direction)
    if pole.length < .0001: pole = Vector((0,-1,0))
    along = (a*a-b*b+distance*distance)/(2*distance)
    joint = hip+direction*along+pole.normalized()*math.sqrt(max(0,a*a-along*along))
    aim(side+'UpLeg',side+'Leg',joint)
    aim(side+'Leg',side+'Foot',target)
    foot = rig.pose.bones[side+'Foot']
    matrix = foot.bone.matrix_local.copy()
    matrix.translation = foot.head.copy()
    foot.matrix = matrix
    update()

for name in ('Punch','PunchLeft','Finisher'):
    action = bpy.data.actions[name]
    rig.animation_data.action = action
    scene.frame_set(0)
    update()
    targets = {}
    for side, sign in (('Left',1),('Right',-1)):
        target = rig.pose.bones[side+'Foot'].head.copy()
        target.x += sign*.035
        target.z = rig.data.bones[side+'Foot'].head_local.z
        targets[side] = target
    original_hips = rig.pose.bones['Hips'].head.copy()
    frames = int(action.frame_range[1])
    peak_error = 0.0
    for frame in range(frames+1):
        scene.frame_set(frame)
        t = frame/frames
        # Load the stance in anticipation, push up into contact, settle on recovery.
        keys = [(0,.045),(.2,.085),(.4,.035),(.58,.045),(1,.045)]
        depth = .045
        for (ta,va),(tb,vb) in zip(keys,keys[1:]):
            if ta <= t <= tb:
                u = (t-ta)/(tb-ta); u = u*u*(3-2*u)
                depth = va+(vb-va)*u
                break
        hips = rig.pose.bones['Hips']
        matrix = hips.matrix.copy()
        matrix.translation = original_hips-Vector((0,0,depth*(1.3 if name=='Finisher' else 1)))
        hips.matrix = matrix
        update()
        for side in targets:
            solve_leg(side,targets[side])
            peak_error = max(peak_error,(rig.pose.bones[side+'Foot'].head-targets[side]).length)
        for bone_name in ('Hips','LeftUpLeg','LeftLeg','LeftFoot','RightUpLeg','RightLeg','RightFoot'):
            bone = rig.pose.bones[bone_name]
            bone.keyframe_insert('location',frame=frame,group=bone_name)
            bone.keyframe_insert('rotation_quaternion',frame=frame,group=bone_name)
    assert peak_error < .002, (name, peak_error)
    print('COMBAT_SUPPORT',name,'max ankle drift',peak_error)
rig['combat_support_pass'] = 1
rig.animation_data.action = original_action
rig.animation_data.action_slot = original_slot
scene.frame_set(0)
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(working))
print('COMBAT_SUPPORT_SAVED; backup:',backup)
