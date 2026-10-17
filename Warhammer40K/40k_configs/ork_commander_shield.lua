-- Only the founding Ork commander. Native BAR remains the shield damage owner.
local M={}
M.Tag='native_corgate_half_standard_cost_v2'
M.ActiveParam='40k_commander_shield_active'
M.WantedParam='40k_commander_shield_wanted'
M.Command=39955 -- Free in the pinned native customcommands registry and project commands.
local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
function M.Capture(nativeCommander,nativeGate)
 local shield=nativeGate.weapondefs.repulsor
 assert(shield.weapontype=='Shield'and shield.shield.radius==550 and shield.shield.power==6175,'Pinned Cortex plasma shield changed')
 assert(shield.shield.powerregenenergy==562.5 and shield.shield.energyupkeep==0,'Pinned Cortex plasma shield cost changed')
 return{upkeep=nativeGate.energyupkeep or 0,weapon=copy(shield),gateParams=copy(nativeGate.customparams)}
end
function M.Apply(defs,reference)
 local d=assert(defs.ork_big_mek_commander,'Missing Ork commander');local cp=assert(d.customparams)
 assert(tostring(cp.prototype40k)=='1'and cp.faction=='Orks','Actual Ork commander presentation required')
 assert(reference.upkeep==0 and reference.weapon.shield.powerregenenergy==562.5 and reference.weapon.shield.radius==550,'Checked native reference required')
 local key,index
 for i,mount in ipairs(d.weapons or{})do
  local name=mount.def:lower();local w=d.weapondefs[name]
  if w and w.weapontype=='Shield'then assert(not key,'Only one existing commander shield allowed');key,index=name,i end
 end
 assert(key,'Existing passive commander shield mount required')
 local sourceParams=copy(d.weapondefs[key].customparams or{})
 local weapon=copy(reference.weapon);weapon.name='Commander plasma shield'
 weapon.shield.radius=reference.weapon.shield.radius/2
 -- Start empty/off; native BAR/engine alone pays for recharge at standard cost.
 weapon.shield.startingpower=0
 weapon.shield.visible=true;weapon.customparams=sourceParams
 d.weapondefs[key]=weapon
 -- Shield uses a separate stock ICON_MODE command, without changing unit state.
 d.onoffable=false;d.activatewhenbuilt=true;d.energyupkeep=reference.upkeep
 cp.shield_radius=weapon.shield.radius;cp.shield_power=weapon.shield.power
 cp.shield_color_mult=reference.gateParams.shield_color_mult
 cp.prototype40k_commander_shield=M.Tag
 cp.commander_shield_idle_energy=nil;cp.commander_shield_moving_energy=nil
 return{unit='ork_big_mek_commander',weapon=index,radius=weapon.shield.radius,power=weapon.shield.power,nativeRechargeEnergy=weapon.shield.powerregenenergy,unitUpkeep=reference.upkeep,defaultOn=false}
end
function M.CanAim(id,S)return S.GetUnitRulesParam(id,M.ActiveParam)==1 end
return M
