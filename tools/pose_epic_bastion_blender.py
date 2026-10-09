import bpy, math, pathlib
from mathutils import Vector
ROOT=pathlib.Path(".").resolve()
bpy.ops.wm.open_mainfile(filepath=str(ROOT/"legbastiont3_original.blend"))
o=bpy.data.objects
for name,deg in [("armPivot2",120),("armPivot3",-120),("extension_root_1",0),("extension_root_2",120),("extension_root_3",-120)]:
    assert name in o, name
    o[name].rotation_euler[2]=math.radians(deg)
# Resting pose as initialized by the current Epic Bastion Lua:
o["ringanchor"].location.z -= 10
# keep imported armature and cannon geometry unchanged; just apply script transforms.
for obj in o:
    if obj.type=="MESH":
        for mat in obj.data.materials:
            mat.diffuse_color=(0.52,0.56,0.53,1)
bpy.context.view_layer.update()
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/"legbastiont3_script_pose.blend"))
bpy.ops.export_scene.gltf(filepath=str(ROOT/"legbastiont3_script_pose.glb"),export_format="GLB")
scene=bpy.context.scene
camdat=bpy.data.cameras.new("Posed Review Camera")
cam=bpy.data.objects.new("Posed Review Camera",camdat);scene.collection.objects.link(cam)
scene.camera=cam
camdat.type='ORTHO';camdat.ortho_scale=345
for n,xyz,pow,size in [("Pose Key",(200,-120,330),42000,180),("Pose Fill",(-170,-100,260),25000,200),("Pose Rim",(10,200,310),33000,180)]:
    ld=bpy.data.lights.new(n,'AREA')
    ob=bpy.data.objects.new(n,ld);scene.collection.objects.link(ob)
    ob.location=xyz;ld.energy=pow;ld.shape='DISK';ld.size=size
scene.render.engine='BLENDER_EEVEE'
scene.render.resolution_x=1200;scene.render.resolution_y=1050;scene.render.resolution_percentage=100
scene.render.film_transparent=True
for name,loc,target in [
    ("legbastiont3_script_pose_isometric.png",(270,-300,245),(0,0,94)),
    ("legbastiont3_script_pose_top.png",(0,-4,390),(0,0,85)),
    ("legbastiont3_script_pose_side.png",(320,-2,125),(0,0,104))
]:
    cam.location=loc
    cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
    for light in [ob for ob in scene.objects if ob.type=='LIGHT']:
        light.rotation_euler=(Vector(target)-light.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(ROOT/name)
    bpy.ops.render.render(write_still=True)
print("POSE REVIEW DONE",[(n, tuple(round(v,2) for v in o[n].rotation_euler)) for n in ("extension_root_1","extension_root_2","extension_root_3")])
