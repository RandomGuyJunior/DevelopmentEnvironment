-- Explicit review-only adapter. No accepted marker or paid-menu edits.
local M={}
local function copy(t)if type(t)~='table'then return t end;local r={};for k,v in pairs(t)do r[k]=copy(v)end;return r end
function M.Apply(name,def,animation,contract,review)
 if review~=true then return nil,'explicit_lifta_review_required'end
 local proof,why=contract.InspectDefinition(name,def,animation)
 if not proof then return nil,why end
 local out=copy(def)
 out.weapons[4].onlytargetcategory='SURFACE VTOL'
 out.customparams.lifta_adaptation='vertical_hold_v1'
 out.weapondefs.mount4.customparams.prototype40k_lifta_hold=1
 return out,{nativeAccepted=false,sourceTimingsRecovered=false,damageChanged=false,sourceSupportsAir=true}
end
function M.Bindings(defs,weapons)
 local result={}
 for id,d in pairs(defs)do
  local cp=d.customParams or{}
  local slot=d.weapons and d.weapons[4];local wd=slot and weapons[slot.weaponDef];local p=wd and wd.customParams or{}
  if d.name=='ork_dakka_stompa'and cp.animsource=='ork_dakka_stompa'and cp.lifta_adaptation=='vertical_hold_v1'
   and wd and wd.type=='BeamLaser'and tostring(p.prototype40k_lifta_hold)=='1'
   and p.source_muzzle=='lifta_droppa_beam_start'and p.source_fireclip=='fire_lifta_droppa'
   and p.source_aimpiece=='lifta_droppa_aim_horizontal'and p.source_pitchpiece=='lifta_droppa_aim_vertical'then
   result[id]={mount=4,weapon=slot.weaponDef}
  end
 end
 return result
end
return M
