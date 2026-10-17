-- Ordinary four-faction playtest policy. Source assets are reused, never copied here.
local M={}
local D=VFS.Include('40k_configs/development_playtest.lua')
local P=VFS.Include('40k_configs/four_faction_constructor_progression.lua')
local function copy(v)if type(v)~='table'then return v end;local o={};for k,x in pairs(v)do o[k]=copy(x)end;return o end
function M.Enabled(o)return D.Enabled(o)and D.OptionEnabled(o.prototype_source_progression)end
M.Sides={{name='Imperial Guard',startunit='imp_field_commander'},{name='Orks',startunit='ork_big_mek_commander'},{name='Random',startunit='dummycom'},{name='Space Marines',startunit='smcom'},{name='Necrons',startunit='nec_lord'}}
M.Starts={'imp_field_commander','smcom','ork_big_mek_commander','nec_lord'}
M.GuardBuilders={'imp_field_commander','wh40k_armck','wh40k_armcv','wh40k_armack','wh40k_armacv','imp_enginseer'}
M.GuardStructures={'imp_hq','imp_barracks','imp_generator','imp_mex','imp_thermo','imp_tank_factory','imp_research','imp_comms_array','imp_missile_defence','imp_superheavy_factory','imp_titan_factory'}
M.MarineStructures={'imp_marine_hq','imp_marine_barracks','imp_marine_generator','imp_marine_mex','imp_marine_thermo','imp_marine_armoury','imp_walker_factory','imp_marine_comms_array','imp_marine_missile_defence'}
M.Menus={
 imp_hq={'imp_enginseer','imp_commissar','wh40k_armack'},
 imp_barracks={'imp_guardsman','imp_commissar','imp_heavy_weapon_team','imp_kasrkin','imp_ogryn'},
 imp_tank_factory={'imp_enginseer','imp_sentinel','imp_hellhound','imp_russ','imp_basilisk','imp_hydra'},
 imp_superheavy_factory={'imp_baneblade'},imp_titan_factory={'imp_warhound'},
 imp_marine_hq={'imp_marine_builder','imp_scout'},
 imp_marine_barracks={'imp_marine','imp_assault_marine','imp_devastator','imp_terminator'},
 imp_walker_factory={'imp_marine_builder','imp_predator','imp_dreadnought','imp_dreadnought_hellfire','imp_dreadnought_ironclad','imp_dreadnought_venerable'},
}
local marine={smcom=true,imp_marine_builder=true,imp_marine=true,imp_scout=true,imp_devastator=true,imp_assault_marine=true,imp_terminator=true,imp_predator=true,imp_dreadnought=true,imp_dreadnought_hellfire=true,imp_dreadnought_ironclad=true,imp_dreadnought_venerable=true,imp_walker_factory=true}
for _,n in ipairs(M.MarineStructures)do marine[n]=true end
M.Requires={
 imp_hq={},imp_barracks={},imp_generator={},imp_mex={},imp_thermo={},imp_research={buildings={'imp_barracks'}},
 imp_tank_factory={buildings={'imp_barracks'}},imp_superheavy_factory={buildings={'imp_hq','imp_tank_factory'}},imp_titan_factory={buildings={'imp_superheavy_factory'}},
 imp_kasrkin={buildings={'imp_research'}},imp_ogryn={buildings={'imp_barracks'}},imp_heavy_weapon_team={buildings={'imp_barracks'}},imp_heavy_weapon_team_deployed={},
 imp_russ={buildings={'imp_tank_factory'}},imp_basilisk={buildings={'imp_tank_factory'}},imp_sentinel={buildings={'imp_tank_factory'}},
 imp_baneblade={buildings={'imp_superheavy_factory'}},imp_warhound={buildings={'imp_titan_factory'}},wh40k_armack={buildings={'imp_tank_factory'}},wh40k_armacv={buildings={'imp_tank_factory'}},
 smcom={engine_initial_exception=true},imp_marine_builder={},imp_marine_hq={},imp_marine_barracks={},imp_marine_generator={},imp_marine_mex={},imp_marine_thermo={},
 imp_marine_armoury={buildings={'imp_marine_barracks'}},imp_walker_factory={buildings={'imp_marine_hq','imp_marine_barracks'}},
 imp_marine={},imp_scout={},imp_assault_marine={buildings={'imp_marine_barracks'}},imp_devastator={buildings={'imp_marine_armoury'}},imp_terminator={buildings={'imp_marine_armoury','imp_walker_factory'}},
 imp_predator={buildings={'imp_walker_factory'}},imp_dreadnought={buildings={'imp_walker_factory'}},imp_dreadnought_hellfire={buildings={'imp_walker_factory'}},imp_dreadnought_ironclad={buildings={'imp_walker_factory','imp_marine_armoury'}},imp_dreadnought_venerable={buildings={'imp_walker_factory','imp_marine_armoury'}},
 ork_mek_shop={buildings={'ork_boyz_hut'}},ork_mek_lab={buildings={'ork_boyz_hut'}},ork_loota={buildings={'ork_mek_lab'}},ork_tankbusta={buildings={'ork_mek_lab'}},
 ork_nob={buildings={'ork_boyz_hut','ork_mek_shop'}},ork_meganob={buildings={'ork_mek_shop'}},ork_gunwagon={buildings={'ork_mek_shop'}},ork_deff_dread={buildings={'ork_mek_shop'}},
 ork_squiggoth={buildings={'ork_mek_shop','ork_waaagh_banner'}},ork_hq_super={buildings={'ork_mek_shop','ork_waaagh_banner'}},
 ork_dakka_stompa={buildings={'ork_hq_super'}},ork_gargant={buildings={'ork_hq_super'}},ork_great_gargant={buildings={'ork_hq_super'}},
 ork_flak_wartrak={buildings={'ork_mek_shop'}},ork_rokkit_interceptor={buildings={'ork_mek_shop'}},
 nec_greater_core={buildings={'nec_core'}},nec_ancient_core={buildings={'nec_greater_core'}},nec_archive={buildings={'nec_ancient_core'}},nec_energy_core={buildings={'nec_ancient_core'}},nec_thermo={buildings={'nec_energy_core'}},
 nec_immortal={buildings={'nec_core'}},nec_destroyer={buildings={'nec_greater_core'}},nec_spyder={buildings={'nec_greater_core'}},nec_heavy_destroyer={buildings={'nec_greater_core','nec_ancient_core'}},nec_monolith_mobile={buildings={'nec_ancient_core'},producer_min_health_fraction=.5},
}
for key,value in pairs(P.Requires)do M.Requires[key]=value end
for key,value in pairs(P.Menus)do M.Menus[key]=value end
function M.Graph(defs,options)
 local g={Requires={},Research={},FourFactionHybrid=true}
 for _,path in ipairs({'ork_release_graph','necron_release_graph'})do
  local old=VFS.Include('40k_configs/'..path..'.lua')
  for k,v in pairs(old.Requires)do g.Requires[k]=copy(v)end
 end
 for k,v in pairs(M.Requires)do g.Requires[k]=copy(v)end
 local n=VFS.Include('40k_configs/necron_release_graph.lua')
 for key,row in pairs(n.Research)do if key~='nec_awakening_1'and key~='nec_awakening_2'and key~='nec_vehicle_armour_1'then
  local r=copy(row);r.requires={buildings={r.producer}};g.Research[key]=r
 end end

 VFS.Include('40k_configs/squad_definitions.lua').AddResearch(g,VFS.Include('40k_configs/active_squad_profiles.lua'))
 for key,d in pairs(defs or{})do local cp=d.customParams or d.customparams or{};if cp.prototype40k_domain_candidate or cp.prototype40k_ranged_variant then g.Requires[key]={}end end
 options=options or(Spring and Spring.GetModOptions and Spring.GetModOptions())or{}
 VFS.Include('40k_configs/ork_v13_build_graph.lua').ApplyGraph(g,defs or{},options)
 return g
end
function M.Apply(defs,o,V)
 if not M.Enabled(o)then return{enabled=false}end
 local report={enabled=true,aliases={},menus={}}
 local function ready(key)
  local d=defs[key];local c=d and d.customparams or{}
  return d and tostring(c.prototype40k)=='1'and d.objectname and c.animsource and V.FileExists('objects3d/'..d.objectname)and V.FileExists('scripts/generated/'..c.animsource..'_anim.lua')
 end
 assert(ready('imp_field_commander')and ready('imp_enginseer'),'Four factions require actual Guard commander and engineer')
 -- Reuse the reviewed complete Force Commander bank; native ARM economic fields
 -- remain the starting template, while the Guard keeps its genuine command actor.
 local working={};for k,d in pairs(defs)do working[k]=d end
 local proof=VFS.Include('40k_configs/commander_presentation_review_hook.lua').Apply(working,{prototype_commander_presentation_review=true,prototype_commander_presentation_mode='both'},V)
 assert(proof.applied,'Four factions require Force Commander assets: '..tostring(proof.reason))
 defs.ork_big_mek_commander=copy(working.ork_big_mek_commander)
 defs.smcom=copy(working.imp_field_commander);defs.smcom.name='Space Marine Force Commander'
 defs.smcom.customparams.prototype40k_donor='smcom';defs.smcom.customparams.prototype40k_tech_requires='smcom'
 local function alias(name,source,label)
  assert(ready(source),'Four faction shared source missing: '..source)
  defs[name]=copy(defs[source]);local d=defs[name];d.name=label
  d.customparams.prototype40k_donor=name;d.customparams.prototype40k_tech_requires=name
  d.customparams.prototype40k_shared_visual_source=source
  d.customparams.i18n_en_humanname=nil;d.customparams.i18n_en_tooltip=nil
  report.aliases[#report.aliases+1]=name
 end
 alias('imp_marine_builder','wh40k_armck','Chapter Engineer')
 defs.imp_marine_builder.description='Marine construction detachment; shared Enginseer actor, native paid construction and repair'
 for _,row in ipairs({{'generator','Plasma Generator'},{'mex','Listening Post'},{'thermo','Thermo Plasma Generator'},{'comms_array','Communications Array'},{'missile_defence','Missile Defence'}})do
  if ready('imp_'..row[1])then alias('imp_marine_'..row[1],'imp_'..row[1],'Chapter '..row[2])end
 end
 for key,d in pairs(defs)do local c=d.customparams or{}
  if tostring(c.prototype40k)=='1'and(c.faction=='Imperium'or marine[key])then
   c.faction=(marine[key]or tostring(c.source_entity or''):find('/space_marines/',1,true))and'Space Marines'or'Imperial Guard'
  end
  if ready(key)then c.prototype40k_source_progression=1 end
 end
 defs.imp_field_commander.name='Imperial Guard Field Commander'
 local function menu(key,list)
  if not ready(key)then return end
  local d=defs[key];d.buildoptions={}
  for _,target in ipairs(list)do if ready(target)then d.buildoptions[#d.buildoptions+1]=target end end
  report.menus[key]=copy(d.buildoptions)
 end
 for _,builder in ipairs(M.GuardBuilders)do menu(builder,M.GuardStructures)end
 menu('smcom',M.MarineStructures);menu('imp_marine_builder',M.MarineStructures)
 for key,list in pairs(M.Menus)do menu(key,list)end
 for alias,source in pairs({wh40k_armlab='imp_barracks',wh40k_armalab='imp_barracks',wh40k_armvp='imp_tank_factory',wh40k_armavp='imp_tank_factory'})do menu(alias,M.Menus[source])end
 -- Reassert baseline identity requirements after legacy source adapters. Never
 -- map Marine products back to Guard facilities through a copied donor field.
 for key in pairs(M.Requires)do if ready(key)then defs[key].customparams.prototype40k_tech_requires=key end end
 report.constructorProgression=P.Apply(defs,ready,copy)
 -- Names are native UnitDef identities as well as translated labels: synced
 -- prerequisite command tooltips must name the same facility the player builds.
 local names={imp_hq='Imperial Guard Headquarters',imp_barracks='Imperial Guard Barracks',imp_tank_factory='Imperial Guard Vehicle Factory',
  wh40k_armlab='Imperial Guard Barracks',wh40k_armalab='Veteran Guard Barracks',wh40k_armvp='Imperial Guard Vehicle Factory',wh40k_armavp='Veteran Guard Vehicle Factory'}
 for key,name in pairs(names)do if ready(key)then defs[key].name=name end end
 -- Concise role lines remain suitable for the stock Info panel.
 local shortRoles={imp_hq='Optional Guard leadership',imp_barracks='Guard infantry / heavy teams',imp_tank_factory='Guard armour / artillery',
  imp_walker_factory='Marine armour / Dreadnoughts',imp_research='Guard infantry research',imp_marine_hq='Optional scout recruitment',
  imp_marine_barracks='Marine infantry production',imp_marine_armoury='Marine infantry research',
  imp_superheavy_factory='Guard superheavy vehicles',imp_titan_factory='Guard Titans'}
 local descriptions={imp_barracks='Produces Guard infantry and heavy weapon teams',imp_tank_factory='Produces Guard armour, artillery and Sentinels',imp_walker_factory='Machine Cult: produces Marine armour and Dreadnoughts',imp_research='Tactica Command: paid Guard infantry capabilities',imp_marine_armoury='Marine Armoury: paid infantry capabilities',imp_hq='Optional Guard command staff recruitment',imp_marine_hq='Optional Marine scout recruitment'}
 for key,description in pairs(descriptions)do if defs[key]and not P.Factories[key]then defs[key].description=description end end
 if defs.imp_walker_factory then defs.imp_walker_factory.name='Space Marine Machine Cult'end
 for key,d in pairs(defs)do if ready(key)then
  local c=d.customparams;c.prototype40k_four_faction=1
  c.prototype40k_short_role=c.prototype40k_short_role or shortRoles[c.prototype40k_donor or key]
  c.i18n_en_humanname=d.name;c.i18n_en_tooltip=d.description
 end end
 return report
end
return M
