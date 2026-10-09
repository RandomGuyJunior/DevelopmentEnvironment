import bpy, math, pathlib
from mathutils import Vector
P=pathlib.Path(".").resolve()
bpy.ops.wm.open_mainfile(filepath=str(P/"legbastiont3_script_pose.blend"))
scene=bpy.context.scene
armor=bpy.data.collections.new("Legion armor refinement V4")
scene.collection.children.link(armor)
# Keep the original Bastion-derived body and the exact original rings and cannon meshes.
palette={"dark":(.055,.074,.064,1),"main":(.155,.204,.169,1),"plate":(.22,.269,.225,1),"edge":(.35,.40,.34,1),"seam":(.075,.095,.08,1),"green":(.06,.55,.16,1)}
mats={}
for name,color in palette.items():
    m=bpy.data.materials.new("LEGION_"+name.upper())
    m.diffuse_color=color;m.use_nodes=True
    p=m.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value=color
    p.inputs["Metallic"].default_value=.48 if name!="green" else .12
    p.inputs["Roughness"].default_value=.52
    if name=="green":
        p.inputs["Emission Color"].default_value=(.04,.45,.1,1)
        p.inputs["Emission Strength"].default_value=2
    mats[name]=m
# Use the original Bastion's distinctive armor design: long, sloping, tapered,
# triangular buttresses and separate ribs; do NOT cover the tower with boxes.
def radial(deg,r,t=0):
    a=math.radians(deg)
    return Vector((math.sin(a)*r+math.cos(a)*t,-math.cos(a)*r+math.sin(a)*t))
def prism(name,stations,angle,material):
    # stations: (r, half_width, height, thickness) forming two tapering faces
    verts=[]
    for r,w,z,thick in stations:
        for t in (-w,w):
            q=radial(angle,r,t)
            verts.append((q.x,q.y,z))
        for t in (-w,w):
            q=radial(angle,r-thick,t)
            verts.append((q.x,q.y,z))
    faces=[]
    for i in range(len(stations)-1):
        k=i*4;j=k+4
        for a,b,c,d in [(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]:
            faces.append((k+a,k+b,k+c,k+d))
    faces.extend([(0,2,3,1),(len(verts)-4,len(verts)-3,len(verts)-1,len(verts)-2)])
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    ob=bpy.data.objects.new(name,mesh);armor.objects.link(ob)
    ob.data.materials.append(mats[material])
    mod=ob.modifiers.new("Machined armor edge bevel","BEVEL");mod.width=.7;mod.segments=2
    ob.modifiers.new("Weighted facet normals","WEIGHTED_NORMAL")
    return ob
# Main original body extends to ~radius 47 in lower sections and tapers higher.
# Place new reinforcement as stepped, sloped Legion shield-plates.
for k in range(3):
    a=120*k
    prism("Legion tapered outer buttress %d"%k,
          [(47,14,8,5),(42,12,28,4.5),(35,10,67,3.5),(27,6,118,3),(22,2.8,146,2)],a,"main")
    prism("Legion outer raised spine %d"%k,
          [(49,2,12,1.5),(45,2.2,36,1.5),(36,2.1,75,1.5),(29,1.7,117,1.2),(23,1,145,1)],a,"edge")
    for side in (-1,1):
        # edge-ribs preserve clear negative spaces and the triangular Legion silhouette
        prism("Legion flanking rib %d %d"%(k,side),
              [(44,2.5,8,2),(41,2.5,32,2),(32,2.1,83,1.8),(23,1.4,132,1.5)],
              a+side*19,"plate")
    prism("Legion lower triangular overlap %d"%k,
          [(50,11,10,3),(46,9,25,2.5),(43,6,42,2),(40,0.8,52,1.5)],a+60,"plate")
    prism("Legion energy channel %d"%k,
          [(43,1.15,26,.6),(39,1.15,49,.6),(34,1.1,76,.6),(30,.7,94,.6)],a+57,"green")
# No new cannon parts here: preserve original cannon geometries for visual review.
# Remove older inherited lights/cameras so the render remains readable.
for obj in list(scene.objects):
    if obj.type in ("LIGHT","CAMERA"): bpy.data.objects.remove(obj,do_unlink=True)
for obj in scene.objects:
    if obj.type=="MESH" and obj.name not in armor.objects:
        if obj.data.materials:obj.data.materials.clear()
        obj.data.materials.append(mats["plate"])
for obj in scene.objects:
    if obj.name.startswith("ring") and obj.type=="MESH":
        obj.data.materials.clear()
        gold=bpy.data.materials.get("Legion ring gold")
        if gold is None:
            gold=bpy.data.materials.new("Legion ring gold");gold.diffuse_color=(.78,.43,.045,1)
        obj.data.materials.append(gold)
bpy.context.view_layer.update()
bpy.ops.wm.save_as_mainfile(filepath=str(P/"epic_bastion_legion_armor_v4.blend"))
bpy.ops.export_scene.gltf(filepath=str(P/"epic_bastion_legion_armor_v4.glb"),export_format="GLB")
camdata=bpy.data.cameras.new("View");cam=bpy.data.objects.new("View",camdata);scene.collection.objects.link(cam)
scene.camera=cam;camdata.type="ORTHO";camdata.ortho_scale=350
target=Vector((0,0,100))
cam.location=(235,-320,245);cam.rotation_euler=(target-cam.location).to_track_quat("-Z","Y").to_euler()
for n,loc,power,size in [("Key",(180,-200,320),30000,180),("Fill",(-210,-50,220),26000,180),("Back",(0,230,260),35000,160)]:
    l=bpy.data.lights.new(n,"AREA");o=bpy.data.objects.new(n,l);scene.collection.objects.link(o);o.location=loc
    o.rotation_euler=(target-o.location).to_track_quat("-Z","Y").to_euler();l.energy=power;l.shape="DISK";l.size=size
scene.render.engine="BLENDER_EEVEE";scene.render.resolution_x=1200;scene.render.resolution_y=1050;scene.render.resolution_percentage=100
scene.render.film_transparent=False;scene.render.filepath=str(P/"epic_bastion_legion_armor_v4.png")
scene.world.color=(.7,.7,.7)
bpy.ops.render.render(write_still=True)
print("SAVED LEGION ARMOR V4")
