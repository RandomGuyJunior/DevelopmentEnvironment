-- Source-coherent release graph; caller owns acceptance, payments and native rule enforcement.
local M={Faction='Necrons',Schema=1}
M.Army={'nec_scarab','nec_lord','nec_warrior','nec_flayed','nec_wraith','nec_immortal','nec_destroyer','nec_spyder','nec_heavy_destroyer','nec_monolith_mobile'}
M.Summoned={'nec_nightbringer'}
M.Structures={'nec_hq','nec_generator','nec_mex','nec_core','nec_greater_core','nec_ancient_core','nec_archive','nec_energy_core','nec_thermo','nec_turret','nec_sentry_pylon','nec_shield_spike'}
M.Requires={
 nec_hq={buildings={},research={},tier=0},
 nec_scarab={buildings={'nec_hq'},research={},tier=0},
 nec_lord={buildings={'nec_core'},research={},tier=0,unit_limit=1,engine_initial_exception=true},
 nec_generator={buildings={'nec_hq'},research={},tier=0},
 nec_mex={buildings={},research={},tier=0},
 nec_core={buildings={'nec_hq'},research={},tier=0},
 nec_greater_core={buildings={'nec_core'},research={'nec_awakening_1'},tier=1},
 nec_ancient_core={buildings={'nec_hq'},research={'nec_awakening_2'},tier=2},
 nec_archive={buildings={'nec_ancient_core'},research={'nec_awakening_2'},tier=2},
 nec_energy_core={buildings={'nec_ancient_core'},research={'nec_awakening_2'},tier=2},
 nec_thermo={buildings={'nec_energy_core'},research={'nec_awakening_2'},tier=2},
 nec_turret={buildings={'nec_hq'},research={},tier=0},
 nec_warrior={buildings={'nec_generator'},research={},tier=0},
 nec_flayed={buildings={'nec_core'},research={},tier=0},
 nec_wraith={buildings={'nec_core'},research={},tier=0},
 nec_immortal={buildings={},research={'nec_awakening_1'},tier=1},
 nec_destroyer={buildings={'nec_greater_core'},research={},tier=1},
 nec_spyder={buildings={'nec_greater_core'},research={},tier=1},
 nec_heavy_destroyer={buildings={'nec_greater_core'},research={'nec_awakening_2'},tier=2},
 nec_monolith_mobile={buildings={'nec_ancient_core'},research={'nec_awakening_2'},tier=2,producer_min_health_fraction=.5},
 -- C'tan is a source transformation/summoning mechanic, not an invented ordinary factory product.
 nec_nightbringer={buildings={'nec_archive'},research={'nec_ctan_manifestation'},tier=2,production_method='lord_transformation'},
}
M.Research={
 nec_awakening_1={name='Monolith Awakening I',producer='nec_hq',cost={metal=0,energy=525},time=135,
  requires={buildings={'nec_core'},research={},tier=0},grants_tier=1,source='attrib/addons/addon_necron_hq_1.lua'},
 nec_awakening_2={name='Monolith Awakening II',producer='nec_hq',cost={metal=0,energy=1000},time=160,
  requires={buildings={'nec_greater_core'},research={'nec_awakening_1'},tier=1},grants_tier=2,source='attrib/addons/addon_necron_hq_2.lua'},
 nec_warrior_gauss_1={name='Warrior Gauss and Durability I',producer='nec_core',cost={metal=0,energy=150},time=80,
  requires={buildings={'nec_hq'},research={},tier=0},source='attrib/research/races/necrons/ua_necron_warrior_boost.lua',
  effects={units={nec_warrior={health_add=120,weapon_damage_mult=1.200000048}}}},
 nec_destroyer_gauss_1={name='Destroyer Gauss and Durability I',producer='nec_greater_core',cost={metal=0,energy=200},time=80,
  requires={buildings={},research={'nec_awakening_1'},tier=1},source='attrib/research/races/necrons/ua_necron_destroyer_boost.lua',
  effects={units={nec_destroyer={health_add=350,weapon_damage_mult=1.100000024}}}},
 nec_monolith_boost={name='Restored Monolith Augmentation',producer='nec_energy_core',cost={metal=0,energy=375},time=60,
  requires={buildings={},research={'nec_awakening_2'},tier=2},source='attrib/research/races/necrons/ua_necron_monolith_boost.lua',
  implementation='source_monolith_speed_and_weapon_modifiers_required',requires_effect_handler=true},
 nec_mass_production={name='Necron Mass Production',producer='nec_energy_core',cost={metal=0,energy=600},time=30,
  requires={buildings={},research={'nec_awakening_2'},tier=2},source='attrib/research/races/necrons/ua_necron_mass_production_research.lua',
  implementation='source_production_modifier_required',requires_effect_handler=true},
 nec_ctan_manifestation={name='Ctan Manifestation',producer='nec_archive',cost={metal=0,energy=1000},time=180,
  requires={buildings={'nec_hq'},research={'nec_awakening_2'},tier=2},source='attrib/research/races/necrons/ua_necron_ctan_research.lua',
  unlocks={'nec_nightbringer'},production_method='lord_transformation',requires_effect_handler=true},
}
-- Third source HQ addon explicitly requires a Chaos HQ. It is not silently rewritten
-- into a self-contained Necron tier. Native release stops at the coherent source tier2.
M.Deferred={nec_awakening_3={source='attrib/addons/addon_necron_hq_3.lua',reason='source explicitly requires unimplemented Chaos HQ; source semantics need investigation'}}
M.Adaptations={
 commander='Selected genuine base DoW Lord founds the economy as the native engine-initial commander. Recruitment retains source Core/cap prerequisite.',
 variants='Base Lord/Immortal and Thermoplasma models are genuine selected visual variants; UA gameplay animators differ. No exact UA appearance claim.',
 economy='Source power costs map numerically to native energy; resource balance uses existing BAR metal/energy adaptation.',
 storage='Initial Lord/HQ native storage remains necessary for the BAR economy. Archive/Energy Core no longer impersonate radar/storage buildings.',
}
local function allowed(defs,ready,name)return type(ready)=='table' and ready[name]==true and type(defs[name])=='table' end
local function filter(defs,ready,list)
 local out={};for _,name in ipairs(list)do if allowed(defs,ready,name)then out[#out+1]=name end end;return out
end
local function copy(value)
 if type(value)~='table'then return value end
 local out={};for k,v in pairs(value)do out[k]=copy(v)end;return out
end
function M.Apply(defs,ready)
 assert(type(defs)=='table' and type(ready)=='table','Necron release requires authored definitions and explicit ready set')
 local applied={requires={},research={},patched={}}
 local function patch(name)
  if not allowed(defs,ready,name)then return end
  local d=defs[name];d.customparams=d.customparams or {};d.customparams.necron_release_graph=1
  d.customparams.source_role_policy='source_coherent_release';applied.patched[#applied.patched+1]=name
  if M.Requires[name]then applied.requires[name]=copy(M.Requires[name])end
  return d
 end
 for _,name in ipairs(M.Army)do patch(name)end
 for _,name in ipairs(M.Summoned)do patch(name)end
 for _,name in ipairs(M.Structures)do
  local d=patch(name)
  if d and name~='nec_hq' and (name=='nec_core' or name=='nec_greater_core' or name=='nec_ancient_core' or name=='nec_archive' or name=='nec_energy_core')then
   d.builder=false;d.canassist=false;d.canreclaim=false;d.workertime=0;d.builddistance=0;d.buildoptions={};d.canmove=false;d.speed=0
   d.customparams.factory=nil;d.customparams.rosterrole='support';d.customparams.production_role='research';d.customparams.unitgroup='util'
   d.yardmap=string.rep('o',(d.footprintx or 1)*(d.footprintz or 1))
   if name=='nec_core'then d.description='Unlocks Necron infantry; researches Warrior gauss and durability'end
   if name=='nec_greater_core'then d.description='Unlocks Necron heavy units; researches Destroyer gauss and durability'end
   if name=='nec_ancient_core'then d.description='Unlocks Necron late-game infrastructure and restored Monolith production'end
   if name=='nec_archive'then d.radardistance=0;d.sonardistance=0;d.energyuse=0;d.energyupkeep=0;d.description='Source Ctan research archive'end
   if name=='nec_energy_core'then d.energystorage=0;d.metalstorage=0;d.description='Source Monolith and late-game research core'end
  end
 end
 if allowed(defs,ready,'nec_hq')then
  local hq=defs.nec_hq;hq.buildoptions=filter(defs,ready,M.Army);hq.builder=true;hq.canmove=true;hq.speed=0
  hq.workertime=hq.workertime or 110;hq.builddistance=hq.builddistance or 220
  hq.customparams.factory=1;hq.customparams.production_role='HQ';hq.yardmap=string.rep('e',(hq.footprintx or 1)*(hq.footprintz or 1))
 end
 for _,name in ipairs({'nec_lord','nec_scarab'})do
  if allowed(defs,ready,name)then
   defs[name].buildoptions=filter(defs,ready,M.Structures)
   if name=='nec_lord'then defs[name].customparams.source_commander_founding_adaptation=1 end
  end
 end
 -- Declaration only: never deduct resources, set tiers, spawn actors or write markers.
 for id,r in pairs(M.Research)do
  if allowed(defs,ready,r.producer)then applied.research[id]=copy(r)end
 end
 return applied
end
return M
