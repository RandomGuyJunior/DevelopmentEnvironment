-- Authored combined-Imperium progression. Readiness is supplied by coordinator;
-- existence/export/diagnostic status never imply native release acceptance.
local M={Faction='Imperium'}
M.Research={
 imperial_logistics={name='Imperial Logistics',producer='imp_research',cost={metal=450,energy=2200},time=45,tier=2,
  requires={buildings={'imp_hq','imp_research'},tier=1}},
 imperial_full_scale_war={name='Full Scale War',producer='imp_research',cost={metal=1400,energy=7000},time=90,tier=3,
  requires={buildings={'imp_hq','imp_research'},research={'imperial_logistics'},tier=2}},
 imperial_titan_writ={name='Titan Deployment Writ',producer='imp_titan_factory',cost={metal=3500,energy=18000},time=120,tier=4,
  requires={buildings={'imp_hq','imp_titan_factory'},research={'imperial_full_scale_war'},tier=3}},
}
M.Requires={
 imp_kasrkin={buildings={'imp_research'},research={'imperial_logistics'},tier=2},
 imp_devastator={buildings={'imp_research'},research={'imperial_logistics'},tier=2},
 imp_ogryn={buildings={'imp_research'},research={'imperial_logistics'},tier=2},
 imp_assault_marine={buildings={'imp_research'},research={'imperial_logistics'},tier=2},
 imp_terminator={buildings={'imp_research'},research={'imperial_full_scale_war'},tier=3},
 imp_walker_factory={buildings={'imp_research'},research={'imperial_logistics'},tier=2},
 imp_dreadnought={buildings={'imp_walker_factory'},research={'imperial_logistics'},tier=2},
 imp_dreadnought_hellfire={buildings={'imp_walker_factory'},research={'imperial_full_scale_war'},tier=3},
 imp_dreadnought_ironclad={buildings={'imp_walker_factory'},research={'imperial_full_scale_war'},tier=3},
 imp_dreadnought_venerable={buildings={'imp_walker_factory'},research={'imperial_full_scale_war'},tier=3},
 imp_russ={buildings={'imp_tank_factory'},research={'imperial_logistics'},tier=2},
 imp_basilisk={buildings={'imp_tank_factory'},research={'imperial_logistics'},tier=2},
 imp_predator={buildings={'imp_tank_factory'},research={'imperial_logistics'},tier=2},
 imp_superheavy_factory={buildings={'imp_hq','imp_research'},research={'imperial_full_scale_war'},tier=3},
 imp_baneblade={buildings={'imp_superheavy_factory'},research={'imperial_full_scale_war'},tier=3},
 imp_titan_factory={buildings={'imp_hq','imp_superheavy_factory'},research={'imperial_full_scale_war'},tier=3},
 imp_warhound={buildings={'imp_titan_factory'},research={'imperial_titan_writ'},tier=4},
}
M.Buildings={
 imp_hq={source='attrib/ebps/races/guard/structures/guard_hq.lua',original='Command, builders, heroes and HQ progression',adapted='Command and constructor production'},
 imp_barracks={source='attrib/ebps/races/guard/structures/guard_infantry.lua',original='Guard infantry recruitment',adapted='Combined Imperial infantry barracks'},
 imp_tank_factory={source='attrib/ebps/races/guard/structures/guard_mechanized.lua',original='Guard mechanised vehicle production',adapted='Imperial armour and artillery production'},
 imp_walker_factory={source='attrib/ebps/races/space_marines/structures/space_marine_vehicle_building.lua',original='Machine Cult Marine vehicle and Dreadnought production',adapted='Machine Cult walker manufactorum'},
 imp_generator={source='attrib/ebps/races/guard/structures/guard_plasma_generator.lua',original='Plasma power income',adapted='Energy income'},
 imp_mex={source='attrib/ebps/races/guard/structures/guard_listening_post.lua',original='Captured strategic point requisition and defence',adapted='Metal spot extraction and strategic point control'},
 imp_thermo={source='attrib/ebps/races/guard/structures/guard_thermo_plasma.lua',original='Advanced strategic-location power production',adapted='Geothermal energy production'},
 imp_research={source='attrib/ebps/races/guard/structures/guard_tactica.lua',original='Guard equipment, infantry, morale and specialist research',adapted='Paid combined Imperial technology research'},
 imp_comms_array={source='attrib/ebps/races/guard/structures/guard_comms_array.lua',original='Forward command, reinforcements and support',adapted='Auspex command and strategic defence support; native role needs proof'},
 imp_superheavy_factory={source='attrib/ebps/races/guard/structures/guard_mars_pattern.lua',original='Mars Pattern super-heavy armour production',adapted='Super-heavy armour command'},
 imp_titan_factory={source='attrib/ebps/races/guard/structures/guard_titan_facility.lua',original='Warhound, Reaver, Warlord and Imperator construction',adapted='Titan assembly facility'},
}
M.Rosters={
 structures={'imp_hq','imp_barracks','imp_tank_factory','imp_walker_factory','imp_generator','imp_mex','imp_thermo','imp_research','imp_comms_array','imp_missile_defence','imp_superheavy_factory','imp_titan_factory'},
 imp_hq={'imp_enginseer','imp_commissar'},
 imp_barracks={'imp_guardsman','imp_marine','imp_scout','imp_commissar','imp_heavy_weapon_team','imp_kasrkin','imp_devastator','imp_ogryn','imp_assault_marine','imp_terminator'},
 imp_tank_factory={'imp_enginseer','imp_hellhound','imp_russ','imp_basilisk','imp_predator','imp_hydra'},
 imp_walker_factory={'imp_enginseer','imp_sentinel','imp_dreadnought','imp_dreadnought_hellfire','imp_dreadnought_ironclad','imp_dreadnought_venerable'},
 imp_superheavy_factory={'imp_baneblade'},imp_titan_factory={'imp_warhound'},
}
-- Do not offer Tactica as a jammer/repair tower, HQ as metal storage, or a
-- generator as an arbitrary converter. Missing source-compatible roles stay
-- explicitly blocked; readiness for one donor cannot legitimise those aliases.
M.BlockedAliases={'armestor','armmstor','armjamt','armveil','armnanotc','armnanotcplat','armmakr','armmmkr','armrad','armarad'}
local function clone(v)
 if type(v)~='table' then return v end
 local t={};for k,x in pairs(v)do t[k]=clone(x)end;return t
end
function M.Apply(defs,ready)
 assert(type(ready)=='function','Imperium release graph needs explicit readiness callback')
 local report={faction=M.Faction,menus={},blocked={},blockedAliases=clone(M.BlockedAliases)}
 local function accepted(k)return defs[k]~=nil and ready(k)==true end
 local function options(parent,list)
  if not accepted(parent)then return end
  local d=defs[parent];d.buildoptions={};report.menus[parent]={}
  for _,k in ipairs(list)do
   if accepted(k)then d.buildoptions[#d.buildoptions+1]=k;report.menus[parent][#report.menus[parent]+1]=k
   else report.blocked[#report.blocked+1]=parent..':'..k end
  end
 end
 for _,builder in ipairs({'imp_field_commander','wh40k_armck','wh40k_armcv','wh40k_armack','wh40k_armacv','imp_enginseer'})do options(builder,M.Rosters.structures)end
 for parent,list in pairs(M.Rosters)do if parent~='structures'then options(parent,list)end end
 -- Recognised accepted native wrappers retain real native cost/build power.
 local aliases={wh40k_armlab='imp_barracks',wh40k_armalab='imp_barracks',wh40k_armvp='imp_tank_factory',wh40k_armavp='imp_tank_factory'}
 for alias,donor in pairs(aliases)do
  if accepted(alias)and (defs[alias].customparams or {}).prototype40k_donor==donor then options(alias,M.Rosters[donor])end
 end
 for key,requires in pairs(M.Requires)do
  if accepted(key)then defs[key].customparams=defs[key].customparams or {};defs[key].customparams.prototype40k_tech_requires=key end
 end
 if accepted('imp_research')then
  local cp=defs.imp_research.customparams or {};defs.imp_research.customparams=cp
  cp.research_pending=nil;cp.prototype40k_research_producer='Imperium'
  defs.imp_research.description='Tactica Command: paid Imperial technology research'
 end
 if accepted('imp_walker_factory')then defs.imp_walker_factory.name='Machine Cult Walker Manufactorum' end
 return report
end
return M
