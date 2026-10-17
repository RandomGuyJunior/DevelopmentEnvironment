-- Actual native advanced naval roles. DoW/UA has no universal ship branch;
-- these are explicit BAR donor adaptations, not invented source conversions.
local M={Rows={
 naval_aa_escort={'corarch','naval',2,'combat','Flak Escort'},
 advanced_cruiser={'corcrus','naval',2,'combat','Heavy Cruiser'},
 naval_missile_ship={'cormship','naval',2,'combat','Missile Ship'},
 advanced_attack_submarine={'corshark','naval',2,'combat','Advanced Attack Submarine'},
}}
local function clone(v)if type(v)~='table'then return v end;local t={};for k,x in pairs(v)do t[k]=clone(x)end;return t end
local function ship(d)return d and not d.canfly and(tonumber(d.minwaterdepth)or 0)>0 and d.movementclass and(tonumber(d.speed)or 0)>0 end
function M.Capture(defs)
 local out={};for _,r in pairs(M.Rows)do local d=assert(defs[r[1]],'Missing native naval donor '..r[1]);assert(ship(d),'Non-naval donor '..r[1]);out[r[1]]=clone(d)end;return out
end
function M.Apply(defs,saved,domains,theme,ready)
 local pending={};local made={}
 for faction,f in pairs(domains.Factions)do
  assert(defs[domains.Key(faction,'naval_factory')]and defs[domains.Key(faction,'advanced_naval_factory')],'Missing naval ladder '..faction)
  for role,r in pairs(M.Rows)do
   local key=domains.Key(faction,role);assert(not defs[key],'Naval role already registered '..key)
   local donor=assert(saved[r[1]],'Missing captured naval donor '..r[1]);assert(ship(donor),'Non-naval capture')
   local t=assert(theme and theme[key],'Missing private naval theme '..key);assert(t.objectname and ready(key,t,donor),'Private naval closure refused '..key)
   local d=clone(donor);d.name=f.label..' '..r[5];d.description='T2 naval combat; themed native BAR adaptation';d.objectname=t.objectname
   local c=d.customparams or{};d.customparams=c;c.faction=f.label;c.prototype40k=1;c.prototype40k_four_faction=1;c.prototype40k_source_progression=1
   c.prototype40k_domain_candidate=1;c.prototype40k_native_donor=r[1];c.prototype40k_donor=key;c.prototype40k_tech_requires=key
   c.prototype40k_native_adaptation='pinned_BAR_naval_combat_expansion_v1';c.prototype40k_shared_visual_source=r[1];c.prototype40k_theme='private_trim_material_v1'
   c.source_naval_combat_trim='unchanged_existing_domain_atlas_partial_trim_v1';c.rosterrole='ship';c.techlevel=2
   c.prototype40k_short_role='T2 naval '..role;c.i18n_en_humanname=d.name;c.i18n_en_tooltip=d.description;c.source_naval_combat_acceptance='pending'
   pending[key]=d;made[#made+1]=key
  end
 end
 for key,d in pairs(pending)do defs[key]=d end
 for faction in pairs(domains.Factions)do
  local factory=defs[domains.Key(faction,'advanced_naval_factory')];factory.buildoptions=factory.buildoptions or{}
  for _,role in ipairs({'naval_aa_escort','advanced_cruiser','naval_missile_ship','advanced_attack_submarine'})do
   local key=domains.Key(faction,role);local found=false;for _,old in ipairs(factory.buildoptions)do if old==key then found=true end end
   if not found then factory.buildoptions[#factory.buildoptions+1]=key end
  end
 end
 table.sort(made);return {definitions=made,policy='native_naval_combat_expansion_v1',nativeAcceptance='pending'}
end
return M
