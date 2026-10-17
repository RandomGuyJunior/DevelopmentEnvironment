function gadget:GetInfo()return{name='40K native melee contact effects',desc='One cosmetic effect for an actual positive native melee hit',author='Local project',layer=0,enabled=true}end
if not gadgetHandler:IsSyncedCode()then return false end
local effects,owners,last={},{},{}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
function gadget:Initialize()
 for wid,w in pairs(WeaponDefs)do
  local c=w.customParams or{}
  if w.type=='Melee'and c.prototype40k_contact_impact_owner=='native_positive_melee_hit_v1'
   and type(c.prototype40k_contact_impact_ceg)=='string'then effects[wid]=c.prototype40k_contact_impact_ceg end
 end
 for def,d in pairs(UnitDefs)do
  local c=d.customParams or{}
  if tostring(c.prototype40k)=='1'then
   local mounts={};for _,row in ipairs(d.weapons or{})do if effects[row.weaponDef]then mounts[row.weaponDef]=true end end
   if next(mounts)then owners[def]=mounts end
  end
 end
end
function gadget:UnitDamaged(id,def,team,damage,paralyzer,wid,pid,attacker,attackerDef,attackerTeam)
 if pid~=-1 or paralyzer or not finite(damage)or damage<=0 or attacker==id or not attacker or not effects[wid]
  or not owners[attackerDef]or not owners[attackerDef][wid]then return end
 if Spring.GetUnitDefID(attacker)~=attackerDef or Spring.GetUnitTeam(attacker)~=attackerTeam
  or Spring.GetUnitIsDead(attacker)
  or Spring.GetUnitDefID(id)~=def or Spring.GetUnitTeam(id)~=team or Spring.GetUnitIsDead(id)then return end
 local x,y,z,mx,my,mz=Spring.GetUnitPosition(id,true)
 if finite(mx)and finite(my)and finite(mz)then x,y,z=mx,my,mz end
 if not finite(x)or not finite(y)or not finite(z)then return end
 -- Native melee has one target per strike. Coalesce duplicate callbacks from
 -- the same attacker/WeaponDef/frame without changing damage or its reload clock.
 local frame=Spring.GetGameFrame();local row=last[attacker]
 if row and row[wid]==frame then return end
 row=row or{};last[attacker]=row;row[wid]=frame
 Spring.SpawnCEG(effects[wid],x,y,z,0,1,0)
end
function gadget:UnitDestroyed(id)last[id]=nil end
