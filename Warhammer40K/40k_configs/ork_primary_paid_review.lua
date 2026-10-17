-- Explicit whole five-role paid review. Native payment/visual acceptance remains external.
local M={Version=1}
local keys={'ork_pile_o_guns','ork_boomy_platform','ork_bigger_generator','ork_giant_waagh_banner_sp_dxp3','ork_stormboy'}
local names={'Pile-o-Guns','Boomy Platform','Bigger Generator','Da Flyboyz Towa','Stormboy'}
local function copy(t)if type(t)~='table'then return t end;local r={};for k,v in pairs(t)do r[k]=copy(v)end;return r end
local function marked(v)return tostring(v)=='1'end
function M.Enabled(o)return marked(o.prototype_ork_primary_roles)and VFS.Include('40k_configs/ork_source_consumers_native.lua').Enabled(o)end
local function hash(s)return type(s)=='string'and #s==64 and s:match('^[0-9a-f]+$')end
local function source(s)return tostring(s):gsub('\\','/'):lower():gsub('^attrib/','')end
function M.Apply(defs,o,F,E,A)
 if not M.Enabled(o)then return{enabled=false}end
 local function no(why,key)return{enabled=true,applied=false,reason=why,key=key}end
 if not F or not F.actors or not E or E.version~=1 then return no('private_source_contract_missing')end
 local jump=VFS.Include('40k_configs/ork_stormboy_jump_native.lua')
 if not jump.Enabled(o)or not jump.Supported(F.actors.ork_stormboy and F.actors.ork_stormboy.cohort)then return no('whole_paid_cohort_jump_missing')end
 for _,path in ipairs({'scripts/40k_roster.lua','40k_configs/ork_source_producer_costs.lua','40k_configs/ork_primary_research_graph_extend.lua','40k_configs/ork_primary_research_native.lua','40k_configs/ork_primary_completed_pose_layers.lua','40k_configs/ork_primary_native_minrange.lua','40k_configs/ork_aircraft_native_definitions.lua','40k_configs/ork_nukklear_bombard_native.lua','scripts/40k_ork_aircraft_aim.lua'})do if not VFS.FileExists(path)then return no('defining_consumer_missing',path)end end
 -- Both genuine products must exist. Missing Nukklear research closes that product at runtime.
 local aircraft=VFS.Include('40k_configs/ork_aircraft_native_definitions.lua')
 for _,key in ipairs({'ork_fighta_bomba','ork_nuke_bomba'})do
  local d=defs[key];local f=A and A[key];local cp=d and d.customparams or{}
  if not d or not f or not hash(f.source_model_sha256)or not hash(f.native_glb_sha256)or cp.source_model_sha256~=f.source_model_sha256 or cp.source_native_glb_sha256~=f.native_glb_sha256 or cp.source_entity~=f.source_entity or #(d.weapons or{})~=4 or d.buildtime~=(key=='ork_fighta_bomba'and 10500 or 36000)then return no('genuine_air_product_missing',key)end
  if not aircraft.DefinitionReady or not aircraft.DefinitionReady(key,f)then return no('whole_air_product_consumer_missing',key)end
  for n,m in ipairs(d.weapons)do local w=d.weapondefs[m.def];if not w or (w.customparams or{}).source_weapon_sha256~=f.weapons[n].sha256 then return no('genuine_air_mount_missing',key)end end
  for _,path in ipairs({'objects3d/'..key..'.glb','scripts/generated/'..key..'_anim.lua','unitpics/40k_'..key..'.png','unittextures/'..key..'_tex1.png','unittextures/'..key..'_tex2.png'})do if not VFS.FileExists(path)then return no('genuine_air_bundle_missing',path)end end
 end
 if not defs.ork_grot or not defs.ork_boyz_hut or defs.ork_grot.workertime~=40 or defs.ork_boyz_hut.workertime~=150 then return no('immutable_native_producer_labor')end
 local assetsPath='scripts/generated/ork_primary_paid_review_assets.lua'
 if not VFS.FileExists(assetsPath)then return no('private_material_readiness_missing')end
 local assets=VFS.Include(assetsPath);if assets.version~=1 then return no('private_material_readiness_invalid')end
 local native=VFS.Include('40k_configs/ork_primary_native_review_definitions.lua');local pending={}
 for i,key in ipairs(keys)do
  local f=F.actors[key];local e=E.entries and E.entries[key]
  if not f or not e or e.reviewed~=true or f.entity~=e.source_entity or f.source_whm_sha256~=e.source_model_sha256 or f.native_glb_sha256~=e.generated_glb_sha256 or not hash(f.source_whm_sha256)or not hash(f.native_glb_sha256)then return no('genuine_identity_missing',key)end
  for _,path in ipairs({'objects3d/'..key..'.glb','scripts/generated/'..key..'_anim.lua','unitpics/40k_'..key..'.png'})do if not VFS.FileExists(path)then return no('genuine_bundle_missing',path)end end
  local bundle=assets.entries[key];if not bundle or bundle.native_glb_sha256~=f.native_glb_sha256 or type(bundle.files)~='table'or #bundle.files<4 then return no('genuine_material_readiness_missing',key)end
  for _,path in ipairs(bundle.files)do if not VFS.FileExists(path)then return no('genuine_material_missing',path)end end
  local ok,d=pcall(native.Build,key,f,F.calibration[key],defs);if not ok or not d then return no('native_definition_refused',key)end
  d.name=names[i];d.description='Source paid '..names[i]..'; explicit native review'
  local cp=d.customparams;cp.faction='Orks';cp.prototype40k=1;cp.prototype40k_source_progression=1;cp.animsource=key;cp.source_entity=f.entity;cp.source_role=f.role;cp.rosterrole=f.role=='jump_infantry'and'infantry'or f.role=='energy'and'generator'or f.role;cp.integration_status='whole_source_paid_review_native_acceptance_pending'
  if key=='ork_stormboy'then cp.source_stormboy_jump=1 end
  if key=='ork_bigger_generator'then
   local rate=defs.ork_generator and defs.ork_generator.energymake
   if type(rate)~='number'or rate<=0 or type(f.power_per_second)~='number'or type(f.reference_source_generator_power)~='number'or f.reference_source_generator_power<=0 then return no('source_energy_ratio_missing',key)end
   d.energymake=rate*f.power_per_second/f.reference_source_generator_power
  end
  if key=='ork_giant_waagh_banner_sp_dxp3'then d.buildoptions={'ork_fighta_bomba','ork_nuke_bomba'};cp.source_fly_tower_ability_closed='UA_ork_fighta_bomma_bombs_missing_whole_consumer';cp.integration_status='paid_production_defence_review_tower_airstrike_closed'end
  pending[key]=d
 end
 VFS.Include('40k_configs/ui_unit_metadata.lua').Apply(pending)
 -- Menus are cloned and committed with the entire candidate set.
 local grot,boy=copy(defs.ork_grot),copy(defs.ork_boyz_hut)
 local function append(d,key)d.buildoptions=d.buildoptions or{};for _,v in ipairs(d.buildoptions)do if v==key then return end end;d.buildoptions[#d.buildoptions+1]=key end
 for _,key in ipairs(keys)do if key~='ork_stormboy'then append(grot,key)end end;append(boy,'ork_stormboy')
 for key,d in pairs(pending)do defs[key]=d end;defs.ork_grot=grot;defs.ork_boyz_hut=boy
 return{enabled=true,applied=true,actors=5,paid_acceptance=false}
end
function M.Graph(o)
 local r={Requires={}};if M.Enabled(o)then for _,key in ipairs(keys)do r.Requires[key]={}end;for _,key in ipairs({'ork_fighta_bomba','ork_nuke_bomba'})do r.Requires[key]={}end end;return r
end
-- Convert only audited original prerequisite leaves; any new consumer fails closed.
function M.Conditions(fields,V)
 local cond={buildings={}};local groups={}
 local buildings={};for key,path in pairs(V.SourceBuildings)do buildings[source(path)]=key end
 for path,value in pairs(fields or{})do
  local group,leaf=path:match('^(.-required_%d+)%.([^%.]+)$')
  if not group then return nil,'unknown_requirement_path:'..path end
  groups[group]=groups[group]or{};groups[group][leaf]=value
 end
 for _,r in pairs(groups)do
  for leaf in pairs(r)do if leaf~='population_required'and leaf~='structure_name'and leaf~='is_display_requirement'and leaf~='global_addon_name'and leaf~='structure_name_either'and leaf~='structure_name_or'then return nil,'unknown_requirement_leaf:'..leaf end end
  if r.population_required then cond.population=math.max(cond.population or 0,r.population_required)end
  if r.structure_name then local k=buildings[source(r.structure_name)];if not k then return nil,'unknown_source_structure'end;cond.buildings[#cond.buildings+1]=k end
  if r.global_addon_name then if source(r.global_addon_name)~='addons/ork_hq_addon.lua'then return nil,'unknown_source_addon'end;cond.global_addon='ork_source_hq_addon'end
  if r.structure_name_either or r.structure_name_or then local a,b=buildings[source(r.structure_name_either)],buildings[source(r.structure_name_or)];if not a or not b then return nil,'unknown_source_alternative'end;cond.any_buildings={a,b}end
 end
 return cond
end
function M.Attach(C,S,D,V,o,F,A)
 if not M.Enabled(o)then return{enabled=false}end
 assert(C.sourceVariantAdapter and C.sourceOrkLifecycle and C.sourceOrkProducerCosts,'Whole source paid lifecycle missing')
 local producerSources={ork_grot='attrib/ebps/races/orks/troops/ork_grot.lua',ork_boyz_hut='attrib/ebps/races/orks/structures/ork_boy_hut.lua',ork_giant_waagh_banner_sp_dxp3=F.actors.ork_giant_waagh_banner_sp_dxp3.entity}
 local conditions={};for _,key in ipairs(keys)do local f=assert(F.actors[key]);local fields=f.source_requirements
  if key=='ork_stormboy'then fields={};for path,value in pairs(f.cohort.fields)do if path:find('squad_requirement_ext.requirements.',1,true)==1 then fields[path]=value end end end
  local c,why=M.Conditions(fields,V);assert(c,'Unknown defining source prerequisite: '..tostring(why));conditions[key]=c
 end
 local old=C.CanBuild
 function C.CanBuild(team,def,builder,initial)
  local d=D[def];local key=d and d.name;local cond=conditions[key];local air=key=='ork_fighta_bomba'or key=='ork_nuke_bomba'
  if not cond and not air then return old(team,def,builder,initial)end
  local u=builder and C.units[builder];local pd=u and D[u.def];local cp=pd and pd.customParams or{}
  local producer=air and'ork_giant_waagh_banner_sp_dxp3'or key=='ork_stormboy'and'ork_boyz_hut'or'ork_grot'
  if initial or not u or not u.finished or u.team~=team or S.GetUnitTeam(builder)~=team or not pd or pd.name~=producer or cp.faction~='Orks'or not cp.source_entity or not hash(cp.source_model_sha256)or not hash(cp.source_native_glb_sha256)then return false end
  if cp.source_entity~=producerSources[producer]then return false end
  local tc=d.customParams or{};local facts=air and A and A[key]or F.actors[key]
  if not facts or tc.source_entity~=(air and facts.source_entity or facts.entity)or tc.source_model_sha256~=(air and facts.source_model_sha256 or facts.source_whm_sha256)or tc.source_native_glb_sha256~=facts.native_glb_sha256 then return false end
  local health,_,_,_,p=S.GetUnitHealth(builder);if not health or health<=0 or not p or p<1 then return false end
  if producer=='ork_grot'and not C.sourceOrkProducerCosts.receipts[builder]then return false end
  if S.GetGameSpeed then local wanted=S.GetGameSpeed();if wanted~=1 then return false end end
  if air then
   if not A or not A[key]or pd.buildSpeed~=150 or not pd.isFactory then return false end
   cond={}
   if key=='ork_nuke_bomba'then
    local research;for k,f in pairs(V.SourceProfiles)do if source(f.source)=='research/races/orks/ua_ork_research_tech_nukklear_bomma.lua'then research=k end end
    if not research or C.suppressed[research]or not C.records[research]or not GG.Recoil40KNukklearBombard then return false end
    cond={buildings={'ork_hq'},research={research}}
   end
  end
  if not C.sourceVariantAdapter.Conditions(team,cond,builder)then return false end
  return old(team,def,builder,false)
 end
 local R={enabled=true,conditions=conditions};C.sourcePrimaryPaidReview=R;return R
end
return M
