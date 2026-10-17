function gadget:GetInfo()
 return {name="40K Heavy Weapon Team deployment",desc="Paid packed/deployed source-model transformation",author="Local project",layer=0,enabled=true}
end
local DEPLOY,PACK=34580,34581
if not gadgetHandler:IsSyncedCode()then
 local selected={}
 local function selectedNow(id)
  for _,unit in ipairs(Spring.GetSelectedUnits() or {})do if unit==id then return true end end
  return false
 end
 local function start(_,id)selected[id]=selectedNow(id)end
 local function cancel(_,id)selected[id]=nil end
 local function replace(_,old,new,team)
  local keep=selected[old];selected[old]=nil
  if keep and team==Spring.GetMyTeamID()then
   local units=Spring.GetSelectedUnits() or {};units[#units+1]=new;Spring.SelectUnitArray(units)
  end
 end
 function gadget:Initialize()
  gadgetHandler:AddSyncAction("40k_hwt_start",start);gadgetHandler:AddSyncAction("40k_hwt_cancel",cancel);gadgetHandler:AddSyncAction("40k_hwt_replace",replace)
 end
 function gadget:Update()
  for id in pairs(selected)do if Spring.ValidUnitID(id)then selected[id]=selectedNow(id)end end
 end
 function gadget:Shutdown()
  gadgetHandler:RemoveSyncAction("40k_hwt_start");gadgetHandler:RemoveSyncAction("40k_hwt_cancel");gadgetHandler:RemoveSyncAction("40k_hwt_replace")
 end
 return
end
local units,pending={},{}
local transitionMirror,previousTransitionMirror
local function registerTransition(id)
 if not transitionMirror then return end
 local label=Spring.GetUnitRulesParam(id,'40k_transition_clip')
 local start=Spring.GetUnitRulesParam(id,'40k_transition_start')
 local finish=Spring.GetUnitRulesParam(id,'40k_transition_end')
 transitionMirror.known[id]=true
 transitionMirror.values[id]=(label~=nil or start~=nil or finish~=nil) and {label,start,finish} or nil
end
local internalOrder=false
local function order(id,cmd,params,options)
 internalOrder=true;Spring.GiveOrderToUnit(id,cmd,params,options);internalOrder=false
end
local packed,deployed,timing
local fps=Game.gameSpeed or 30
local public={public=true}
local function sorted(t)local keys={};for id in pairs(t)do keys[#keys+1]=id end;table.sort(keys);return keys end
local function alive(id)return Spring.ValidUnitID(id) and not Spring.GetUnitIsDead(id)end
local function busy(id)
 local hp,max,para,capture,progress=Spring.GetUnitHealth(id)
 if not hp or hp<=0 or not progress or progress<1 then return true end
 if Spring.GetUnitTransporter(id) or Spring.GetUnitIsBuilding(id)then return true end
 local transporting=Spring.GetUnitIsTransporting(id);if transporting and #transporting>0 then return true end
 if Spring.GetUnitIsStunned(id)then return true end
 local vx,vy,vz,speed=Spring.GetUnitVelocity(id)
 if not vx or (speed or math.sqrt(vx*vx+vy*vy+vz*vz))>.025 then return true end
 return false
end
local function facing(id)return math.floor(((Spring.GetUnitHeading(id) or 0)%65536)/16384+.5)%4 end
local function location(id,target)
 local x,y,z=Spring.GetUnitPosition(id);if not x then return false end
 local half=math.max(target.xsize or 4,target.zsize or 4)*(Game.squareSize or 8)/2+8
 if x<half or z<half or x>Game.mapSizeX-half or z>Game.mapSizeZ-half then return false end
 local lowest,highest=math.huge,-math.huge
 for dx=-1,1 do for dz=-1,1 do
  local ground=Spring.GetGroundHeight(x+dx*half,z+dz*half)
  if ground<=0 then return false end
  lowest=math.min(lowest,ground);highest=math.max(highest,ground)
 end end
 if highest-lowest>6 then return false end
 -- Conservative clearance excludes every other unit and feature, including
 -- neighbouring factory footprints. No collision/terrain flags are modified.
 local clearance=half+48
 for _,other in ipairs(Spring.GetUnitsInRectangle(x-clearance,z-clearance,x+clearance,z+clearance) or {})do
  if other~=id and alive(other)then return false end
 end
 if #(Spring.GetFeaturesInRectangle(x-half,z-half,x+half,z+half) or {})>0 then return false end
 if target.id==deployed.id then
  local status,feature=Spring.TestBuildOrder(target.id,x,y,z,facing(id))
  -- Pinned API returns1 when the sole packed mobile source occupies the site;
  -- an open site maps to2. Features and other units were rejected above.
  if feature or not status or status<1 then return false end
 else
  -- Terrain-only native move test avoids mistaking the source stationary model
  -- for an obstacle to its own replacement. Independent occupancy stays strict.
  if not Spring.TestMoveOrder(target.id,x,y,z,0,0,0,true,false,false)then return false end
 end
 return true,x,y,z
end
local function clearPose(id)
 Spring.SetUnitRulesParam(id,"40k_transition_clip",nil,public)
 Spring.SetUnitRulesParam(id,"40k_transition_start",nil,public)
 Spring.SetUnitRulesParam(id,"40k_transition_end",nil,public)
 if transitionMirror then transitionMirror.values[id]=nil end
end
local function cancel(id,why)
 local state=pending[id];if not state then return end;pending[id]=nil
 if alive(id)then
  clearPose(id)
 end
 if transitionMirror then transitionMirror.values[id]=nil end
 SendToUnsynced("40k_hwt_cancel",id);Spring.Echo("40K HWT","CANCEL",id,why)
end
local function descriptor(id)
 local defID=Spring.GetUnitDefID(id);if defID~=packed.id and defID~=deployed.id then return end
 local cmd=defID==packed.id and DEPLOY or PACK
 local disabled=pending[id]~=nil or busy(id)
 local desc={id=cmd,type=CMDTYPE.ICON,name=cmd==DEPLOY and "Deploy" or "Pack",action=cmd==DEPLOY and "40kdeploy" or "40kpack",tooltip=cmd==DEPLOY and "Deploy the paid team and its heavy bolter on clear dry ground" or "Pack the heavy bolter for movement",disabled=disabled}
 local index=Spring.FindUnitCmdDesc(id,cmd)
 if index then Spring.EditUnitCmdDesc(id,index,desc)else Spring.InsertUnitCmdDesc(id,desc)end
 units[id]=true
end
local function replay(id,queue,mobile)
 for _,command in ipairs(queue or {})do
  local c=command.id
  if c~=DEPLOY and c~=PACK and c~=CMD.STOP and c>0 then
   local movement=c==CMD.MOVE or c==CMD.PATROL or c==CMD.FIGHT or c==CMD.GUARD
   if mobile or not movement then order(id,c,command.params or {},{"shift"})end
  end
 end
end
local function begin(id,cmd)
 if pending[id] or busy(id)then return false end
 local defID=Spring.GetUnitDefID(id)
 if (cmd==DEPLOY and defID~=packed.id) or (cmd==PACK and defID~=deployed.id)then return false end
 local target=cmd==DEPLOY and deployed or packed
 if not location(id,target)then return false end
 local frame=Spring.GetGameFrame();local clip=cmd==DEPLOY and "deploy" or "pack"
 local states=Spring.GetUnitStates(id) or {}
 local queue=Spring.GetCommandQueue(id,32) or {}
 local state={target=target,team=Spring.GetUnitTeam(id),finish=frame+timing[clip],clip=clip,queue=queue,firestate=states.firestate or 2,movestate=states.movestate or 1}
 pending[id]=state
 -- The shared roster script gates AimWeapon and BlockShot on this transition.
 -- Do not issue temporary FIRE_STATE0: stock Holdfire Fix converts that event
 -- into a LuaUI inserted STOP on the next frame, cancelling this paid deploy.
 order(id,CMD.STOP,{},{})
 Spring.SetUnitRulesParam(id,"40k_transition_clip",clip,public)
 Spring.SetUnitRulesParam(id,"40k_transition_start",frame,public)
 Spring.SetUnitRulesParam(id,"40k_transition_end",state.finish,public)
 if transitionMirror then transitionMirror.values[id]={clip,frame,state.finish} end
 SendToUnsynced("40k_hwt_start",id);descriptor(id)
 Spring.Echo("40K HWT","START",id,clip,frame,state.finish)
 return true
end
local function finish(id,state)
 if not alive(id) or busy(id) or Spring.GetUnitTeam(id)~=state.team then cancel(id,"source_changed");return end
 local ok,x,y,z=location(id,state.target);if not ok then cancel(id,"site_changed");return end
 local hp,max,para,capture,progress=Spring.GetUnitHealth(id)
 local exp=Spring.GetUnitExperience(id) or 0;local dx,dy,dz=Spring.GetUnitDirection(id)
 local buildTime,metalCost,energyCost=Spring.GetUnitCosts(id)
 -- Never pretend this replacement was produced by a native factory. The
 -- temporary GG record allows evidence observers to distinguish a paid morph.
 GG.Prototype40kTransform={from=id,toDef=state.target.id,team=state.team}
 local function create()return Spring.CreateUnit(state.target.id,x,y,z,facing(id),state.team,false,false)end
 local paid=GG.Recoil40KResearch
 local callOK,new
 if paid then callOK,new=paid.WithCreationPermit(state.team,state.target.id,id,create)
 else callOK,new=pcall(create)end
 GG.Prototype40kTransform=nil
 if not callOK or not new then cancel(id,"replacement_failed_original_retained");return end
 Spring.SetUnitExperience(new,exp)
 local _,newMax=Spring.GetUnitHealth(new)
 if not newMax or newMax<=0 then Spring.DestroyUnit(new,false,true);cancel(id,"replacement_health_invalid");return end
 Spring.SetUnitHealth(new,{health=math.max(.001,newMax*hp/max),paralyze=para*newMax/max,capture=capture})
 Spring.SetUnitCosts(new,{buildTime=buildTime,metalCost=metalCost,energyCost=energyCost})
 if dx then Spring.SetUnitDirection(new,dx,dy,dz)end
 Spring.SetUnitRulesParam(new,"40k_transform_from",id,public)
 Spring.SetUnitRulesParam(new,"40k_hwt_form",state.target.id==packed.id and "packed" or "deployed",public)
 order(new,CMD.FIRE_STATE,{state.firestate},{})
 order(new,CMD.MOVE_STATE,{state.movestate},{})
 pending[id]=nil;units[id]=nil
 -- Reclaimed=true creates no wreck/death sequence and gives no resources back
 -- in the pinned engine. A successful replacement consumes exactly one source.
 Spring.DestroyUnit(id,false,true)
 descriptor(new);replay(new,state.queue,state.target.id==packed.id)
 SendToUnsynced("40k_hwt_replace",id,new,state.team)
 Spring.Echo("40K HWT","TRANSFORM",id,new,state.clip,"paid_cost_preserved",metalCost,energyCost,"health_fraction",hp/max,"experience",exp)
end
function gadget:Initialize()
 packed=UnitDefNames.imp_heavy_weapon_team;deployed=UnitDefNames.imp_heavy_weapon_team_deployed
 if not packed or not deployed then gadgetHandler:RemoveGadget(self);return end
 packed=UnitDefs[packed.id];deployed=UnitDefs[deployed.id]
 local path="scripts/generated/"
 for _,key in ipairs({"imp_heavy_weapon_team","imp_heavy_weapon_team_deployed"})do
  if not VFS.FileExists("objects3d/"..key..".glb") or not VFS.FileExists(path..key.."_anim.lua")then gadgetHandler:RemoveGadget(self);return end
 end
 -- The same immutable banks are used by the real unit scripts; share them
 -- instead of retaining a second large pair after deployment admission.
 GG.Prototype40kAnimationCache=GG.Prototype40kAnimationCache or{}
 local cache=GG.Prototype40kAnimationCache
 local function bank(key)
  if not cache[key]then cache[key]=VFS.Include(path..key..'_anim.lua')end
  return cache[key]
 end
 local p=bank('imp_heavy_weapon_team');local d=bank('imp_heavy_weapon_team_deployed')
 local deploy=p.clips and p.clips.deploy;local pack=d.clips and d.clips.pack
 if not p.clips or not p.clips.idle or not p.clips.walk or not p.clips.fire or not d.clips or not d.clips.idle or not d.clips.fire
  or not deploy or deploy.source~="deployed_setup_heavy_bolter" or not pack or pack.source~="deployed_breakdown_heavy_bolter" then gadgetHandler:RemoveGadget(self);return end
 if not deploy or not pack or not deploy.duration or not pack.duration or deploy.duration<=0 or pack.duration<=0 or deploy.duration>20 or pack.duration>20 then gadgetHandler:RemoveGadget(self);return end
 if packed.metalCost~=deployed.metalCost or packed.energyCost~=deployed.energyCost or packed.buildTime~=deployed.buildTime or not packed.canMove or deployed.canMove then
  Spring.Echo("40K HWT","DISABLED","paired_cost_or_mobility_mismatch");gadgetHandler:RemoveGadget(self);return
 end
 timing={deploy=math.ceil(deploy.duration*fps),pack=math.ceil(pack.duration*fps)}
 previousTransitionMirror=GG.Prototype40kTransitionState
 transitionMirror={known={},values={}}
 GG.Prototype40kTransitionState=transitionMirror
 gadgetHandler:RegisterCMDID(DEPLOY);gadgetHandler:RegisterCMDID(PACK)
 for _,id in ipairs(Spring.GetAllUnits())do registerTransition(id);descriptor(id)end
end
function gadget:UnitCreated(id,defID)registerTransition(id);if packed and (defID==packed.id or defID==deployed.id)then descriptor(id)end end
function gadget:UnitFinished(id,defID)if packed and (defID==packed.id or defID==deployed.id)then descriptor(id)end end
function gadget:UnitDestroyed(id)if pending[id]then cancel(id,"source_destroyed")end;units[id]=nil;if transitionMirror then transitionMirror.known[id]=nil;transitionMirror.values[id]=nil end end
function gadget:UnitLoaded(id)if pending[id]then cancel(id,"source_transported")end end
function gadget:UnitTaken(id)if pending[id]then cancel(id,"source_transferred")end end
function gadget:UnitGiven(id)if packed then descriptor(id)end end
function gadget:AllowCommand(id,defID,team,cmd)
 if internalOrder then return true end
 if not packed or (defID~=packed.id and defID~=deployed.id)then return true end
 if cmd==DEPLOY or cmd==PACK then begin(id,cmd);return false end
 if pending[id]then if cmd==CMD.STOP then cancel(id,"player_cancelled");return true end;return false end
 return true
end
function gadget:GameFrame(frame)
 for _,id in ipairs(sorted(pending))do
  local state=pending[id]
  if not alive(id)then cancel(id,"source_destroyed")
  elseif busy(id) or Spring.GetUnitTeam(id)~=state.team then cancel(id,"source_became_busy")
  elseif frame>=state.finish then finish(id,state)end
 end
 if frame%15==0 then for _,id in ipairs(sorted(units))do if alive(id)then descriptor(id)else units[id]=nil end end end
end

function gadget:Shutdown()
 for _,id in ipairs(sorted(pending))do cancel(id,"gadget_shutdown")end
 if transitionMirror and GG.Prototype40kTransitionState==transitionMirror then GG.Prototype40kTransitionState=previousTransitionMirror end
 transitionMirror=nil
end
