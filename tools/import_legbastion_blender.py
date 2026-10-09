import bpy, struct, pathlib, urllib.request
p=pathlib.Path("legbastion.s3o")
if not p.exists():
 urllib.request.urlretrieve("https://raw.githubusercontent.com/RandomGuyJunior/Beyond-All-Reason/master/objects3d/Units/legbastion.s3o",p)
data=p.read_bytes()
hd=struct.Struct("<12sI5f4I")
pc=struct.Struct("<10I3f")
vt=struct.Struct("<8f")
h=hd.unpack_from(data,0)
assert h[0].startswith(b"Spring unit")
def name(off):
 if not off:return ""
 return data[off:data.index(b"\0",off)].decode("utf-8","replace")
def xyz(x,y,z):return x,-z,y
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
material=bpy.data.materials.new("Legion armor reference")
material.diffuse_color=(0.38,0.42,0.48,1)
report=[]
def piece(off,parent=None):
 q=pc.unpack_from(data,off)
 no,nc,co,nv,vo,vert_type,prim,ni,io,col,ox,oy,oz=q
 nm=name(no); verts=[];uv=[]
 for i in range(nv):
  x,y,z,nx,ny,nz,u,v=vt.unpack_from(data,vo+i*vt.size)
  verts.append(xyz(x,y,z));uv.append((u,1-v))
 inds=struct.unpack_from("<"+str(ni)+"I",data,io) if ni else ()
 faces=[]
 if prim==0:
  faces=[tuple(inds[i:i+3]) for i in range(0,ni-2,3) if len(set(inds[i:i+3]))==3 and max(inds[i:i+3])<nv]
 elif prim==1:
  last=[];flip=False
  for j in inds:
   if j==4294967295:last=[];flip=False;continue
   last.append(j)
   if len(last)>=3:
    a,b,c=last[-3:]
    if len({a,b,c})==3 and max(a,b,c)<nv:faces.append((b,a,c) if flip else (a,b,c))
    flip=not flip
 elif prim==2: # S3O quad list: four local indices per face
  faces=[tuple(inds[i:i+4]) for i in range(0,ni-3,4)
         if len(set(inds[i:i+4]))==4 and max(inds[i:i+4])<nv]
 if faces:
  mesh=bpy.data.meshes.new(nm);mesh.from_pydata(verts,[],faces);mesh.update()
  obj=bpy.data.objects.new(nm,mesh)
  lay=mesh.uv_layers.new(name="S3O UV")
  for poly in mesh.polygons:
   for li in poly.loop_indices: lay.data[li].uv=uv[mesh.loops[li].vertex_index]
  mesh.materials.append(material)
 else:obj=bpy.data.objects.new(nm,None);obj.empty_display_type="PLAIN_AXES"
 bpy.context.collection.objects.link(obj)
 obj.parent=parent;obj.location=xyz(ox,oy,oz)
 obj["S3O_piece"]=nm
 report.append((nm,nv,len(faces),tuple(round(v,2) for v in obj.location)))
 if nc:
  child=struct.unpack_from("<"+str(nc)+"I",data,co)
  for c in child:piece(c,obj)
 return obj
root=piece(h[7])
pathlib.Path("legbastion_piece_report.txt").write_text("Original BAR legbastion.s3o\nradius: %s height: %s\n"%(h[2],h[3])+"\n".join(map(str,report)))
bpy.ops.wm.save_as_mainfile(filepath=str(pathlib.Path("legbastion_original.blend").resolve()))
print("Converted",len(report),"pieces")

# Trigger reference Blender conversion through the GitHub Actions push workflow.
