-- Authored source voice/weapon associations. Runtime metadata does not imply acceptance.
local M={}
-- No verified source aircraft acknowledgement for Orc_Ship2. Preserve native
-- aircraft feedback; never relabel shared Ork infantry speech as Gunship voice.
local noSourceVoice={ork_gunship=true}
local profiles={imp_guardsman='guard',imp_marine='marine',guardsman='guard',space_marine='marine',imp_russ='russ',leman_russ='russ',imp_enginseer='enginseer',imp_commissar='commissar',imp_kasrkin='kasrkin',imp_scout='marine',imp_devastator='marine',imp_predator='marine',imp_assault_marine='marine',imp_terminator='marine',imp_dreadnought='dreadnought',ork_boy='ork',meganob='mega',killa_kan='kan',ork_meganob='mega',ork_killa_kan='kan',ork_warboss='warboss',ork_grot='grot',ork_trukk='trukk',nec_lord='lord',nec_scarab='scarab'}
for key,profile in pairs({imp_scout='scout',imp_assault_marine='assault',imp_terminator='terminator',imp_predator='predator',imp_baneblade='baneblade',imp_basilisk='basilisk',imp_hellhound='hellhound',imp_sentinel='sentinel',imp_ogryn='ogryn',imp_heavy_weapon_team='heavy_weapons',imp_heavy_weapon_team_deployed='heavy_weapons',ork_tankbusta='tankbusta',ork_nob='nob',ork_wartrak='wartrak',ork_squiggoth='squiggoth',nec_destroyer='nec_destroyer',nec_heavy_destroyer='nec_heavy_destroyer',nec_immortal='nec_immortal',nec_flayed='nec_flayed',nec_pariah='nec_pariah',nec_wraith='nec_wraith',nec_monolith='nec_monolith',nec_tomb_spyder='nec_spyder',nec_spyder='nec_spyder',nec_monolith_mobile='nec_monolith',nec_nightbringer='nec_nightbringer',imp_hq='guard_building',imp_barracks='guard_building',imp_tank_factory='guard_building',imp_walker_factory='guard_building',imp_generator='guard_building',imp_mex='guard_building',imp_thermo='guard_building',imp_research='guard_building',imp_superheavy_factory='guard_building',imp_titan_factory='guard_building',ork_settlement='ork_building',ork_boyz_hut='ork_building',ork_mek_shop='ork_building',ork_mek_lab='ork_building',ork_generator='ork_building',ork_resource_factory='ork_building',ork_listening_post='ork_building',ork_waaagh_banner='ork_building',ork_hq_super='ork_building'})do profiles[key]=profile end
-- Distinct faction aliases must not hide their actual actor behind donor IDs.
profiles.smcom='force_commander';profiles.imp_force_commander_candidate='force_commander'
profiles.ork_big_mek_defence='big_mek';profiles.imp_marine_builder='enginseer'
profiles.imp_dreadnought_hellfire='dreadnought';profiles.imp_dreadnought_ironclad='dreadnought';profiles.imp_dreadnought_venerable='dreadnought'
local buildingProfiles={
 imp_hq='guard_hq',imp_barracks='guard_infantry',imp_mex='guard_listening_post',imp_superheavy_factory='guard_marspattern',imp_tank_factory='guard_mechanized',imp_generator='guard_plasmagenerator',imp_research='guard_tactica',imp_thermo='guard_thermoplasma',
 imp_marine_hq='space_marines_marine_hq',imp_marine_barracks='space_marines_barracks',imp_marine_armoury='space_marines_armoury',imp_walker_factory='space_marines_machine_cult',imp_marine_mex='space_marines_listening_post',imp_marine_generator='space_marines_plasma_generator',imp_marine_thermo='space_marines_thermo_generator',
 ork_settlement='orks_ork_hq',ork_boyz_hut='orks_boyz_hut',ork_generator='orks_generator',ork_listening_post='orks_listening_post',ork_mek_shop='orks_mek_shop',ork_mek_lab='orks_pile_of_guns',ork_waaagh_banner='orks_waagh_banner',
 nec_hq='necron_monolith',nec_generator='necron_plasma_generator',nec_mex='necron_listening_post',nec_core='necron_summoning_core',nec_greater_core='necron_greater_summoning_core',nec_archive='necron_forbidden_archive',nec_energy_core='necron_energy_core',nec_thermo='necron_thermoplasma_generator',nec_turret='necron_turret',
}
-- Authored composites reuse the selector of their actual visual ingredient.
-- These sound identities do not import HQ/research/gameplay roles.
for key,profile in pairs({
 ork_boyz_hut_t2='orks_boyz_hut',ork_warcamp='orks_boyz_hut',
 ork_mek_lab_t3='orks_pile_of_guns',
 fortyk_ork_air_factory='orks_ork_hq',fortyk_ork_advanced_air_factory='orks_ork_hq',fortyk_ork_super_air_factory='orks_ork_hq',
 ork_generator_t2='orks_generator',ork_generator_t3='orks_generator',ork_geothermal='orks_generator',
})do buildingProfiles[key]=profile end
for key,profile in pairs(buildingProfiles)do profiles[key]='building_'..profile end
-- Provisional shared vehicle-class cues, never generic Boy infantry speech.
-- Existing Kan/Wartrak recordings are borrowed profiles, not bespoke GOH voices.
profiles.ork_morkanaut='kan'
profiles.ork_warbike_crewed='wartrak'
-- Genuine Grot speech; creature has no verified source voice mapping.
profiles.ork_gretchin_combat='grot'
noSourceVoice.ork_bomb_squig=true
local structureRoles={HQ=true,hq=true,barracks=true,tank_factory=true,walker_factory=true,command_factory=true,infantry_factory=true,equipment_research=true,research=true,generator=true,extractor=true,mex=true,thermo=true,geothermal=true,radar=true,support=true,storage=true,energy_storage=true,metal_storage=true,repair=true,turret=true}
function M.IsStructure(d,cp)
 cp=cp or(d and(d.customparams or d.customParams))or{}
 if cp.rosterrole=='infantry'or cp.rosterrole=='builder'or cp.prototype40k_vital=='commander'or cp.prototype40k_vital=='constructor'then return false end
 return cp.source_voice_kind=='structure'or structureRoles[cp.production_role or cp.rosterrole or cp.prototype40k_vital]==true
  or type(cp.source_entity)=='string'and cp.source_entity:find('/structures/',1,true)~=nil or d and(d.isBuilding==true or d.yardmap~=nil)or false
end
function M.Profile(key,cp)
 cp=cp or{}
 if noSourceVoice[key]then return nil end
 local structure=M.IsStructure(nil,cp)
 local function allowed(profile)
  -- A building may borrow a genuine building cue, never a mobile actor line.
  return profile and(not structure or profile:sub(1,9)=='building_')and profile or nil
 end
 -- The alias itself is authoritative for deliberately shared Chapter structures.
 if profiles[key]and key:sub(1,3)~='arm'and key:sub(1,3)~='cor'then return allowed(profiles[key])end
 for _,source in ipairs({cp.prototype40k_donor or'',cp.prototype40k_shared_visual_source or'',cp.animsource or''})do
  if noSourceVoice[source]then return nil end
  local profile=allowed(profiles[source]);if profile then return profile end
 end
 if structure then return nil end
 return cp.faction=='Necrons'and'necron'or cp.faction=='Orks'and'ork'or cp.faction=='Space Marines'and'marine'or(cp.faction=='Imperium'or cp.faction=='Imperial Guard')and'guard'or nil
end
function M.EventAllowed(d,event)
 if not d then return false end
 if event=='move'then return(tonumber(d.speed)or 0)>0 end
 if event=='attack'then return d.canAttack~=false and d.canattack~=false and #(d.weapons or{})>0 end
 if event=='repair'then return(d.isBuilder==true or d.builder==true)and not M.IsStructure(d)end
 return event=='selection'or event=='unit_complete'
end
function M.Clips(clips,profile,event,exists)
 local valid={}
 for _,c in ipairs(profile and clips['voice_'..profile..'_'..event]or{})do
  if type(c)=='table'and type(c.file)=='string'and c.file:match('^sounds/40k/')and type(c.duration)=='number'and c.duration==c.duration and c.duration>0 and c.duration<=30 and exists(c.file)then valid[#valid+1]=c end
 end
 return valid
end
function M.WeaponFamily(key,cp,family)
 local source=cp and (cp.prototype40k_donor or cp.animsource) or key
 if family=='flamer' then
  if source=='ork_burna' then return 'burna' end
  if source=='imp_hellhound' then return nil end -- loop attribution pending
 end
 if family=='claw' then
  if source=='ork_warboss' then return 'power_claw' end
  if source~='killa_kan' and source~='ork_killa_kan' then return nil end
 end
 return family
end
local function applyWeaponAudio(key,d,cp,clips)
   for _,w in pairs(d.weapondefs or {})do
    local family=M.WeaponFamily(key,cp,(w.customparams or {}).source_fx_family)
    local entries=family and clips['weapon_'..family]
    if entries and entries[1] and VFS.FileExists(entries[1].file)then w.soundstart='40k_'..family;w.soundstartvolume=1 end
    local impact=clips.weapon_explosion
    if impact and impact[1] and VFS.FileExists(impact[1].file) and (tonumber(w.areaofeffect)or 0)>=16 then w.soundhit='40k_explosion';w.soundhitvolume=.7 end
   end
end
function M.ApplyWeaponAudio(defs)
 if not VFS.FileExists('40k_configs/generated_audio.lua')then return end
 local clips=VFS.Include('40k_configs/generated_audio.lua')
 for key,d in pairs(defs)do local cp=d.customparams or{};if tostring(cp.prototype40k)=='1'then applyWeaponAudio(key,d,cp,clips)end end
end
function M.Apply(defs)
 if not VFS.FileExists('40k_configs/generated_audio.lua') then return end
 local clips=VFS.Include('40k_configs/generated_audio.lua')
 for key,d in pairs(defs)do
  local cp=d.customparams or {}
  if tostring(cp.prototype40k)=='1' then
   cp.source_voice_kind=M.IsStructure(d,cp)and'structure'or'mobile'
   cp.source_voice_profile=M.Profile(key,cp);d.customparams=cp
   -- Stock acknowledgement mechanisms remain present for unrelated BAR actors.
   -- Marked actors have exactly one unsynced representative speaker below.
   local function available(event)
    return #M.Clips(clips,cp.source_voice_profile,event,VFS.FileExists)>0
   end
   d.sounds=d.sounds or {}
   -- Structures never inherit spoken infantry/robot acknowledgements.
   -- Mobile actors with genuinely missing events retain their native feedback.
   if available('selection')or cp.source_voice_kind=='structure'then d.sounds.select=nil end
   if available('move')or available('attack')or available('repair')or cp.source_voice_kind=='structure'then d.sounds.ok=nil end
   if available('move')or cp.source_voice_kind=='structure'then d.sounds.arrived=nil end
   applyWeaponAudio(key,d,cp,clips)
  end
 end
end
return M
