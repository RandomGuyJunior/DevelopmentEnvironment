function gadget:GetInfo() return {name='Infantry Shoot and Charge',layer=10001,enabled=true} end
local SOUND,MELEE='bar40k_squad_small_arm','bar40k_squad_melee_hit'
if not gadgetHandler:IsSyncedCode() then
 local nextSound,nextMelee=0,0
 local audio=VFS.FileExists("gamedata/ork_squad_audio_profiles.lua") and VFS.Include("gamedata/ork_squad_audio_profiles.lua") or {}
 local lastRanged={}
 local function profile(u,kind)
  local cp=UnitDefs[Spring.GetUnitDefID(u)].customParams
  local p=audio[cp.squad_sound_profile]
  return p and p[kind],cp.tenguard_squad
 end
 local lastMelee={}
 local function audible(u)
  if not Spring.ValidUnitID(u) then return false end
  local spec,full=Spring.GetSpectatingState();local los=Spring.GetUnitLosState(u,Spring.GetMyAllyTeamID(),false)
  return (spec and full or los and los.los) and Spring.IsUnitInView(u)
 end
 local function sound(_,u,muzzle,f)
  if f<nextSound or not audible(u) then return end
  local x,y,z=Spring.GetUnitPiecePosDir(u,muzzle);if not x then return end
  local p,guard=profile(u,'ranged')
  if p and f<(lastRanged[u] or -1) then return end
  local key=p and p.keys[math.random(1,#p.keys)] or (guard and 'squad_dow_lasgun' or 'squad_dow_slugga')
  Spring.PlaySoundFile(key,p and p.gain or (guard and 3.3 or 2.0),x,y,z,'sfx');nextSound=f+3
  if p then lastRanged[u]=f+(p.intervalFrames or 12) end
 end
 local function melee(_,u,f)
  if f<nextMelee or f<(lastMelee[u] or -1) or not audible(u) then return end
  local x,y,z=Spring.GetUnitPosition(u);local p,guard=profile(u,'melee')
  local key=p and p.keys[math.random(1,#p.keys)] or ('squad_dow_'..(guard and 'guard' or 'ork')..'_melee_'..math.random(1,3))
  Spring.PlaySoundFile(key,p and p.gain or (guard and 1.6 or 1.8),x,y,z,'sfx')
  nextMelee=f+4;lastMelee[u]=f+(p and p.intervalFrames or 12)
 end
 function gadget:Initialize()gadgetHandler:AddSyncAction(SOUND,sound);gadgetHandler:AddSyncAction(MELEE,melee)end
 function gadget:Shutdown()gadgetHandler:RemoveSyncAction(SOUND);gadgetHandler:RemoveSyncAction(MELEE)end
 return
end
local FOCUS,CHARGE=34582,34583
local squads,focus,retaliate={},{},{}
local function hostile(u,v)
 return v and Spring.ValidUnitID(v) and not Spring.GetUnitIsDead(v) and not Spring.AreTeamsAllied(Spring.GetUnitTeam(u),Spring.GetUnitTeam(v))
end
local function visibleGround(u,v)
 if not hostile(u,v)then return false end
 local d=UnitDefs[Spring.GetUnitDefID(v)];local los=Spring.GetUnitLosState(v,Spring.GetUnitAllyTeam(u))
 return d and not d.canFly and los and los.los
end
-- Explicit mapping keeps a mixed squad's ranged slot2 separate from melee.
local function meleeSlots(u,d)
 local c=UnitDefs[d or Spring.GetUnitDefID(u)].customParams
 return tonumber(c.squad_melee_first)or 2,tonumber(c.squad_melee_last)or 2
end
local function setMeleeTarget(u,target,d)
 local first,last=meleeSlots(u,d)
 for n=first,last do Spring.SetUnitTarget(u,target,false,false,n)end
end
local function isMeleeWeapon(u,d,weapon)
 local first,last=meleeSlots(u,d)
 for n=first,last do local slot=UnitDefs[d].weapons[n];if slot and slot.weaponDef==weapon then return true end end
 return false
end
local function labels(u,value)
 local c=UnitDefs[Spring.GetUnitDefID(u)].customParams
 if c.knight_combat_modes then return value==1 and 'Charge' or 'Ranged',value==1 and 'Close to use melee weapons' or 'Stay at range and shoot','Ranged' end
 return value==1 and 'Charge' or 'Shoot',value==1 and 'Charge into melee' or 'Stand and fire','Shoot'
end
local function setFocus(u,value)
 focus[u]=value;Spring.SetUnitRulesParam(u,'squad_combat_focus',value,{inlos=true})
 local idx=Spring.FindUnitCmdDesc(u,FOCUS)
 if idx then local name,tip,ranged=labels(u,value);Spring.EditUnitCmdDesc(u,idx,{name=name,action=value==1 and 'squadcharge' or 'squadshoot',tooltip=tip,params={value,ranged,'Charge'}})end
end
local function register(u,d)
 local c=UnitDefs[d].customParams;if not(c.squad_capacity or c.tenboy_squad or c.tenguard_squad or c.squad_melee_controller)then return end
 if c.squad_no_melee then return end
 squads[u]=true
 if not Spring.FindUnitCmdDesc(u,FOCUS)then Spring.InsertUnitCmdDesc(u,{id=FOCUS,type=CMDTYPE.ICON_MODE,name='Shoot',action='squadshoot',tooltip='Stand and fire',params={0,'Shoot','Charge'}})end
 setFocus(u,Spring.GetUnitRulesParam(u,'squad_combat_focus')or(tonumber(c.squad_default_focus) or (c.tenboy_squad and 1 or 0)))
end
function gadget:Initialize()
 GG.SquadMelee={};GG.SquadSound=function(u,m,f)SendToUnsynced(SOUND,u,m,f)end
 gadgetHandler:RegisterCMDID(FOCUS);gadgetHandler:RegisterCMDID(CHARGE)
 for _,u in ipairs(Spring.GetAllUnits())do register(u,Spring.GetUnitDefID(u))end
end
function gadget:UnitCreated(u,d)register(u,d)end
function gadget:UnitDestroyed(u)squads[u]=nil;focus[u]=nil;retaliate[u]=nil;GG.SquadMelee[u]=nil end
function gadget:AllowCommand(u,d,t,cmd,params)
 if cmd~=FOCUS then return true end
 if squads[u]then setFocus(u,params[1]==1 and 1 or 0)end
 return false
end
local function insertCharge(u,target)
 -- Keep the original attack underneath: Shoot restores it, and queued orders
 -- survive. A normal Move/Stop still cancels the charge immediately.
 Spring.GiveOrderToUnit(u,CMD.INSERT,{0,CHARGE,CMD.OPT_INTERNAL,target},{'alt'})
end
function gadget:CommandFallback(u,d,t,cmd,params)
 if cmd~=CHARGE then return false end
 local target=params[1]
 if not squads[u]or focus[u]~=1 or not visibleGround(u,target)then
  Spring.SetUnitRulesParam(u,'squad_charge_target',-1,{inlos=true});return true,true
 end
 local x,y,z=Spring.GetUnitPosition(u);local tx,ty,tz=Spring.GetUnitPosition(target)
 Spring.SetUnitRulesParam(u,'squad_charge_target',target,{inlos=true})
 if GG.SquadMelee[u]then
  Spring.SetUnitMoveGoal(u,x,y,z,1)
  setMeleeTarget(u,GG.SquadMelee[u],d)
 else
  Spring.SetUnitMoveGoal(u,tx,ty,tz,8)
  Spring.SetUnitTarget(u,target,false,false,1)
 end
 return true,false
end
function gadget:UnitDamaged(u,d,t,damage,paralyzer,weapon,projectile,attacker,attackerDef)
 if damage<=0 or not attacker then return end
 if squads[u]and focus[u]==1 and hostile(u,attacker)then retaliate[u]=attacker end
 if squads[attacker]and attackerDef and isMeleeWeapon(attacker,attackerDef,weapon)then
  SendToUnsynced(MELEE,attacker,Spring.GetGameFrame())
 end
end
function gadget:GameFrame(f)
 if f%6~=0 then return end
 for u in pairs(squads)do
  local cmd,opts,tag,p1,p2=Spring.GetUnitCurrentCommand(u)
  if focus[u]==1 then
   if cmd==CMD.ATTACK and p1 and not p2 and visibleGround(u,p1)then insertCharge(u,p1)
   elseif (not cmd or cmd==CMD.FIGHT or cmd==CMD.PATROL)and visibleGround(u,retaliate[u])then insertCharge(u,retaliate[u])end
  end
  retaliate[u]=nil
  local x,y,z=Spring.GetUnitPosition(u)
  local cp=UnitDefs[Spring.GetUnitDefID(u)].customParams
  local base=tonumber(cp.squad_melee_engage_radius)or 55
  local radius=base+(GG.SquadMelee[u]and 4 or 0)
  local extra=cp.squad_melee_first and 96 or 0
  local nearest,best=nil,radius*radius
  for _,v in ipairs(Spring.GetUnitsInCylinder(x,z,radius+extra))do
   local first=meleeSlots(u)
   if UnitDefs[Spring.GetUnitDefID(u)].weapons[first] and v~=u and(focus[u]==1 or focus[v]==1 or cp.squad_melee_opportunistic)and visibleGround(u,v)then
    local vx,vy,vz=Spring.GetUnitPosition(v);local dist=(vx-x)^2+(vz-z)^2
    if cp.squad_melee_first then
     local r=Spring.GetUnitRadius(v)or 0
     dist=math.max(0,math.sqrt(dist)-math.min(r,96))^2
    end
    if math.abs(vy-y)<20 and(dist<best or dist==best and v<(nearest or v+1))then nearest,best=v,dist end
   end
  end
  GG.SquadMelee[u]=nearest;Spring.SetUnitRulesParam(u,'squad_melee_target',nearest or -1,{inlos=true})
  if nearest then setMeleeTarget(u,nearest)end
 end
end
function gadget:Shutdown()GG.SquadMelee=nil;GG.SquadSound=nil end
