from pathlib import Path
import bpy, struct, urllib.request
from mathutils import Vector
src = Path("legapopupdef.s3o")
if not src.exists():
    urllib.request.urlretrieve("https://raw.githubusercontent.com/RandomGuyJunior/Beyond-All-Reason/master/objects3d/Units/legapopupdef.s3o", src)
data=src.read_bytes()
H=struct.Struct("<12sI5f4I"); P=struct.Struct("<10I3f"); V=struct.Struct("<8f")
h=H.unpack_from(data)
assert h[0].startswith(b"Spring unit")
def name(off): return data[off:data.index(b"\0",off)].decode("utf8","replace") if off else ""
def xyz(v): return (v[0],-v[2],v[1])
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
mat=bpy.data.materials.new("Epic Bastion source geometry - UV reference")
mat.diffuse_color=(0.39,0.44,0.41,1)
info=[]
def load(off,parent=None):
    no,nc,co,nv,vo,ty,prim,ni,io,coll,x,y,z=P.unpack_from(data,off)
    n=name(no); vertices=[];uv=[]
    for i in range(nv):
        vx,vy,vz,nx,ny,nz,u,v=V.unpack_from(data,vo+i*V.size)
        vertices.append(xyz((vx,vy,vz)));uv.append((u,1-v))
    inds=struct.unpack_from("<"+str(ni)+"I",data,io) if ni else ()
    faces=[]
    if prim==0:
        faces=[tuple(inds[i:i+3]) for i in range(0,ni-2,3) if len(set(inds[i:i+3]))==3 and max(inds[i:i+3])<nv]
    elif prim==1:
        prev=[];flip=False
        for j in inds:
            if j==4294967295:prev=[];flip=False;continue
            prev.append(j)
            if len(prev)>=3:
                a,b,c=prev[-3:]
                if len({a,b,c})==3 and max(a,b,c)<nv:faces.append((b,a,c) if flip else (a,b,c))
                flip=not flip
    elif prim==2:
        faces=[tuple(inds[i:i+4]) for i in range(0,ni-3,4) if len(set(inds[i:i+4]))==4 and max(inds[i:i+4])<nv]
    if faces:
        mesh=bpy.data.meshes.new(n);mesh.from_pydata(vertices,[],faces);mesh.update()
        obj=bpy.data.objects.new(n,mesh)
        layer=mesh.uv_layers.new(name="Original S3O UV")
        for face in mesh.polygons:
            for li in face.loop_indices:layer.data[li].uv=uv[mesh.loops[li].vertex_index]
        mesh.materials.append(mat)
    else:
        obj=bpy.data.objects.new(n,None);obj.empty_display_type="PLAIN_AXES";obj.empty_display_size=2
    bpy.context.collection.objects.link(obj);obj.parent=parent;obj.location=xyz((x,y,z))
    obj["S3O_piece"]=n; obj["S3O_primitive"]=prim
    info.append((n,nv,len(faces),[round(x,2),round(y,2),round(z,2)]))
    if nc:
        for ptr in struct.unpack_from("<"+str(nc)+"I",data,co):load(ptr,obj)
    return obj
root=load(h[7]);root["S3O_radius"]=h[2];root["S3O_height"]=h[3]
Path("legapopupdef_piece_report.txt").write_text("Source randomguy-hosting/objects3d/Units/legapopupdef.s3o\nS3O radius: %s height: %s\n"%(h[2],h[3])+"\n".join(map(str,info)),encoding="utf8")
bpy.ops.wm.save_as_mainfile(filepath=str(Path("legapopupdef_original.blend").resolve()))
# Export GLB without source texture replacement: UVs are preserved, material neutral.
bpy.ops.export_scene.gltf(filepath=str(Path("legapopupdef_original.glb").resolve()),export_format="GLB")
camera_data=bpy.data.cameras.new("Reference Camera");camera=bpy.data.objects.new("Reference Camera",camera_data);bpy.context.collection.objects.link(camera)
bpy.context.scene.camera=camera
camera.location=(310,-345,285); target=Vector((0,0,108))
camera.rotation_euler=(target-camera.location).to_track_quat("-Z","Y").to_euler();camera_data.type="ORTHO";camera_data.ortho_scale=385
for n,loc,power,size in [("Key",(180,-120,320),35000,180),("Fill",(-190,-90,220),25000,170),("Rim",(0,200,280),35000,160)]:
    ld=bpy.data.lights.new(n,'AREA');ob=bpy.data.objects.new(n,ld);bpy.context.collection.objects.link(ob);ob.location=loc;ob.rotation_euler=(target-ob.location).to_track_quat('-Z','Y').to_euler();ld.energy=power;ld.shape='DISK';ld.size=size
scene=bpy.context.scene;scene.render.engine="BLENDER_EEVEE";scene.render.resolution_x=1100;scene.render.resolution_y=1000;scene.render.resolution_percentage=100;scene.render.film_transparent=True;scene.render.filepath=str(Path("legapopupdef_original_preview.png").resolve())
bpy.ops.render.render(write_still=True)
print("Epic Bastion source conversion: ",len(info),"pieces")
