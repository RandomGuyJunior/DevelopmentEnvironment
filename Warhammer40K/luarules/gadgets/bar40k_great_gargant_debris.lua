function gadget:GetInfo()
 return{name='Great Gargant breakup wreckage',desc='Ground-origin flat wreckage with planted ankles and one salvage entitlement',author='BAR 40K',layer=0,enabled=true}
end
if not gadgetHandler:IsSyncedCode()then return false end
local config=VFS.Include('luarules/configs/bar40k_great_debris.lua')
local definitions,owned,seen,pending,flights,protected,awaitGroup,groupQueue={},{},{},{},{},{},{},{}
local serial=Spring.GetGameRulesParam("bar40k_great_debris_serial")or 0
local identity={1,0,0,0,1,0,0,0,1}
local pi=math.pi
local function add(a,b)return{a[1]+b[1],a[2]+b[2],a[3]+b[3]}end
local function sub(a,b)return{a[1]-b[1],a[2]-b[2],a[3]-b[3]}end
local function point(r,p)return{r[1]*p[1]+r[2]*p[2]+r[3]*p[3],r[4]*p[1]+r[5]*p[2]+r[6]*p[3],r[7]*p[1]+r[8]*p[2]+r[9]*p[3]}end
local function mul(a,b)local r={};for i=0,2 do for j=1,3 do r[i*3+j]=a[i*3+1]*b[j]+a[i*3+2]*b[3+j]+a[i*3+3]*b[6+j]end end;return r end
local function smooth(t)return t*t*(3-2*t)end
local function yaw(a)local c,s=math.cos(a),math.sin(a);return{c,0,s,0,1,0,-s,0,c}end
local function normalize(q)local l=math.sqrt(q[1]^2+q[2]^2+q[3]^2+q[4]^2);return{q[1]/l,q[2]/l,q[3]/l,q[4]/l}end
local function quaternion(r)
 local trace=r[1]+r[5]+r[9];local q
 if trace>0 then local s=math.sqrt(trace+1)*2;q={s/4,(r[8]-r[6])/s,(r[3]-r[7])/s,(r[4]-r[2])/s}
 elseif r[1]>r[5]and r[1]>r[9]then local s=math.sqrt(1+r[1]-r[5]-r[9])*2;q={(r[8]-r[6])/s,s/4,(r[2]+r[4])/s,(r[3]+r[7])/s}
 elseif r[5]>r[9]then local s=math.sqrt(1+r[5]-r[1]-r[9])*2;q={(r[3]-r[7])/s,(r[2]+r[4])/s,s/4,(r[6]+r[8])/s}
 else local s=math.sqrt(1+r[9]-r[1]-r[5])*2;q={(r[4]-r[2])/s,(r[3]+r[7])/s,(r[6]+r[8])/s,s/4}end
 return normalize(q)
end
local function fromQuaternion(q)
 local w,x,y,z=q[1],q[2],q[3],q[4]
 return{1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w),2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w),2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)}
end
local function groundFrame(angle,x,z)
 -- Match native CSolidObject::UpdateDirVectors(GetSmoothNormal). Flat baked
 -- chunks follow the local floor; their open sides remain buried underneath.
 local ux,uy,uz=Spring.GetGroundNormal(x,z)
 local q=normalize({1+uy,uz,0,-ux})
 return mul(fromQuaternion(q),yaw(angle))
end
local function slerp(a,b,t)
 local dot=0;for i=1,4 do dot=dot+a[i]*b[i]end
 if dot<0 then b={-b[1],-b[2],-b[3],-b[4]};dot=-dot end
 local q={}
 if dot>.9995 then for i=1,4 do q[i]=a[i]+(b[i]-a[i])*t end;return normalize(q)end
 local angle=math.acos(math.max(-1,math.min(1,dot)));local s=math.sin(angle);local x,y=math.sin((1-t)*angle)/s,math.sin(t*angle)/s
 for i=1,4 do q[i]=a[i]*x+b[i]*y end;return normalize(q)
end
local function spin(axis,angle)
 local x,y,z=axis[1],axis[2],axis[3];local c,s=math.cos(angle),math.sin(angle);local t=1-c
 return{c+x*x*t,x*y*t-z*s,x*z*t+y*s,y*x*t+z*s,c+y*y*t,y*z*t-x*s,z*x*t-y*s,z*y*t+x*s,c+z*z*t}
end
local function featureValid(id)return Spring.ValidFeatureID(id)end
local function orient(id,r)
 -- Native ComposeMatrix has model-X=-rightdir, model-Y=updir, model-Z=frontdir.
 Spring.SetFeatureDirection(id,r[3],r[6],r[9],-r[1],-r[4],-r[7])
end
local function clampMap(x,z)return math.max(8,math.min(Game.mapSizeX-8,x)),math.max(8,math.min(Game.mapSizeZ-8,z))end
local function surface(x,z)return Spring.GetGroundHeight(x,z)end
local function setPose(part,p,r)
 if not featureValid(part.id)then return end
 Spring.SetFeaturePosition(part.id,p[1],p[2],p[3],false);orient(part.id,r)
end
local function settle(part)
 if not featureValid(part.id)then return end
 Spring.SetFeatureVelocity(part.id,0,0,0)
 -- These meshes already have their ground contact at localY=0; intentional
 -- burial is geometry below zero, never an origin which native physics lifts.
 -- Keep ordinary native vertical gravity unlocked so late crater deformation
 -- drops the wreck naturally. XZ and all impulses remain locked.
 Spring.SetFeatureMoveCtrl(part.id,false,0,1,0,0,0,0,0,1,0)
 Spring.SetFeatureBlocking(part.id,false,false,true,true,false,false,false)
 protected[part.id]=nil
end
local function create(part,team,frame,shot)
 local id=Spring.CreateFeature(part.feature,part.p[1],part.p[2],part.p[3],0,team)
 if not id then return false end
 part.id=id;awaitGroup[id]=shot
 Spring.SetFeatureRulesParam(id,'great_debris_group',shot.token);Spring.SetFeatureRulesParam(id,'great_debris_definition',shot.definition);Spring.SetFeatureRulesParam(id,'great_debris_origin_x',shot.origin[1]);Spring.SetFeatureRulesParam(id,'great_debris_origin_z',shot.origin[3])
 Spring.SetFeatureMoveCtrl(id,true,0,0,0,0,0,0);Spring.SetFeatureBlocking(id,false,false,false,false,false,false,false)
 Spring.SetFeatureResources(id,part.metal,0,math.max(1,part.metal),1,part.metal,0);Spring.SetFeatureResurrect(id,-1);orient(id,part.r);protected[id]=frame;return true
end
local function enqueue(unit,wreckLevel)
 if seen[unit]then return true end
 local cfg=definitions[Spring.GetUnitDefID(unit)];if not cfg then return false end
 local x,y,z,mx,my,mz=Spring.GetUnitPosition(unit,true);local front,up,right=Spring.GetUnitVectors(unit);local pieces=Spring.GetUnitPieceMap(unit)
 if not(x and front and up and right and pieces)then return false end
 local unitR={-right[1],up[1],front[1],-right[2],up[2],front[2],-right[3],up[3],front[3]}
 local entitlement=wreckLevel>=2 and(cfg.nativeHeapMetal or cfg.heapMetal)or(cfg.nativeWreckMetal or cfg.totalMetal)
 local factor=entitlement/cfg.totalMetal
 local shot={definition=Spring.GetUnitDefID(unit),salvageFeature=cfg.salvageFeature,reclaimScale=cfg.reclaimScale or 1,unit=unit,team=Spring.GetUnitTeam(unit),frame=Spring.GetGameFrame(),origin={x,y,z},middle={mx or x,my or y+100,mz or z},parts={},radius=cfg.scatterRadius or 190,totalMetal=cfg.totalMetal*factor}
 for _,item in ipairs(cfg.parts)do
  local bone=pieces[item.bone];if not bone or not FeatureDefNames[item.feature]then return false end
  local matrix={Spring.GetUnitPieceMatrix(unit,bone)};local px,py,pz=Spring.GetUnitPiecePosDir(unit,bone)
  if #matrix~=16 or not px then return false end
  local localR={matrix[1],matrix[5],matrix[9],matrix[2],matrix[6],matrix[10],matrix[3],matrix[7],matrix[11]};local pieceR=mul(unitR,localR);local r=mul(pieceR,item.bindRotation or identity)
  shot.parts[#shot.parts+1]={feature=item.feature,name=item.name,group=item.stationary and item.name or item.group,stationary=item.stationary,p=add({px,py,pz},point(pieceR,item.center)),r=r,bounds=item.bounds,mid=item.mid or{0,0,0},metal=item.metal*factor}
 end
 for i=1,20 do
  local item=cfg.rubble[(i-1)%#cfg.rubble+1];if not FeatureDefNames[item.feature]then return false end
  local a=i*2.399963229728653;local radius=10+3*(i%5)
  shot.parts[#shot.parts+1]={feature=item.feature,name='rubble'..i,group='rubble'..i,rubble=true,p=add(shot.middle,{math.cos(a)*radius,(i%4-1.5)*4,math.sin(a)*radius}),r=unitR,bounds=item.bounds,mid={0,0,0},metal=(cfg.rubbleMetal or 7500)/20*factor}
 end
 local metal=0;for _,p in ipairs(shot.parts)do metal=metal+p.metal end
 if math.abs(metal-shot.totalMetal)>.01 then return false end
 serial=serial+1;shot.token=serial;Spring.SetGameRulesParam("bar40k_great_debris_serial",serial)
 pending[#pending+1]=shot;seen[unit]=true;return true
end
local function chooseLanding(shot,angle,radius,extent)
 local best,bestScore
 for i=0,11 do
  local a=angle+i*2*pi/12
  for _,factor in ipairs({.65,.82,1})do
   local x,z=clampMap(shot.origin[1]+math.sin(a)*radius*factor,shot.origin[3]+math.cos(a)*radius*factor);local lo,hi=math.huge,-math.huge
   for _,offset in ipairs({{0,0},{extent,0},{-extent,0},{0,extent},{0,-extent},{extent*.7,extent*.7},{-extent*.7,-extent*.7}})do local h=surface(x+offset[1],z+offset[2]);lo=math.min(lo,h);hi=math.max(hi,h)end
   local turn=math.min(i,12-i)*2*pi/12;local score=hi-lo+turn*1.5+(1-factor)*2
   if not bestScore or score<bestScore then best,bestScore={x,z},score end
  end
 end
 return best[1],best[2]
end
local function groupSalvage(shot)
 if shot.grouped then return true end
 if not GG.SquadSalvageGroupFeatures then groupQueue[shot.token]=shot;return false end
 local gid=GG.SquadSalvageGroupFeatures(shot.ids,shot.origin[1],shot.origin[3],shot.team,shot.salvageFeature,shot.reclaimScale)
 if gid==nil then
  -- Feature-cap failure keeps existing individually recoverable salvage. It
  -- never deletes resources or refills the original entitlement.
  for _,id in ipairs(shot.ids)do awaitGroup[id]=nil end
  shot.grouped=true;groupQueue[shot.token]=nil;return false
 end
 for _,id in ipairs(shot.ids)do awaitGroup[id]=nil end
 shot.grouped=true;shot.pool=gid;groupQueue[shot.token]=nil;return true
end
local function start(shot,frame)
 local groups,order={},{};local created={}
 for _,part in ipairs(shot.parts)do
  if not create(part,shot.team,frame,shot)then
   for _,id in ipairs(created)do protected[id]=nil;awaitGroup[id]=nil;if featureValid(id)then Spring.DestroyFeature(id)end end
   Spring.Echo('BAR40K Great Gargant debris: feature creation failed; sequence cancelled');return
  end
  created[#created+1]=part.id;local key=part.group
  if not groups[key]then groups[key]={parts={},stationary=part.stationary,rubble=part.rubble,center={0,0,0}};order[#order+1]=key end
  local g=groups[key];g.parts[#g.parts+1]=part;g.center=add(g.center,add(part.p,point(part.r,part.mid)))
 end
 shot.ids=created;shot.remaining=#order
 for index,key in ipairs(order)do
  local g=groups[key];for j=1,3 do g.center[j]=g.center[j]/#g.parts end
  local a=math.atan2(g.center[1]-shot.origin[1],g.center[3]-shot.origin[3])+((shot.unit*7+index*13)%17/16-.5)*.5
  if g.rubble then a=index*2.399963229728653+shot.unit*.173 end
  local radial=shot.radius*(g.rubble and(.12+(index%10)*.06)or(.50+(index%5)*.07));local extent=g.rubble and 40 or 65
  local tx,tz=chooseLanding(shot,a,radial,extent);if g.stationary then tx,tz=g.parts[1].p[1],g.parts[1].p[3]end
  local base=g.parts[1].r;local fromYaw=math.atan2(base[3],base[9]);local toYaw=fromYaw+(g.stationary and 0 or((shot.unit+index*11)%19/18-.5)*1.2);local turn=yaw(toYaw-fromYaw)
  for _,part in ipairs(g.parts)do
   local offset=sub(part.p,g.center);local flat=point(turn,offset);local x,z=clampMap(tx+flat[1],tz+flat[3]);if g.stationary then x,z=part.p[1],part.p[3]end
   part.target={x,surface(x,z),z};part.fromQ=quaternion(part.r);part.heading=toYaw;part.toQ=quaternion(groundFrame(toYaw,x,z));part.offset=offset
  end
  g.shot=shot;g.start=frame;g.duration=g.stationary and 18 or(g.rubble and 24+(index%5)*3 or 54+(index%4)*5);g.apex=g.stationary and 0 or(g.rubble and 12+(index%4)*4 or 45+(index%4)*10);g.axis={math.cos(a),0,math.sin(a)};flights[#flights+1]=g
 end
end
function gadget:Initialize()
 for name,cfg in pairs(config.units)do if UnitDefNames[name]then
  definitions[UnitDefNames[name].id]=cfg
  if cfg.nativeWreckSalvage then
   local dead,heap=FeatureDefNames[name..'_dead'],FeatureDefNames[name..'_heap']
   cfg.nativeWreckMetal=dead and FeatureDefs[dead.id]and tonumber(FeatureDefs[dead.id].metal)or cfg.totalMetal
   cfg.nativeHeapMetal=heap and FeatureDefs[heap.id]and tonumber(FeatureDefs[heap.id].metal)or cfg.heapMetal
  end
 end
  for _,p in ipairs(cfg.parts)do if FeatureDefNames[p.feature]then owned[FeatureDefNames[p.feature].id]=p end end
  for _,p in ipairs(cfg.rubble)do if FeatureDefNames[p.feature]then owned[FeatureDefNames[p.feature].id]=p end end
 end
 -- Save-load recovery grounds only our existing features, preserving IDs and
 -- partially reclaimed resources. Models are already baked flat around the floor.
 for _,id in ipairs(Spring.GetAllFeatures())do if owned[Spring.GetFeatureDefID(id)]then
  local fx,fy,fz=Spring.GetFeatureDirection(id);local x,y,z=Spring.GetFeaturePosition(id)
  local h=Spring.GetFeatureHeading(id)
  if x and fx then Spring.SetFeaturePosition(id,x,surface(x,z),z,false);orient(id,groundFrame(h and h*2*pi/65536 or math.atan2(fx,fz),x,z))end
  settle({id=id})
  local token=Spring.GetFeatureRulesParam(id,'great_debris_group')
  local owner=Spring.GetFeatureRulesParam(id,'squad_salvage_group')
  if token and token>0 and not(owner and owner>=0 and Spring.ValidFeatureID(owner))then
   serial=math.max(serial,token)
   local def=Spring.GetFeatureRulesParam(id,'great_debris_definition');local cfg=definitions[def]
   if cfg then
    local shot=groupQueue[token]
    if not shot then shot={token=token,definition=def,ids={},origin={Spring.GetFeatureRulesParam(id,'great_debris_origin_x')or x,0,Spring.GetFeatureRulesParam(id,'great_debris_origin_z')or z},team=Spring.GetFeatureTeam(id),salvageFeature=cfg.salvageFeature,reclaimScale=cfg.reclaimScale or 1};groupQueue[token]=shot end
    shot.ids[#shot.ids+1]=id;awaitGroup[id]=shot
   end
  end
 end end
 Spring.SetGameRulesParam("bar40k_great_debris_serial",serial)
 GG.Bar40KGreatDeath={Begin=enqueue}
end
function gadget:UnitCreated(unit)seen[unit]=nil end
function gadget:GameFrame(frame)
 for _,shot in pairs(groupQueue)do groupSalvage(shot)end
 if #pending>0 then local list=pending;pending={};for _,shot in ipairs(list)do start(shot,frame)end end
 for i=#flights,1,-1 do
  local g=flights[i];local t=math.min(1,math.max(0,(frame-g.start)/g.duration));local turn=g.stationary and identity or spin(g.axis,math.sin(pi*t)*(g.rubble and .5 or .85));local blend=smooth(t)
  for _,part in ipairs(g.parts)do
   part.target[2]=surface(part.target[1],part.target[3]);part.toQ=quaternion(groundFrame(part.heading,part.target[1],part.target[3]));local p={}
   for k=1,3 do p[k]=part.p[k]+(part.target[k]-part.p[k])*t end
   local deviation=sub(point(turn,part.offset),part.offset)
   for k=1,3 do p[k]=p[k]+deviation[k]end
   p[2]=p[2]+4*g.apex*t*(1-t)
   setPose(part,p,mul(turn,fromQuaternion(slerp(part.fromQ,part.toQ,blend))))
  end
  if t>=1 then for _,part in ipairs(g.parts)do setPose(part,part.target,fromQuaternion(part.toQ));settle(part)end;g.shot.remaining=g.shot.remaining-1;if g.shot.remaining==0 then groupSalvage(g.shot)end;table.remove(flights,i)end
 end
end
function gadget:FeaturePreDamaged(id,def,team,damage)if protected[id]then return 0,0 end end
function gadget:FeatureDestroyed(id)protected[id]=nil;awaitGroup[id]=nil end
function gadget:AllowFeatureBuildStep(builder,team,id,def,part)if protected[id]or awaitGroup[id]then return false end;return true end
function gadget:Shutdown()
 for _,g in ipairs(flights)do for _,part in ipairs(g.parts)do if featureValid(part.id)then setPose(part,{part.target[1],surface(part.target[1],part.target[3]),part.target[3]},groundFrame(part.heading,part.target[1],part.target[3]));settle(part)end end;g.shot.remaining=g.shot.remaining-1;if g.shot.remaining==0 then groupSalvage(g.shot)end end
 GG.Bar40KGreatDeath=nil
end
