function gadget:GetInfo()return{name='40K Crewed Warbike contact ram',desc='Targeted native attack run, actual collision damage and loop',author='Local project',layer=45,enabled=true}end
if not gadgetHandler:IsSyncedCode()then return false end
local S=Spring;local bike=UnitDefNames.ork_warbike_crewed
if not bike or tostring((bike.customParams or{}).prototype40k_warbike_ram)~='1'then return false end
local config=VFS.Include('40k_configs/warbike_contact_ram.lua');local RAM=config.Command
local forwarding=false;local watched={};local C
local function live(id)return type(id)=='number'and S.ValidUnitID(id)and not S.GetUnitIsDead(id)end
local function watch(def)
 if not def then return end
 local row=watched[def]
 if row then row.count=row.count+1;return end
 local before=Script.GetWatchUnit(def)==true
 watched[def]={count=1,before=before};if not before then Script.SetWatchUnit(def,true)end
end
local function releaseWatch(def)
 local row=watched[def];if not row then return end
 row.count=row.count-1;if row.count>0 then return end
 watched[def]=nil;if not row.before then Script.SetWatchUnit(def,false)end
end
local function releaseGoal(id,goal)
 if not live(id)or S.MoveCtrl.IsEnabled(id)then return end
 local md=S.GetUnitMoveTypeData(id)
 if md and md.name=='ground'and math.abs((md.goalx or math.huge)-goal.x)<.01 and math.abs((md.goalz or math.huge)-goal.z)<.01 then S.ClearUnitGoal(id,false)end
end
C=config.New({
 Live=live,Team=S.GetUnitTeam,Definition=S.GetUnitDefID,Allied=S.AreTeamsAllied,Neutral=S.GetUnitNeutral,
 Frame=S.GetGameFrame,Head=function(id)return(S.GetUnitCommands(id,1)or{})[1]end,
 Ground=function(id)local d=UnitDefs[S.GetUnitDefID(id)];return d and not d.canFly and not d.isAirUnit end,
 Busy=function(id)return S.GetUnitTransporter(id)or S.MoveCtrl.IsEnabled(id)or select(1,S.GetUnitIsStunned(id))end,
 Visible=function(id,target)local ally=S.GetUnitAllyTeam(id);local state=ally and S.GetUnitLosState(target,ally);return state and state.los==true or false end,
 Position=S.GetUnitPosition,MoveData=S.GetUnitMoveTypeData,Radius=function(id)return S.GetUnitRadius(id)or 16 end,
 Height=function(id)return S.GetUnitHeight(id)or 16 end,MaxSpeed=function(id)return UnitDefs[S.GetUnitDefID(id)].speed end,
 Velocity=function(id)local x,_,z=S.GetUnitVelocity(id);return x or 0,z or 0 end,
 Goal=function(id,x,z,raw)
  local d=UnitDefs[S.GetUnitDefID(id)];if x<8 or z<8 or x>Game.mapSizeX-8 or z>Game.mapSizeZ-8 then return false end
  local y=S.GetGroundHeight(x,z)
  if S.TestMoveOrder(d.id,x,y,z,0,0,0,true,false,false)~=true then return false end
  S.SetUnitMoveGoal(id,x,y,z,raw and 2 or 8,nil,raw);return true
 end,ReleaseGoal=releaseGoal,
 Target=function(id,target)S.SetUnitTarget(id,target,false,true)end,
 ReleaseTarget=function(id,target)
  if not live(id)then return end
  local kind,_,current=S.GetUnitWeaponTarget(id,1)
  if kind==1 and current==target then S.SetUnitTarget(id,nil)end
 end,
 LastHit=function(id)return S.GetUnitRulesParam(id,'40k_warbike_last_ram_frame')end,
 SetLastHit=function(id,frame)S.SetUnitRulesParam(id,'40k_warbike_last_ram_frame',frame,{private=true})end,
 Damage=function(target,amount,attacker)S.AddUnitDamage(target,amount,0,attacker,-1,0,0,0)end,
 Watch=watch,ReleaseWatch=releaseWatch,Report=function(id,state)S.SetUnitRulesParam(id,'40k_warbike_ram_state',state,{allied=true})end,
})
local stateCommands={}
for _,name in ipairs({'FIRE_STATE','MOVE_STATE','REPEAT','CLOAK','IDLEMODE'})do if CMD[name]then stateCommands[CMD[name]]=true end end
function gadget:Initialize()gadgetHandler:RegisterCMDID(RAM);GG.Recoil40KWarbikeRam=C end
function gadget:Shutdown()if GG.Recoil40KWarbikeRam==C then GG.Recoil40KWarbikeRam=nil end;for _,id in ipairs(S.GetAllUnits())do if S.GetUnitDefID(id)==bike.id then C.Cancel(id,'shutdown')end end end
function gadget:AllowCommand(id,def,team,cmd,params,opts,tag,player,fromSynced,fromLua,fromInsert)
 if def~=bike.id then return cmd~=RAM end
 if forwarding then return true end
 if cmd==RAM then return false end -- Only the stock targeted ATTACK redirects here.
 local target=cmd==CMD.ATTACK and #params==1 and params[1]
 local td=target and live(target)and UnitDefs[S.GetUnitDefID(target)]
 local los=td and S.GetUnitLosState(target,S.GetUnitAllyTeam(id))
 if td and not td.canFly and not td.isAirUnit and not S.GetUnitNeutral(target)and not S.AreTeamsAllied(team,S.GetUnitTeam(target))and los and los.los==true then
  forwarding=true
  if fromInsert then S.GiveOrderToUnit(id,CMD.INSERT,{tag,RAM,opts and opts.coded or 0,params[1]},fromInsert.coded or 0)
  else if not(opts and opts.shift)then C.Cancel(id,'new_attack')end;S.GiveOrderToUnit(id,RAM,params,opts and opts.coded or 0)end
  forwarding=false;return false
 end
 if fromInsert then return true end -- Future ordinary orders must not cancel the current run on admission.
 if cmd==CMD.REMOVE and(opts and(opts.alt or math.floor((opts.coded or 0)/128)%2==1))then
  local translated={};local changed=false
  for i,value in ipairs(params)do translated[i]=value==CMD.ATTACK and RAM or value;changed=changed or value==CMD.ATTACK end
  if changed then forwarding=true;S.GiveOrderToUnit(id,cmd,translated,opts.coded or 0);forwarding=false;return false end
 end
 if not stateCommands[cmd]and cmd~=CMD.INSERT and cmd~=CMD.REMOVE and not(opts and opts.shift)then C.Cancel(id,'ordinary_native_command')end
 return true
end
function gadget:CommandFallback(id,def,team,cmd,params,opts,tag)
 if cmd~=RAM or def~=bike.id then return false end
 return C.Fallback(id,params[1],tag)
end
function gadget:GameFrame(frame)C.Frame(frame)end
function gadget:UnitUnitCollision(a,b)C.Collision(a,b);C.Collision(b,a)end
function gadget:UnitDestroyed(id)C.Removed(id,true)end
function gadget:UnitGiven(id)C.Removed(id)end
function gadget:UnitTaken(id)C.Removed(id)end
function gadget:UnitLoaded(id)C.Removed(id)end
