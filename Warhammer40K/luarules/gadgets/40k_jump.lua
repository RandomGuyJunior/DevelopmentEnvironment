function gadget:GetInfo()
 return {name='40K native jump packs',desc='Source-charge jump command using native synced MoveCtrl',author='Local project',layer=0,enabled=true}
end
if not gadgetHandler:IsSyncedCode()then return end
local G=VFS.Include('40k_configs/jump_geometry.lua')
local JUMP=G.Command;local configs,charges,states,done={},{},{},{}
local activeIDs,activeDirty={},false
local maxUnitRadius,maxFeatureRadius=0,0
local mc=Spring.MoveCtrl
local Storm=VFS.Include('40k_configs/ork_stormboy_jump_native.lua')
local stormEnabled=Storm.Enabled(Spring.GetModOptions())
local storm
local assault;local SquadJump=VFS.Include('40k_configs/squad_jump_contract.lua')
local function ownedAssault(id)
 local d=UnitDefs[Spring.GetUnitDefID(id)];local cp=d and d.customParams or{}
 return cp.prototype40k_squad_product=='marine_assault'or(cp.prototype40k_squad_profile=='marine_assault'and tonumber(cp.prototype40k_squad_internal)==1)
end
local function radius(id,feature)
 local sx,sy,sz,ox,oy,oz
 if feature then sx,sy,sz,ox,oy,oz=Spring.GetFeatureCollisionVolumeData(id)
 else sx,sy,sz,ox,oy,oz=Spring.GetUnitCollisionVolumeData(id)end
 if not (G.Finite(sx)and G.Finite(sy)and G.Finite(sz)and G.Finite(ox)and G.Finite(oy)and G.Finite(oz))then return nil end
 return .5*math.sqrt(sx*sx+sy*sy+sz*sz)+math.sqrt(ox*ox+oy*oy+oz*oz)
end
local function cacheRadius(id,feature)
 local r=radius(id,feature)
 if r then if feature then maxFeatureRadius=math.max(maxFeatureRadius,r)else maxUnitRadius=math.max(maxUnitRadius,r)end end
end
local function canLand(id,p)
 if not(p[1]>0 and p[3]>0 and p[1]<Game.mapSizeX and p[3]<Game.mapSizeZ)then return false end
 local defID=Spring.GetUnitDefID(id);local ground=Spring.GetGroundHeight(p[1],p[3])
 return G.Finite(ground)and ground>=0 and Spring.TestMoveOrder(defID,p[1],ground,p[3],0,0,0,true,true,false)==true
end
local function center(id,p)
 local x,y,z,mx,my,mz=Spring.GetUnitPosition(id,true)
 if not(G.Finite(mx)and G.Finite(my)and G.Finite(mz))then return nil end
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
     if not r or not G.Finite(mx)or not G.Finite(my)or not G.Finite(mz)then return false end
     if G.PointSegmentSquared(mx,my,mz,ca,cb)<(ra+r)^2 then return false end
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
  if not G.Finite(ground)or ground>y+.01 then return false end
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
local function publish(id)
 Spring.SetUnitRulesParam(id,'40k_jump_charge',charges[id]/30,{allied=true})
 if ownedAssault(id)then
  Spring.SetUnitRulesParam(id,'40k_assault_jump_charge',charges[id],{private=true})
  Spring.SetUnitRulesParam(id,'40k_assault_jump_frame',Spring.GetGameFrame(),{private=true})
 end
end
local function target(params)
 if type(params)~='table'or not G.Finite(params[1])or not G.Finite(params[2])or not G.Finite(params[3])then return nil end
 if params[1]<=0 or params[3]<=0 or params[1]>=Game.mapSizeX or params[3]>=Game.mapSizeZ then return nil end
 local y=Spring.GetGroundHeight(params[1],params[3]);if not G.Finite(y)then return nil end
 return {params[1],y,params[3]}
end
local function usable(id)
 if Spring.GetUnitTransporter(id)~=nil or mc.IsEnabled(id)then return false end
 local stunned,inbuild=Spring.GetUnitIsStunned(id);local _,_,_,_,progress=Spring.GetUnitHealth(id)
 return not stunned and not inbuild and progress and progress>=1
end
local function finish(id,s)
 if mc.IsEnabled(id)and mc.GetTag(id)==G.Tag then
  mc.SetVelocity(id,0,0,0);mc.SetNoBlocking(id,false);mc.Disable(id)
  -- Actual current landed XZ only: native ground forced-move restores native
  -- blocking/quadfield state after ScriptMoveType destruction unmarks it.
  if Spring.GetUnitTransporter(id)==nil and s.stage=='land'then Spring.SetUnitPosition(id,s.position[1],s.position[3])end
 end
 if s.sourceGroup and storm then storm.Finished(id,s)end
 if s.assaultGroup and assault then assault.Finished(id,s);Spring.SetUnitRulesParam(id,'40k_assault_jump_airborne',0,{private=true})end
 states[id]=nil;done[id]=s.commandTag;activeDirty=true
 Spring.SetUnitRulesParam(id,'40k_jump_active',0,{allied=true})
end
local function prepare(id,params)
 local config=configs[Spring.GetUnitDefID(id)];if not config then return false end;local b=target(params)
 local x,y,z=Spring.GetUnitPosition(id);local a={x,y,z}
 if not b or not usable(id)or not G.Finite(x)or G.Distance(a,b)<8 or G.Distance(a,b)>config.range or not canLand(id,b)then return false end
 local distance=G.Distance(a,b);local height=math.max(64,math.min(128,distance*.22))
 local flight=math.max(10,math.floor(config.flight*distance/config.range+.5))
 local prev=a
 for f=1,flight do local p=G.Arc(a,b,f/flight,height);if not sweep(id,prev,p)then return false end;prev=p end
 return {stage='launch',stageStart=0,a=a,b=b,height=height,flightFrames=flight,config=config,commandTag=nil,position=a,history={a}}
end
local function begin(id,s,tag,frame,source)
 local config,a,b=s.config,s.a,s.b
 mc.Enable(id);mc.SetTag(id,G.Tag);mc.SetExtrapolate(id,false);mc.SetGravity(id,0);mc.SetTrackGround(id,false);mc.SetVelocity(id,0,0,0);mc.SetNoBlocking(id,true)
 mc.SetHeading(id,Spring.GetHeadingFromVector(b[1]-a[1],b[3]-a[3]))
 if not source then charges[id]=charges[id]-config.cost;publish(id)end
 s.stageStart=frame;s.commandTag=tag
 states[id]=s;done[id]=nil;activeDirty=true
 Spring.SetUnitRulesParam(id,'40k_jump_active',1,{allied=true})
 if s.assaultGroup then Spring.SetUnitRulesParam(id,'40k_assault_jump_airborne',1,{private=true})end
 return true
end
local function start(id,params,tag,frame)
 if ownedAssault(id)then if not assault then return false end;return assault.Start(id,params,tag,frame)end
 if storm and configs[Spring.GetUnitDefID(id)].stormboy then return storm.Start(id,params,tag,frame)end
 local s=prepare(id,params);if not s then return false end
 if charges[id]<s.config.cost then return nil end
 return begin(id,s,tag,frame,false)
end
local function enterLand(id,s,frame)
 s.stage='land';s.stageStart=frame;mc.SetNoBlocking(id,false)
 if s.sourceGroup and storm then storm.Landed(id,s)end
end
local function move(id,s,next)
 local old=s.position;mc.SetVelocity(id,next[1]-old[1],next[2]-old[2],next[3]-old[3]);mc.SetPosition(id,next[1],next[2],next[3]);s.position=next
end
local function recover(id,s,frame)
 local current=s.position
 local ground={current[1],Spring.GetGroundHeight(current[1],current[3]),current[3]}
 if canLand(id,ground)then
  local next,reached=G.Step(current,ground,s.config.maxStep)
  if sweep(id,current,next)then move(id,s,next);if reached then enterLand(id,s,frame);mc.SetVelocity(id,0,0,0)end;return end
 end
 if #s.history>1 then
  local previous=s.history[#s.history-1];local next,reached=G.Step(current,previous,s.config.maxStep)
  if sweep(id,current,next)then move(id,s,next);if reached then table.remove(s.history)end else mc.SetVelocity(id,0,0,0)end
 end
 -- If every fresh safe route is obstructed, remain at the last safe airborne
 -- position until one clears; never teleport into an invalid landing square.
end
function gadget:AllowCommand(id,defID,team,cmd,params)
 if cmd==JUMP then return configs[defID]~=nil and target(params)~=nil and(not configs[defID].stormboy or storm and storm.Allowed(id)) end
 if cmd==CMD.INSERT and params and params[2]==JUMP then return configs[defID]~=nil and target({params[4],params[5],params[6]})~=nil and(not configs[defID].stormboy or storm and storm.Allowed(id)) end
 return true
end
function gadget:CommandFallback(id,defID,team,cmd,params,options,tag)
 if cmd~=JUMP then return false end
 if not configs[defID]then return true,true end
 if done[id]==tag then done[id]=nil;return true,true end
 if states[id]then return true,false end
 local result=start(id,params,tag,Spring.GetGameFrame())
 return true,result==false -- charge waiting retains the native queued order.
end
function gadget:GameFrame(frame)
 if storm then storm.Frame(frame)end
 for id,charge in pairs(charges)do
  local c=configs[Spring.GetUnitDefID(id)]
  if c and not c.stormboy then charges[id]=math.min(c.capacity,charge+c.regen);if frame%30==0 then publish(id)end end
 end
 if activeDirty then activeIDs={};for id in pairs(states)do activeIDs[#activeIDs+1]=id end;table.sort(activeIDs);activeDirty=false end
 for _,id in ipairs(activeIDs)do
  local s=states[id]
  if s then
   if not mc.IsEnabled(id)or mc.GetTag(id)~=G.Tag then
    if s.sourceGroup and storm then storm.Removed(id)end
    if s.assaultGroup and assault then assault.Cancel(id);assault.Finished(id,s);Spring.SetUnitRulesParam(id,'40k_assault_jump_airborne',0,{private=true})end
    states[id]=nil;done[id]=s.commandTag;activeDirty=true;Spring.SetUnitRulesParam(id,'40k_jump_active',0,{allied=true})
   elseif Spring.GetUnitTransporter(id)~=nil then finish(id,s)
   else
    local cmd,_,tag=Spring.GetUnitCurrentCommand(id)
    if s.assaultGroup then if not assault.Valid(s)then s.aborting=true end
    elseif s.sourceGroup then if not storm.Valid(s)then s.aborting=true end
    elseif cmd~=JUMP or tag~=s.commandTag then s.aborting=true end
    if s.aborting and s.stage~='land'then s.stage='air';recover(id,s,frame)
    elseif s.stage=='launch'and frame-s.stageStart>=s.config.launch then s.stage='air';s.stageStart=frame
    elseif s.stage=='air'then
     local phase=math.min(1,(frame-s.stageStart)/s.flightFrames);local p=G.Arc(s.a,s.b,phase,s.height)
     if not sweep(id,s.position,p)or (phase==1 and not canLand(id,p))then s.aborting=true;recover(id,s,frame)
     else move(id,s,p);s.history[#s.history+1]=p;if phase==1 then enterLand(id,s,frame);mc.SetVelocity(id,0,0,0)end end
    elseif s.stage=='land'and frame-s.stageStart>=s.config.land then finish(id,s)end
   end
  end
 end
 if storm then storm.Save(states)end
end
function gadget:UnitCreated(id,defID)
 cacheRadius(id,false)
 if configs[defID]then
  charges[id]=configs[defID].stormboy and 0 or configs[defID].capacity
  if ownedAssault(id)then
   assert(Spring.GetUnitRulesParam(id,'40k_assault_jump_airborne')~=1,'Airborne Assault squad save is unsupported; refuse reload')
   local charge=Spring.GetUnitRulesParam(id,'40k_assault_jump_charge');local at=Spring.GetUnitRulesParam(id,'40k_assault_jump_frame')
   if charge~=nil or at~=nil then
    assert(G.Finite(charge)and charge>=0 and charge<=configs[defID].capacity and G.Finite(at)and at>=0 and at<=Spring.GetGameFrame(),'Assault saved native charge refused')
    charges[id]=math.min(configs[defID].capacity,charge+(Spring.GetGameFrame()-at)*configs[defID].regen)
   end
  end
  publish(id)
  Spring.InsertUnitCmdDesc(id,{id=JUMP,type=CMDTYPE.ICON_MAP,name='Jump',action='40k_jump',cursor='Jump',
   tooltip='Jump pack: '..configs[defID].range..' range, 45 charge; regenerates 1 charge/second. Shift queues normally.'})
 end
end
function gadget:UnitFinished(id)cacheRadius(id,false)end
function gadget:FeatureCreated(id)cacheRadius(id,true)end
function gadget:UnitDestroyed(id)if assault then assault.Removed(id)end;if storm then storm.Removed(id)end;charges[id]=nil;states[id]=nil;done[id]=nil;activeDirty=true end
function gadget:UnitTaken(id)if assault then assault.Cancel(id)end;if storm then storm.Removed(id)end;if states[id]then states[id].aborting=true end end
function gadget:UnitGiven(id)if assault then assault.Cancel(id)end;if storm then storm.Removed(id)end;if states[id]then states[id].aborting=true end end
function gadget:Initialize()
 assert(not CMD[JUMP],'40K jump command ID collides with native command')
 for _,name in ipairs({'Enable','Disable','IsEnabled','SetTag','GetTag','SetPosition','SetVelocity','SetExtrapolate','SetHeading','SetGravity','SetTrackGround','SetNoBlocking'})do assert(type(mc[name])=='function','Missing native MoveCtrl '..name)end
 for id,d in pairs(UnitDefs)do local cp=d.customParams or{}
  if stormEnabled and cp.source_entity==Storm.entity and tostring(cp.source_stormboy_jump)=='1'then configs[id]=Storm.Config(Game.gameSpeed)
  elseif tostring(cp.source_jump_required)=='1'and cp.source_entity~=Storm.entity then configs[id]=G.Config(cp)end
 end
 if stormEnabled then storm=Storm.New(Spring,UnitDefs,Game.gameSpeed,G,{Prepare=prepare,Begin=begin})end

 if Spring.GetModOptions and VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(Spring.GetModOptions().prototype_marine_assault_squad)then
  assert(GG.Recoil40KSquads,'Assault jump requires real squad owner')
  local function pairSafe(ids,plans)
   local maximum=0;for _,id in ipairs(ids)do maximum=math.max(maximum,plans[id].flightFrames)end
   for i=1,#ids do for j=i+1,#ids do
    local a,b=ids[i],ids[j];local ra,rb=radius(a,false),radius(b,false);if not ra or not rb then return false end
    local pa,pb=center(a,plans[a].a),center(b,plans[b].a);if not pa or not pb then return false end
    local prior={pa[1]-pb[1],pa[2]-pb[2],pa[3]-pb[3]}
    for frame=1,maximum do
     local aa=G.Arc(plans[a].a,plans[a].b,math.min(1,frame/plans[a].flightFrames),plans[a].height)
     local bb=G.Arc(plans[b].a,plans[b].b,math.min(1,frame/plans[b].flightFrames),plans[b].height)
     local ca,cb=center(a,aa),center(b,bb);local relative={ca[1]-cb[1],ca[2]-cb[2],ca[3]-cb[3]}
     if G.PointSegmentSquared(0,0,0,prior,relative)<(ra+rb)^2 then return false end;prior=relative
    end
   end end;return true
  end
  assault=SquadJump.New{
   Squad=function(id)return GG.Recoil40KSquads.Get(id)end,
   Live=function(id,team)local hp,_,_,_,progress=Spring.GetUnitHealth(id);return hp and hp>0 and progress and progress>=1 and Spring.GetUnitTeam(id)==team and Spring.GetUnitTransporter(id)==nil and not(GG.Recoil40KSquadTransport and GG.Recoil40KSquadTransport.Busy(id))and ownedAssault(id)end,
   Position=Spring.GetUnitPosition,Head=function(id)local cmd,_,tag=Spring.GetUnitCurrentCommand(id);return cmd,tag end,
   Charge=function(id)return charges[id]or 0 end,Prepare=prepare,PairSafe=pairSafe,
   Active=function(id)return mc.IsEnabled(id)and mc.GetTag(id)==G.Tag end,
   Commit=function(ids,plans,heads,frame)for _,id in ipairs(ids)do assert(begin(id,plans[id],heads[id],frame,false))end end}
  GG.Recoil40KAssaultJump=assault
 end
 GG.Recoil40KJump={states=states,command=JUMP}
 for _,id in ipairs(Spring.GetAllUnits())do self:UnitCreated(id,Spring.GetUnitDefID(id))end
 for _,id in ipairs(Spring.GetAllFeatures())do cacheRadius(id,true)end
 if storm then storm.Restore(states);activeDirty=true end
end
function gadget:Shutdown()
 if storm then storm.Save(states)end
 for id,s in pairs(states)do if mc.IsEnabled(id)and mc.GetTag(id)==G.Tag then mc.SetNoBlocking(id,false);mc.Disable(id)end end
 if GG.Recoil40KJump and GG.Recoil40KJump.states==states then GG.Recoil40KJump=nil end
 if GG.Recoil40KAssaultJump==assault then GG.Recoil40KAssaultJump=nil end
end
