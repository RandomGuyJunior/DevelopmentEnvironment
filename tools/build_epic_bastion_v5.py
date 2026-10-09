import bpy, math, pathlib
from mathutils import Vector
P=pathlib.Path(".").resolve()
bpy.ops.wm.open_mainfile(filepath=str(P/"epic_bastion_legion_armor_v4.blend"))
scene=bpy.context.scene
build=bpy.data.collections.new("V5 integrated cannon engineering")
scene.collection.children.link(build)
mats={k:bpy.data.materials.get("LEGION_"+k.upper()) for k in ("dark","main","plate","edge","seam","green")}
def mesh(name,verts,faces,mat,parent=None):
    me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update()
    ob=bpy.data.objects.new(name,me);build.objects.link(ob)
    if parent:ob.parent=parent
    me.materials.append(mats[mat])
    bevel=ob.modifiers.new("Machined edge","BEVEL");bevel.width=.55;bevel.segments=2
    ob.modifiers.new("Facet normals","WEIGHTED_NORMAL")
    return ob
def square(name,start,end,w1,h1,w2,h2,mat,parent=None):
    # Local assembly extends in -Y; per-end sizes permit angled, chamfer-like casing.
    verts=[]
    for y,w,h in ((start,w1,h1),(end,w2,h2)):
        for x,z in ((-w/2,-h/2),(w/2,-h/2),(w/2,h/2),(-w/2,h/2)):
            verts.append((x,y,z))
    faces=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
    return mesh(name,verts,faces,mat,parent)
def ring(name,inner,outer,z,thick,mat,parent=None,n=24):
    verts=[]
    for z0,r in ((z-thick/2,outer),(z-thick/2,inner),(z+thick/2,outer),(z+thick/2,inner)):
        for j in range(n):
            a=j*2*math.pi/n
            verts.append((r*math.cos(a),r*math.sin(a),z0))
    f=[]
    for k1,k2 in ((0,2),(1,3),(0,1),(2,3)):
        for j in range(n):
            i=k1*n+j; ni=k1*n+(j+1)%n; ii=k2*n+j; nii=k2*n+(j+1)%n
            f.append((i,ni,nii,ii))
    return mesh(name,verts,f,mat,parent)
# Remove prior broken visible donor meshes, but retain pivots, scripts, hierarchy.
removed=[]
for obj in list(scene.objects):
    if obj.name.startswith(("extension_arm_","extension_pedestal_","gauss1_pitchbridge","gauss2_pitchbridge","gauss3_pitchbridge")) or (obj.name.startswith(("gauss1_","gauss2_","gauss3_")) and obj.type=="MESH"):
        removed.append(obj.name)
        bpy.data.objects.remove(obj,do_unlink=True)
# Fill all three radial positions with self-contained modeled mounts.
# Each root rotates at (0,+120,-120); material is only a provisional armor palette.
for i in (1,2,3):
    parent=bpy.data.objects["extension_root_"+str(i)]
    housing=bpy.data.objects.new("gauss%d_integrated_mount"%i,None)
    build.objects.link(housing);housing.parent=parent
    housing.location=(0,-28,-76)
    # Load-bearing armored socket / turning race / deep mechanical turret.
    square("gauss%d lower bridge"%i,24,-13,24,11,20,10,"dark",housing)
    square("gauss%d load frame"%i,7,-27,24,19,19,17,"main",housing)
    square("gauss%d central tapered mantlet"%i,-10,-43,20,20,14,15,"plate",housing)
    square("gauss%d gun recoil sleeve"%i,-37,-65,12,11,9,9,"dark",housing)
    square("gauss%d single barrel"%i,-54,-84,8,8,7,7,"edge",housing)
    square("gauss%d muzzle surround"%i,-80,-87,10,10,9,9,"main",housing)
    square("gauss%d power rail"%i,-50,-82,2.7,1.1,2.7,1.1,"green",housing).location.z=5
    for side in (-1,1):
        x=side*10.4
        support=square("gauss%d lateral load member %s"%(i,side),18,-32,3.5,8,2.7,7,"edge",housing)
        support.location.x=x;support.location.z=-3
        plate=square("gauss%d angled armor cover %s"%(i,side),-18,-56,3.5,15,2.3,9,"plate",housing)
        plate.location.x=side*8.7;plate.location.z=1.5
    # Three named marker pieces included for future rig/script alignment.
    for n,y in (("mount",-8),("barrel",-57),("muzzle",-88)):
        marker=bpy.data.objects.new("v5_gauss%d_%s"%(i,n),None)
        build.objects.link(marker);marker.parent=housing;marker.location=(0,y,0)
# Cradle support sits on the existing Bastion tower; no roof and no side clamps.
ring("V5 cradle machine race",16.5,24,134,3,"dark")
ring("V5 cradle armor lip",22,27,136,3,"main")
ring("V5 recessed green power channel",21.2,22,136.5,1.1,"green")
# Remove old preview lights and cameras then create a brighter clay inspection.
for obj in list(scene.objects):
    if obj.type in ("CAMERA","LIGHT"):bpy.data.objects.remove(obj,do_unlink=True)
bpy.context.view_layer.update()
bpy.ops.wm.save_as_mainfile(filepath=str(P/"epic_bastion_v5_connected.blend"))
bpy.ops.export_scene.gltf(filepath=str(P/"epic_bastion_v5_connected.glb"),export_format="GLB")
camera_data=bpy.data.cameras.new("V5 camera");camera=bpy.data.objects.new("V5 camera",camera_data);scene.collection.objects.link(camera)
scene.camera=camera;camera_data.type="ORTHO";camera_data.ortho_scale=265
camera.location=(195,-255,215);target=Vector((0,0,93))
camera.rotation_euler=(target-camera.location).to_track_quat("-Z","Y").to_euler()
for n,loc,power,size in [("key",(90,-180,275),32000,155),("fill",(-165,-65,200),24000,160),("rim",(25,145,265),34000,150)]:
    ld=bpy.data.lights.new(n,'AREA');obj=bpy.data.objects.new(n,ld);scene.collection.objects.link(obj)
    obj.location=loc;obj.rotation_euler=(target-obj.location).to_track_quat('-Z','Y').to_euler();ld.energy=power;ld.shape='DISK';ld.size=size
scene.world.color=(.7,.7,.7)
scene.view_settings.view_transform="Standard"
scene.view_settings.look="Medium High Contrast"
scene.view_settings.exposure=1.15
scene.render.engine="BLENDER_EEVEE";scene.render.resolution_x=1200;scene.render.resolution_y=1050;scene.render.resolution_percentage=100
scene.render.image_settings.file_format="PNG"
scene.render.filepath=str(P/"epic_bastion_v5_connected.png")
bpy.ops.render.render(write_still=True)
print("V5 removed legacy donor cannon meshes",removed)
