-- Hybrid native health research owner. Source variant mode has its own composer.
-- Engine AddExperience replaces maxHP after its grade-only callback. Reconcile
-- only units with a completed paid health addition, after native simulation.
local M={}
local function finite(v)return type(v)=='number'and v==v and v>=0 and v<math.huge end
local function near(a,b)return math.abs(a-b)<=math.max(1,math.abs(a),math.abs(b))*1e-6 end
function M.New(S,defs,healthScale)
 assert(finite(healthScale),'Actual experience health scale required')
 assert(S.GetUnitExperience and S.GetUnitHealth and S.SetUnitMaxHealth and S.SetUnitHealth,'Native health APIs required')
 local H={watched={}}
 local function apply(id,def,add)
  local hp,max=S.GetUnitHealth(id)
  if not hp or hp<=0 or not max or max<=0 then H.watched[id]=nil;return false end
  local base=defs[def]and defs[def].health
  assert(finite(base)and base>0 and finite(add),'Unmodified UnitDef health and paid addition required')
  local limited=0
  if healthScale>0 then
   local _,lim=S.GetUnitExperience(id);assert(finite(lim)and lim<=1,'Native limited experience unavailable');limited=lim
  end
  local wanted=(base+add)*(1+limited*healthScale)
  if not near(max,wanted)then
   -- Snapshot before SetUnitMaxHealth clamps current HP on a reduction.
   local fraction=hp/max
   S.SetUnitMaxHealth(id,wanted);S.SetUnitHealth(id,{health=fraction*wanted})
  end
  return true
 end
 function H.Apply(id,def,add)
  local applied=apply(id,def,add)
  if applied and add>0 and healthScale>0 then H.watched[id]={def=def,add=add}
  else H.watched[id]=nil end
  return applied
 end
 function H.Remove(id)H.watched[id]=nil end
 function H.Frame()
  local ids={};for id in pairs(H.watched)do ids[#ids+1]=id end;table.sort(ids)
  for _,id in ipairs(ids)do local row=H.watched[id];apply(id,row.def,row.add)end
 end
 return H
end
return M
