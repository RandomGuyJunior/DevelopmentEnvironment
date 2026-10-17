-- BAR-style ground production. Genuine existing actors supply appearance; pinned
-- BAR factory/constructor templates supply native paid production economics.
local M={}
M.EconomicFields={'metalcost','energycost','buildtime','workertime'}
M.Aliases={
 {'imp_marine_vehicle_builder','armcv','Chapter Vehicle Works Engineer','Space Marines'},
 {'imp_marine_advanced_builder','armack','Senior Chapter Engineer','Space Marines'},
 {'imp_marine_advanced_vehicle_builder','armacv','Senior Chapter Vehicle Works Engineer','Space Marines'},
 {'imp_marine_advanced_barracks','imp_marine_barracks','Veteran Space Marine Barracks','Space Marines'},
 {'imp_marine_advanced_factory','imp_walker_factory','Advanced Space Marine Machine Cult','Space Marines'},
 {'nec_vehicle_scarab','nec_scarab','Vehicle Foundry Scarab','Necrons'},
 {'nec_advanced_scarab','nec_scarab','Advanced Tomb Scarab','Necrons'},
 {'nec_advanced_vehicle_scarab','nec_scarab','Advanced Vehicle Foundry Scarab','Necrons'},
 {'nec_vehicle_factory','nec_hq','Necron Vehicle Foundry','Necrons'},
 {'nec_advanced_factory','nec_hq','Advanced Necron Tomb Factory','Necrons'},
 {'nec_advanced_vehicle_factory','nec_hq','Advanced Necron Vehicle Foundry','Necrons'},
}
-- name -> domain, tier, exact pinned BAR economic template.
M.Factories={
 imp_barracks={'infantry',1,'armlab'},imp_tank_factory={'vehicle',1,'armvp'},
 armlab={'infantry',1,'armlab'},armvp={'vehicle',1,'armvp'},
 armalab={'infantry',2,'armalab'},armavp={'vehicle',2,'armavp'},
 imp_superheavy_factory={'vehicle',3,'armshltx'},imp_titan_factory={'infantry',3,'armshltx'},
 imp_marine_barracks={'infantry',1,'armlab'},imp_walker_factory={'vehicle',1,'armvp'},
 imp_marine_advanced_barracks={'infantry',2,'armalab'},imp_marine_advanced_factory={'vehicle',2,'armavp'},
 ork_boyz_hut={'infantry',1,'corlab'},ork_mek_shop={'vehicle',1,'corvp'},
 ork_mek_lab={'infantry',2,'coralab'},ork_resource_factory={'vehicle',2,'coravp'},ork_hq_super={'vehicle',3,'corgant'},
 nec_hq={'infantry',1,'armlab'},nec_vehicle_factory={'vehicle',1,'armvp'},
 nec_advanced_factory={'infantry',2,'armalab'},nec_advanced_vehicle_factory={'vehicle',2,'armavp'},
}
M.Constructors={
 armck={'infantry',1,'armck'},armcv={'vehicle',1,'armcv'},armack={'infantry',2,'armack'},armacv={'vehicle',2,'armacv'},
 imp_enginseer={'infantry',1,'armck'},
 imp_marine_builder={'infantry',1,'armck'},imp_marine_vehicle_builder={'vehicle',1,'armcv'},
 imp_marine_advanced_builder={'infantry',2,'armack'},imp_marine_advanced_vehicle_builder={'vehicle',2,'armacv'},
 corck={'infantry',1,'corck'},corcv={'vehicle',1,'corcv'},corack={'infantry',2,'corack'},coracv={'vehicle',2,'coracv'},
 ork_grot={'infantry',1,'corck'},ork_big_mek_defence={'infantry',2,'corack'},
 nec_scarab={'infantry',1,'armck'},nec_vehicle_scarab={'vehicle',1,'armcv'},
 nec_advanced_scarab={'infantry',2,'armack'},nec_advanced_vehicle_scarab={'vehicle',2,'armacv'},
}
M.Factions={
 ['Imperial Guard']={commander='armcom',base={'imp_barracks','imp_tank_factory','imp_generator','imp_mex','imp_comms_array','imp_hq','imp_research'},
  support={'imp_thermo','imp_missile_defence'},advanced={infantry='armalab',vehicle='armavp'},
  late={infantry={'imp_titan_factory'},vehicle={'imp_superheavy_factory'}}},
 ['Space Marines']={commander='smcom',base={'imp_marine_barracks','imp_walker_factory','imp_marine_generator','imp_marine_mex','imp_marine_comms_array','imp_marine_hq','imp_marine_armoury'},
  support={'imp_marine_thermo','imp_marine_missile_defence'},advanced={infantry='imp_marine_advanced_barracks',vehicle='imp_marine_advanced_factory'},late={}},
 ['Orks']={commander='corcom',base={'ork_boyz_hut','ork_mek_shop','ork_generator','ork_listening_post','ork_settlement','ork_waaagh_banner'},
  support={},advanced={infantry='ork_mek_lab',vehicle='ork_resource_factory'},late={infantry={'ork_hq_super'},vehicle={'ork_hq_super'}}},
 ['Necrons']={commander='nec_lord',base={'nec_hq','nec_vehicle_factory','nec_generator','nec_mex','nec_turret','nec_core'},
  support={'nec_greater_core','nec_sentry_pylon','nec_shield_spike'},advanced={infantry='nec_advanced_factory',vehicle='nec_advanced_vehicle_factory'},
  late={infantry={'nec_ancient_core','nec_archive','nec_energy_core','nec_thermo'},vehicle={'nec_ancient_core','nec_archive','nec_energy_core','nec_thermo'}}},
}
M.Menus={
 imp_hq={'imp_commissar'},
 imp_barracks={'armck','imp_guardsman','imp_commissar','imp_heavy_weapon_team'},
 imp_tank_factory={'armcv','imp_sentinel','imp_hellhound','imp_hydra'},
 armalab={'armack','imp_kasrkin','imp_ogryn'},armavp={'armacv','imp_russ','imp_basilisk'},
 imp_superheavy_factory={'imp_baneblade'},imp_titan_factory={'imp_warhound'},
 imp_marine_hq={'imp_scout'},
 imp_marine_barracks={'imp_marine_builder','imp_scout','imp_marine','imp_assault_marine'},
 imp_walker_factory={'imp_marine_vehicle_builder','imp_predator','imp_dreadnought'},
 imp_marine_advanced_barracks={'imp_marine_advanced_builder','imp_devastator','imp_terminator'},
 imp_marine_advanced_factory={'imp_marine_advanced_vehicle_builder','imp_dreadnought_hellfire','imp_dreadnought_ironclad','imp_dreadnought_venerable'},
 ork_settlement={'ork_slugga','ork_warboss'},
 ork_boyz_hut={'corck','ork_boy','ork_slugga','ork_burna','ork_tankbusta'},
 ork_mek_shop={'corcv','ork_wartrak','ork_lobba','ork_killa_kan','ork_flak_wartrak'},
 ork_mek_lab={'corack','ork_loota','ork_nob','ork_meganob','ork_big_mek_defence'},
 ork_resource_factory={'coracv','ork_gunwagon','ork_deff_dread','ork_squiggoth','ork_looted_rhino','ork_battlewagon_armageddon','ork_battlefortress_armageddon','ork_rokkit_interceptor'},
 -- Great Teleporta keeps its existing accepted products; retirement policy is final.
 nec_hq={'nec_scarab','nec_warrior','nec_flayed','nec_wraith'},
 nec_vehicle_factory={'nec_vehicle_scarab','nec_destroyer'},
 nec_advanced_factory={'nec_advanced_scarab','nec_immortal','nec_spyder'},
 nec_advanced_vehicle_factory={'nec_advanced_vehicle_scarab','nec_heavy_destroyer','nec_monolith_mobile'},
}
M.Menus.armlab=M.Menus.imp_barracks;M.Menus.armvp=M.Menus.imp_tank_factory
M.Requires={}
for name in pairs(M.Factories)do M.Requires[name]={}end
for name in pairs(M.Constructors)do M.Requires[name]={}end
for _,list in pairs(M.Menus)do for _,name in ipairs(list)do M.Requires[name]={}end end
for _,f in pairs(M.Factions)do for _,name in ipairs(f.base)do M.Requires[name]={}end end
-- Optional improvements retain useful disabled explanations, never general tiers.
M.Requires.imp_research={buildings={'imp_barracks'}}
M.Requires.imp_marine_armoury={buildings={'imp_marine_barracks'}}
for _,name in ipairs({'nec_generator','nec_core','nec_greater_core','nec_ancient_core','nec_archive','nec_energy_core','nec_thermo','nec_turret','nec_sentry_pylon','nec_shield_spike'})do M.Requires[name]={}end
M.Requires.nec_lord={unit_limit=1,engine_initial_exception=true,production_method='engine_initial_commander'}
M.Requires.nec_nightbringer={buildings={'nec_archive'},research={'nec_ctan_manifestation'},production_method='lord_transformation'}

function M.Apply(defs,ready,copy)
 local templates={}
 for _,rows in ipairs({M.Factories,M.Constructors})do for _,row in pairs(rows)do
  local key=row[3];assert(defs[key],'Pinned native production template absent: '..key)
  templates[key]={};for _,field in ipairs(M.EconomicFields)do templates[key][field]=assert(defs[key][field],key..':'..field)end
 end end
 for _,row in ipairs(M.Aliases)do
  local key,source,label,faction=unpack(row);assert(ready(source),'Genuine production alias source absent: '..source)
  local d=copy(defs[source]);defs[key]=d;d.name=label;local c=d.customparams
  c.faction=faction;c.prototype40k_donor=key;c.prototype40k_tech_requires=key;c.prototype40k_shared_visual_source=source
 end
 local function menu(key,list)
  if not ready(key)then return end
  local d=defs[key];d.buildoptions={}
  for _,target in ipairs(list)do if ready(target)then d.buildoptions[#d.buildoptions+1]=target end end
 end
 for key,list in pairs(M.Menus)do menu(key,list)end
 for key,row in pairs(M.Factories)do if ready(key)then
  local d=defs[key];local c=d.customparams;d.builder=true;d.canmove=true;d.speed=0
  c.factory=1;c.production_role=row[1]=='infantry'and'infantry_factory'or'tank_factory';c.rosterrole=c.production_role
  c.prototype40k_vital=nil;c.prototype40k_factory_tier=row[2];c.prototype40k_factory_domain=row[1]
  c.techlevel=row[2];c.prototype40k_economy_template=row[3];c.prototype40k_tech_requires=key
  c.prototype40k_short_role='T'..row[2]..' '..row[1]..' production'
  d.description=c.prototype40k_short_role..'; trains '..(row[2]<3 and'its domain constructor'or'heavy units')
  for field,value in pairs(templates[row[3]])do d[field]=value end
 end end
 local function append(out,list)for _,name in ipairs(list or{})do out[#out+1]=name end end
 for faction,f in pairs(M.Factions)do menu(f.commander,f.base)end
 for key,row in pairs(M.Constructors)do if ready(key)then
  local d=defs[key];local c=d.customparams;local f=assert(M.Factions[c.faction],key..' faction')
  local list={};append(list,f.base);append(list,f.support);list[#list+1]=f.advanced[row[1]]
  if row[2]>=2 then append(list,f.late[row[1]])end
  menu(key,list);c.prototype40k_constructor_tier=row[2];c.prototype40k_constructor_domain=row[1]
  c.prototype40k_economy_template=row[3];c.prototype40k_tech_requires=key;c.techlevel=row[2]
  c.prototype40k_short_role='T'..row[2]..' '..row[1]..' constructor'
  d.description=c.prototype40k_short_role..'; genuine shared builder actor; builds '..(row[2]==1 and'T2 '..row[1]..' factory'or'advanced '..row[1]..' infrastructure')
  for field,value in pairs(templates[row[3]])do d[field]=value end
 end end
 if ready('nec_hq')then defs.nec_hq.name='Necron Tomb Factory'end
 if ready('ork_resource_factory')then defs.ork_resource_factory.name='Advanced Ork Vehicle Factory'end
 if ready('ork_mek_lab')then defs.ork_mek_lab.name='Veteran Ork Infantry Works'end
 -- Every public requirement has its actual definition identity, including old aliases.
 for key in pairs(M.Requires)do if ready(key)then defs[key].customparams.prototype40k_tech_requires=key end end
 return {policy='bar_constructor_ground_v1',economy_scale=1}
end
return M
