local M={Version=1}
M.Factions={
 guard={label='Imperial Guard',commander='imp_field_commander',base={'imp_generator','imp_mex','imp_comms_array','imp_missile_defence'},builders={'wh40k_armck','wh40k_armcv','wh40k_armack','wh40k_armacv','imp_enginseer'}},
 marine={label='Space Marines',commander='smcom',base={'imp_marine_generator','imp_marine_mex','imp_marine_comms_array','imp_marine_missile_defence'},builders={'imp_marine_builder','imp_marine_vehicle_builder','imp_marine_advanced_builder','imp_marine_advanced_vehicle_builder'}},
 ork={label='Orks',commander='ork_big_mek_commander',base={'ork_generator','ork_listening_post','ork_waaagh_banner'},builders={'wh40k_corck','wh40k_corcv','wh40k_corack','wh40k_coracv','ork_grot'}},
 necron={label='Necrons',commander='nec_lord',base={'nec_generator','nec_mex','nec_turret','nec_core'},builders={'nec_scarab','nec_vehicle_scarab','nec_advanced_scarab','nec_advanced_vehicle_scarab'}},
}
-- Capture true native donors BEFORE any overlay. Never make a ground engineer fly.
M.Rows={
 air_factory={'corap','air',1,'factory','Air Foundry'},advanced_air_factory={'coraap','air',2,'factory','Advanced Air Foundry'},
 air_constructor={'corca','air',1,'constructor','Aerial Construction Drone'},advanced_air_constructor={'coraca','air',2,'constructor','Advanced Aerial Construction Drone'},fighter={'corveng','air',1,'combat','Interceptor'},
 naval_factory={'corsy','naval',1,'factory','Naval Shipyard'},advanced_naval_factory={'corasy','naval',2,'factory','Advanced Naval Shipyard'},
 naval_constructor={'corcs','naval',1,'constructor','Construction Barge'},advanced_naval_constructor={'coracsub','naval',2,'constructor','Submersible Construction Tender'},
 patrol_boat={'corpt','naval',1,'combat','Patrol Gunboat'},destroyer={'corroy','naval',1,'combat','Escort Destroyer'},submarine={'corsub','naval',1,'combat','Attack Submarine'},
}
-- Native BAR ship-builder economy. T1 BAR uses the common cormex, not a
-- nonexistent coruwmex. Its unchanged underwater siting requires native review.
M.WaterEconomyRows={
 water_tidal_generator={'cortide',1,'energy','Tidal Power Array'},
 water_extractor={'wh40k_cormex',1,'metal','Seabed Extractor'},
 advanced_water_generator={'coruwfus',2,'energy','Submerged Fusion Reactor'},
 advanced_water_extractor={'coruwmme',2,'metal','Advanced Seabed Extractor'},
}
local function clone(v)if type(v)~='table'then return v end;local t={};for k,x in pairs(v)do t[k]=clone(x)end;return t end
function M.Key(f,r)return 'fortyk_'..f..'_'..r end
function M.Capture(defs)
 local s={};for _,r in pairs(M.Rows)do assert(defs[r[1]],'Missing pinned domain donor '..r[1]);s[r[1]]=clone(defs[r[1]])end
 for _,r in pairs(M.WaterEconomyRows)do if defs[r[1]]then s[r[1]]=clone(defs[r[1]])end end;return s
end
function M.Apply(defs,saved,ready,theme)
 assert(saved and saved.corap and saved.corsy,'Capture before overlays');local made,requires={},{}
 for faction,f in pairs(M.Factions)do for role,r in pairs(M.Rows)do
  local n=M.Key(faction,role);assert(not defs[n],'Already applied '..n);local d=clone(assert(saved[r[1]]));defs[n]=d;made[#made+1]=n
  d.name=f.label..' '..r[5];d.description='T'..r[3]..' '..r[2]..' '..r[4]..'; themed native adaptation';d.buildoptions={};d.customparams=d.customparams or{};local c=d.customparams
  c.faction=f.label;c.prototype40k=1;c.prototype40k_four_faction=1;c.prototype40k_source_progression=1;c.prototype40k_domain_candidate=1
  c.prototype40k_native_donor=r[1];c.prototype40k_donor=n;c.prototype40k_tech_requires=n;c.prototype40k_native_adaptation='pinned_BAR_role_preserved_v1';c.prototype40k_shared_visual_source=r[1]
  c.rosterrole=r[4]=='factory'and r[2]..'_factory'or r[4]=='constructor'and'constructor'or r[2]=='air'and'aircraft'or'ship';c.techlevel=r[3]
  c.i18n_en_humanname=d.name;c.i18n_en_tooltip=d.description;c.prototype40k_short_role='T'..r[3]..' '..r[2]..' '..r[4]
  if r[4]=='factory'then c.factory=1;c.prototype40k_factory_domain=r[2];c.prototype40k_factory_tier=r[3]
  elseif r[4]=='constructor'then c.prototype40k_constructor_domain=r[2];c.prototype40k_constructor_tier=r[3]end
  requires[n]={};local t=theme and theme[n];if t then d.objectname=t.objectname;c.prototype40k_theme='private_trim_material_v1'else c.prototype40k_theme_pending=1 end
 end end
 local function menu(maker,list,replace)
  local d=defs[maker];if not d then return end;d.buildoptions=replace and{}or(d.buildoptions or{})
  for _,target in ipairs(list)do local td=defs[target];if td and(ready(target)or(td.customparams or{}).prototype40k_domain_candidate==1)then
   local present=false;for _,old in ipairs(d.buildoptions)do if old==target then present=true end end;if not present then d.buildoptions[#d.buildoptions+1]=target end
  end end
 end
 for faction,f in pairs(M.Factions)do
  local function k(r)return M.Key(faction,r)end;local t1={k('air_factory'),k('naval_factory')}
  if ready(f.commander)then menu(f.commander,t1,false)end;for _,b in ipairs(f.builders)do if ready(b)then menu(b,t1,false)end end
  menu(k('air_factory'),{k('air_constructor'),k('fighter')},true);menu(k('advanced_air_factory'),{k('advanced_air_constructor'),k('fighter')},true)
  menu(k('naval_factory'),{k('naval_constructor'),k('patrol_boat'),k('destroyer'),k('submarine')},true)
  menu(k('advanced_naval_factory'),{k('advanced_naval_constructor'),k('destroyer'),k('submarine')},true)
  for _,domain in ipairs({'air','naval'})do for _,tier in ipairs({1,2})do
   local list=clone(f.base);list[#list+1]=k(domain..'_factory');list[#list+1]=k('advanced_'..domain..'_factory')
   menu(k((tier==2 and'advanced_'or'')..domain..'_constructor'),list,true)
  end end
 end
 table.sort(made);return {policy='native_air_naval_candidate_v1',definitions=made,Requires=requires}
end
-- Root supplies verified source facts/assets. This never switches global review flags.
function M.AddFighta(defs,facts,aircraftBuilder,assetsReady)
 if not assetsReady or not assetsReady('ork_fighta_bomba')then return false,'missing_private_asset_closure'end
 local f=facts and facts.ork_fighta_bomba;if not f then return false,'missing_source_facts'end
 local ok,why=aircraftBuilder.DefinitionReady('ork_fighta_bomba',f);if not ok then return false,why end
 local d=aircraftBuilder.Build('ork_fighta_bomba',f,f.producer_workertime);d.name='Fighta-Bomma';d.description='Ork source fighter-bomber; four genuine weapon groups'
 local c=d.customparams;c.prototype40k_domain_candidate=1;c.prototype40k_four_faction=1;c.prototype40k_donor='ork_fighta_bomba';c.prototype40k_tech_requires='ork_fighta_bomba'
 c.prototype40k_ork_aircraft_review=nil;c.prototype40k_ork_aircraft_domain=1;c.i18n_en_humanname=d.name;c.i18n_en_tooltip=d.description
 local producer=assert(defs[M.Key('ork','air_factory')]);d.buildtime=f.production.seconds*producer.workertime;c.source_labor_reference=M.Key('ork','air_factory');c.source_native_domain_buildtime=d.buildtime
 defs.ork_fighta_bomba=d;producer.buildoptions[#producer.buildoptions+1]='ork_fighta_bomba';return true
end
-- Separate coordinator hook after native domain aliases; no unrelated menus.
function M.ApplyWaterEconomy(defs,saved,assetsReady,theme)
 local made,requires={},{}
 -- Check all inputs before mutating definitions or menus.
 for faction in pairs(M.Factions)do
  assert(defs[M.Key(faction,'naval_constructor')]and defs[M.Key(faction,'advanced_naval_constructor')],'Native naval branch absent')
  for role,r in pairs(M.WaterEconomyRows)do
   local key=M.Key(faction,role);assert(not defs[key],'Water economy already applied '..key)
   assert(saved[r[1]],'Capture untouched water donor '..r[1]);assert(theme and theme[key]and assetsReady(key),'Private native water closure absent '..key)
  end
 end
 for faction,f in pairs(M.Factions)do for role,r in pairs(M.WaterEconomyRows)do
  local key=M.Key(faction,role);local d=clone(saved[r[1]]);defs[key]=d
  d.name=f.label..' '..r[4];d.description='T'..r[2]..' water '..r[3]..'; pinned native BAR economy adaptation';d.objectname=theme[key].objectname
  local c=d.customparams or{};d.customparams=c;c.faction=f.label;c.prototype40k=1;c.prototype40k_four_faction=1;c.prototype40k_source_progression=1
  c.prototype40k_domain_candidate=1;c.prototype40k_native_donor=r[1];c.prototype40k_donor=key;c.prototype40k_tech_requires=key
  c.prototype40k_native_adaptation='pinned_BAR_water_economy_v1';c.prototype40k_shared_visual_source=r[1]
  c.prototype40k_theme='private_trim_material_v1';c.prototype40k_water_economy=1;c.prototype40k_water_economy_tier=r[2]
  c.rosterrole=r[3]=='energy'and'generator'or'extractor';c.production_role=c.rosterrole;c.techlevel=r[2]
  c.i18n_en_humanname=d.name;c.i18n_en_tooltip=d.description;c.prototype40k_short_role='T'..r[2]..' water '..r[3]
  c.source_water_placement_acceptance='pending';c.source_resource_role=r[3];requires[key]={};made[#made+1]=key
 end end
 local function append(maker,target)
  local d=defs[maker];for _,old in ipairs(d.buildoptions or{})do if old==target then return end end
  d.buildoptions=d.buildoptions or{};d.buildoptions[#d.buildoptions+1]=target
 end
 for faction in pairs(M.Factions)do for _,tier in ipairs({1,2})do
  local maker=M.Key(faction,(tier==2 and'advanced_'or'')..'naval_constructor')
  for role,r in pairs(M.WaterEconomyRows)do if r[2]<=tier then append(maker,M.Key(faction,role))end end
 end end
 table.sort(made);return {definitions=made,Requires=requires,policy='native_water_economy_v1',nativeAcceptance='pending'}
end
return M
