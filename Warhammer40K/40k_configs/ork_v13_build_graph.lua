-- Orks-first v1.3, 11 October 2026. Availability only: never creates UnitDefs,
-- reads model geometry, changes native bills, or grants production acceptance.
local M={Version='orks_first_v13',AirOption='prototype_ork_advanced_air_development'}
local function cp(d)return d and(d.customparams or d.customParams)or{}end
local function enabled(v)return v==true or v==1 or v=='1'end
function M.AdvancedAir(options)return enabled((options or{})[M.AirOption])end
M.Factories={
 {'ORK-INF-1','ork_boyz_hut','infantry',1,'Da Boyz Hut',{'wh40k_corck','ork_slugga','ork_gretchin_squad','ork_bomb_squig'}},
 {'ORK-INF-2','ork_boyz_hut_t2','infantry',2,'Expanded Da Boyz Hut',{'wh40k_corack','ork_nob','ork_boy','ork_ard_boy','ork_burna','ork_stormboy'}},
 {'ORK-INF-3','ork_warcamp','infantry',3,'Ork Warcamp',{'ork_flash_gitz','ork_loota','ork_meganob','ork_tankbusta','ork_kommando','ork_big_mek_defence'}},
 {'ORK-VEH-1','ork_mek_shop','vehicle',1,'Da Mek Shop',{'wh40k_corcv','ork_trukk','ork_wartrak','ork_killa_kan','ork_kan_twin_shoota','ork_kan_twin_kmb','ork_kan_twin_rokkit','ork_grot_tank','ork_warbike_crewed'}},
 {'ORK-VEH-2','ork_mek_lab','vehicle',2,'Mek Lab',{'wh40k_coracv','ork_gunwagon','ork_battlewagon_armageddon','ork_deff_dread','ork_dread_ranged_fourarm','ork_looted_tank'}},
 {'ORK-VEH-3','ork_mek_lab_t3','vehicle',3,'Expanded Mek Lab',{'ork_kill_bursta','ork_kill_krusha','ork_squiggoth','ork_battlefortress_armageddon','ork_morkanaut'}},
 {'ORK-AIR-1','fortyk_ork_air_factory','air',1,'Ork Airfield',{'ork_mek_kopta','ork_fighta_bomba'}},
 {'ORK-AIR-2','fortyk_ork_advanced_air_factory','air',2,'Advanced Ork Airfield',{'ork_big_mek_kopta'}},
 {'ORK-AIR-3','fortyk_ork_super_air_factory','air',3,'Heavy Ork Airfield',{'ork_gunship'}},
 {'ORK-SUP-3','ork_hq_super','superheavy',3,'Meanest Tellyporta',{'ork_kustom_stompa','ork_dakka_stompa','ork_gargant','ork_great_gargant'}},
}
-- Existing native ground constructor identities remain distinct. I2/V1/V2
-- currently share genuine repair-capable Big Mek artwork; their final appearances remain
-- explicitly pending. Commander and mega-armoured support are not constructors.
M.Builders={
 {'ORK-BLD-I1','wh40k_corck','infantry',1,'Gretchin Builder'},
 {'ORK-BLD-I2','wh40k_corack','infantry',2,'Ork Builder'},
 {'ORK-BLD-V1','wh40k_corcv','vehicle',1,'Mek Builder'},
 {'ORK-BLD-V2','wh40k_coracv','vehicle',2,'Big Mek Constructor'},
 {'ORK-BLD-A1','ork_mek_kopta','air',1,'Mek Kopta'},
 {'ORK-BLD-A2','ork_big_mek_kopta','air',2,'Big Mek Kopta'},
}
-- design ID, exact key, structure tier, minimum builder tier. Artillery is
-- deliberately stricter than the general current/next-tier construction rule.
M.Structures={
 {'ORK-ENE-1','ork_generator',1,0},
 {'ORK-ENE-2','ork_generator_t2',2,1},
 {'ORK-ENE-3','ork_generator_t3',3,2},
 {'ORK-GEO-2','ork_geothermal',2,1},
 {'ORK-MEX-1','ork_listening_post',1,0},
 {'ORK-MEX-2','ork_listening_post_t2',2,1},
 {'ORK-MEX-3','ork_listening_post_t3',3,2},
 {'ORK-ART-1','ork_boomy_platform',1,1},
 {'ORK-ART-2','ork_kaboomy_platform',2,2},
 {'ORK-WALL-1','ork_wall',1,0},
 {'ORK-WALL-2','ork_wall_t2',2,1},
 {'ORK-DEF-O1','ork_ouchy_platform',1,0},
 {'ORK-DEF-O2','ork_ouchy_platform_t2',2,1},
 {'ORK-DEF-O3','ork_ouchy_platform_t3',3,2},
 {'ORK-DEF-W1','ork_waaagh_banner',1,0},
 {'ORK-DEF-W2','ork_waaagh_banner_t2',2,1},
 {'ORK-DEF-G1','ork_grot_turret',1,0},
}
M.Known={ork_big_mek_commander=true};M.Producer={};M.AdvancedAirKeys={}
for _,r in ipairs(M.Factories)do
 M.Known[r[2]]=true
 for _,key in ipairs(r[6])do
  assert(not M.Producer[key],'Duplicate Ork product '..key)
  M.Known[key]=true;M.Producer[key]=r[2]
  if r[3]=='air'and r[4]>1 then M.AdvancedAirKeys[key]=true end
 end
 if r[3]=='air'and r[4]>1 then M.AdvancedAirKeys[r[2]]=true end
end
for _,r in ipairs(M.Structures)do M.Known[r[2]]=true end
-- Donor/legacy identities are not alternate products or extra builders.
M.Legacy={ork_settlement=true,ork_hq=true,ork_resource_factory=true,
 ork_grot=true,ork_kustim_stompa=true,wh40k_corlab=true,wh40k_coralab=true,corvp=true,coravp=true,
 wh40k_corsolar=true,wh40k_corwin=true,wh40k_coradvsol=true,wh40k_corfus=true,wh40k_corafus=true,wh40k_corgeo=true,
 wh40k_cormex=true,wh40k_cormoho=true,wh40k_corestor=true,wh40k_cormstor=true,wh40k_corrad=true,wh40k_corarad=true,
 wh40k_corjamt=true,wh40k_corshroud=true,wh40k_cornanotc=true,wh40k_cornanotcplat=true,wh40k_cormakr=true,wh40k_cormmkr=true}
function M.IsOrk(key,d)
 return M.Known[key]or M.Legacy[key]or key:sub(1,4)=='ork_'or key:sub(1,11)=='fortyk_ork_'or cp(d).faction=='Orks'
end
function M.IsNaval(key,d)
 local c=cp(d)
 if c.prototype40k_factory_domain=='naval'or c.prototype40k_constructor_domain=='naval'
  or c.rosterrole=='ship'or c.prototype40k_water_economy or c.source_water_utility_acceptance then return true end
 -- Also close original native water-only donor routes, without touching land
 -- amphibians, water terrain, flight or ordinary map behaviour.
 local water=tonumber(d and(d.minwaterdepth or d.minWaterDepth))or 0
 return water>0 and not(d.canfly or d.canFly)
end
function M.SafetyReason(key,d,options)
 if M.IsNaval(key,d)then return 'Naval content excluded'end
 local c=cp(d)
 if M.AdvancedAirKeys[key]and c.prototype40k_ork_v13_air_content_ready==0 then return 'Ork aircraft route incomplete or empty'end
 local highAir=M.AdvancedAirKeys[key]or(M.IsOrk(key,d)and
  ((c.prototype40k_factory_domain=='air'and(tonumber(c.prototype40k_factory_tier)or 0)>1)
   or(c.prototype40k_constructor_domain=='air'and(tonumber(c.prototype40k_constructor_tier)or 0)>1)
   or(d and(d.canfly or d.canFly)and(tonumber(c.techlevel)or 0)>1)))
 if highAir and not M.AdvancedAir(options)and not enabled(c.prototype40k_ork_v13_air_ready)then return 'Ork aircraft route readiness pending'end
 return nil
end
function M.BlockReason(key,d,options)
 local reason=M.SafetyReason(key,d,options);if reason then return reason end
 if M.IsOrk(key,d)and not M.Known[key]and not enabled(cp(d).prototype40k_squad_internal)then return 'Outside current Ork roster'end
 return nil
end
local function present(defs,key)
 local d=defs[key]
 return d and type(d.objectname)=='string'and d.objectname~=''and type(d.script)=='string'and d.script~=''
end
-- Atomic activation prevents moving existing infantry/heavies into factories
-- which do not yet exist. These four new definitions need authored recipe IDs;
-- availability itself is not proof that their art/egress passed native review.
M.ActivationRecipes={ork_boyz_hut_t2='ORK-INF-2',ork_warcamp='ORK-INF-3',ork_mek_lab_t3='ORK-VEH-3',ork_mek_kopta='ORK-BLD-A1'}
M.ActivationRequired={'ork_big_mek_commander','wh40k_corck','wh40k_corack','wh40k_corcv','wh40k_coracv','ork_boyz_hut','ork_boyz_hut_t2','ork_warcamp','ork_mek_shop','ork_mek_lab','ork_mek_lab_t3','ork_hq_super','fortyk_ork_air_factory','ork_mek_kopta'}
function M.Readiness(defs,V)
 local missing={}
 for _,key in ipairs(M.ActivationRequired)do
  local d=defs[key];local recipe=M.ActivationRecipes[key]
  if not present(defs,key)then missing[#missing+1]='definition:'..key
  elseif d.builder~=true or(tonumber(d.workertime)or 0)<=0 or(tonumber(d.buildtime)or 0)<=0 then missing[#missing+1]='native_builder:'..key
  elseif recipe and cp(d).prototype40k_ork_v13_recipe~=recipe then missing[#missing+1]='recipe:'..key
  elseif M.SafetyReason(key,d,{})then missing[#missing+1]='normal_availability:'..key
  elseif not(V and V.FileExists and V.FileExists('objects3d/'..d.objectname)and V.FileExists('scripts/'..d.script))then missing[#missing+1]='model_or_script:'..key
  end
 end
 for _,r in ipairs(M.Factories)do if r[3]~='air'or r[4]==1 then
  local d=defs[r[2]]
  if d and(type(d.yardmap)~='string'or d.yardmap=='')then missing[#missing+1]='factory_yard:'..r[2]end
  if d then
   local speed=tonumber(d.speed)
   if speed==nil then speed=math.abs((tonumber(d.maxvelocity)or 0)*30)end
   if enabled(d.canfly)or speed>0 then missing[#missing+1]='factory_immobility:'..r[2]end
  end
 end end
 if defs.ork_mek_kopta and not defs.ork_mek_kopta.canfly then missing[#missing+1]='flight:ork_mek_kopta'end
 table.sort(missing);return #missing==0,missing
end
function M.Apply(defs,options,V)
 -- Useful T2 constructor production no longer waits for a wider aircraft
 -- roster. Only genuine supplied factory/constructor closures qualify. T3
 -- still needs separately recorded native production/flight/combat acceptance.
 local function closed(key)
  local d=defs[key]
  return present(defs,key)and V and V.FileExists and V.FileExists('objects3d/'..d.objectname)and V.FileExists('scripts/'..d.script)
 end
 local function positive(n)return type(n)=='number'and n==n and n>0 and n<math.huge end
 local function factory(key)
  local d=defs[key]
  return closed(key)and d.builder==true and positive(d.workertime)and positive(d.buildtime)
   and positive(d.metalcost)and positive(d.energycost)and type(d.yardmap)=='string'and d.yardmap~=''
   and not enabled(d.canfly)and not(tonumber(d.speed)and tonumber(d.speed)>0)
   and not(tonumber(d.maxvelocity)and tonumber(d.maxvelocity)>0)
 end
 local function product(key,builder)
  local d=defs[key]
  return closed(key)and enabled(d.canfly)and positive(d.metalcost)and positive(d.energycost)and positive(d.buildtime)
   and(not builder or(d.builder==true and d.canmove==true and positive(d.workertime)and positive(d.builddistance)and positive(d.speed)))
 end
 local air2=factory('fortyk_ork_advanced_air_factory')and product('ork_big_mek_kopta',true)
  and cp(defs.fortyk_ork_advanced_air_factory).prototype40k_ork_v13_recipe=='ORK-AIR-2'
  and cp(defs.ork_big_mek_kopta).prototype40k_ork_v13_recipe=='ORK-BLD-A2'
  and defs.ork_big_mek_kopta.builder==true and defs.ork_big_mek_kopta.canfly==true
  and(tonumber(defs.ork_big_mek_kopta.workertime)or 0)>0
 local air3Content=factory('fortyk_ork_super_air_factory')and product('ork_gunship',false)
  and cp(defs.fortyk_ork_super_air_factory).prototype40k_ork_v13_recipe=='ORK-AIR-3'
  and cp(defs.ork_gunship).prototype40k_ork_v13_recipe=='ORK-AIR-3-GUNSHIP'
  and defs.ork_gunship.canattack==true and type(defs.ork_gunship.weapons)=='table'and #defs.ork_gunship.weapons>0
 local air3=air3Content
  and enabled(cp(defs.fortyk_ork_super_air_factory).prototype40k_native_air_accepted)
  and enabled(cp(defs.ork_gunship).prototype40k_native_air_accepted)
 for _,key in ipairs({'fortyk_ork_advanced_air_factory','ork_big_mek_kopta','fortyk_ork_super_air_factory','ork_gunship'})do
  local d=defs[key]
  if d then
   d.customparams=cp(d)
   local ready=air3
   if M.Producer[key]=='fortyk_ork_advanced_air_factory'or key=='fortyk_ork_advanced_air_factory'then ready=air2 end
   d.customparams.prototype40k_ork_v13_air_ready=ready and 1 or nil
   local content=air3Content
   if M.Producer[key]=='fortyk_ork_advanced_air_factory'or key=='fortyk_ork_advanced_air_factory'then content=air2 end
   d.customparams.prototype40k_ork_v13_air_content_ready=content and 1 or 0
  end
 end
 local active,blockers=M.Readiness(defs,V)
 local report={policy=M.Version,active=active,blockers=blockers,advancedAir=M.AdvancedAir(options),present={},missing={},incomplete={},disabled={}}
 if defs.ork_big_mek_commander then
  defs.ork_big_mek_commander.customparams=cp(defs.ork_big_mek_commander)
  defs.ork_big_mek_commander.customparams.prototype40k_ork_v13_graph_active=active and 1 or 0
 end
 if not active then
  -- Keep the previous useful ground/T1-air milestone until the four genuine
  -- replacement definitions exist. Excluded domains never gain that exception.
  for key,d in pairs(defs)do
   local reason=M.SafetyReason(key,d,options)
   if reason then
    d.customparams=cp(d);d.customparams.prototype40k_tech_requires=key
    d.customparams.prototype40k_availability_reason=reason
    report.disabled[#report.disabled+1]=key
   end
   if d.buildoptions then
    local list={};if not reason then for _,target in ipairs(d.buildoptions)do
     if defs[target]and not M.SafetyReason(target,defs[target],options)then list[#list+1]=target end
    end end;d.buildoptions=list
   end
  end
  table.sort(report.disabled);return report
 end
 local allowed={};local menus={}
 for key in pairs(M.Known)do
  if not defs[key]then report.missing[#report.missing+1]=key
  elseif not present(defs,key)then report.incomplete[#report.incomplete+1]=key
  else report.present[#report.present+1]=key;allowed[key]=not M.BlockReason(key,defs[key],options)end
 end
 local function append(list,key)if allowed[key]then list[#list+1]=key end end
 for _,r in ipairs(M.Factories)do
  local key=r[2];menus[key]={}
  if allowed[key]then for _,product in ipairs(r[6])do append(menus[key],product)end end
 end
 local function construction(tier)
  local list={}
  for _,r in ipairs(M.Factories)do if r[4]<=tier+1 then append(list,r[2])end end
  for _,r in ipairs(M.Structures)do
   local startingEconomy=r[1]=='ORK-ENE-1'or r[1]=='ORK-MEX-1'
   if r[4]<=tier and r[3]<=tier+1 and(tier>0 or startingEconomy)then append(list,r[2])end
  end
  return list
 end
 menus.ork_big_mek_commander=construction(0)
 for _,r in ipairs(M.Builders)do menus[r[2]]=allowed[r[2]]and construction(r[4])or{}end
 for key,d in pairs(defs)do
  local c=cp(d);local ork=M.IsOrk(key,d);local reason=M.BlockReason(key,d,options)
  if ork or reason then
   d.customparams=c;c.prototype40k_tech_requires=key
   c.prototype40k_ork_v13=ork and 1 or nil
   c.prototype40k_availability_reason=reason
   if reason then report.disabled[#report.disabled+1]=key end
  end
  -- Every producer is filtered, including foreign/captured/native aliases. A
  -- product never gains a second route merely because an older adapter added it.
  if d.buildoptions then
   local list={}
   if not ork and not reason then for _,target in ipairs(d.buildoptions)do
    local td=defs[target]
    if td and not M.IsOrk(target,td)and not M.BlockReason(target,td,options)then list[#list+1]=target end
   end end
   d.buildoptions=menus[key]or list
  elseif menus[key]then d.buildoptions=menus[key]end
 end
 local function label(key,name,description)
  local d=defs[key];if not d then return end
  local c=d.customparams;d.name=name;d.description=description
  c.i18n_en_humanname=name;c.i18n_en_tooltip=description;c.prototype40k_short_role=description
 end
 for _,r in ipairs(M.Factories)do if present(defs,r[2])then
  local c=defs[r[2]].customparams;c.prototype40k_factory_domain=r[3];c.prototype40k_factory_tier=r[4];c.techlevel=r[4]
  c.production_role=r[3]=='vehicle'and'tank_factory'or r[3]=='superheavy'and'walker_factory'or r[3]..'_factory'
  c.rosterrole=c.production_role;c.prototype40k_vital=nil
  label(r[2],r[5],'T'..r[4]..' '..r[3]..' production')
 end end
 for _,r in ipairs(M.Builders)do if present(defs,r[2])then
  local c=defs[r[2]].customparams;c.prototype40k_constructor_domain=r[3];c.prototype40k_constructor_tier=r[4];c.techlevel=r[4]
  local note=c.prototype40k_constructor_appearance_note
  label(r[2],r[5],'T'..r[4]..' builder; constructs T1-T'..(r[4]+1)..' structures'..(note and'; '..note or''))
 end end
 if defs.ork_big_mek_commander then defs.ork_big_mek_commander.customparams.prototype40k_constructor_tier=0 end
 -- The old adapter incorrectly gives this combat/support actor construction.
 if defs.ork_big_mek_defence then
  local d=defs.ork_big_mek_defence;d.builder=false;d.buildoptions={}
  d.customparams.prototype40k_constructor_tier=nil;d.customparams.prototype40k_constructor_domain=nil
 end
 for _,field in ipairs({'present','missing','incomplete','disabled'})do table.sort(report[field])end
 return report
end
function M.ApplyGraph(graph,defs,options)
 graph.Requires=graph.Requires or{}
 local active=enabled(cp(defs.ork_big_mek_commander).prototype40k_ork_v13_graph_active)
 -- Stale entries may outlive definition registration. Clear only Ork entries;
 -- the existing squad research and other factions retain their own contracts.
 if active then for key in pairs(graph.Requires)do if M.IsOrk(key,defs[key])then graph.Requires[key]={}end end end
 for key,d in pairs(defs)do
  local reason=active and M.BlockReason(key,d,options)or M.SafetyReason(key,d,options)
  if reason then graph.Requires[key]={production_method=reason}
  elseif active and M.IsOrk(key,d)then graph.Requires[key]={}end
 end
 -- Native frame-zero starting commander exception, never a paid factory entry.
 if active then graph.Requires.ork_big_mek_commander={unit_limit=1,engine_initial_exception=true,production_method='Starting commander'}end
 graph.OrkAvailability=M.Version;graph.OrkGraphActive=active;graph.OrkAdvancedAir=M.AdvancedAir(options)
 return graph
end
return M
