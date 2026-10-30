-- One ground-unit mover temporarily follows a checked arc; member meshes are presentation only.
function gadget:GetInfo() return {name='Stormboy squad jetpack movement',layer=10002,enabled=true} end
if not gadgetHandler:IsSyncedCode() then return end
local mc=Spring.MoveCtrl
local TAG=4034584
local states,units,nextTry={},{},{}
local maxUnitRadius,maxFeatureRadius=0,0
local fps=Game.gameSpeed
local function finite(v)return type(v)=='number'and v==v and v~=math.huge and v~=-math.huge end
local function pointSegmentSquared(px,py,pz,a,b)
 local dx,dy,dz=b[1]-a[1],b[2]-a[2],b[3]-a[3];local n=dx*dx+dy*dy+dz*dz
 local t=n>0 and math.max(0,math.min(1,((px-a[1])*dx+(py-a[2])*dy+(pz-a[3])*dz)/n))or 0
 return (px-a[1]-dx*t)^2+(py-a[2]-dy*t)^2+(pz-a[3]-dz*t)^2
end
local function arc(a,b,t,h)return {a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t+4*h*t*(1-t),a[3]+(b[3]-a[3])*t}end
local function step(a,b,limit)
 local dx,dy,dz=b[1]-a[1],b[2]-a[2],b[3]-a[3];local n=math.sqrt(dx*dx+dy*dy+dz*dz)
 if n<=limit then return b,true end
 return {a[1]+dx/n*limit,a[2]+dy/n*limit,a[3]+dz/n*limit},false
end
local function radius(id,feature)
 local sx,sy,sz,ox,oy,oz
 if feature then sx,sy,sz,ox,oy,oz=Spring.GetFeatureCollisionVolumeData(id)
 else sx,sy,sz,ox,oy,oz=Spring.GetUnitCollisionVolumeData(id)end
 if not (finite(sx)and finite(sy)and finite(sz)and finite(ox)and finite(oy)and finite(oz))then return nil end
 return .5*math.sqrt(sx*sx+sy*sy+sz*sz)+math.sqrt(ox*ox+oy*oy+oz*oz)
end
local function cacheRadius(id,feature)
 local r=radius(id,feature)
 if r then if feature then maxFeatureRadius=math.max(maxFeatureRadius,r)else maxUnitRadius=math.max(maxUnitRadius,r)end end
end
local function canLand(id,p)
 if not(p[1]>0 and p[3]>0 and p[1]<Game.mapSizeX and p[3]<Game.mapSizeZ)then return false end
 local defID=Spring.GetUnitDefID(id);local ground=Spring.GetGroundHeight(p[1],p[3])
 return finite(ground)and ground>=0 and Spring.TestMoveOrder(defID,p[1],ground,p[3],0,0,0,true,true,false)==true
end
local function center(id,p)
 local x,y,z,mx,my,mz=Spring.GetUnitPosition(id,true)
 if not(finite(mx)and finite(my)and finite(mz))then return nil end
 return {p[1]+mx-x,p[2]+my-y,p[3]+mz-z}
end
local function sweep(id,a,b)
 local ra=radius(id,false);local ca,cb=center(id,a),center(id,b)
 if not ra or not ca or not cb then return false end
 -- Swept enclosing collision spheres are conservative for native boxes/cylinders
 -- and rotated offsets. No target, team or scenery is silently excluded.
 local function objects(feature,maxR)
  local pad=ra+maxR
  local x1,z1=math.min(ca[1],cb[1])-pad,math.min(ca[3],cb[3])-pad
  local x2,z2=math.max(ca[1],cb[1])+pad,math.max(ca[3],cb[3])+pad
  local list=feature and Spring.GetFeaturesInRectangle(x1,z1,x2,z2)or Spring.GetUnitsInRectangle(x1,z1,x2,z2)
  table.sort(list)
  for _,other in ipairs(list)do
   if feature or other~=id then
    local blocking,solid
    if feature then blocking,solid=Spring.GetFeatureBlocking(other)else blocking,solid=Spring.GetUnitBlocking(other)end
    if blocking or solid then
     local x,y,z,mx,my,mz
     if feature then x,y,z,mx,my,mz=Spring.GetFeaturePosition(other,true)else x,y,z,mx,my,mz=Spring.GetUnitPosition(other,true)end
     local r=radius(other,feature)
     if not r or not finite(mx)or not finite(my)or not finite(mz)then return false end
     if pointSegmentSquared(mx,my,mz,ca,cb)<(ra+r)^2 then
      local initial=(mx-ca[1])^2+(my-ca[2])^2+(mz-ca[3])^2
      local final=(mx-cb[1])^2+(my-cb[2])^2+(mz-cb[3])^2
      if initial>=(ra+r)^2 or final<initial-.001 then return false end
     end
    end
   end
  end
  return true
 end
 if not objects(false,maxUnitRadius)or not objects(true,maxFeatureRadius)then return false end
 -- Sample terrain under the entire conservative moving envelope, with spacing
 -- at most four elmos, including horizontal radius/footprint margins.
 local length=math.sqrt((b[1]-a[1])^2+(b[2]-a[2])^2+(b[3]-a[3])^2)
 local steps=math.max(1,math.ceil(length/4))
 for n=1,steps do
  local t=n/steps;local x,y,z=a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t,a[3]+(b[3]-a[3])*t
  local ground=Spring.GetGroundHeight(x,z)
  if not finite(ground)or ground>y+.01 then return false end
  local terrainFootprint
  for _,offset in ipairs({{0,0},{ra,0},{-ra,0},{0,ra},{0,-ra}})do
   if x+offset[1]<=0 or z+offset[2]<=0 or x+offset[1]>=Game.mapSizeX or z+offset[2]>=Game.mapSizeZ then return false end
   if Spring.GetGroundHeight(x+offset[1],z+offset[2])>y+.01 then
    -- Native grounded infantry already stands on legal gradients despite an
    -- upright foot plane. Only native full-footprint terrain legality permits
    -- this near-ground variation; cliffs/non-walkable squares remain refused.
    if terrainFootprint==nil then terrainFootprint=Spring.TestMoveOrder(Spring.GetUnitDefID(id),x,ground,z,0,0,0,true,false,false)==true end
    if not terrainFootprint then return false end
   end
  end
 end
 return true
end

local function stamp(id,s,phase,frame)
 s.phase=phase;s.phaseFrame=frame
 Spring.SetUnitRulesParam(id,'squad_jetpack_phase',phase,{inlos=true})
 Spring.SetUnitRulesParam(id,'squad_jetpack_frame',frame,{inlos=true})
end
local function currentGoal(id)
 local cmd,opts,tag,p1,p2,p3=Spring.GetUnitCurrentCommand(id)
 if (cmd==CMD.MOVE or cmd==CMD.FIGHT or cmd==CMD.PATROL)and finite(p1)and finite(p3)then return {p1,Spring.GetGroundHeight(p1,p3),p3},cmd,tag end
 if cmd==34583 and p1 and not p2 and Spring.ValidUnitID(p1) and not Spring.GetUnitIsDead(p1)then
  local los=Spring.GetUnitLosState(p1,Spring.GetUnitAllyTeam(id));if not(los and los.los)then return end
  local cp=Spring.GetUnitRulesParam(id,'squad_combat_focus')
  if cp~=1 then return end -- ranged attacks keep their native firing-distance behaviour
  local x,y,z=Spring.GetUnitPosition(id);local tx,ty,tz=Spring.GetUnitPosition(p1)
  local dx,dz=tx-x,tz-z;local d=math.sqrt(dx*dx+dz*dz)
  if d<=65 then return end
  return {tx-dx/d*48,Spring.GetGroundHeight(tx-dx/d*48,tz-dz/d*48),tz-dz/d*48},cmd,tag
 end
end
local function usable(id)
 local stunned,building=Spring.GetUnitIsStunned(id);local _,_,_,_,progress=Spring.GetUnitHealth(id)
 return not stunned and not building and progress and progress>=1 and not Spring.GetUnitTransporter(id) and not mc.IsEnabled(id)
end
local function prepare(id,goal,cmd,tag)
 if not usable(id)then return end
 local x,y,z=Spring.GetUnitPosition(id);local a={x,y,z};local dx,dz=goal[1]-x,goal[3]-z;local d=math.sqrt(dx*dx+dz*dz)
 if d<128 then return end
 local reach=math.min(320,d);local b={x+dx/d*reach,0,z+dz/d*reach};b[2]=Spring.GetGroundHeight(b[1],b[3])
 -- Fixed bounded endpoint search: shorter hops retain native pathfinding if none is safe.
 for _,fraction in ipairs({1,.75,.5})do
  local endpoint={a[1]+(b[1]-a[1])*fraction,0,a[3]+(b[3]-a[3])*fraction};endpoint[2]=Spring.GetGroundHeight(endpoint[1],endpoint[3])
  if reach*fraction>=80 and canLand(id,endpoint)then
   for _,height in ipairs({96,160})do
    local count=math.max(8,math.ceil(reach*fraction/12));local previous=a;local clear=true
    for n=1,count do local p=arc(a,endpoint,n/count,height);if not sweep(id,previous,p)then clear=false;break end;previous=p end
    if clear then return {a=a,b=endpoint,height=height,frames=math.max(15,math.ceil(reach*fraction/150*fps),math.ceil(4*height/6)),position=a,history={a},cmd=cmd,tag=tag,team=Spring.GetUnitTeam(id)}end
   end
  end
 end
end
local function finish(id,s,frame)
 if mc.IsEnabled(id)and mc.GetTag(id)==TAG then
  mc.SetVelocity(id,0,0,0);mc.SetNoBlocking(id,false);mc.Disable(id)
  -- Ground forced-move at the SAME landed XZ rebuilds native blocking registration.
  if s.phase==2 and not Spring.GetUnitTransporter(id)then Spring.SetUnitPosition(id,s.position[1],s.position[3])end
 end
 states[id]=nil;nextTry[id]=frame+45
 Spring.SetUnitRulesParam(id,'squad_jetpack_airborne',0,{inlos=true})
 Spring.SetUnitRulesParam(id,'squad_jetpack_vertical',0,{inlos=true})
 Spring.SetUnitRulesParam(id,'squad_jetpack_recovering',0,{inlos=true})
end
local function begin(id,s,frame)
 -- Persist only this controller's checked route. A reload recovers to ground
 -- without taking over another controller or rewriting the native order queue.
 for k=1,3 do
  Spring.SetUnitRulesParam(id,'squad_jetpack_origin_'..k,s.a[k],{private=true})
  Spring.SetUnitRulesParam(id,'squad_jetpack_goal_'..k,s.b[k],{private=true})
 end
 Spring.SetUnitRulesParam(id,'squad_jetpack_arc_height',s.height,{private=true})
 Spring.SetUnitRulesParam(id,'squad_jetpack_arc_frames',s.frames,{private=true})
 mc.Enable(id);mc.SetTag(id,TAG);mc.SetExtrapolate(id,false);mc.SetGravity(id,0);mc.SetTrackGround(id,false);mc.SetVelocity(id,0,0,0);mc.SetNoBlocking(id,true)
 mc.SetHeading(id,Spring.GetHeadingFromVector(s.b[1]-s.a[1],s.b[3]-s.a[3]))
 states[id]=s;stamp(id,s,0,frame)
 Spring.SetUnitRulesParam(id,'squad_jetpack_airborne',1,{inlos=true})
 if GG.SquadMelee then GG.SquadMelee[id]=nil end
end
local function move(id,s,p)
 local old=s.position;local vy=p[2]-old[2]
 mc.SetVelocity(id,p[1]-old[1],vy,p[3]-old[3]);mc.SetPosition(id,p[1],p[2],p[3]);s.position=p
 Spring.SetUnitRulesParam(id,'squad_jetpack_vertical',vy>.02 and 1 or vy<-.02 and -1 or 0,{inlos=true})
end
local function land(id,s,frame)stamp(id,s,2,frame);mc.SetVelocity(id,0,0,0);mc.SetNoBlocking(id,false)end
local function recover(id,s,frame)
 local p=s.position;local down={p[1],Spring.GetGroundHeight(p[1],p[3]),p[3]}
 if canLand(id,down)then
  local q,reached=step(p,down,5)
  if sweep(id,p,q)then move(id,s,q);if reached then land(id,s,frame)end;return end
 end
 if #s.history>1 then
  local q,reached=step(p,s.history[#s.history-1],5)
  if sweep(id,p,q)then move(id,s,q);if reached then table.remove(s.history)end;return end
 end
 -- All searches and motion steps are bounded. If even the previously clear
 -- route becomes blocked, hold safely and retry instead of teleporting through it.
 mc.SetVelocity(id,0,0,0)
end
function gadget:GameFrame(frame)
 for id in pairs(units)do
  local s=states[id]
  if s then
   if not mc.IsEnabled(id)or mc.GetTag(id)~=TAG then finish(id,s,frame)
   elseif Spring.GetUnitTransporter(id)then finish(id,s,frame)
   else
    local cmd,_,tag=Spring.GetUnitCurrentCommand(id)
    local stunned=Spring.GetUnitIsStunned(id)
    if s.phase~=2 and(cmd~=s.cmd or tag~=s.tag or Spring.GetUnitTeam(id)~=s.team or stunned)then
     if s.phase~=3 then stamp(id,s,3,frame);Spring.SetUnitRulesParam(id,'squad_jetpack_recovering',1,{inlos=true})end
    end
    if s.phase==3 then recover(id,s,frame)
    elseif s.phase==0 and frame-s.phaseFrame>=math.ceil(.433*fps)then stamp(id,s,1,frame)
    elseif s.phase==1 then
     local t=math.min(1,(frame-s.phaseFrame)/s.frames);local p=arc(s.a,s.b,t,s.height)
     if not sweep(id,s.position,p)or(t==1 and not canLand(id,p))then stamp(id,s,3,frame);Spring.SetUnitRulesParam(id,'squad_jetpack_recovering',1,{inlos=true});recover(id,s,frame)
     else move(id,s,p);s.history[#s.history+1]=p;if t==1 then land(id,s,frame)end end
    elseif s.phase==2 and frame-s.phaseFrame>=math.ceil(.767*fps)then finish(id,s,frame)end
   end
  elseif frame>=(nextTry[id]or 0)and frame%15==id%15 then
   nextTry[id]=frame+30
   local goal,cmd,tag=currentGoal(id)
   if goal then local plan=prepare(id,goal,cmd,tag);if plan then begin(id,plan,frame)end end
  end
 end
end
local function register(id,def)
 cacheRadius(id,false)
 if UnitDefs[def].customParams.squad_jetpack then units[id]=true end
end
function gadget:Initialize()
 for _,id in ipairs(Spring.GetAllUnits())do register(id,Spring.GetUnitDefID(id))end
 for _,id in ipairs(Spring.GetAllFeatures())do cacheRadius(id,true)end
 for id in pairs(units)do
  if mc.IsEnabled(id)and mc.GetTag(id)==TAG then
   local x,y,z=Spring.GetUnitPosition(id);local current={x,y,z};local a,b={},{}
   for k=1,3 do a[k]=Spring.GetUnitRulesParam(id,'squad_jetpack_origin_'..k);b[k]=Spring.GetUnitRulesParam(id,'squad_jetpack_goal_'..k)end
   local h=Spring.GetUnitRulesParam(id,'squad_jetpack_arc_height');local frames=Spring.GetUnitRulesParam(id,'squad_jetpack_arc_frames')
   local history={current}
   if finite(a[1])and finite(a[2])and finite(a[3])and finite(b[1])and finite(b[2])and finite(b[3])and finite(h)and h>=0 and h<=160 and finite(frames)and frames>=1 and frames<=200 then
    local dx,dz=b[1]-a[1],b[3]-a[3];local d=dx*dx+dz*dz
    local t=d>0 and math.max(0,math.min(1,((x-a[1])*dx+(z-a[3])*dz)/d))or 0
    history={a}
    for n=1,math.min(200,math.floor(t*frames))do history[#history+1]=arc(a,b,n/frames,h)end
    history[#history+1]=current
   end
   local cmd,_,tag=Spring.GetUnitCurrentCommand(id)
   local s={position=current,history=history,cmd=cmd,tag=tag,team=Spring.GetUnitTeam(id)}
   states[id]=s;stamp(id,s,3,Spring.GetGameFrame())
   Spring.SetUnitRulesParam(id,'squad_jetpack_airborne',1,{inlos=true})
   Spring.SetUnitRulesParam(id,'squad_jetpack_recovering',1,{inlos=true})
  end
 end
end
function gadget:UnitCreated(id,def)register(id,def)end
function gadget:UnitFinished(id)cacheRadius(id,false)end
function gadget:FeatureCreated(id)cacheRadius(id,true)end
function gadget:UnitDestroyed(id)states[id]=nil;units[id]=nil;nextTry[id]=nil end
function gadget:Shutdown()
 for id,s in pairs(states)do if Spring.ValidUnitID(id)then finish(id,s,Spring.GetGameFrame())end end
end
