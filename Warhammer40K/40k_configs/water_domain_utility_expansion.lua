-- Explicit pinned native water infrastructure adaptations; no invented DoW ship assets.
local M={Rows={
 water_sonar={'corsonar',1,'sonar','Seabed Sonar Array'},
 advanced_water_sonar={'corason',2,'sonar','Advanced Seabed Sonar Array'},
 water_radar={'corfrad',1,'radar','Floating Sensor Array'},
 water_energy_storage={'coruwes',1,'storage','Submerged Energy Store'},
 water_metal_storage={'coruwms',1,'storage','Submerged Metal Store'},
 water_laser_defence={'corfhlt',1,'turret','Floating Laser Defence'},
 advanced_water_laser_defence={'corfdoom',2,'turret','Advanced Floating Laser Defence'},
 water_torpedo_defence={'cortl',1,'turret','Seabed Torpedo Defence'},
 advanced_water_torpedo_defence={'coratl',2,'turret','Advanced Seabed Torpedo Defence'},
}}
local function clone(v)if type(v)~='table'then return v end;local t={};for k,x in pairs(v)do t[k]=clone(x)end;return t end
local function water(d)return d and not d.canfly and not d.canmove and(tonumber(d.minwaterdepth)or 0)>0 end
function M.Capture(defs)
 local saved={};for _,r in pairs(M.Rows)do local d=assert(defs[r[1]],'Missing water utility donor '..r[1]);assert(water(d),'Non-native static water donor '..r[1]);saved[r[1]]=clone(d)end;return saved
end
function M.Apply(defs,saved,domains,theme,ready)
 local pending,made={},{}
 for faction,f in pairs(domains.Factions)do
  assert(defs[domains.Key(faction,'naval_constructor')]and defs[domains.Key(faction,'advanced_naval_constructor')],'Missing naval constructors '..faction)
  for role,r in pairs(M.Rows)do
   local key=domains.Key(faction,role);assert(not defs[key],'Water utility already registered '..key)
   local donor=assert(saved[r[1]],'Missing native utility capture '..r[1]);assert(water(donor),'Invalid captured water utility')
   local t=assert(theme and theme[key],'Missing private water utility theme '..key);assert(t.objectname and ready(key,t,donor),'Private water utility closure refused '..key)
   local d=clone(donor);d.name=f.label..' '..r[4];d.description='T'..r[2]..' water '..r[3]..'; themed native BAR adaptation';d.objectname=t.objectname
   local c=d.customparams or{};d.customparams=c;c.faction=f.label;c.prototype40k=1;c.prototype40k_four_faction=1;c.prototype40k_source_progression=1
   c.prototype40k_domain_candidate=1;c.prototype40k_native_donor=r[1];c.prototype40k_donor=key;c.prototype40k_tech_requires=key
   c.prototype40k_native_adaptation='pinned_BAR_water_utility_expansion_v1';c.prototype40k_shared_visual_source=r[1];c.prototype40k_theme='private_trim_material_v1'
   c.source_water_utility_trim='unchanged_existing_domain_atlas_partial_trim_v1';c.rosterrole=r[3];c.techlevel=r[2]
   c.prototype40k_short_role='T'..r[2]..' water '..r[3];c.i18n_en_humanname=d.name;c.i18n_en_tooltip=d.description;c.source_water_utility_acceptance='pending'
   pending[key]=d;made[#made+1]=key
  end
 end
 for key,d in pairs(pending)do defs[key]=d end
 for faction in pairs(domains.Factions)do for tier=1,2 do
  local maker=defs[domains.Key(faction,(tier==2 and'advanced_'or'')..'naval_constructor')];maker.buildoptions=maker.buildoptions or{}
  for _,role in ipairs({'water_sonar','advanced_water_sonar','water_radar','water_energy_storage','water_metal_storage','water_laser_defence','advanced_water_laser_defence','water_torpedo_defence','advanced_water_torpedo_defence'})do
   if M.Rows[role][2]<=tier then
    local key=domains.Key(faction,role);local found=false;for _,old in ipairs(maker.buildoptions)do if old==key then found=true end end
    if not found then maker.buildoptions[#maker.buildoptions+1]=key end
   end
  end
 end end
 table.sort(made);return {definitions=made,policy='native_water_utility_expansion_v1',nativeAcceptance='pending'}
end
return M
