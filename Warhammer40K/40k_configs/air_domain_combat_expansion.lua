-- Scoped authored native-air adaptations. Capture stock donors before overlays;
-- apply only after the existing four-faction domain factories/private themes exist.
-- This module neither implements fictitious source models nor grants acceptance.
local M={Rows={
 air_scout={'corfink','air',1,'combat','Aerial Reconnaissance Drone'},
 light_bomber={'corshad','air',1,'combat','Light Bomber'},
 advanced_fighter={'corvamp','air',2,'combat','Advanced Interceptor'},
 heavy_bomber={'corhurc','air',2,'combat','Heavy Bomber'},
}}
local function clone(v)if type(v)~='table'then return v end;local t={};for k,x in pairs(v)do t[k]=clone(x)end;return t end
function M.Capture(defs)
 local out={};for _,r in pairs(M.Rows)do
  local d=assert(defs[r[1]],'Missing native air donor '..r[1]);assert(d.canfly==true,'Non-aircraft donor '..r[1]);out[r[1]]=clone(d)
 end;return out
end
function M.Apply(defs,saved,domains,theme,ready)
 local pending={};local made={}
 -- Validate the whole package first: no partial menus or definitions on refusal.
 for faction,f in pairs(domains.Factions)do
  assert(defs[domains.Key(faction,'air_factory')]and defs[domains.Key(faction,'advanced_air_factory')],'Missing native air ladder '..faction)
  for role,r in pairs(M.Rows)do
   local key=domains.Key(faction,role);assert(not defs[key],'Air adaptation already exists '..key)
   local donor=assert(saved[r[1]],'Missing captured aircraft '..r[1]);assert(donor.canfly==true,'Non-aircraft capture')
   local t=assert(theme and theme[key],'Missing private air theme '..key)
   assert(t.objectname and ready(key,t,donor),'Private air closure refused '..key)
   local d=clone(donor);d.name=f.label..' '..r[5];d.description='T'..r[3]..' air combat; themed native BAR adaptation';d.objectname=t.objectname
   local c=d.customparams or{};d.customparams=c;c.faction=f.label;c.prototype40k=1;c.prototype40k_four_faction=1;c.prototype40k_source_progression=1
   c.prototype40k_domain_candidate=1;c.prototype40k_native_donor=r[1];c.prototype40k_donor=key;c.prototype40k_tech_requires=key
   c.prototype40k_native_adaptation='pinned_BAR_air_combat_expansion_v1';c.prototype40k_shared_visual_source=r[1];c.prototype40k_theme='private_trim_material_v1'
   c.source_air_combat_trim='unchanged_existing_domain_atlas_partial_trim_v1'
   c.rosterrole='aircraft';c.techlevel=r[3];c.prototype40k_short_role='T'..r[3]..' air '..(role=='air_scout'and'scout'or role)
   c.i18n_en_humanname=d.name;c.i18n_en_tooltip=d.description;c.source_air_combat_acceptance='pending'
   pending[key]=d;made[#made+1]=key
  end
 end
 for key,d in pairs(pending)do defs[key]=d end
 local function append(maker,key)
  local d=defs[maker];d.buildoptions=d.buildoptions or{};for _,old in ipairs(d.buildoptions)do if old==key then return end end
  d.buildoptions[#d.buildoptions+1]=key
 end
 for faction in pairs(domains.Factions)do
  for _,role in ipairs({'air_scout','light_bomber'})do append(domains.Key(faction,'air_factory'),domains.Key(faction,role))end
  for _,role in ipairs({'air_scout','advanced_fighter','heavy_bomber'})do append(domains.Key(faction,'advanced_air_factory'),domains.Key(faction,role))end
 end
 table.sort(made);return {definitions=made,policy='native_air_combat_expansion_v1',nativeAcceptance='pending'}
end
return M
