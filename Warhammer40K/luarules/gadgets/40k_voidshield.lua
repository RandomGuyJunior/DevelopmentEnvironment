function gadget:GetInfo()
 return {name='40K source self void shields',desc='Explicitly verified morale profiles only',author='Local Recoil Project',layer=-10,enabled=true}
end
if not gadgetHandler:IsSyncedCode() then return end
local profiles=VFS.Include('40k_configs/voidshield_profiles.lua')
local states={}
local function publish(id,s)
 Spring.SetUnitRulesParam(id,'40k_voidshield_charge',s.charge,{inlos=true})
 Spring.SetUnitRulesParam(id,'40k_voidshield_broken',s.broken and 1 or 0,{inlos=true})
 Spring.SetUnitRulesParam(id,'40k_voidshield_unsupported_hits',s.unsupported,{inlos=true})
end
local function finite(n)return type(n)=='number' and n==n and n>-math.huge and n<math.huge end
function gadget:UnitFinished(id,def)
 local cp=UnitDefs[def].customParams or {}
 local p=profiles[cp.source_voidshield_profile]
 -- Source-only candidates must never acquire automatic health immunity.
 if not p or tonumber(cp.source_voidshield_profile_verified)~=1 then return end
 if states[id] then return end -- transfer / repeated completion must not refill
 states[id]={profile=p,charge=p.initial,broken=false,brokenFrame=nil,unsupported=0}
 publish(id,states[id])
end
function gadget:Initialize()
 GG.Recoil40KVoidShield={states=states}
 for _,id in ipairs(Spring.GetAllUnits())do
  local _,_,_,_,progress=Spring.GetUnitHealth(id)
  if progress and progress>=1 then self:UnitFinished(id,Spring.GetUnitDefID(id))end
 end
end
function gadget:UnitPreDamaged(id,def,team,damage,paralyzer,weapon,projectile,attacker,attackerDef,attackerTeam)
 local s=states[id]
 if not s or s.broken or paralyzer or not finite(damage) or damage<=0 then return damage,1 end
 local wd=weapon and WeaponDefs[weapon]
 local cp=wd and wd.customParams
 local morale=cp and tonumber(cp.source_morale_damage)
 -- A measured per-native-hit scalar (including burst/beam fraction and falloff).
 -- Unknown / unconverted weapons and environmental damage remain real damage.
 if not cp or tonumber(cp.source_morale_per_native_hit_verified)~=1 or not finite(morale) or morale<0 then
  s.unsupported=s.unsupported+1;publish(id,s);return damage,1
 end
 s.charge=math.max(0,s.charge-morale*(1-s.profile.moraleArmour))
 if s.charge<=0 then
  s.broken=true;s.brokenFrame=Spring.GetGameFrame();publish(id,s)
  -- Conservative ordering until source measurement resolves the breaking hit.
  return damage,1
 end
 publish(id,s)
 -- Self only: no team energy, neighboring-unit immunity, healing, or projectile
 -- interception invented by applying an area Shield weapon to a body ability.
 return 0,0
end
function gadget:GameFrame(frame)
 for id,s in pairs(states)do
  local p=s.profile
  local rate=s.broken and p.brokenRegen or p.activeRegen
  s.charge=math.min(p.maximum,s.charge+rate/30)
  if s.broken and frame-s.brokenFrame>=p.minimumBreakFrames and s.charge>=p.recoveryThreshold then
   s.broken=false;s.brokenFrame=nil
  end
  -- Rules updates at sim cadence needed for exact future save/reload fixtures.
  publish(id,s)
 end
end
function gadget:UnitDestroyed(id)states[id]=nil end
function gadget:Shutdown()if GG.Recoil40KVoidShield and GG.Recoil40KVoidShield.states==states then GG.Recoil40KVoidShield=nil end end
