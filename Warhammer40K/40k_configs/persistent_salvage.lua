-- Orks-first v1.3 section15. Metadata only; no model imports or resource owner.
local M={}
local function yes(v)return v==true or v==1 or v=='1'end
local function index(defs)local names={};for key,d in pairs(defs)do if type(key)=='string'then names[key:lower()]=key end;if type(d.name)=='string'then names[d.name:lower()]=key end end;return names end
local function resolve(value,defs,names)
 if type(value)=='number'then return defs[value]and value end
 if type(value)=='string'and value~=''then return names[value:lower()]end
end
function M.ApplyUnitWrecks(units)
 local changed=0
 for _,u in pairs(units)do
  local defs=u.featuredefs
  if defs then
   local names=index(defs);local key=resolve(u.corpse,defs,names)or resolve(u.wreckname,defs,names);local seen={}
   while key and not seen[key]do
    seen[key]=true;local d=defs[key]
    local reclaimable=d.reclaimable==nil and not yes(d.indestructible)or yes(d.reclaimable)
    if reclaimable then
     -- Native reclaimable defaults to destructable; preserve that old default
     -- explicitly before making this definition indestructible.
     if d.reclaimable==nil then d.reclaimable=true end
     d.indestructible=true;d.flammable=false;changed=changed+1
    end
    key=resolve(d.featuredead,defs,names)
   end
  end
 end
 return changed
end
function M.ProtectedFeatures(units,features)
 local protected={};local names=index(features)
 local function chain(key)
  local seen={}
  while key and not seen[key]do
   seen[key]=true;local d=features[key]
   if d.reclaimable then protected[key]=true end
   key=resolve(d.deathFeatureID,features,names)
  end
 end
 -- Added 40K units alone receive the faction's persistent-wreck policy.
 -- Restored BAR factions and unrelated scenery retain native combat damage.
 for _,u in pairs(units)do
  local p=u.customParams or{}
  if yes(p.prototype40k)then chain(resolve(u.wreckName,features,names)or resolve(u.corpse,features,names))end
 end
 for key,d in pairs(features)do
  local p=d.customParams or{}
  if yes(p.prototype40k_tactical_remains)or yes(p.prototype40k_infantry_pile)or yes(p.corpse_reclaim_review)
   or yes(p.prototype40k_russ_native_wreck)or yes(p.prototype40k_ork_ranged_native_wreck)or yes(p.ordinary_generator_scrap)then chain(key)end
 end
 return protected
end
return M
