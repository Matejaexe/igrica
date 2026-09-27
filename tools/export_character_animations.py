"""Blender --background --factory-startup --python tools/export_character_animations.py
Export the editable working .blend without regenerating any actions.
"""
import bpy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT/'assets/characters/spidey/blender/spidey_run_from_reference_v1.blend'
WORKING = ROOT/'assets/characters/spidey/blender/spidey_animation_working.blend'
assert WORKING.exists(), 'Working animation file is missing; restore it before exporting.'
bpy.ops.wm.open_mainfile(filepath=str(WORKING))
rig = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
# Load only original armature data for validation, not a second character.
with bpy.data.libraries.load(str(SOURCE), link=False) as (available, loaded):
    loaded.armatures = list(available.armatures)
reference = loaded.armatures[0]
assert set(rig.data.bones.keys()) == set(reference.bones.keys()), 'Bone names changed'
for bone in reference.bones:
    actual = rig.data.bones[bone.name]
    assert (actual.parent.name if actual.parent else None) == (bone.parent.name if bone.parent else None), 'Hierarchy changed: '+bone.name
    assert all(abs(actual.matrix_local[i][j]-bone.matrix_local[i][j]) < 1e-6 for i in range(4) for j in range(4)), 'Rest matrix changed: '+bone.name
for armature in loaded.armatures:
    bpy.data.armatures.remove(armature)
required = {'Idle','RunFlow','Sprint','Jump','Fall','Land','SwingLeft','SwingRight','WallRun','Punch','PunchLeft','Finisher'}
assert required.issubset(set(bpy.data.actions.keys())), 'Required action missing'
# No save_as_mainfile and no pose generation: artist edits remain authoritative.
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/characters/spidey/spidey_traversal.glb'),export_format='GLB',export_animation_mode='ACTIONS',export_force_sampling=True)
print('ANIMATION_EXPORT_OK: original rig compatible; existing working actions exported')
