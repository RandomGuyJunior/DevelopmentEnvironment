function gadget:GetInfo()return{name='40K real infantry squads',desc='Paid fixed squads, native orders and builder casualty repair',author='Local project',layer=40,enabled=true}end
if not gadgetHandler:IsSyncedCode()then return false end
local options=Spring.GetModOptions()or{}
if not VFS.Include('40k_configs/four_faction_playtest.lua').Enabled(options)then return false end
local S=Spring;local profiles=VFS.Include('40k_configs/active_squad_profiles.lua');local R;local formation
local fixture=VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(options.prototype_squad_fixture)
local REPAIR=34591;local builders={};local redirect=false;local forwarding=false;local repairing={};local researched={};local dirty={};local fixtureBlocked={}
local product,internal={},{}
for id,d in pairs(UnitDefs)do
 local cp=d.customParams or{}
 if cp.prototype40k_squad_product then product[id]=cp.prototype40k_squad_product end
 if tonumber(cp.prototype40k_squad_internal or 0)==1 then internal[id]=true end
end
if not next(product)then return false end
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
-- Native valid IDs can still refer to deferred-dead bodies until deletion.
assert(type(S.ValidUnitID)=='function'and type(S.GetUnitIsDead)=='function','native squad liveness API unavailable')
local function nativeAlive(id)
 return finite(id)and id>=0 and id==math.floor(id)and S.ValidUnitID(id)==true and S.GetUnitIsDead(id)==false
end
local function discard(id)if nativeAlive(id)then S.DestroyUnit(id,false,true)end end
local function live(id,team)
 if not nativeAlive(id)then return false end
 local hp,_,_,_,p=S.GetUnitHealth(id)
 return finite(hp)and hp>0 and finite(p)and p>=1 and(team==nil or S.GetUnitTeam(id)==team)
end
local function role(key,slot,upgrade)local p=profiles.profiles[key];return slot==p.specialSlot and upgrade and p.special or p.member end
local function cost(name)local d=UnitDefNames[name];return{metal=d.metalCost,energy=d.energyCost,work=d.buildTime}end
local function position(id)return S.GetUnitPosition(id)end
local function definition(id)
 local name=UnitDefs[S.GetUnitDefID(id)].name
 for _,p in pairs(profiles.profiles)do if name==p.product then return p.member end end
 return name
end
local function isResearched(team,key)local research=profiles.profiles[key].research;return research and S.GetTeamRulesParam(team,'40k_research_'..research)==1 or false end
local function put(id,k,v)S.SetUnitRulesParam(id,'40k_squad_'..k,v,{allied=true})end
local function plan(origin,names,reservations,factory)
 local x,y,z=position(origin);if not x then return end
 local chosen={};local occupied={}
 for pending,row in pairs(reservations or{})do if pending~=origin then for _,p in ipairs(row.plan)do occupied[#occupied+1]=p end end end
 -- Births stay on the local native factory pad; no jumps beyond hostile blockers.
 local offsets={{24,0},{0,24},{-24,0},{0,-24},{24,24},{-24,24},{24,-24},{-24,-24},{40,0},{0,40},{-40,0},{0,-40}}
 -- Use this actual native yard, rather than assuming the Marine donor size.
 -- Larger source huts otherwise cannot deliver all their paid real members.
 if factory then
  local fd=UnitDefs[S.GetUnitDefID(factory)];local fx,_,fz=position(factory)
  if not fd or not fx then return end
  local rx,rz=64,64
  for _,name in ipairs(names)do
   local d=UnitDefs[UnitDefNames[name].id]
   rx=math.max(rx,(fd.xsize or 0)*4+(d.xsize or 2)*4+8)
   rz=math.max(rz,(fd.zsize or 0)*4+(d.zsize or 2)*4+8)
  end
  for _,p in ipairs({{rx,0},{0,rz},{-rx,0},{0,-rz},{rx,rz},{-rx,rz},{rx,-rz},{-rx,-rz}})do
   offsets[#offsets+1]={fx-x+p[1],fz-z+p[2]}
  end
 end
 for _,name in ipairs(names)do
  local d=UnitDefNames[name];local selected
  for _,off in ipairs(offsets)do
   local px,pz=x+off[1],z+off[2];local py=S.GetGroundHeight(px,pz)
   local state,feature=S.TestBuildOrder(d.id,px,py,pz,0)
   local okay=px>16 and pz>16 and px<Game.mapSizeX-16 and pz<Game.mapSizeZ-16 and state and state>=2 and not feature
   if okay then for _,id in ipairs(S.GetUnitsInCylinder(px,pz,16)or{})do if id~=origin and id~=factory then okay=false;break end end end
   if okay then for _,p in ipairs(occupied)do if (p[1]-px)^2+(p[3]-pz)^2<24^2 then okay=false;break end end end
   if okay then selected={px,py,pz};break end
  end
  if not selected then return end
  chosen[#chosen+1]=selected;occupied[#occupied+1]=selected
 end
 return chosen
end
local function orders(id,queue,renewGoal)
 if queue then
  local squad=formation and R and R.Get(id)
  if squad then queue=formation.FilterQueue(squad,id,queue)end
  if renewGoal then local head=queue[1];local p=head and head.params or{}
   if not squad or id~=squad.leader or not live(id,squad.team)or not head or head.id~=CMD.MOVE or not finite(p[1])or not finite(p[2])or not finite(p[3])then return false end
  end
  local previous=forwarding;forwarding=true
  S.GiveOrderToUnit(id,CMD.STOP,{},0)
  if renewGoal then
   -- STOP may retain a completed native goal/atGoal cache. Reset only the
   -- real leader's standard routed goal before exact replay, without a second
   -- STOP or raw follower path. Eight is stock SQUARE_SIZE MOVE goal radius.
   local p=queue[1].params;S.SetUnitMoveGoal(id,p[1],p[2],p[3],8,nil,false)
   local md=S.GetUnitMoveTypeData(id)
   if not md or md.name~='ground'or md.progressState~='active'or not finite(md.goalx)or not finite(md.goalz)or math.abs(md.goalx-p[1])>.001 or math.abs(md.goalz-p[3])>.001 then forwarding=previous;return false end
  end
  for _,row in ipairs(queue)do if row.id>=0 then S.GiveOrderToUnit(id,row.id,row.params or{},(row.options and row.options.coded or 0)+((row.options and row.options.shift)and 0 or CMD.OPT_SHIFT))end end
  forwarding=previous
  if squad and id~=squad.leader then formation.Changed(squad,id)end
  if renewGoal then return true end
  return
 end
 return S.GetUnitCommands(id,-1)or{}
end
local function inheritState(id,from)
 local states=type(from)=='table'and from or S.GetUnitStates(from);if not states then return end
 local previous=forwarding;forwarding=true
 if CMD.FIRE_STATE and states.firestate~=nil then S.GiveOrderToUnit(id,CMD.FIRE_STATE,{states.firestate},0)end
 if CMD.MOVE_STATE and states.movestate~=nil then S.GiveOrderToUnit(id,CMD.MOVE_STATE,{states.movestate},0)end
 forwarding=previous
end
local function replace(old,name,team)
 if S.GetUnitTransporter(old)then return end -- Retry after native unloading.
 local x,y,z=position(old);if not x or not live(old,team)then return end
 local hp,max=S.GetUnitHealth(old);local xp=S.GetUnitExperience(old)or 0;local q=orders(old);local heading=S.GetUnitHeading(old);local states=S.GetUnitStates(old)
 -- Native Euler yaw has opposite heading handedness and inverse-angle rounding.
 -- Preserve the exact signed heading and actual terrain up vector directly.
 if not S.SetUnitHeadingAndUpDir or not S.GetUnitVectors or type(heading)~='number'or heading~=math.floor(heading)or heading< -32768 or heading>32767 then return end
 local _,up=S.GetUnitVectors(old)
 if type(up)~='table'or not finite(up[1])or not finite(up[2])or not finite(up[3])or up[1]^2+up[2]^2+up[3]^2<1e-8 then return end
 local blocking={S.GetUnitBlocking(old)};S.SetUnitBlocking(old,false)
 local new=S.CreateUnit(name,x,y,z,0,team,false,false)
 if not new or not live(new,team)or not live(old,team)then
  if new then discard(new)end
  if nativeAlive(old)then S.SetUnitBlocking(old,unpack(blocking))end;return
 end
 S.SetUnitExperience(new,xp);local _,newmax=S.GetUnitHealth(new);S.SetUnitHealth(new,{health=math.min(newmax,newmax*hp/max)})
 if fixture then local h,m=S.GetUnitHealth(new);S.Echo('40K_SQUAD_NATIVE MODEL_SWAP','old_fraction',hp/max,'new_fraction',h/m,'old_xp',xp,'new_xp',S.GetUnitExperience(new))end
 S.SetUnitHeadingAndUpDir(new,heading,up[1],up[2],up[3])
 if not live(old,team)or not live(new,team)or S.GetUnitHeading(new)~=heading then discard(new);if nativeAlive(old)then S.SetUnitBlocking(old,unpack(blocking))end;return end
 local squad=R.Get(old);local replacementOrders=formation and squad and formation.FilterQueue(squad,old,q)or q
 S.DestroyUnit(old,false,true);orders(new,replacementOrders)
 inheritState(new,states)
 return new
end
local P={Live=live,Role=role,Definition=definition,Cost=cost,Plan=plan,
 Team=S.GetUnitTeam,Transfer=function(id,team)S.TransferUnit(id,team,false)end,
 Create=function(name,team,p,builder)return S.CreateUnit(name,p[1],p[2],p[3],0,team,false,false,nil,builder)end,
 Destroy=discard,Replace=replace,
 Use=function(team,m,e)return S.UseTeamResource(team,{metal=m,energy=e})end,
 Health=function(id,value)if value then S.SetUnitHealth(id,{health=value});return end;return S.GetUnitHealth(id)end,
 Experience=function(id,value)if value~=nil then S.SetUnitExperience(id,value)end;return S.GetUnitExperience(id)end,
 Capacity=function(team,n)return (S.GetTeamUnitCount(team)or 0)+n<=(S.GetTeamMaxUnits(team)or 0)end,
 Researched=isResearched,Orders=orders,InheritState=inheritState,Allied=S.AreTeamsAllied,Transported=S.GetUnitTransporter,
 Busy=function(id)return(GG.Recoil40KSquadTransport and GG.Recoil40KSquadTransport.Busy(id))or(GG.Recoil40KAssaultJump and GG.Recoil40KAssaultJump.Busy(id))or false end,
 SetInvestment=function(id,c)S.SetUnitCosts(id,{metalCost=c.metal,energyCost=c.energy,buildTime=c.work})end,
 Serial=function(value)if value then S.SetGameRulesParam('40k_squad_serial',value);return value end;return S.GetGameRulesParam('40k_squad_serial')or 0 end,
 Publish=function(id,s,slot,n,h,max)
  for k,v in pairs({id=s.id,slot=slot,leader=s.leader,living=n,capacity=profiles.profiles[s.profile].capacity,health=h,maxhealth=max,generation=s.generations[slot],profile=profiles.profiles[s.profile].id,owner=s.team,special=isResearched(s.team,s.profile)and 1 or 0})do put(id,k,v)end
  local j=R and R.repair[s.id]
  for k,value in pairs(s.investments[slot])do put(id,'investment_'..k,value)end
  put(id,'schema',R.Version)
  if formation then formation.Changed(s)end
  -- Every survivor carries missing-slot history: corpses retain those identities.
  for savedSlot=1,profiles.profiles[s.profile].capacity do put(id,'slot_generation_'..savedSlot,s.generations[savedSlot]or 0)end
  for k,v in pairs({repair_slot=j and j.slot or 0,repair_def=j and UnitDefNames[j.def].id or 0,repair_work=j and j.work or 0,repair_metal=j and j.metal or 0,repair_energy=j and j.energy or 0})do put(id,k,v)end
 end,
 FactoryOrders=function(factory,id)
  if formation then formation.Factory(R.Get(id),factory,false)end
  if factory then for _,member in ipairs(R.Members(id))do put(member,'movement_factory',factory);put(member,'movement_factory_released',0)end end
  local q=orders(id);if #q>0 then return q end
  if factory then return orders(factory)end
  return{}
 end}
-- Shared formation owns travel only; the native paid squad/combat owner remains.
local formationStates={}
for _,name in ipairs({'FIRE_STATE','MOVE_STATE','REPEAT','IDLEMODE','CLOAK'})do if CMD[name]then formationStates[CMD[name]]=true end end
local compact=VFS.Include('40k_configs/ork_compact_squad_formation.lua') -- geometry constants only; its old arrival owner is not instantiated.
local egressGeometry=VFS.Include('40k_configs/guard_factory_egress_geometry.lua') -- native yard/collision union, shared with physical exit checks.
local formationAvailable=true
for _,name in ipairs({'GetUnitMoveTypeData','SetUnitMoveGoal','ClearUnitGoal','GetUnitHeading','GetHeadingFromVector','GetUnitVectors','GetUnitVelocity','GetUnitIsStunned','GetUnitStates','GetUnitCollisionVolumeData','GetUnitBuildFacing','SetUnitHeadingAndUpDir','TestMoveOrder','GetUnitsInRectangle','GetUnitBlocking','GetFeaturesInRectangle','GetFeatureBlocking','GetUnitWeaponTarget'})do
 if type(S[name])~='function'then formationAvailable=false end
end
formationAvailable=formationAvailable and S.MoveCtrl and type(S.MoveCtrl.SetGroundMoveTypeData)=='function'and type(S.MoveCtrl.IsEnabled)=='function'or false
local function token(id)
 local squad=R and R.Get(id);local member=R and R.member[id]
 if not squad or not member or not nativeAlive(id)then return end
 return squad.id..':'..member.slot..':'..tostring(squad.generations[member.slot])..':'..tostring(S.GetUnitDefID(id))
end
local function releaseGoal(id,goal)
 if not goal or token(id)~=goal.token or S.MoveCtrl.IsEnabled(id)then return end
 local md=S.GetUnitMoveTypeData(id)
 if md and md.name=='ground'and finite(md.goalx)and finite(md.goalz)and math.abs(md.goalx-goal.x)<.001 and math.abs(md.goalz-goal.z)<.001 then S.ClearUnitGoal(id,false)end
end
formation=VFS.Include('40k_configs/squad_movement_formation.lua').New({
 MOVE=CMD.MOVE,FIGHT=CMD.FIGHT,PATROL=CMD.PATROL,GUARD=CMD.GUARD,STOP=CMD.STOP,WAIT=CMD.WAIT,ATTACK=CMD.ATTACK,INSERT=CMD.INSERT,REMOVE=CMD.REMOVE,
 Available=function()return formationAvailable end,
 StateCommand=function(cmd)return formationStates[cmd]==true end,
 Profile=function(key)return profiles.profiles[key]end,
 Members=function(id)return R.Members(id)end,Squad=function(id)return R.Get(id)end,
 Definition=function(id)return UnitDefs[S.GetUnitDefID(id)]end,
 Token=token,Live=live,Position=position,Ground=S.GetGroundHeight,
 Queue=function(id)return S.GetUnitCommands(id,-1)end,
 Head=function(id)return(S.GetUnitCommands(id,1)or{})[1]end,
 MoveData=function(id)return formationAvailable and S.GetUnitMoveTypeData(id)or nil end,
 Busy=function(id)return S.GetUnitTransporter(id)or P.Busy(id)or S.MoveCtrl.IsEnabled(id)or(select(1,S.GetUnitIsStunned(id))==true)end,
 Envelope=function(id,d,key)
  local profile=profiles.profiles[key];local row=compact.Body(d)
  local lateral=math.max(profile.spacing or 20,(d.xsize or 2)*8+2)
  local longitudinal=math.max(profile.spacing or 20,(d.zsize or 2)*8+2)
  if row then lateral=math.max(lateral,row.width+2);longitudinal=math.max(longitudinal,row.depth+2)end
  -- Mobile collision uses the native MoveDef footprint radius, not the
  -- potentially smaller authored model/UnitDef footprint. Keep a small
  -- clearance and the real model radius as a reversible visual floor.
  local move=d.moveDef;local diameter=0
  if move and finite(move.xsize)and finite(move.zsize)then diameter=math.max(move.xsize,move.zsize)*8 end
  local radius=type(S.GetUnitRadius)=='function'and S.GetUnitRadius(id)
  if finite(radius)and radius>0 then diameter=math.max(diameter,radius*2)end
  if diameter>0 then lateral=math.max(lateral,diameter+2);longitudinal=math.max(longitudinal,diameter+2)end
  return lateral,longitudinal
 end,
 Direction=function(id)
  -- Formation follows the existing route tangent, not incidental collision
  -- velocity. Switching direction source when pacing reaches zero rotates
  -- local slots precisely when the bodies are trying to regroup.
  local md=S.GetUnitMoveTypeData(id);local x,_,z=position(id);local n
  if md and finite(md.currwaypointx)and finite(md.currwaypointz)and x then local dx,dz=md.currwaypointx-x,md.currwaypointz-z;n=math.sqrt(dx*dx+dz*dz);if n>.01 then return dx/n,dz/n end end
  local vx,_,vz=S.GetUnitVelocity(id);n=finite(vx)and finite(vz)and math.sqrt(vx*vx+vz*vz)or 0
  if n>.01 then return vx/n,vz/n end
  local front=S.GetUnitVectors(id);if type(front)~='table'then return end;n=math.sqrt(front[1]^2+front[3]^2);if n<.001 then return end;return front[1]/n,front[3]/n
 end,
 Facing=function(id,dx,dz)local _,up=S.GetUnitVectors(id);return S.GetHeadingFromVector(dx,dz),up end,
 Combat=function(id)
  local d=UnitDefs[S.GetUnitDefID(id)]
  for n in ipairs(d and d.weapons or{})do local targetType=S.GetUnitWeaponTarget(id,n);if targetType~=0 and targetType~=nil then return true end end
  return false
 end,
 Clear=function(id,x,y,z,own)
  local d=UnitDefs[S.GetUnitDefID(id)];local rx,rz=(d.xsize or 2)*4+2,(d.zsize or 2)*4+2
  if x<=rx or z<=rz or x>=Game.mapSizeX-rx or z>=Game.mapSizeZ-rz then return false end
  -- Native full-footprint terrain check, plus native blocking facts excluding
  -- only this same formation. GroundMoveType collision remains enabled.
  if S.TestMoveOrder(d.id,x,y,z,0,0,0,true,false,false)~=true then return false end
  for _,other in ipairs(S.GetUnitsInRectangle(x-rx,z-rz,x+rx,z+rz)or{})do
   if not own[other]and S.GetUnitBlocking(other)~=false then return false end
  end
  for _,feature in ipairs(S.GetFeaturesInRectangle(x-rx,z-rz,x+rx,z+rz)or{})do if S.GetFeatureBlocking(feature)~=false then return false end end
  return true
 end,
 RawGoal=function(id,x,y,z,radius)S.SetUnitMoveGoal(id,x,y,z,radius,nil,true)end,
 ReleaseGoal=releaseGoal,
 BeginFollow=function(id,seed,leader)
  local q=S.GetUnitCommands(id,1);if q and q[1]and q[1].id==34592 and q[1].params[1]==seed and q[1].params[2]==leader then return end
  local previous=forwarding;forwarding=true;S.GiveOrderToUnit(id,34592,{seed,leader},CMD.OPT_INTERNAL or 8);forwarding=previous
 end,
 EndFollow=function(id,expectedToken)
  if token(id)~=expectedToken then return end
  local previous=forwarding;forwarding=true
  for _,row in ipairs(S.GetUnitCommands(id,-1)or{})do if row.id==34592 then S.GiveOrderToUnit(id,CMD.REMOVE,{row.tag},0)end end
  forwarding=previous
 end,
 Demote=function(id,squad)orders(id,formation.FilterQueue(squad,id,S.GetUnitCommands(id,-1)or{}))end,
 SyncState=function(id,leader)
  local a,b=S.GetUnitStates(leader),S.GetUnitStates(id);if not a or not b then return end
  local previous=forwarding;forwarding=true
  for _,row in ipairs({{'firestate','FIRE_STATE'},{'movestate','MOVE_STATE'},{'repeat','REPEAT'},{'cloak','CLOAK'},{'autoland','IDLEMODE'}})do
   local field,cmd=row[1],CMD[row[2]]
   if cmd and a[field]~=nil and a[field]~=b[field]then local value=a[field];if type(value)=='boolean'then value=value and 1 or 0 end;S.GiveOrderToUnit(id,cmd,{value},0)end
  end
  forwarding=previous
 end,
 FactoryClear=function(factory,ids,plan)
  if not nativeAlive(factory)then return true end
  local fd=UnitDefs[S.GetUnitDefID(factory)];local fx,_,fz=position(factory)
  if not fd or not fd.isFactory or not fx then return false end
  for _,id in ipairs(ids)do local d=UnitDefs[S.GetUnitDefID(id)];local x,_,z=position(id)
   if not d or not x then return false end
   if math.abs(x-fx)<=fd.xsize*4+d.xsize*4+8 and math.abs(z-fz)<=fd.zsize*4+d.zsize*4+8 then return false end
   if egressGeometry.Outside(S,UnitDefs,factory,id)~=true then return false end
  end
  if plan then
   local parent=egressGeometry.Envelope(S,UnitDefs,factory);if not parent then return false end
   local function crosses(x,z,tx,tz,reach)
    local enter,leave=0,1
    for _,axis in ipairs({{x,tx-x,parent.minX-reach,parent.maxX+reach},{z,tz-z,parent.minZ-reach,parent.maxZ+reach}})do
     local origin,delta,lo,hi=axis[1],axis[2],axis[3],axis[4]
     if math.abs(delta)<1e-8 then if origin<lo or origin>hi then return false end
     else
      local a,b=(lo-origin)/delta,(hi-origin)/delta;if a>b then a,b=b,a end
      enter=math.max(enter,a);leave=math.min(leave,b);if enter>leave then return false end
     end
    end
    return true
   end
   for _,slot in ipairs(plan)do
    local child=egressGeometry.Envelope(S,UnitDefs,slot.id);local x,_,z=position(slot.id)
    if not child or not finite(x)or not finite(z)or not finite(slot.desiredX)or not finite(slot.desiredZ)then return false end
    -- A circle around the actual horizontal union is conservative through
    -- yaw changes; the entire desired formation must clear this producer.
    local hx=math.max(math.abs(child.minX-x),math.abs(child.maxX-x))
    local hz=math.max(math.abs(child.minZ-z),math.abs(child.maxZ-z));local reach=math.sqrt(hx*hx+hz*hz)
    if not(slot.desiredX+reach<parent.minX or slot.desiredX-reach>parent.maxX or slot.desiredZ+reach<parent.minZ or slot.desiredZ-reach>parent.maxZ)then return false end
    if not finite(slot.x)or not finite(slot.z)or crosses(x,z,slot.x,slot.z,reach)then return false end
   end
  end
  return true
 end,
 Face=function(id,heading)
  -- Preserve this body's own native terrain up, rather than leader pitch.
  local _,up=S.GetUnitVectors(id)
  if type(up)=='table'and finite(up[1])and finite(up[2])and finite(up[3])and up[1]^2+up[2]^2+up[3]^2>1e-8 then S.SetUnitHeadingAndUpDir(id,heading,up[1],up[2],up[3])end
 end,
 Pace=function(id,value)
  if not finite(value)or value<0 or not nativeAlive(id)then return false end
  if S.MoveCtrl.SetGroundMoveTypeData(id,'maxWantedSpeed',value)~=1 then return false end
  local md=S.GetUnitMoveTypeData(id);return md and finite(md.maxWantedSpeed)and math.abs(md.maxWantedSpeed-value)<.001 or false
 end,
 ResumeQueue=function(id,queue)return orders(id,queue,true)end,
 Replay=orders})
local builderCallbacks=VFS.Include('40k_configs/native_builder_callbacks.lua')
local function stopBuild(id)
 builderCallbacks.Call(S,UnitDefs,id,'StopBuilding')
 if S.ClearUnitGoal then S.ClearUnitGoal(id)end
 repairing[id]=nil
end
local function loadSaved()
 local snapshot={version=R.Version,serial=P.Serial(),squads={},repair={}}
 local savedRepair={}
 for _,id in ipairs(S.GetAllUnits())do
  local seed=S.GetUnitRulesParam(id,'40k_squad_id');local slot=S.GetUnitRulesParam(id,'40k_squad_slot')
  if seed and seed>0 and slot then
   if S.GetUnitRulesParam(id,'40k_squad_schema')~=R.Version then return false end
   local key=profiles.byID[S.GetUnitRulesParam(id,'40k_squad_profile')];if not key then return false end
   local s=snapshot.squads[seed]or{id=seed,profile=key,team=S.GetUnitTeam(id),slots={},generations={},investments={}}
   if s.profile~=key or s.team~=S.GetUnitTeam(id)then return false end
   if s.slots[slot]then return false end
   s.slots[slot]=id;s.generations[slot]=S.GetUnitRulesParam(id,'40k_squad_generation')or 1;snapshot.squads[seed]=s
   for savedSlot=1,profiles.profiles[s.profile].capacity do
    local generation=S.GetUnitRulesParam(id,'40k_squad_slot_generation_'..savedSlot)
    if not generation or generation<1 or generation~=math.floor(generation)then return false end
    if generation>0 then
     if s.generations[savedSlot]and s.generations[savedSlot]~=generation then return false end
     s.generations[savedSlot]=generation
    end
   end
   s.investments[slot]={};for _,k in ipairs({'metal','energy','work'})do s.investments[slot][k]=S.GetUnitRulesParam(id,'40k_squad_investment_'..k)end
   -- Every survivor receives the same repair tuple in Publish. Contradictory
   -- saved tuples must not be accepted according to native enumeration order.
   local tuple={}
   for _,field in ipairs({'slot','def','work','metal','energy'})do
    local value=S.GetUnitRulesParam(id,'40k_squad_repair_'..field)or 0
    if type(value)~='number'or value~=value or value<0 or value==math.huge then return false end
    tuple[field]=value
    if savedRepair[seed]and savedRepair[seed][field]~=value then return false end
   end
   savedRepair[seed]=tuple
   local rs=tuple.slot
   if rs>0 then local def=S.GetUnitRulesParam(id,'40k_squad_repair_def');if not UnitDefs[def]then return false end
    snapshot.repair[seed]={slot=rs,def=UnitDefs[def].name,work=S.GetUnitRulesParam(id,'40k_squad_repair_work')or 0,metal=S.GetUnitRulesParam(id,'40k_squad_repair_metal')or 0,energy=S.GetUnitRulesParam(id,'40k_squad_repair_energy')or 0}
   end
  end
 end
 return R.Restore(snapshot)
end
function gadget:Initialize()
 R=VFS.Include('40k_configs/squad_runtime.lua').New(P,profiles);GG.Recoil40KSquads=R;gadgetHandler:RegisterCMDID(REPAIR);gadgetHandler:RegisterCMDID(34592)
 assert(loadSaved(),'Squad saved membership refused')
 GG.Recoil40KSquadFormation=formation
 for _,squad in pairs(R.squads)do
  formation.Track(squad)
  local factory=S.GetUnitRulesParam(squad.leader,'40k_squad_movement_factory')
  if type(factory)=='number'and factory>=0 then formation.Factory(squad,factory,S.GetUnitRulesParam(squad.leader,'40k_squad_movement_factory_released')==1)end
 end
 if not formationAvailable then S.Echo('40K SQUAD FORMATION UNAVAILABLE essential_native_API; ordinary native movement fallback')end
 if VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(S.GetModOptions().prototype_squad_transport_pilot)then
  GG.Recoil40KSquadTransportAPI={Get=R.Get,
   Capacity=function(seed)local state=R.squads[seed];return state and profiles.profiles[state.profile].capacity end,
   SlotDef=function(seed,slot)local state=R.squads[seed];if not state then return end
    local id=state.slots[slot];return id and S.GetUnitDefID(id)or UnitDefNames[role(state.profile,slot,isResearched(state.team,state.profile))].id
   end,Changed=function(seed)dirty[seed]=true end}
 end
 for _,id in ipairs(S.GetAllUnits())do
  local factory=S.GetUnitRulesParam(id,'40k_squad_factory')
  if product[S.GetUnitDefID(id)]and factory and factory>0 and S.ValidUnitID(factory)then builders[id]=factory end
 end
end
function gadget:Shutdown()for seed in pairs(R.squads)do formation.Forget(seed)end;if GG.Recoil40KSquadFormation==formation then GG.Recoil40KSquadFormation=nil end;if GG.Recoil40KSquads==R then GG.Recoil40KSquads=nil;GG.Recoil40KSquadTransportAPI=nil end end
function gadget:UnitCreated(id,def,team,builder)
 if product[def]and builder and UnitDefs[S.GetUnitDefID(builder)].isFactory then builders[id]=builder;put(id,'factory',builder)end
end
function gadget:AllowUnitCreation(def,builder)
 if internal[def]then return R and (R.creating or next(R.mutating)~=nil)or false end
 return true
end
function gadget:AllowUnitBuildStep(builder,team,id,def,part)
 if not product[def]or part<=0 then return true end
 local _,_,_,_,progress=S.GetUnitHealth(id)
 if progress and progress+part>=1 then
  local factory=builders[id];local allowed=factory and live(factory,team)and R.CanFinish(id,product[def],team,factory)or false
  if not allowed and fixture and not fixtureBlocked[id]then
   fixtureBlocked[id]=true;local x,y,z=position(id);local detail={}
   for _,off in ipairs({{24,0},{40,0},{64,0},{0,64},{-64,0},{0,-64}})do detail[#detail+1]=tostring(S.TestBuildOrder(UnitDefNames.imp_marine_member.id,x+off[1],S.GetGroundHeight(x+off[1],z+off[2]),z+off[2],0))end
   S.Echo('40K_SQUAD_NATIVE PREFLIGHT_BLOCK',id,'factory',factory,'progress',progress,'sites',table.concat(detail,','))
  end
  return allowed
 end
 return true
end
function gadget:UnitFinished(id,def,team)
 local factory=builders[id]
 if product[def]and factory then
  local delivered,why=R.Finish(id,product[def],team,factory)
  if not delivered then
   -- Unexpected native birth failure is visible and frozen, never free repair.
   put(id,'delivery_failed',1);S.GiveOrderToUnit(id,CMD.STOP,{},0)
   for n in ipairs(UnitDefs[def].weapons or{})do S.SetUnitWeaponState(id,n,{reloadState=2147483647})end
   S.Echo('40K SQUAD DELIVERY REFUSED',id,why)
  else S.Echo('40K SQUAD COMPLETE',id,R.Get(id).id,R.Get(id).profile,profiles.profiles[product[def]].capacity)end
  builders[id]=nil
  put(id,'factory',0)
 end
end
function gadget:UnitFromFactory(id,def,team,factory)
 if not R.Get(id)then return end
 -- Pinned CFactory::FinishBuild assigns rally orders before this callback.
 local q=orders(id)
 formation.Factory(R.Get(id),factory,true)
 for _,body in ipairs(R.Members(id))do put(body,'movement_factory',factory);put(body,'movement_factory_released',1)end
 for _,member in ipairs(R.Members(id))do if member~=id then orders(member,q);inheritState(member,id)end end
end
function gadget:UnitIdle(id)formation.Idle(R.Get(id))end
function gadget:UnitCmdDone(id,def,team,cmd,params,opts)
 if not forwarding and(cmd==CMD.STOP or cmd==CMD.WAIT)then local squad=R.Get(id);if squad and id==squad.leader then formation.Command(squad,cmd,params or{},opts)end end
end
function gadget:UnitLoaded(id)local s=R.Get(id);if s then formation.Command(s,CMD.WAIT,{})end end
function gadget:UnitDestroyed(id)
 local s=not R.mutating[id]and R.Get(id)
 if s then formation.BeforeRemove(s,id)end
 builders[id]=nil;if repairing[id]then stopBuild(id)end;R.Remove(id)
 if s then if R.squads[s.id]then formation.Changed(s)else formation.Forget(s.id)end end
end
function gadget:UnitGiven(id,def,team)local s=R.Get(id);if s then formation.Forget(s.id)end;R.Transfer(id,team)end
function gadget:UnitDamaged(id)local s=R.Get(id);if s then dirty[s.id]=true end end
function gadget:UnitUnloaded(id)local s=R.Get(id);if s then dirty[s.id]=true;formation.Track(s)end end
local removeTags=VFS.Include('40k_configs/squad_remove_tags.lua')
local supported={[CMD.MOVE]=true,[CMD.ATTACK]=true,[CMD.FIGHT]=true,[CMD.PATROL]=true,[CMD.STOP]=true,[CMD.WAIT]=true,[CMD.GUARD]=true,[CMD.INSERT]=true,[CMD.REMOVE]=true}
if profiles.profiles.marine_assault then supported[VFS.Include('40k_configs/jump_geometry.lua').Command]=true end
for _,name in ipairs({'FIRE_STATE','MOVE_STATE','REPEAT','IDLEMODE','CLOAK'})do if CMD[name]then supported[CMD[name]]=true end end
function gadget:AllowCommand(id,def,team,cmd,params,opts,cmdTag,playerID,fromSynced,fromLua,fromInsert)
 if cmd==34592 and not forwarding then return false end -- Internal local following only.
 if redirect or forwarding then return true end
 if fromInsert then
  -- Pinned BAR unwraps INSERT in-place before this call: cmd/params/opts
  -- describe its inner command; cmdTag and fromInsert retain its envelope.
  local squad=R.Get(id)
  if not squad or not supported[cmd]then return true end
  if id~=squad.leader then return false end
  local wrapped={cmdTag,cmd,opts and opts.coded or 0}
  for i,value in ipairs(params)do wrapped[i+3]=value end
  cmd=CMD.INSERT;params=wrapped;opts=fromInsert
 end
 if cmd==CMD.REPAIR and UnitDefs[def].isBuilder and not UnitDefs[def].isFactory and #params==1 then
  local s=R.Get(params[1])
  if s and S.AreTeamsAllied(s.team,team)then
   redirect=true;S.GiveOrderToUnit(id,REPAIR,{s.id},opts and opts.coded or 0);redirect=false;return false
  end
 end
 if cmd==REPAIR then local s=R.squads[params[1]];return UnitDefs[def].isBuilder and not UnitDefs[def].isFactory and s and S.AreTeamsAllied(s.team,team)or false end
 local s=R.Get(id)
 if s and id==s.leader and not supported[cmd]then formation.Command(s,cmd,params)end
 if s and supported[cmd]then
  if id~=s.leader then return false end
  local removals
  local insertions
  if cmd==CMD.REMOVE and not removeTags.ByID(opts)then
   -- Read every target first: an ambiguous/unavailable queue cancels the
   -- leader command too, without partially removing any member's orders.
   if not S.GetUnitCommands then return false end
   local queues={}
   for _,member in ipairs(R.Members(id))do if member~=id then queues[#queues+1]={id=member,queue=S.GetUnitCommands(member,-1)}end end
   removals=removeTags.Plan(S.GetUnitCommands(id,-1),queues,params)
   if not removals then return false end
  elseif cmd==CMD.INSERT and not removeTags.ByID(opts)then
   -- Native non-ALT INSERT addresses a local tag, before (or RIGHT_MOUSE
   -- after) its command. Missing anchors are native no-ops, never positions.
   insertions={}
   if #params>=3 then
    if not S.GetUnitCommands then return false end
    local queues={}
    for _,member in ipairs(R.Members(id))do if member~=id then queues[#queues+1]={id=member,queue=S.GetUnitCommands(member,-1)}end end
    local anchors=removeTags.Plan(S.GetUnitCommands(id,-1),queues,{params[1]})
    if not anchors then return false end
    for _,row in ipairs(anchors)do if #row.tags>0 then
     local translated={};for i,value in ipairs(params)do translated[i]=value end
     translated[1]=row.tags[1];insertions[#insertions+1]={id=row.id,params=translated}
    end end
   end
  end
  formation.Command(s,cmd,params,opts)
  local forwardFormation=formation.Forward(s,cmd,params)
  forwarding=true
  if not forwardFormation then
   -- Only the actual leader receives routed travel/inserted travel.
  elseif removals then
   for _,row in ipairs(removals)do if #row.tags>0 then S.GiveOrderToUnit(row.id,cmd,row.tags,opts and opts.coded or 0)end end
  elseif insertions then
   for _,row in ipairs(insertions)do S.GiveOrderToUnit(row.id,cmd,row.params,opts and opts.coded or 0)end
  else
   for _,member in ipairs(R.Members(id))do if member~=id then S.GiveOrderToUnit(member,cmd,params,opts and opts.coded or 0)end end
  end
  forwarding=false
 end
 if repairing[id]and cmd~=REPAIR and not(opts and opts.shift)then stopBuild(id)end
 return true
end
function gadget:CommandFallback(id,def,team,cmd,params)
 if cmd==34592 then return true,not formation.ActiveFollower(R.Get(id),id,params)end
 if cmd~=REPAIR then return false end
 local s=R.squads[params[1]]
 if not s or not S.AreTeamsAllied(s.team,team)or not live(id,team)or not R.NeedsRepair(s.leader)then if repairing[id]then stopBuild(id)end;return true,true end
 for _,member in ipairs(R.Members(s.leader))do
  if S.GetUnitTransporter(member)or P.Busy(member)then if repairing[id]then stopBuild(id)end;return true,false end
 end
 local x,y,z=position(id);local tx,ty,tz=position(s.leader);if not x or not tx then return true,true end
 local range=UnitDefs[def].buildDistance or 100
 if (x-tx)^2+(z-tz)^2>range^2 then if repairing[id]then stopBuild(id)end;S.SetUnitMoveGoal(id,tx,ty,tz,range*.8);return true,false end
 local frame=S.GetGameFrame();local last=repairing[id]and repairing[id].last or frame-1
 if not repairing[id]then
  builderCallbacks.Call(S,UnitDefs,id,'StartBuilding',0,0)
 end
 repairing[id]={last=frame,seed=s.id}
 local livingBefore=S.GetUnitRulesParam(s.leader,'40k_squad_living')
 R.RepairStep(s.id,team,(UnitDefs[def].buildSpeed or 0)*math.min(16,math.max(0,frame-last))/Game.gameSpeed)
 if S.GetUnitRulesParam(s.leader,'40k_squad_living')~=livingBefore then formation.Changed(s)end
 return true,false
end
function gadget:GameFrame(frame)
 formation.Frame(frame,R.squads)
 if frame%15~=0 then return end
 for seed,s in pairs(R.squads)do
  local key=s.team..':'..s.profile;local value=isResearched(s.team,s.profile)
  if researched[key]~=value or dirty[seed]or R.researchPending[seed]then R.RefreshResearch(seed)end
 end
 for _,s in pairs(R.squads)do researched[s.team..':'..s.profile]=isResearched(s.team,s.profile)end
 dirty={}
end
