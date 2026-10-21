-- Experimental visual reconstruction only; native synced simulation owns hits,
-- aiming, muzzle positions, movement and damage. Collision gadget is separate.
function widget:GetInfo()
 return {name='Forge Ork Depth Volumes',desc='Animated per-piece Depth Volume asset renderer',author='Local BAR 40K project',layer=11,enabled=true}
end
local CONFIG='luaui/configs/forge_ork_depth_volumes.lua'
if not VFS.FileExists(CONFIG) then return false end
local index=VFS.Include(CONFIG)
if index.method~='VOLUME' or type(index.assets)~='table' then return false end
local LEGACY='Forge Mork native piece impostor prototype'
local defs,assets,order={},{},{}
for name in pairs(index.assets)do order[#order+1]=name end
table.sort(order)
for _,name in ipairs(order)do
 local cfg=index.assets[name]
 local asset={name=name,cfg=cfg,legacyMork=cfg.unitDefs.bar40k_ork_morkanaut_extreme==true}
 assets[#assets+1]=asset
 for unitName,enabled in pairs(cfg.unitDefs or{})do
  if enabled and UnitDefNames[unitName]then
   local defID=UnitDefNames[unitName].id
   if defs[defID]then Spring.Echo('FORGE_DEPTH duplicate UnitDef renderer',unitName);return false end
   defs[defID]=asset
  end
 end
end
if not next(defs)then return false end
local iv=gl.InstanceVBOTable
local shader,vertices,indices
local attached,missingWarned={},{}
local elapsed=0
local legacyWarning=false
local opaquePassLogged=false

local VS=[[#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__
layout(location=0) in vec3 corner;
layout(location=1) in vec3 center;
layout(location=2) in vec3 axisX;
layout(location=3) in vec3 axisY;
layout(location=4) in vec3 axisZ;
layout(location=5) in vec3 bounds;
layout(location=6) in vec4 rect0;
layout(location=7) in vec4 rect1;
layout(location=8) in vec4 rect2;
layout(location=9) in vec4 rect3;
layout(location=10) in vec4 rect4;
layout(location=11) in vec4 rect5;
layout(location=12) in uint pieceIndex;
layout(location=13) in uvec4 instData;
struct SUniformsBuffer {
 uint composite;uint unused2;uint unused3;uint unused4;
 float maxHealth;float health;float unused5;float unused6;
 vec4 drawPos;vec4 speed;vec4[4] userDefined;
};
layout(std140,binding=1) readonly buffer UniformsBuffer{SUniformsBuffer uni[];};
#if USEQUATERNIONS == 0
 layout(std140,binding=0) readonly buffer MatrixBuffer{mat4 UnitPieces[];};
#else
 //__QUATERNIONDEFS__
#endif

out vec3 boxPosition;
flat out vec3 eyeBox;
flat out vec3 worldCenter;
flat out mat3 boxToWorld;
flat out vec4 captureUV[6];
void main(){
 #if USEQUATERNIONS == 0
  mat4 modelMatrix=UnitPieces[instData.x];
  mat4 pieceMatrix=mat4mix(mat4(1.0),UnitPieces[instData.x+pieceIndex+1u],modelMatrix[3][3]);
  mat4 worldMat=modelMatrix*pieceMatrix;
 #else
  mat4 worldMat=TransformToMatrix(GetPieceWorldTransform(instData.x,pieceIndex));
 #endif
 if((uni[instData.y].composite&1u)==0u||abs(determinant(mat3(worldMat)))<1e-12){gl_Position=vec4(2,2,2,1);return;}
 worldCenter=(worldMat*vec4(center,1)).xyz;
 boxToWorld=mat3(worldMat)*mat3(axisX*bounds.x,axisY*bounds.y,axisZ*bounds.z);
 eyeBox=inverse(boxToWorld)*(cameraViewInv[3].xyz-worldCenter);
 boxPosition=corner;
 captureUV[0]=rect0;captureUV[1]=rect1;captureUV[2]=rect2;captureUV[3]=rect3;captureUV[4]=rect4;captureUV[5]=rect5;
 gl_Position=cameraViewProj*vec4(worldCenter+boxToWorld*corner,1);
}
]]
local FS=[[#version 420
//__ENGINEUNIFORMBUFFERDEFS__
uniform sampler2D atlas;
uniform sampler2D depthAtlas;
uniform sampler2D normalAtlas;
uniform float cutoff;
uniform float thickness;
in vec3 boxPosition;
flat in vec3 eyeBox;
flat in vec3 worldCenter;
flat in mat3 boxToWorld;
flat in vec4 captureUV[6];
out vec4 fragColor;
bool probe(vec3 q,vec3 signs,out vec2 chosenUV){
 float closest=1e10;bool hit=true;chosenUV=vec2(0);
 for(int axis=0;axis<3;++axis){
  vec2 projection=axis==0?vec2(q.y*signs.x,q.z):(axis==1?vec2(-q.x*signs.y,q.z):vec2(q.x*signs.z,q.y));
  int view=axis*2+(signs[axis]>0?0:1);
  vec4 rect=captureUV[view];vec2 uv=rect.xy+clamp(projection+.5,0.,1.)*rect.zw;
  vec4 depth=textureLod(depthAtlas,uv,0.);
  // Native bitmap loaders can reduce PNG16 to RGBA8. RG stores a full 16-bit
  // normalized depth explicitly, so the volume does not inherit 8-bit bands.
  float surface=dot(depth.rg,vec2(65280.,255.))/65535.-.5;
  float distance=q[axis]*signs[axis]-surface;
  float coverage=textureLod(atlas,uv,0.).a;
  hit=hit&&(distance<thickness)&&(coverage>cutoff)&&all(lessThanEqual(abs(projection),vec2(.50001)));
  if(abs(distance)<closest){closest=abs(distance);chosenUV=uv;}
 }
 return hit;
}
void main(){
 vec3 direction=normalize(boxPosition-eyeBox);
 vec3 safe=vec3(direction.x>=0?1.:-1.,direction.y>=0?1.:-1.,direction.z>=0?1.:-1.)*max(abs(direction),vec3(1e-7));
 vec3 a=(-vec3(.5)-eyeBox)/safe,b=(vec3(.5)-eyeBox)/safe;
 vec3 nearV=min(a,b),farV=max(a,b);
 float entry=max(max(nearV.x,nearV.y),nearV.z),exit=min(min(farV.x,farV.y),farV.z);
 entry=max(entry,0.);if(exit<=entry)discard;
 // Cull duplicate rear fragments while still allowing a camera inside bounds.
 bool inside=all(lessThan(abs(eyeBox),vec3(.5)));
 if(!inside&&!gl_FrontFacing)discard;
 vec3 signs=vec3(direction.x<=0?1.:-1.,direction.y<=0?1.:-1.,direction.z<=0?1.:-1.);
 float stepSize=(exit-entry)/96.,time=entry;vec2 uv;bool found=false;
 for(int i=0;i<=96;++i){if(probe(eyeBox+direction*time,signs,uv)){found=true;break;}time+=stepSize;}
 if(!found)discard;
 float low=max(entry,time-stepSize);
 for(int i=0;i<4;++i){float mid=(low+time)*.5;if(probe(eyeBox+direction*mid,signs,uv))time=mid;else low=mid;}
 probe(eyeBox+direction*time,signs,uv);
 vec4 c=textureLod(atlas,uv,0.);if(c.a<cutoff)discard;
 vec3 hitWorld=worldCenter+boxToWorld*(eyeBox+direction*time);
 vec4 clip=cameraViewProj*vec4(hitWorld,1.);
 float ndc=clip.z/clip.w;gl_FragDepth=(renderCaps&1u)!=0u?ndc:ndc*.5+.5;
 mat3 normalBasis=mat3(normalize(boxToWorld[0]),normalize(boxToWorld[1]),normalize(boxToWorld[2]));
 vec3 normal=normalize(normalBasis*(textureLod(normalAtlas,uv,0.).rgb*2.-1.));
 vec3 illumination=sunAmbientModel.rgb+sunDiffuseModel.rgb*max(dot(normal,sunDir.xyz),0.);
 vec3 colour=pow(max(pow(c.rgb,vec3(2.2))*illumination,vec3(0.)),vec3(1./2.2));
 fragColor=vec4(colour,1.);
}
]]

local function legacyActive()
 if widgetHandler.FindWidget then return widgetHandler:FindWidget(LEGACY)~=nil end
 local known=widgetHandler.knownWidgets and widgetHandler.knownWidgets[LEGACY]
 return known and known.active or false
end
local function blocked(asset)
 return asset.legacyMork and legacyActive()
end
local function remove(id)
 local entry=attached[id];if not entry then return end
 for _,key in ipairs(entry.keys)do iv.popElementInstance(entry.asset.instances,key)end
 attached[id]=nil
end
local function visible(id)
 local _,full=Spring.GetSpectatingState()
 return full or Spring.IsUnitAllied(id)or Spring.IsUnitInLos(id)
end
local function append(dst,src)for _,v in ipairs(src)do dst[#dst+1]=v end end
local function attach(id,asset)
 if attached[id]or blocked(asset)or not visible(id)or Spring.GetUnitIsDead(id)then return end
 local pieces=Spring.GetUnitPieceMap(id);if not pieces then return end
 -- An incompatible model gets no partial draw. Validate all names before
 -- appending even one proxy; piece maps are one-based, shader indices zero-based.
 for _,part in ipairs(asset.cfg.parts)do
  if not pieces[part.piece]then
   local key=asset.name..':'..part.piece
   if not missingWarned[key]then Spring.Echo('FORGE_DEPTH missing native piece',asset.name,part.piece);missingWarned[key]=true end
   return
  end
 end
 local keys={}
 for pi,part in ipairs(asset.cfg.parts)do
  local row={};append(row,part.center)
  for _,axis in ipairs(part.axes)do append(row,axis)end
  append(row,part.size)
  for _,view in ipairs(part.views)do append(row,view.uv)end
  append(row,{pieces[part.piece]-1,0,0,0,0})
  local key=id..'_'..pi
  iv.pushElementInstance(asset.instances,row,key,true,nil,id);keys[#keys+1]=key
 end
 attached[id]={asset=asset,keys=keys}
 Spring.Echo('FORGE_DEPTH native attached',asset.name,id,#keys)
end
local function clearAttached()
 local ids={};for id in pairs(attached)do ids[#ids+1]=id end
 for _,id in ipairs(ids)do remove(id)end
end
local function reconcile()
 local removals={}
 for id,entry in pairs(attached)do
  if not Spring.ValidUnitID(id)or Spring.GetUnitIsDead(id)or not visible(id)
     or defs[Spring.GetUnitDefID(id)]~=entry.asset or blocked(entry.asset)then removals[#removals+1]=id end
 end
 for _,id in ipairs(removals)do remove(id)end
 for _,id in ipairs(Spring.GetAllUnits()or{})do
  local asset=defs[Spring.GetUnitDefID(id)]
  if asset and asset.instances then attach(id,asset)end
 end
 if not legacyWarning and legacyActive()then
  Spring.Echo('FORGE_DEPTH legacy Mork widget active: new Mork draw suppressed; disable old widget during integration')
  legacyWarning=true
 end
end
local function makeLayout()
 local layout={}
 for i,name in ipairs({'center','axisX','axisY','axisZ','bounds','rect0','rect1','rect2','rect3','rect4','rect5'})do
  layout[#layout+1]={id=i,name=name,size=i>=6 and 4 or 3}
 end
 layout[#layout+1]={id=12,name='pieceIndex',type=GL.UNSIGNED_INT,size=1}
 layout[#layout+1]={id=13,name='instData',type=GL.UNSIGNED_INT,size=4}
 return layout
end
function widget:Initialize()
 if not(iv and gl.LuaShader and gl.GetVBO)then widgetHandler:RemoveWidget();return end
 shader=gl.LuaShader.CheckShaderUpdates({vsSrc=VS,fsSrc=FS,shaderName='Forge Ork Depth Volumes',
  uniformInt={atlas=0,depthAtlas=1,normalAtlas=2},uniformFloat={cutoff=.1,thickness=.004},
  shaderConfig={USEQUATERNIONS=Engine.FeatureSupport.transformsInGL4 and '1'or'0'},forceupdate=true})
 if not shader then Spring.Echo('FORGE_DEPTH shader compile failed');widgetHandler:RemoveWidget();return end
 vertices=gl.GetVBO(GL.ARRAY_BUFFER,false);indices=gl.GetVBO(GL.ELEMENT_ARRAY_BUFFER,false)
 if not(vertices and indices)then widgetHandler:RemoveWidget();return end
 vertices:Define(8,{{id=0,name='corner',size=3}})
 vertices:Upload({-.5,-.5,-.5,.5,-.5,-.5,.5,.5,-.5,-.5,.5,-.5,-.5,-.5,.5,.5,-.5,.5,.5,.5,.5,-.5,.5,.5})
 indices:Define(36);indices:Upload({0,2,1,0,3,2,4,5,6,4,6,7,0,1,5,0,5,4,3,7,6,3,6,2,0,4,7,0,7,3,1,2,6,1,6,5})
 for _,asset in ipairs(assets)do
  local instance=iv.makeInstanceVBOTable(makeLayout(),math.max(64,#asset.cfg.parts*4),'ForgeDepth_'..asset.name,13)
  if not instance then Spring.Echo('FORGE_DEPTH instance buffer failed',asset.name);widgetHandler:RemoveWidget();return end
  instance.numVertices=36;instance.vertexVBO=vertices;instance.indexVBO=indices
  instance.VAO=iv.makeVAOandAttach(vertices,instance.instanceVBO,indices);instance.primitiveType=GL.TRIANGLES
  asset.instances=instance
 end
 reconcile();Spring.Echo('FORGE_DEPTH renderer ready',#assets,'asset groups')
end
function widget:Update(dt)
 elapsed=elapsed+dt
 if elapsed>.5 then elapsed=0;if shader then reconcile()end end
end
-- Engine model transforms are ready here, immediately before transparent
-- weapon particles. Writing reconstructed gl_FragDepth preserves occlusion.
function widget:DrawWorldPreParticles(drawAboveWater,drawBelowWater,drawReflection,drawRefraction)
 if drawReflection or drawRefraction or not drawAboveWater or not shader then return end
 if not opaquePassLogged then Spring.Echo('FORGE_DEPTH transforms ready before particles',Spring.GetGameFrame());opaquePassLogged=true end
 gl.PushAttrib(GL.ALL_ATTRIB_BITS)
 gl.Culling(false);gl.DepthTest(GL.LEQUAL);gl.DepthMask(true);gl.Blending(false)
 shader:Activate()
 for _,asset in ipairs(assets)do
  local instance=asset.instances
  if instance and instance.usedElements>0 and not blocked(asset)then
   shader:SetUniform('cutoff',asset.cfg.alphaCutoff or .1)
   shader:SetUniform('thickness',asset.cfg.depthThickness or .004)
   gl.Texture(0,asset.cfg.texture);gl.Texture(1,asset.cfg.depthTexture);gl.Texture(2,asset.cfg.normalTexture)
   iv.drawInstanceVBO(instance)
  end
 end
 shader:Deactivate();gl.Texture(2,false);gl.Texture(1,false);gl.Texture(0,false)
 gl.PopAttrib()
end
function widget:UnitDestroyed(id)if shader then remove(id)end end
function widget:RenderUnitDestroyed(id)if shader then remove(id)end end
function widget:UnitLeftLos(id)if shader and not visible(id)then remove(id)end end
function widget:UnitEnteredLos(id)if shader then local asset=defs[Spring.GetUnitDefID(id)];if asset then attach(id,asset)end end end
function widget:PlayerChanged()if shader then clearAttached();reconcile()end end
function widget:Shutdown()
 attached={}
 for _,asset in ipairs(assets)do
  if asset.instances then asset.instances:Delete();asset.instances=nil end
 end
 if vertices then vertices:Delete();vertices=nil end
 if indices then indices:Delete();indices=nil end
 if shader then shader:Finalize();shader=nil end
end
