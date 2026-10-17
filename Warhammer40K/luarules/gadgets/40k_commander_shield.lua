function gadget:GetInfo()
 return{name='40K Commander Shield Toggle',desc='Independent toggle; native BAR shield costs, recharge and damage',author='BAR 40K',layer=-20,enabled=true}
end
if not gadgetHandler:IsSyncedCode()then return false end
local S=Spring
local policy=VFS.Include('40k_configs/ork_commander_shield.lua')
local targets,tracked={},{}
for id,d in pairs(UnitDefs)do
 local p=d.customParams or{}
 if p.prototype40k_commander_shield==policy.Tag then
  assert(d.name=='ork_big_mek_commander','Commander shield policy on a non-commander')
  local number
  for n,w in ipairs(d.weapons)do if WeaponDefs[w.weaponDef].type=='Shield'then assert(not number);number=n end end
  assert(number,'Commander native shield missing')
  targets[id]={number=number}
 end
end
local function active(id)
 local state=tracked[id]
 if state then return state.wanted and S.GetUnitIsActive(id)and not S.GetUnitIsStunned(id)end
 return nil
end
local function publish(id)
 S.SetUnitRulesParam(id,policy.ActiveParam,active(id)and 1 or 0,{allied=true})
end
local function command(id,state)
 local desc={id=policy.Command,type=CMDTYPE.ICON_MODE,name='Plasma Shield',action='40kplasmashield',queueing=false,
  tooltip='Plasma shield: standard plasma-generator energy cost while recharging',params={state.wanted and 1 or 0,'Off','On'}}
 local index=S.FindUnitCmdDesc(id,policy.Command)
 if index then S.EditUnitCmdDesc(id,index,desc)else S.InsertUnitCmdDesc(id,desc)end
end
local function track(id,def)
 if targets[def]then
  tracked[id]={def=def,wanted=false}
  S.SetUnitShieldState(id,targets[def].number,false)
  S.SetUnitRulesParam(id,policy.WantedParam,0,{allied=true})
  publish(id);command(id,tracked[id])
 end
end
function gadget:UnitCreated(id,def)track(id,def)end
function gadget:UnitFinished(id,def)track(id,def)end
function gadget:UnitDestroyed(id)tracked[id]=nil end
function gadget:UnitGiven(id,def)track(id,def)end
function gadget:UnitTaken(id,def)track(id,def)end
function gadget:Initialize()
 assert(not CMD[policy.Command]and not(Game.CustomCommands and Game.CustomCommands.GameCMD and Game.CustomCommands.GameCMD[policy.Command]),'Plasma Shield command ID collision')
 assert(not GG.Recoil40KCommanderShieldAllowed and not GG.Recoil40KCommanderShieldActive,'Duplicate commander shield toggle')
 GG.Recoil40KCommanderShieldActive=active
 GG.Recoil40KCommanderShieldAllowed=function(id)
  local enabled=active(id)
  if enabled==nil then return nil end
  if not enabled then return false end
  local state=tracked[id]
  local native,power=S.GetUnitShieldState(id,targets[state.def].number)
  return(native==true or native==1)and type(power)=='number'and power>0
 end
 for _,id in ipairs(S.GetAllUnits())do track(id,S.GetUnitDefID(id))end
end
function gadget:AllowCommand(id,def,team,cmd,params)
 if cmd~=policy.Command then return true end
 local state=tracked[id]
 if not state or state.def~=def or type(params)~='table'or #params~=1 or(params[1]~=0 and params[1]~=1)then return false end
 state.wanted=params[1]==1
 S.SetUnitRulesParam(id,policy.WantedParam,state.wanted and 1 or 0,{allied=true})
 S.SetUnitShieldState(id,targets[def].number,false)
 publish(id);command(id,state)
 return false -- Consumed stock-HUD mode toggle, never a movement/queue order.
end
function gadget:GameFrame(frame)
 for id,state in pairs(tracked)do
  publish(id)
  if not active(id)then S.SetUnitShieldState(id,targets[state.def].number,false)end
  -- Native AimShield, engine recharge and BAR downtime/recovery own enabling,
  -- charge and energy payment. No custom resource use or charge modification.
 end
end
function gadget:Shutdown()
 for id,state in pairs(tracked)do S.SetUnitShieldState(id,targets[state.def].number,false);S.SetUnitRulesParam(id,policy.ActiveParam,0,{allied=true})end
 GG.Recoil40KCommanderShieldAllowed=nil;GG.Recoil40KCommanderShieldActive=nil
end
