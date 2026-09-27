"""Run with Blender --background --factory-startup --python tools/build_traversal_clips.py.
Derives a portable GLB from the unchanged authored Blender source; adds prototype
traversal clips in the animation layer only. Does not write the source .blend.
"""
import bpy
import math
from pathlib import Path
from mathutils import Quaternion, Vector

ROOT = Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(ROOT / 'assets/characters/spidey/blender/spidey_run_from_reference_v1.blend'))
rig = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
scene = bpy.context.scene
scene.render.fps = 30
original_action = rig.animation_data.action
original_slot = rig.animation_data.action_slot

def pose(name, degrees, axis=(1, 0, 0)):
    bone = rig.pose.bones[name]
    basis = bone.bone.matrix_local.to_quaternion()
    bone.rotation_mode = 'QUATERNION'
    bone.rotation_quaternion = basis.inverted() @ Quaternion(Vector(axis), math.radians(degrees)) @ basis

def running_arm(side, sign, swing, elbow):
    # Bend around the anatomical elbow plane after relaxing the shoulder.
    lateral = Quaternion(Vector((0,1,0)), math.radians(sign*35))
    drive = Quaternion(Vector((1,0,0)), math.radians(swing))
    bend = Quaternion(Vector((1,0,0)), math.radians(elbow))
    for name, rotation in [(side+'Arm', drive @ lateral),
                           (side+'ForeArm', lateral.inverted() @ bend @ lateral)]:
        bone = rig.pose.bones[name]
        basis = bone.bone.matrix_local.to_quaternion()
        bone.rotation_quaternion = basis.inverted() @ rotation @ basis

def frame_pose(kind, t):
    for b in rig.pose.bones:
        b.matrix_basis.identity()
    pulse = math.sin(t * math.tau)
    # Compact resting arms, using model-space axes transformed to bone space.
    for side, sign in [('Left', 1), ('Right', -1)]:
        pose(side + 'Arm', sign * 35, (0, 1, 0))
        pose(side + 'ForeArm', -15)
        if kind == 'Idle':
            pose('Spine1', 1.2 * pulse)
        elif kind in ('Jump', 'Fall', 'Land'):
            bend = {'Jump': 18 + 28 * math.sin(math.pi * t), 'Fall': 16 + pulse * 3, 'Land': 48 * math.sin(math.pi * t)}[kind]
            pose(side + 'UpLeg', -bend)
            pose(side + 'Leg', bend * 1.7)
            pose(side + 'Arm', sign * (8 if kind == 'Fall' else 20), (0, 1, 0))
            pose(side + 'ForeArm', -35)
            pose('Spine1', 18 * math.sin(math.pi * t) if kind == 'Land' else -5)
        elif kind.startswith('Swing') or kind == 'Zip':
            active = kind == 'Zip' or side in kind
            pose(side + 'Arm', -sign * 135 if active else sign * 30, (0, 1, 0))
            pose(side + 'ForeArm', -12 if active else -55)
            pose(side + 'UpLeg', (-55 if 'Tuck' in kind else -18) + sign * (10 + pulse * 6))
            pose(side + 'Leg', (90 if 'Tuck' in kind else 35) + sign * 12)
        elif kind in ('Release', 'Dive', 'Punch'):
            pose('Spine1', 18 if kind == 'Dive' else -8)
            pose(side + 'UpLeg', -20 + sign * 12)
            pose(side + 'Leg', 45 + sign * 15)
            if kind == 'Punch':
                pose(side + 'Arm', -75 * math.sin(math.pi * t) if side == 'Right' else -15)
                pose(side + 'ForeArm', -15 if side == 'Right' else -70)
            else:
                pose(side + 'Arm', sign * (10 if kind == 'Release' else 38), (0, 1, 0))
                pose(side + 'ForeArm', -55 if kind == 'Release' else -10)
        elif kind == 'WallClimb':
            stride = pulse * sign
            pose(side + 'Arm', -sign * (95 + 30 * stride), (0, 1, 0))
            pose(side + 'ForeArm', -45)
            pose(side + 'UpLeg', -40 - stride * 25)
            pose(side + 'Leg', 75 + stride * 20)
        elif kind in ('StartRun', 'StopRun', 'LandRun', 'HardLand'):
            compression = math.sin(math.pi * t)
            if kind == 'HardLand':
                bend = 52 * compression
                pose(side + 'UpLeg', -bend)
                pose(side + 'Leg', bend * 1.7)
                pose('Spine', 24 * compression)
                running_arm(side, sign, -22 * compression, -35)
            else:
                stride = math.sin(t * math.pi) * sign
                braking = kind == 'StopRun'
                pose(side + 'UpLeg', stride * 30 - (18 if kind == 'LandRun' else 8) * compression)
                pose(side + 'Leg', 12 + max(0,-stride)*65 + (22 if kind == 'LandRun' else 0)*compression)
                pose('Spine', (-12 if braking else 14)*compression)
                running_arm(side, sign, -stride*28, -65)
        elif kind.startswith('WallJump'):
            wall_side = 1 if kind.endswith('Left') else -1
            extend = math.sin(t*math.pi*.5)
            pose(side + 'UpLeg', -45*(1-extend) + sign*wall_side*16)
            pose(side + 'Leg', 75*(1-extend)+12)
            running_arm(side, sign, -35 + sign*wall_side*25, -40)
            pose('Spine1', wall_side*12*(1-extend),(0,0,1))
        elif kind.startswith('AirJump'):
            lead = 1 if kind.endswith('Left') else -1
            tuck = math.sin(math.pi*t)
            pose(side + 'UpLeg', -25-tuck*(48 if sign==lead else 12))
            pose(side + 'Leg', 30+tuck*(78 if sign==lead else 35))
            running_arm(side, sign, -30+sign*lead*30*tuck, -65)
            pose('Spine1', -12*tuck)
        elif kind == 'Glide':
            pose(side+'Arm', -sign*30, (0,1,0))
            pose(side+'ForeArm', -8)
            pose(side+'UpLeg', -5+sign*3)
            pose(side+'Leg', 12)
            pose('Spine1', -5)
        elif kind == 'Vault':
            tuck = math.sin(math.pi*t)
            pose(side+'UpLeg', -25-tuck*(45 if sign==1 else 25))
            pose(side+'Leg', 25+tuck*80)
            running_arm(side,sign,-20-tuck*25,-35)
            pose('Spine', 18*tuck)
        elif kind.startswith('Dodge'):
            lean = 1 if kind.endswith('Left') else -1
            amount = math.sin(math.pi*t)
            pose(side+'UpLeg', -25-amount*25+sign*lean*15)
            pose(side+'Leg', 55+amount*25)
            running_arm(side,sign,-15-sign*lean*20,-70)
            pose('Spine1',lean*20*amount,(0,1,0))
        elif kind in ('PunchLeft','Finisher'):
            lead = 1 if kind == 'PunchLeft' else -1
            strike = math.sin(math.pi*t)
            running_arm(side,sign,-75*strike if sign==lead else -10,-15 if sign==lead else -65)
            pose('Spine1',lead*20*strike,(0,0,1))
            pose(side+'UpLeg',-10+sign*lead*8)
            pose(side+'Leg',20)
        elif kind == 'RunFlow':
            stride = pulse * sign
            # Original athletic cycle: drive, supported leg, heel recovery.
            pose(side + 'UpLeg', stride * 43 - 8)
            pose(side + 'Leg', 18 + max(0, -stride) * 92)
            pose(side + 'Foot', -12 - max(0, stride) * 12)
            running_arm(side, sign, -stride*40, -86 + stride*8)
            pose('Spine', 8)
            pose('Spine1', pulse * 5, (0,0,1))
            pose('Hips', -pulse * 3, (0,0,1))
        elif kind in ('WallRun', 'Walk'):
            stride = pulse * sign
            pose(side + 'UpLeg', stride * (35 if kind == 'WallRun' else 24) - (12 if kind == 'WallRun' else 0))
            pose(side + 'Leg', 10 + max(0, -stride) * (55 if kind == 'WallRun' else 30))
            pose(side + 'ForeArm', -75 if kind == 'WallRun' else -18 - max(0, stride)*16)
            running_arm(side, sign, -stride*(32 if kind == 'WallRun' else 22), -75 if kind == 'WallRun' else -22)
            pose(side + 'Foot', -max(0, -stride)*10)
            pose('Spine1', pulse * 3, (0,0,1))
            pose('Hips', -pulse * 2, (0,0,1))

for kind, seconds in [('DodgeLeft', .28), ('DodgeRight', .28), ('PunchLeft', .25), ('Finisher', .42), ('Glide', 1.2), ('Vault', .5), ('StartRun', .24), ('StopRun', .28), ('LandRun', .26), ('HardLand', .48), ('WallJumpLeft', .3), ('WallJumpRight', .3), ('AirJumpLeft', .4), ('AirJumpRight', .4), ('RunFlow', .64), ('Idle', 2), ('Walk', .9), ('Jump', .4), ('Fall', 1), ('Land', .3), ('SwingLeft', 1.2), ('SwingRight', 1.2), ('Zip', .45), ('WallRun', .6), ('SwingTuckLeft', 1.2), ('SwingTuckRight', 1.2), ('Release', .34), ('Dive', 1), ('Punch', .3), ('WallClimb', .65)]:
    action = bpy.data.actions.new(kind)
    rig.animation_data.action = action
    count = round(seconds * 30)
    for frame in range(count + 1):
        frame_pose(kind, frame / count)
        if kind in ('StartRun', 'StopRun', 'LandRun', 'HardLand'):
            # Keep the supporting ankle at its rest height while compressing.
            bpy.context.view_layer.update()
            lowest = min(rig.pose.bones[side+'Foot'].head.z for side in ('Left','Right'))
            rest_height = min(rig.data.bones[side+'Foot'].head_local.z for side in ('Left','Right'))
            hips = rig.pose.bones['Hips']
            hips.location = hips.bone.matrix_local.to_quaternion().inverted() @ Vector((0,0,rest_height-lowest))
        for bone in rig.pose.bones:
            bone.keyframe_insert('rotation_quaternion', frame=frame, group=bone.name)
            bone.keyframe_insert('location', frame=frame, group=bone.name)
    action.use_fake_user = True

rig.animation_data.action = original_action
rig.animation_data.action_slot = original_slot
scene.frame_set(0)
# Discover exporter enum values before selecting the known GLB/actions modes.
props = bpy.ops.export_scene.gltf.get_rna_type().properties
# export_format uses a dynamic callback; confirmed GLB in installed exporter source.
assert 'ACTIONS' in [i.identifier for i in props['export_animation_mode'].enum_items]
bpy.ops.export_scene.gltf(filepath=str(ROOT / 'assets/characters/spidey/spidey_traversal.glb'), export_format='GLB', export_animation_mode='ACTIONS', export_force_sampling=True)
print('TRAVERSAL_EXPORT_OK')
