import bpy, math, pathlib
from mathutils import Vector
P=pathlib.Path(".").resolve()
bpy.ops.wm.open_mainfile(filepath=str(P/"epic_bastion_v5_connected.blend"))
sc=bpy.context.scene
removed=[]
# The three original armatures form the unwanted side arms. Delete their visible meshes.
# Delete V5's redundant tray (we replace it fully), and precisely three V4 armor
# overlaps near the cannon paths.
for o in list(sc.objects):
    if o.name in ("armature1","armature2","armature3") or o.name.startswith("V5 cradle") or o.name.startswith("Legion lower triangular overlap "):
        if o.type=="MESH":
            removed.append(o.name)
            bpy.data.objects.remove(o,do_unlink=True)
# No vertical posts or retaining fins of any kind. The cradle is purely underneath.
goldparts=[bpy.data.objects.get(n) for n in ("ring","ring2","ring3","ring4")]
goldparts=[o for o in goldparts if o and o.type=="MESH"]
assert len(goldparts)==4, "Expected four original Epic Bastion rings"
bpy.context.view_layer.update()
def bounds(o):
    return [o.matrix_world @ Vector(c) for c in o.bound_box]
coords=[p for o in goldparts for p in bounds(o)]
zmin=min(p.z for p in coords); zmax=max(p.z for p in coords)
rmax=max(math.hypot(p.x,p.y) for p in coords)
# Real geometry dimensions drive cradle footprint. The docking ring is just beneath
# the minimum Z of the resting rings; nothing projects above them.
z=zmin-1.7
col=bpy.data.collections.new("V7 open ring resting cradle")
sc.collection.children.link(col)
mat={name:bpy.data.materials.get("LEGION_"+name.upper()) for name in ("dark","main","edge","green")}
def annulus(name,rin,rout,cz,h,material,segments=48):
    verts=[]
    for zz,rr in ((cz-h/2,rout),(cz-h/2,rin),(cz+h/2,rout),(cz+h/2,rin)):
        for i in range(segments):
            a=2*math.pi*i/segments
            verts.append((rr*math.cos(a),rr*math.sin(a),zz))
    faces=[]
    for p,q in ((0,2),(1,3),(0,1),(2,3)):
        for i in range(segments):
            j=(i+1)%segments
            faces.append((p*segments+i,p*segments+j,q*segments+j,q*segments+i))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);col.objects.link(obj)
    mesh.materials.append(mat[material])
    return obj
# Substantial lower deck, recessed bearing rim and concentric low-profile pads.
# No top frame, clamps, jaws or spikes, by design.
annulus("V7 recessed load bearing foundation",rmax*.54,rmax*1.1,z-3.0,5.0,"dark")
annulus("V7 outer angled armor rim",rmax*.94,rmax*1.12,z-1.7,2.8,"main")
annulus("V7 energy distribution race",rmax*.83,rmax*.88,z-.85,.6,"green")
annulus("V7 gold ring rest bearing",rmax*.66,rmax*.82,z-.6,1.0,"edge")
# All V7 components end beneath the gold rings.
highest=max(max(v.z for v in bounds(o)) for o in col.objects)
assert highest < zmin+0.01,(highest,zmin)
print("CRADLE RING BOUNDS",rmax,zmin,zmax,"CRADLE TOP",highest,"REMOVED",removed)
# The original model remains unedited in hosting. Save edited work in DevelopmentEnvironment.
bpy.ops.wm.save_as_mainfile(filepath=str(P/"epic_bastion_v7_true_open_cradle.blend"))
bpy.ops.export_scene.gltf(filepath=str(P/"epic_bastion_v7_true_open_cradle.glb"),export_format="GLB")
for obj in list(sc.objects):
    if obj.type in ("LIGHT","CAMERA"): bpy.data.objects.remove(obj,do_unlink=True)
cd=bpy.data.cameras.new("Cradle review");cam=bpy.data.objects.new("Cradle review",cd);sc.collection.objects.link(cam)
sc.camera=cam;cd.type="ORTHO";cd.ortho_scale=260
target=Vector((0,0,zmin-50))
cam.location=(210,-250,zmin+110)
cam.rotation_euler=(target-cam.location).to_track_quat("-Z","Y").to_euler()
for n,power,loc in (("key",40000,(130,-120,zmin+150)),("fill",28000,(-160,-50,zmin+70)),("rim",38000,(40,150,zmin+140))):
    ld=bpy.data.lights.new(n,"AREA");obj=bpy.data.objects.new(n,ld);sc.collection.objects.link(obj)
    obj.location=loc;obj.rotation_euler=(target-obj.location).to_track_quat("-Z","Y").to_euler();ld.energy=power;ld.shape="DISK";ld.size=140
sc.render.engine="BLENDER_EEVEE";sc.render.resolution_x=1100;sc.render.resolution_y=1000
sc.render.resolution_percentage=100;sc.render.image_settings.file_format="PNG"
sc.view_settings.view_transform="Standard";sc.view_settings.exposure=1.6
sc.render.filepath=str(P/"epic_bastion_v7_true_open_cradle.png")
bpy.ops.render.render(write_still=True)
