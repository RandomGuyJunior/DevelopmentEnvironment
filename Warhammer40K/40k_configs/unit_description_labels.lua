-- Client-side I18N labels only. Never change UnitDefs or customParams: those
-- remain part of the strict native identity and simulation metadata.
local M={}
local function marked(v)return v==true or v==1 or v=='1'or v=='true'end
local function params(d)return d and(d.customParams or d.customparams)or{}end
function M.Accepted(d)
 local c=params(d)
 return marked(c.prototype40k_ui_ready)or marked(c.prototype40k)
  or marked(c.prototype40k_constructor_singleton)
end
local specific={
 ork_boy='Ranged infantry',ork_slugga='Melee infantry',ork_gretchin_squad='Light ranged infantry',ork_gretchin='Light ranged infantry',
 ork_ard_boy='Armoured infantry',ork_burna='Flame infantry',ork_flash_gitz='Heavy ranged infantry',ork_loota='Heavy ranged infantry',
 ork_nob='Heavy melee infantry',ork_warboss='Infantry leader',ork_tankbusta='Anti-armour infantry',ork_boy_rokkit='Anti-armour infantry',
 ork_kommando='Stealth infantry',ork_stormboy='Assault infantry',ork_meganob='Armoured infantry',ork_bomb_squig='Explosive creature',
 imp_guardsman='Ranged infantry',imp_marine='Ranged infantry',imp_assault_marine='Assault infantry',imp_scout='Scout infantry',
 imp_kasrkin='Elite ranged infantry',imp_ogryn='Heavy infantry',imp_commissar='Infantry leader',imp_terminator='Heavy infantry',
 imp_devastator='Heavy ranged infantry',imp_marine_heavy='Heavy ranged infantry',imp_heavy_weapon_team='Heavy weapon squad',
 imp_heavy_weapon_team_deployed='Heavy weapon squad',nec_warrior='Ranged infantry',nec_immortal='Heavy ranged infantry',
 nec_flayed='Melee infantry',nec_wraith='Assault infantry',nec_nightbringer='Heavy combat support',
 ork_gunship='Heavy gunship',ork_fighta_bomba='Attack aircraft',ork_boomy_platform='Fixed artillery',
 ork_looted_rhino='Transport vehicle',ork_trukk='Transport vehicle',ork_wartrukk='Transport vehicle',ork_warbike='Attack bike',
 ork_crewed_warbike='Attack bike',ork_warbike_crewed='Attack bike',ork_killa_kan='Combat walker',ork_morkanaut='Heavy walker',ork_big_mek_defence='Shield support',
 ork_kan_twin_kmb='Energy-weapon walker',ork_kan_twin_rokkit='Missile walker',ork_kan_twin_shoota='Machine-gun walker',
 ork_dread_ranged_fourarm='Ranged combat walker',imp_titan_factory='Titan factory',
 ork_dakka_stompa='Super-heavy walker',ork_stompa='Super-heavy walker',ork_gargant='Super-heavy walker',
 ork_great_gargant='Super-heavy walker',ork_squiggoth='Heavy combat creature',imp_warhound='Super-heavy walker',
 imp_baneblade='Super-heavy tank',imp_hellhound='Flame tank',imp_russ='Battle tank',imp_predator='Battle tank',
 ork_battlewagon_armageddon='Heavy combat vehicle',ork_battlefortress_armageddon='Super-heavy vehicle',
 nec_destroyer='Ranged skimmer',nec_heavy_destroyer='Heavy ranged skimmer',nec_monolith_mobile='Heavy combat vehicle',
 nec_spyder='Support walker',ork_rokkit_interceptor='Missile defence',nec_shield_spike='Shield defence',
 ['40k_relic_objective']='Capturable relic',imp_marine_hq='Infantry factory',imp_hq='Infantry factory',ork_settlement='Infantry factory',
}
local roles={
 infantry='Ranged infantry',tank='Combat vehicle',walker='Combat walker',aircraft='Combat aircraft',creature='Combat creature',
 generator='Power generator',geothermal='Geothermal generator',thermo='Geothermal generator',extractor='Metal extractor',mex='Metal extractor',
 energy_storage='Energy storage',metal_storage='Metal storage',storage='Resource storage',converter='Energy converter',
 radar='Radar',advanced_recon='Radar',jammer='Radar jammer',repair='Repair station',research='Research building',
 equipment_research='Research building',support='Support structure',defence='Defence turret',field_defence='Defence turret',
 strategic_defence='Missile defence',anti_air='Anti-air defence',artillery='Artillery',capturable_relic='Capturable relic',
 infantry_factory='Infantry factory',barracks='Infantry factory',tank_factory='Vehicle factory',walker_factory='Walker factory',
 air_factory='Aircraft factory',command_factory='Infantry factory',hq='Infantry factory',
}
function M.Description(key,d)
 if not M.Accepted(d)then return nil end
 local c=params(d);key=tostring(key or'')
 local role=tostring(c.prototype40k_vital or c.production_role or c.rosterrole or''):lower()
 local tier=tonumber(c.prototype40k_constructor_tier or c.prototype40k_builder_tier or c.techlevel)
 local commander=role=='commander'or marked(c.iscommander)or key=='imp_field_commander'or key=='ork_big_mek_commander'or key=='smcom'or key=='nec_lord'
 if commander then return 'Commander / builder'end
 if marked(c.prototype40k_temporary_constructor_appearance)then
  return(tier and'T'..tier..' 'or'')..'flying builder (temporary BAR model)'
 end
 if role=='constructor'or role=='builder'or c.prototype40k_constructor_domain then
  local flying=c.prototype40k_constructor_domain=='air'or marked(d.canFly or d.canfly)
  return(tier and'T'..tier..' 'or'')..(flying and'Flying builder'or'Builder')
 end
 local keyWithoutMember=key:gsub('_member$','')
 if specific[key]or specific[keyWithoutMember]then return specific[key]or specific[keyWithoutMember]end
 if roles[role]then
  local factoryTier=tonumber(c.prototype40k_factory_tier)
  return(factoryTier and'T'..factoryTier..' 'or'')..roles[role]
 end
 -- Future accepted actors still get a short role, without exposing source,
 -- diagnostic, research-gate or acceptance text from their old tooltips.
 if marked(d.isFactory or d.isfactory)then return 'Unit factory'end
 if marked(d.isBuilder or d.builder)then return 'Builder'end
 if marked(d.canFly or d.canfly)then return 'Combat aircraft'end
 if marked(d.isBuilding or d.isbuilding)then return 'Support structure'end
 if c.unitgroup=='weaponaa'or c.unitgroup=='aa'then return 'Anti-air unit'end
 return 'Combat unit'
end
return M
