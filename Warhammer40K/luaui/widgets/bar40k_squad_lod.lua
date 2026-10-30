function widget:GetInfo() return {name='Infantry distance detail',desc='Shared medium geometry and distant animated soldiers',author='BAR40K',layer=12,enabled=true} end
local cfg=VFS.Include('luaui/configs/squad_lod.lua')
for _,role in ipairs({'gretchin','shoota','loota','kommando','nob','ardboy','burna','stormboy','dakka','meganob','flashgit','tankbusta','grotcannon','mekgun'}) do
 local path='luaui/configs/orksquad_lod_'..role..'.lua'
 if VFS.FileExists(path) then cfg[role]=VFS.Include(path) end
end
local iv=gl.InstanceVBOTable
local known,resources={},{}
local shaders={}
local types={}
if UnitDefNames.orkslugga then types[UnitDefNames.orkslugga.id]='boy' end
if UnitDefNames.igguards then types[UnitDefNames.igguards.id]='guard' end
for kind,c in pairs(cfg) do if c.unitName and UnitDefNames[c.unitName] then types[UnitDefNames[c.unitName].id]=kind end end
local COMMON=[[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__
//__QUATERNIONDEFS__
layout(location=6) in uvec4 instData;
layout(location=5) in vec4 settings;
out vec2 texUV;
out vec3 worldNormal;
out float fogAmount;
flat out vec2 coverage;
Transform bone(uint b){return Lerp(transforms[instData.x+2u*(1u+b)],transforms[instData.x+2u*(1u+b)+1u],timeInfo.w);}
Transform unitTx(){return Lerp(transforms[instData.x],transforms[instData.x+1u],timeInfo.w);}
]]
local MID=COMMON..[[
layout(location=0)in vec3 pos;
layout(location=1)in vec3 norm;
layout(location=2)in vec2 uv;
layout(location=3)in vec4 joints;
layout(location=4)in vec4 weights;
void main(){
 vec4 p=vec4(0);vec3 n=vec3(0);
 for(int i=0;i<4;i++){if(weights[i]>.0001){Transform b=bone(uint(settings.x-1.+joints[i]));p+=ApplyTransform(b,vec4(pos,1))*weights[i];n+=RotateByQuaternion(b.quat,norm)*weights[i];}}
 Transform u=unitTx();vec4 world=ApplyTransform(u,p);
 gl_Position=cameraViewProj*world;fogAmount=clamp((fogParams.y-length(world.xyz-cameraViewInv[3].xyz))*fogParams.w,0.,1.);worldNormal=RotateByQuaternion(u.quat,n);texUV=uv;coverage=settings.zw;
}
]]
local CARD=COMMON..[[
layout(location=0)in vec2 corner;
layout(location=1)in vec3 center;
layout(location=2)in vec3 right;
layout(location=3)in vec3 up;
layout(location=4)in vec4 rect;
layout(location=7)in vec2 extent;
layout(location=8)in vec3 feet;
layout(location=9)in vec4 motion;
flat out mat3 basis;
void main(){
 float co=cos(settings.x),si=sin(settings.x);mat3 Y=mat3(vec3(co,0,-si),vec3(0,1,0),vec3(si,0,co));
 basis=Y*mat3(vec3(1,0,0),vec3(0,0,-1),vec3(0,1,0));
 Transform root=ApplyTransform(unitTx(),bone(uint(settings.y-1.)));
 vec3 c=ApplyTransform(root,vec4(0,0,0,1)).xyz+basis*center;
 vec3 r=cameraViewInv[0].xyz;vec3 u=cameraViewInv[1].xyz;
 gl_Position=cameraViewProj*vec4(c+r*corner.x*extent.x+u*corner.y*extent.y,1);fogAmount=clamp((fogParams.y-length(c-cameraViewInv[3].xyz))*fogParams.w,0.,1.);
 texUV=rect.xy+vec2(corner.x+.5,.5-corner.y)*rect.zw;worldNormal=vec3(0,1,0);coverage=settings.zw;
}
]]
local SHADOW=COMMON..[[
layout(location=0)in vec2 corner;
layout(location=1)in vec3 ground;
layout(location=2)in vec3 slope;
layout(location=3)in vec3 feet;
layout(location=4)in vec4 motion;
void main(){
 vec3 movingFeet=feet+motion.xyz*clamp(timeInfo.x+timeInfo.w-motion.w,0.,3.);
 vec2 direction=-sunDir.xz/max(sunDir.y,.35);
 vec2 along=length(direction)>.01?normalize(direction):vec2(0,1);
 vec2 across=vec2(along.y,-along.x);
 vec2 p=movingFeet.xz+direction*2.+across*corner.x*5.+along*corner.y*(5.+length(direction)*3.);
 float y=ground.y+dot(p-ground.xz,slope.xy)+.12;
 gl_Position=cameraViewProj*vec4(p.x,y,p.y,1);
 texUV=corner*2.;coverage=settings.zw;worldNormal=vec3(0,1,0);fogAmount=clamp((fogParams.y-length(feet-cameraViewInv[3].xyz))*fogParams.w,0.,1.);
}
]]
local SHADOWFS=[[
#version 420
in vec2 texUV;flat in vec2 coverage;in float fogAmount;
out vec4 fragColor;
void main(){float r=dot(texUV,texUV);if(r>=1.)discard;fragColor=vec4(0,0,0,.38*(1.-smoothstep(.08,1.,r))*coverage.x*fogAmount);}
]]
local FS=[[
#version 420
//__ENGINEUNIFORMBUFFERDEFS__
uniform sampler2D paint,normalTex;
in vec2 texUV;in vec3 worldNormal;in float fogAmount;flat in vec2 coverage;
#ifdef CARD
flat in mat3 basis;
#endif
out vec4 fragColor;
float noise(){return fract(52.9829189*fract(dot(floor(gl_FragCoord.xy),vec2(.06711056,.00583715))));}
vec3 oct(vec2 v){v=v*2.-1.;vec3 n=vec3(v,1.-abs(v.x)-abs(v.y));if(n.z<0.)n.xy=(1.-abs(n.yx))*sign(n.xy+1e-20);return normalize(n);}
void main(){
 float d=noise();if(d>=coverage.x||d<coverage.y)discard;
 vec3 n=normalize(worldNormal);vec4 col;
#ifdef CARD
 vec2 uv=vec2(texUV.x,1.-texUV.y);float lod=clamp(textureQueryLod(paint,uv).x,0.,2.5);col=textureLod(paint,uv,lod);if(col.a<.4)discard;n=normalize(basis*oct(textureLod(normalTex,uv,lod).rg));
#else
 col=texture(paint,vec2(texUV.x,1.-texUV.y));
#endif
 vec3 light=sunAmbientModel.rgb+sunDiffuseModel.rgb*max(dot(n,sunDir.xyz),0.);
 vec3 x=max(col.rgb*light,vec3(0));
 vec3 mapped=(x*(4.85*x+.85))/(x*(3.5*x+.85)+1.);
 fragColor=vec4(mix(fogColor.rgb,mapped*1.2,fogAmount),1);
}
]]
local function smooth(a,b,v) local t=math.max(0,math.min(1,(v-a)/(b-a)));return t*t*(3-2*t) end
local function flat(rows) local t={};for _,r in ipairs(rows)do for _,v in ipairs(r)do t[#t+1]=v end end;return t end
local function append(t,r)for _,v in ipairs(r)do t[#t+1]=v end end
local function setup(kind)
 local c=cfg[kind];local r={};resources[kind]=r
 local v=gl.GetVBO(GL.ARRAY_BUFFER,false);v:Define(#c.vertices,{{id=0,name='pos',size=3},{id=1,name='norm',size=3},{id=2,name='uv',size=2},{id=3,name='joints',size=4},{id=4,name='weights',size=4}});v:Upload(flat(c.vertices))
 local ix=gl.GetVBO(GL.ELEMENT_ARRAY_BUFFER,false);ix:Define(#c.indices);ix:Upload(c.indices)
 local m=iv.makeInstanceVBOTable({{id=5,name='settings',size=4},{id=6,name='instData',size=4,type=GL.UNSIGNED_INT}},256,'InfantryMid'..kind,6)
 m.numVertices=#c.indices;m.vertexVBO=v;m.indexVBO=ix;m.VAO=iv.makeVAOandAttach(v,m.instanceVBO,ix);m.primitiveType=GL.TRIANGLES;r.mid=m
 local q=gl.GetVBO(GL.ARRAY_BUFFER,false);q:Define(4,{{id=0,name='corner',size=2}});q:Upload({-.5,-.5,.5,-.5,-.5,.5,.5,.5})
 local qi=gl.GetVBO(GL.ELEMENT_ARRAY_BUFFER,false);qi:Define(6);qi:Upload({0,1,2,2,1,3})
 local f=iv.makeInstanceVBOTable({{id=1,name='center',size=3},{id=2,name='right',size=3},{id=3,name='up',size=3},{id=4,name='rect',size=4},{id=5,name='settings',size=4},{id=6,name='instData',size=4,type=GL.UNSIGNED_INT},{id=7,name='extent',size=2},{id=8,name='feet',size=3},{id=9,name='motion',size=4}},256,'InfantryFar'..kind,6)
 f.numVertices=6;f.vertexVBO=q;f.indexVBO=qi;f.VAO=iv.makeVAOandAttach(q,f.instanceVBO,qi);f.primitiveType=GL.TRIANGLES;r.far=f
 local s=iv.makeInstanceVBOTable({{id=1,name='ground',size=3},{id=2,name='slope',size=3},{id=3,name='feet',size=3},{id=4,name='motion',size=4},{id=5,name='settings',size=4},{id=6,name='instData',size=4,type=GL.UNSIGNED_INT}},256,'InfantryShadow'..kind,6)
 s.numVertices=6;s.vertexVBO=q;s.indexVBO=qi;s.VAO=iv.makeVAOandAttach(q,s.instanceVBO,qi);s.primitiveType=GL.TRIANGLES;r.shadow=s
 r.buffers={v,ix,q,qi}
end
local function register(id,d)
 local kind=types[d];if not kind or known[id]then return end
 local c=cfg[kind];local map=Spring.GetUnitPieceMap(id);if not map then return end
 local roots,bases={},{}
 for i=1,#c.roots do
  roots[i]=map[c.roots[i]];bases[i]=map[c.memberBones[i][1]]
  if not roots[i]or not bases[i] then return end
  for b,n in ipairs(c.memberBones[i])do if map[n]~=bases[i]+b-1 then Spring.Echo('INFANTRY_LOD noncontiguous bones; retaining full model');return end end
 end
 known[id]={kind=kind,roots=roots,bases=bases,removed=0,far=0}
end
local function restore(id)
 if Spring.ValidUnitID(id)then Spring.SetUnitNoDraw(id,false);gl.SetUnitBufferUniforms(id,{0},14);Spring.SetUnitAlwaysUpdateMatrix(id,false)end
end
function widget:Initialize()
 if not(iv and gl.LuaShader and Engine.FeatureSupport.transformsInGL4) then widgetHandler:RemoveWidget();return end
 shaders.mid=gl.LuaShader.CheckShaderUpdates({vsSrc=MID,fsSrc=FS,shaderName='InfantryMedium',uniformInt={paint=0,normalTex=1},shaderConfig={},forceupdate=true})
 shaders.far=gl.LuaShader.CheckShaderUpdates({vsSrc=CARD,fsSrc=FS:gsub('#version 420','#version 420\n#define CARD'),shaderName='InfantryCards',uniformInt={paint=0,normalTex=1},shaderConfig={},forceupdate=true})
 shaders.shadow=gl.LuaShader.CheckShaderUpdates({vsSrc=SHADOW,fsSrc=SHADOWFS,shaderName='InfantryGroundShadow',shaderConfig={},forceupdate=true})
 if not shaders.mid or not shaders.far or not shaders.shadow then Spring.Echo('INFANTRY_LOD shader failure; original graphics retained');widgetHandler:RemoveWidget();return end
 for kind in pairs(cfg)do setup(kind)end
 for _,id in ipairs(Spring.GetAllUnits())do register(id,Spring.GetUnitDefID(id))end
 WG.InfantryLOD={stats={},force=nil};Spring.Echo('INFANTRY_LOD ready')
end
function widget:UnitCreated(id,d)register(id,d)end
function widget:UnitEnteredLos(id,team,ally,d)register(id,d or Spring.GetUnitDefID(id))end
function widget:UnitDestroyed(id)known[id]=nil end
local lastRefresh=-100;local lastCamera={}
local function refresh()
 local cx,cy,cz=Spring.GetCameraPosition();local now=Spring.GetGameFrame();local cs=Spring.GetCameraState()
 local signature=table.concat({cx,cy,cz,cs.rx or 0,cs.ry or 0,cs.fov or 45,WG.InfantryLOD.force or ''},':')
 if now-lastRefresh<2 and lastCamera.signature==signature then return end
 local elapsed=math.min(.1,math.max(1,now-lastRefresh)/30);lastRefresh=now;lastCamera.signature=signature;
local _,vy=Spring.GetViewGeometry();local cam=Spring.GetCameraState();local focal=vy/(2*math.tan(math.rad(cam.fov or 45)/2));local stats={full=0,medium=0,far=0}
 for _,r in pairs(resources)do iv.clearInstanceTable(r.mid);iv.clearInstanceTable(r.far);iv.clearInstanceTable(r.shadow)end
 local frame=Spring.GetGameFrame()
 for id,k in pairs(known)do
  local _,full=Spring.GetSpectatingState();local visible=Spring.ValidUnitID(id)and not Spring.GetUnitIsDead(id)and (full or Spring.IsUnitAllied(id)or Spring.IsUnitInLos(id))and not Spring.GetUnitTransporter(id)
  local x,y,z=Spring.GetUnitPosition(id)
  if visible and x and Spring.IsUnitInView(id) and not (Spring.IsUnitIcon and Spring.IsUnitIcon(id)) then
   local pixels=(cfg[k.kind].height or 11)*focal/math.max(1,math.sqrt((x-cx)^2+(y-cy)^2+(z-cz)^2))
   local removed=1-smooth(10,16,pixels);local far=1-smooth(2.5,4.5,pixels)
   local force=WG.InfantryLOD.force;if force then removed=force=='full'and 0 or 1;far=force=='far'and 1 or 0 end
   local function ease(old,target)return old+math.max(-elapsed*4,math.min(elapsed*4,target-old))end
   if not force then removed=ease(k.removed,removed);far=ease(k.far,far)end
   far=math.min(far,removed);k.far=far
   local _,_,_,_,build=Spring.GetUnitHealth(id);if (build and build<1)or Spring.GetUnitIsCloaked(id) or y<0 then removed=0;far=0 end
   if math.abs(removed-k.removed)>.00001 then gl.SetUnitBufferUniforms(id,{removed},14);k.removed=removed end
   local hidden=removed>.9999;if hidden~=k.hidden then Spring.SetUnitNoDraw(id,hidden);k.hidden=hidden end
   local update=removed>0;if update~=k.update then Spring.SetUnitAlwaysUpdateMatrix(id,update);k.update=update end
   if removed<.001 then stats.full=stats.full+1 else
    if far>.999 then stats.far=stats.far+1 else stats.medium=stats.medium+1 end
    local c=cfg[k.kind];local r=resources[k.kind];local prefix=c.prefix or (k.kind=='boy'and'tenboy'or'tenguard');local gait=Spring.GetUnitRulesParam(id,prefix..'_gait_phase')or 0
    local vx,vy,vz,speed=Spring.GetUnitVelocity(id);vx,vy,vz,speed=vx or 0,vy or 0,vz or 0,speed or 0;local alive=Spring.GetUnitRulesParam(id,prefix..'_alive')or #c.roots;local mode=Spring.GetUnitRulesParam(id,prefix..'_lod_mode_1')or 0;local shot=Spring.GetUnitRulesParam(id,prefix..'_shotframe')or-1000;local shooter=Spring.GetUnitRulesParam(id,prefix..'_shooter')or 0
    local flightClip,flightTime,flightLoop,flightStagger
    if c.flight and Spring.GetUnitRulesParam(id,'squad_jetpack_airborne')==1 then
     local phase=Spring.GetUnitRulesParam(id,'squad_jetpack_phase')or 1
     local start=Spring.GetUnitRulesParam(id,'squad_jetpack_frame')or frame
     local vertical=Spring.GetUnitRulesParam(id,'squad_jetpack_vertical')or 0
     local key=phase==0 and 'fly_launch'or phase==2 and 'fly_land'or vertical>0 and 'fly_climb'or vertical<0 and 'fly_descend'or 'fly_idle'
     flightClip=c.flight[key];flightTime=(frame-start)/30;flightLoop=phase~=0 and phase~=2;flightStagger=phase==1
    end
    local gy=Spring.GetGroundHeight(x,z)
    local sx=(Spring.GetGroundHeight(x+24,z)-Spring.GetGroundHeight(x-24,z))/48
    local sz=(Spring.GetGroundHeight(x,z+24)-Spring.GetGroundHeight(x,z-24))/48
    for i=1,#c.roots do
     if i<=alive or (Spring.GetUnitRulesParam(id,prefix..'_hidden_'..i)or 0)==0 then
      local key=id*64+i
      local fx,fy,fz=Spring.GetUnitPiecePosDir(id,k.roots[i]);fx,fy,fz=fx or x,fy or y,fz or z
      if i<=alive then iv.pushElementInstance(r.shadow,{x,gy,z,sx,sz,0,fx,fy,fz,vx,vy,vz,frame,0,k.roots[i],removed,0,0,0,0,0},key,true,true,id)end
      local dying=i>alive
      local memberFar=dying and 0 or far
      if memberFar<.9999 then iv.pushElementInstance(r.mid,{k.bases[i],k.roots[i],removed,memberFar,0,0,0,0},key,true,true,id)end
      if memberFar>0 then
       local px,py,pz=x,y,z;local yaw=Spring.GetUnitRulesParam(id,prefix..'_lod_yaw_'..i)or 0
       local view=(math.atan2(cx-px,cz-pz)-yaw)%(2*math.pi);local ny=c.yawCount or 12;local yi=math.floor(view/(2*math.pi/ny)+.5)%ny
       local elev=math.deg(math.atan2(cy-py,math.sqrt((cx-px)^2+(cz-pz)^2)));local ei=elev<40 and 0 or elev<67.5 and 1 or 2
       if c.elevations then ei=0;local nearest=math.huge;for j,e in ipairs(c.elevations)do local delta=math.abs(elev-e);if delta<nearest then ei=j-1;nearest=delta end end end
       local pose=0;if speed>.5 then pose=(mode==2 and 16 or 2)+math.floor((gait+(i-1)*.137)%1*6)elseif mode==2 then pose=k.kind=='guard'and i<=3 and 14 or 1 end
       if mode==3 then pose=8+math.floor((frame/30*.8+i*.137)%1*6)end
       if i==shooter and frame-shot<4 and mode~=3 then pose=k.kind=='guard'and i<=3 and speed<=.5 and 22 or 15 end
       if c.poseMap then pose=c.poseMap[pose+1]end
       if flightClip then
        local t=flightTime/flightClip.duration+(flightStagger and c.memberPhases[i]or 0)
        local index
        if flightLoop then index=math.floor((t%1)*flightClip.count+.5)%flightClip.count
        else index=math.min(flightClip.count-1,math.floor(math.max(0,math.min(1,t))*flightClip.count))end
        pose=flightClip.first+index
       end
       local v=c.views[pose*ny*(c.elevations and #c.elevations or 3)+ei*ny+yi+1];local row={};append(row,v.center);append(row,v.right);append(row,v.up);append(row,v.rect);append(row,{yaw,k.roots[i],far,0,0,0,0,0});append(row,v.extent);append(row,{fx,fy,fz});append(row,{vx,vy,vz,frame})
       iv.pushElementInstance(r.far,row,key,true,true,id)
      end
     end
    end
   end
  else if k.removed>0 or k.hidden then restore(id);k.removed=0;k.hidden=false;k.update=false end end
 end
 for _,r in pairs(resources)do iv.uploadAllElements(r.mid);iv.uploadAllElements(r.far);iv.uploadAllElements(r.shadow)end
 WG.InfantryLOD.stats=stats
end
function widget:DrawWorldPreParticles(above,below,reflection,refraction)
 if not above or reflection or refraction or not shaders.mid then return end
 refresh();gl.PushAttrib(GL.ALL_ATTRIB_BITS);gl.Culling(false);gl.DepthTest(GL.LEQUAL);gl.DepthMask(true);gl.Blending(false)
 gl.AlphaTest(false);gl.DepthMask(false);gl.Blending(GL.SRC_ALPHA,GL.ONE_MINUS_SRC_ALPHA)
 shaders.shadow:Activate()
 for _,r in pairs(resources)do if r.shadow.usedElements>0 then iv.drawInstanceVBO(r.shadow)end end
 shaders.shadow:Deactivate();gl.Blending(false);gl.DepthMask(true)
 for kind,r in pairs(resources)do
  if r.mid.usedElements>0 then shaders.mid:Activate();gl.Texture(0,cfg[kind].texture);iv.drawInstanceVBO(r.mid);shaders.mid:Deactivate()end
  if r.far.usedElements>0 then shaders.far:Activate();gl.Texture(0,':cl:'..cfg[kind].paint);gl.Texture(1,':cl:'..cfg[kind].normal);iv.drawInstanceVBO(r.far);shaders.far:Deactivate()end
 end
 gl.Texture(1,false);gl.Texture(0,false);gl.PopAttrib()
end
function widget:Shutdown()
 for id in pairs(known)do restore(id)end
 for _,r in pairs(resources)do r.mid:Delete();r.far:Delete();r.shadow:Delete();for _,b in ipairs(r.buffers)do b:Delete()end end
 for _,s in pairs(shaders)do if s then s:Finalize()end end
 WG.InfantryLOD=nil
end
