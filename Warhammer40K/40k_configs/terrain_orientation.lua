-- Final actor orientation policy, after native-role donor replacement.
-- Native grounded movement performs the rotation; source skeleton clocks stay untouched.
local M={}
local floating={nec_destroyer=true,nec_heavy_destroyer=true,nec_monolith_mobile=true}
local vertical={infantry=true,builder=true,walker=true,commander=true,constructor=true}
local vehicle={tank=true,transport=true,artillery=true,bike=true}
local function marked(v) return v==true or v==1 or v=='1' end
function M.Classify(name,ud)
 local cp=ud.customparams or {}
 if not marked(cp.prototype40k) then return nil,'native_actor_unchanged' end
 if marked(ud.canfly) then return nil,'air_actor_unchanged' end
 if marked(ud.canhover) or tostring(ud.movementclass or ''):upper():find('HOVER',1,true) then return nil,'native_hover_actor_unchanged' end
 if ud.canmove==false or (tonumber(ud.speed or ud.maxvelocity) or 0)<=0 then return nil,'static_actor_unchanged' end
 local override=cp.source_ground_orientation
 if override=='terrain' then return false,'explicit_terrain' end
 if override=='upright' then return true,'explicit_upright' end
 local source=cp.animsource or cp.prototype40k_donor or name
 if floating[source] or floating[name] then return true,'floating_actor_vertical' end
 local role=cp.rosterrole or cp.production_role
 if vertical[role] then return true,'standing_actor_vertical' end
 if vehicle[role] or ud.script=='40k_tank.lua' then return false,'ground_vehicle_terrain' end
 -- Baseline human/walker source scripts predate the explicit roster role field.
 if ud.script=='40k_infantry.lua' then return true,'standing_baseline_vertical' end
 return nil,'unclassified_actor_unchanged'
end
function M.Apply(defs)
 local report={changed={},unchanged={}}
 for name,ud in pairs(defs) do
  local value,why=M.Classify(name,ud)
  if value~=nil then
   if ud.upright~=value then report.changed[#report.changed+1]={name=name,upright=value,reason=why} end
   ud.upright=value
  else report.unchanged[#report.unchanged+1]={name=name,reason=why} end
 end
 return report
end
return M
