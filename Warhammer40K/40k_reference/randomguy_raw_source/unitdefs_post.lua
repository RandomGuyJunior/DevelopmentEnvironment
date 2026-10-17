-- Authored roster overlay; pinned BAR preprocessing is an ignored dependency.
-- Native post already ran before the isolated authoring overlay.
-- STOCK_TRANSPORT_REFERENCE_UNCHANGED_POST_BOUNDARY
-- Default-off isolated reference retains the exact pinned BAR preprocessing.
local stockReferenceOptions=Spring and Spring.GetModOptions and Spring.GetModOptions()or{}
if tostring(stockReferenceOptions.prototype_stock_transport_reference)=='1'then
 assert(stockReferenceOptions.prototype_diagnostic=='normal','Stock reference requires explicit normal mode')
 local function off(v)return v==false or v==0 or v=='0'end
 assert(off(stockReferenceOptions.prototype_development_playtest)and off(stockReferenceOptions.prototype_source_progression),'Stock reference must disable authored gameplay overlays')
 return
end
-- Capture unchanged native costs/shield before the Ork presentation replaces it.
local commanderShield=VFS.Include('40k_configs/ork_commander_shield.lua')
local commanderShieldReference=commanderShield.Capture(UnitDefs.corcom,UnitDefs.corgate)
local nativeFactoryPilots=VFS.Include('40k_configs/native_factory_pilots.lua')
local function copyNative(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copyNative(x)end;return r end
local nativeFactoryContracts=nativeFactoryPilots.Capture(UnitDefs,copyNative)
local nativeDomains=VFS.Include('40k_configs/air_naval_domain_candidate.lua')
local nativeDomainContracts=nativeDomains.Capture(UnitDefs)
local airCombatExpansion=VFS.Include('40k_configs/air_domain_combat_expansion.lua')
local nativeAirCombatContracts
local navalCombatExpansion=VFS.Include('40k_configs/naval_domain_combat_expansion.lua')
local nativeNavalCombatContracts
local waterUtilityExpansion=VFS.Include('40k_configs/water_domain_utility_expansion.lua')
local nativeWaterUtilityContracts
local nativeAirCombatOptions=Spring and Spring.GetModOptions and Spring.GetModOptions()or{}
if VFS.Include('40k_configs/four_faction_playtest.lua').Enabled(nativeAirCombatOptions)then
 nativeAirCombatContracts=airCombatExpansion.Capture(UnitDefs)
 nativeNavalCombatContracts=navalCombatExpansion.Capture(UnitDefs)
 nativeWaterUtilityContracts=waterUtilityExpansion.Capture(UnitDefs)
end
local factoryRosters={
 armlab={"armck","imp_guardsman","imp_marine"},
 armalab={"armack","imp_guardsman","imp_marine"},
 armvp={"armcv","imp_russ"},
 armavp={"armacv","imp_russ"},
 corlab={"corck","ork_boy","ork_meganob"},
 coralab={"corack","ork_boy","ork_meganob"},
 corvp={"corcv","ork_killa_kan"},
 coravp={"coracv","ork_killa_kan"},
}
local factoryNames={
 armlab="Imperium Barracks",armalab="Advanced Imperium Barracks",
 armvp="Imperium Tank Factory",armavp="Advanced Imperium Tank Factory",
 corlab="Ork Barracks",coralab="Advanced Ork Barracks",
 corvp="Ork Walker Factory",coravp="Advanced Ork Walker Factory",
}
local function addOption(ud,name)
 if not UnitDefs[name] then return end
 for _,option in ipairs(ud.buildoptions) do if option==name then return end end
 ud.buildoptions[#ud.buildoptions+1]=name
end
for name,ud in pairs(UnitDefs) do
 local prefix=name:sub(1,3)
 if ud.buildoptions and (prefix=="arm" or prefix=="cor") then
  local options={}
  for _,option in ipairs(ud.buildoptions) do
   local target=UnitDefs[option]
   if target and (target.builder or (not target.canmove and (not target.weapons or #target.weapons==0))) then
    options[#options+1]=option
   end
  end
  ud.buildoptions=options
  -- Mobile native constructors and commanders retain both required build paths.
  -- Native factories can declare canmove, so identify them by yardmap too.
  if ud.builder and ud.canmove and not ud.yardmap and not factoryRosters[name] then
   addOption(ud,prefix.."lab")
   addOption(ud,prefix.."vp")
  end
 end
end
for name,roster in pairs(factoryRosters) do
 local ud=UnitDefs[name]
 if ud then
  ud.buildoptions={}
  for _,option in ipairs(roster) do if UnitDefs[option] then ud.buildoptions[#ud.buildoptions+1]=option end end
  ud.name=factoryNames[name]
  ud.description=(name:find("lab") and "Infantry production" or name:sub(1,3)=="arm" and "Tank production" or "Walker production")
  ud.customparams=ud.customparams or {}
  ud.customparams.prototype40k_factory=name:find("lab") and "infantry" or "heavy"
 end
end

-- Expanded diagnostic mode exposes only actual exported assets. Individual
-- native acceptance markers gate the Imperium additions in normal play.
local diagnostic=Spring and Spring.GetModOptions and Spring.GetModOptions().prototype_diagnostic
if diagnostic=="roster" then
 for _,ud in pairs(UnitDefs)do
  local cp=ud.customparams
  if cp and cp.prototype40k and cp.rosterrole then cp.diagnostic="roster" end
 end
end

local sourceOptions=Spring and Spring.GetModOptions and Spring.GetModOptions() or {}
local sourceProduction=VFS.Include('40k_configs/source_production.lua')
local originalAliases={}
if sourceProduction.Enabled(sourceOptions) then
 local function clone(v)if type(v)~='table'then return v end;local out={};for k,x in pairs(v)do out[k]=clone(x)end;return out end
 for _,key in ipairs(sourceProduction.BlockedAliases())do if UnitDefs[key]then originalAliases[key]=clone(UnitDefs[key])end end
end
local vitalRoles=VFS.Include("40k_configs/vital_roles.lua")
local vitalReport=vitalRoles.Apply(UnitDefs)
if Spring and Spring.Echo then Spring.Echo("40K VITAL GRAPH",#vitalReport.replaced,"replaced",#vitalReport.blocked,"blocked",vitalReport.diagnostic and "diagnostic" or "accepted") end
local vitalAdditions=VFS.Include("40k_configs/vital_addition_graph.lua")
vitalAdditions.Apply(UnitDefs)
local sourceReport=sourceProduction.Apply(UnitDefs,sourceOptions,originalAliases)
if sourceReport.enabled and Spring and Spring.Echo then Spring.Echo('40K SOURCE PROGRESSION',sourceReport.exposed,sourceReport.review and 'review_not_accepted' or 'accepted')end
-- Full genuine Ork HQ only in explicit source review; preserve paid source menus.
VFS.Include('40k_configs/40k_ork_hq_registry.lua').ApplyRaw(UnitDefs,sourceOptions)
-- Genuine Marine producers and exact variant requirements follow source menu rewrites.
-- Guard Enginseers/native constructors are a declared combined-Imperium builder
-- adaptation, never presented as a converted Marine Servitor.
if sourceReport.enabled then
 local marine=VFS.Include('40k_configs/marine_infrastructure_candidates.lua')
 local function sourceReady(key)
  local d=UnitDefs[key];local cp=d and d.customparams or{}
  return d~=nil and tostring(cp.prototype40k)=='1'and d.objectname~=nil and cp.animsource~=nil
   and VFS.FileExists('objects3d/'..d.objectname)
   and VFS.FileExists('scripts/generated/'..cp.animsource..'_anim.lua')
   and (sourceReport.review or VFS.Include('40k_configs/development_playtest.lua').Allowed(key,sourceOptions) or VFS.FileExists('40k_configs/validated/'..key..'.lua'))
 end
 marine.ApplyMenus(UnitDefs,sourceReady,{'armcom','armck','armcv','armack','armacv','imp_enginseer'})
 VFS.Include('40k_configs/primary_variant_progression.lua').Apply(UnitDefs,sourceReady,marine.Bindings)
 VFS.Include('40k_configs/40k_tactical_bike_registry.lua').ApplyRaw(UnitDefs,sourceOptions,sourceReady)
end
local mixedV2Report=VFS.Include('40k_configs/mixed_v2_adapter.lua').Apply(UnitDefs,sourceOptions)
if mixedV2Report.enabled then
 assert(mixedV2Report.applied,'40K mixed v2 refused: '..table.concat(mixedV2Report.blockers or {},'; '))
 if Spring and Spring.Echo then Spring.Echo('40K MIXED V2 GRAPH',mixedV2Report.exposed,'diagnostic_unpaid_seeds_only')end
end
-- Default-off source commander presentation review; no launcher option enables it.
local fourFaction=VFS.Include('40k_configs/four_faction_playtest.lua')
local commanderReviewOptions=sourceOptions
if fourFaction.Enabled(sourceOptions)then
 commanderReviewOptions={};for k,v in pairs(sourceOptions)do commanderReviewOptions[k]=v end
 -- The split owns both commander identities; the historical review must never
 -- replace the Guard with a Marine before the separate Marine copy is made.
 commanderReviewOptions.prototype_commander_presentation_review=false
end
local commanderReview=VFS.Include('40k_configs/commander_presentation_review_hook.lua').Apply(UnitDefs,commanderReviewOptions,VFS)
assert(commanderReview.applied,'Commander presentation review refused: '..tostring(commanderReview.reason))
local splitReport=fourFaction.Apply(UnitDefs,sourceOptions,VFS)
if fourFaction.Enabled(sourceOptions)then
 VFS.Include('40k_configs/ork_v13_ground_constructors.lua').Apply(UnitDefs,VFS)
 local servoReport=VFS.Include('40k_configs/servo_skull_presentation.lua').Apply(UnitDefs,VFS)
 assert(servoReport.applied,'Imperial servo presentation refused: '..tostring(servoReport.reason))
end
if splitReport.enabled and Spring and Spring.Echo then Spring.Echo('40K FOUR FACTIONS','hybrid_paid_production')end
VFS.Include('40k_configs/native_sensor_roles.lua').Apply(UnitDefs,sourceOptions,fourFaction)
local uiMetadata=VFS.Include("40k_configs/ui_unit_metadata.lua")
uiMetadata.Apply(UnitDefs)
VFS.Include("40k_configs/weapon_families.lua")
VFS.Include('40k_configs/40k_ork_hq_registry.lua').FinalizeMounts(UnitDefs,sourceOptions)

-- Cosmetic source families require actual marked exports; no acceptance grants.
local function sourceFxReady(key)
 local d=UnitDefs[key];local cp=d and d.customparams or {}
 return tostring(cp.prototype40k)=='1' and d.objectname~=nil and cp.animsource~=nil
  and VFS.FileExists('objects3d/'..d.objectname)
  and VFS.FileExists('scripts/generated/'..cp.animsource..'_anim.lua')
end
VFS.Include('40k_configs/necron_weapon_fx.lua').Apply(UnitDefs,sourceFxReady)
VFS.Include('40k_configs/imperial_weapon_fx.lua').Apply(UnitDefs)


-- Apply after every accepted native donor copy and other UnitDef overlays.
VFS.Include("40k_configs/terrain_orientation.lua").Apply(UnitDefs)

-- Source defensive stages share the existing native resource and health owners.
local fixedExtractorPilot=VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(sourceOptions.prototype_extractor_fixed_tier_pilot)
assert(not fixedExtractorPilot or fourFaction.Enabled(sourceOptions),'Fixed extractor pilot requires ordinary four-faction source progression')
if fourFaction.Enabled(sourceOptions)then
 if fixedExtractorPilot then
  local fixed=VFS.Include('40k_configs/extractor_fixed_tier_candidate.lua')
  fixed.Apply(UnitDefs,VFS)
  fixed.ApplyMenus(UnitDefs,VFS.Include('40k_configs/four_faction_constructor_progression.lua'))
 else
  VFS.Include('40k_configs/listening_post_definitions.lua').Apply(UnitDefs,VFS,VFS.Include('40k_configs/listening_post_profiles.lua'),VFS.Include('40k_configs/listening_post_bindings.lua'))
 end
end

VFS.Include('40k_configs/audio_profiles.lua').Apply(UnitDefs)
VFS.Include('40k_configs/ork_transport_envelope_movement.lua').ApplyDefinitions(UnitDefs,sourceOptions)
VFS.Include('40k_configs/ork_ground_release_review.lua').Apply(UnitDefs,sourceOptions)
VFS.Include('40k_configs/ork_native_unload_clearance_review.lua').Apply(UnitDefs,sourceOptions)

-- Hammer actor and target lifting retired by user design, 8 October 2026.

-- Explicit bounded Wraith phase/base-defense metadata; normal definitions unchanged.
VFS.Include('40k_configs/necron_wraith_review_definitions.lua').Apply(UnitDefs,sourceOptions)

-- Explicit Spyder corpse identity review; ordinary definitions stay unchanged.
VFS.Include('40k_configs/necron_spyder_review_definitions.lua').Apply(UnitDefs,sourceOptions)

VFS.Include('40k_configs/imp_hq_native_admission_witness.lua').Apply(UnitDefs,sourceOptions)

local primaryPaidReview=VFS.Include('40k_configs/ork_primary_paid_review.lua')
if primaryPaidReview.Enabled(sourceOptions)then
 local r=primaryPaidReview.Apply(UnitDefs,sourceOptions,VFS.Include('scripts/generated/ork_primary_role_contract.lua'),VFS.Include('scripts/generated/ork_source_consumer_bundle_evidence.lua'),VFS.Include('scripts/generated/ork_aircraft_source_facts.lua'))
 assert(r.applied,'Whole five paid Ork roles refused: '..tostring(r.reason)..':'..tostring(r.key))
 local b=VFS.Include('40k_configs/ork_source_baseline_review.lua').Apply(UnitDefs,sourceOptions)
 assert(b.applied,'Whole fourteen source baselines refused: '..tostring(b.reason)..':'..tostring(b.key))
end
VFS.Include('40k_configs/ork_source_bundle_metadata.lua').Apply(UnitDefs,sourceOptions)
if VFS.Include('40k_configs/ork_source_consumers_native.lua').Enabled(sourceOptions)then
 local p=VFS.Include('scripts/generated/ork_source_producer_work_profiles.lua')
 local r=VFS.Include('40k_configs/ork_source_producer_costs.lua').ApplyDefinitions(UnitDefs,sourceOptions,p)
 assert(r.applied,'Genuine Ork producer product definitions refused: '..tostring(r.reason)..':'..tostring(r.key))
end

if primaryPaidReview.Enabled(sourceOptions)and VFS.FileExists('scripts/generated/ork_nukklear_tech_facts.lua')then
 local r,why=VFS.Include('40k_configs/ork_nukklear_tech_review.lua').ApplyMenu(UnitDefs,VFS.Include('scripts/generated/ork_nukklear_tech_facts.lua'),sourceOptions)
 assert(r and r.applied,'Exact source Nukklear producer menu refused: '..tostring(why))
end
VFS.Include('40k_configs/ork_primary_visual_review.lua').Apply(UnitDefs,sourceOptions)

-- Final policy prevents historical review flags from resurrecting retired content.
VFS.Include('40k_configs/ork_retired_content_policy.lua').FilterDefinitions(UnitDefs)
if UnitDefs.ork_dakka_stompa then
 local d,why=VFS.Include('40k_configs/ork_stompa_design.lua').Apply(UnitDefs.ork_dakka_stompa)
 assert(d,'Retained Stompa design refused: '..tostring(why));UnitDefs.ork_dakka_stompa=d
end

-- Apply AFTER final ork_stompa_design baseline. Explicit future review only;
-- the first playable checkpoint keeps the existing arm unless root enables it.
if VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(sourceOptions.prototype_stompa_multigun_review)and UnitDefs.ork_dakka_stompa then
 assert(VFS.FileExists('objects3d/ork_dakka_stompa_multigun.glb')and VFS.FileExists('scripts/generated/ork_stompa_multigun_facts.lua'),'Four gun source marker assets missing')
 local d,why=VFS.Include('40k_configs/ork_stompa_multigun_design.lua').Apply(UnitDefs.ork_dakka_stompa,VFS.Include('scripts/generated/ork_stompa_multigun_facts.lua'))
 assert(d,'Four gun Stompa refused: '..tostring(why));UnitDefs.ork_dakka_stompa=d
end

-- After both retained design modules; explicit unpaid diagnostic only.
local fw=VFS.Include('40k_configs/stompa_weapon_fixture.lua')
if fw.Enabled(sourceOptions)then
 assert(UnitDefs.ork_dakka_stompa and UnitDefs.ork_deff_dread,'Actual diagnostic actors missing')
 local cp=UnitDefs.ork_dakka_stompa.customparams
 assert(cp.source_stompa_arm_status=='dakka_four_guns_v1','Full real muzzle design required')
 cp.diagnostic='roster'
end

-- Exact paired model/bank/wreck only in the existing unpaid Stompa fixture.
local dakkaReference=VFS.Include('40k_configs/ork_dakka_reference_diagnostic.lua')
if dakkaReference.Enabled(sourceOptions,VFS)then
 dakkaReference.ApplyUnits(UnitDefs,sourceOptions,VFS,VFS.Include('40k_configs/ork_dakka_jugref_facts.lua'))
end

-- Source building envelopes include all faction aliases and preserve yard centres.
VFS.Include('40k_configs/building_placement_policy.lua').Apply(UnitDefs)
if fixedExtractorPilot then
 VFS.Include('40k_configs/extractor_fixed_tier_yards.lua').Apply(UnitDefs,VFS.Include('40k_configs/extractor_fixed_tier_candidate.lua').Families)
end

-- Normal play uses measured source gait after all faction aliases exist.
VFS.Include('40k_configs/natural_locomotion.lua').Apply(UnitDefs,sourceOptions,VFS.Include('40k_configs/development_playtest.lua'),VFS.Include('40k_configs/natural_locomotion_tuning.lua'))

-- Native weapon damage tables remain untouched by a bespoke Armour/AP pass.
if fourFaction.Enabled(sourceOptions)then
 nativeFactoryPilots.Apply(UnitDefs,nativeFactoryContracts,VFS.FileExists,sourceOptions)
 VFS.Include('40k_configs/ork_squad_rokkit_role.lua').Preflight(UnitDefs,VFS)
 local flamer=VFS.Include('40k_configs/guard_squad_flamer_integration.lua').Prepare(UnitDefs,VFS,VFS.Include('40k_configs/squad_profiles.lua'),sourceOptions,fourFaction.Enabled(sourceOptions),VFS.Include('40k_configs/guard_squad_flamer_role.lua'))
 if flamer.enabled then UnitDefs[flamer.source]=flamer.definition end
 VFS.Include('40k_configs/squad_definitions.lua').Apply(UnitDefs,VFS,VFS.Include('40k_configs/active_squad_profiles.lua'))
 VFS.Include('40k_configs/wartrukk_squad_candidate.lua').Apply(UnitDefs,VFS,VFS.Include('40k_configs/active_squad_profiles.lua'),sourceOptions)
 if VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(sourceOptions.prototype_squad_transport_pilot)then
  VFS.Include('40k_configs/squad_carrier_candidate.lua').Apply(UnitDefs,VFS,VFS.Include('40k_configs/active_squad_profiles.lua'))
 end
 nativeDomains.Apply(UnitDefs,nativeDomainContracts,function(key)
  local d=UnitDefs[key];local cp=d and d.customparams or{}
  return d and ((cp.prototype40k_native_factory_pilot==1 and VFS.FileExists('objects3d/'..d.objectname)and VFS.FileExists('scripts/'..d.script))or sourceFxReady(key))
 end,VFS.Include('scripts/generated/air_naval_theme_facts.lua'))
 VFS.Include('40k_configs/air_combat_expansion_registration.lua').Apply(UnitDefs,nativeAirCombatContracts,nativeDomains,VFS,airCombatExpansion)
 VFS.Include('40k_configs/water_expansions_registration.lua').Apply('naval',UnitDefs,nativeNavalCombatContracts,nativeDomains,VFS,navalCombatExpansion)
 if VFS.FileExists('scripts/generated/water_economy_theme_facts.lua')then
  local theme=VFS.Include('scripts/generated/water_economy_theme_facts.lua')
  nativeDomains.ApplyWaterEconomy(UnitDefs,nativeDomainContracts,function(key)
   return theme[key]and VFS.FileExists('objects3d/'..theme[key].objectname)
  end,theme)
 end
 VFS.Include('40k_configs/water_expansions_registration.lua').Apply('utility',UnitDefs,nativeWaterUtilityContracts,nativeDomains,VFS,waterUtilityExpansion)
 if VFS.FileExists('scripts/generated/fighta_air_domain_facts.lua')then
  local facts=VFS.Include('scripts/generated/fighta_air_domain_facts.lua')
  local closure={'objects3d/ork_fighta_bomba.glb','unittextures/ork_fighta_bomba_tex1.png','unittextures/ork_fighta_bomba_tex2.png','unitpics/40k_ork_fighta_bomba.png','scripts/generated/ork_fighta_bomba_anim.lua'}
  local report,why=VFS.Include('40k_configs/fighta_air_domain_candidate.lua').Attach(UnitDefs,nativeDomains,facts,VFS.Include('40k_configs/ork_aircraft_native_definitions.lua'),function(key)
   for _,path in ipairs(closure)do if not VFS.FileExists(path)then return false end end;return key=='ork_fighta_bomba'
  end)
  assert(report,'Genuine Fighta domain refused: '..tostring(why))
  -- Newly registered actor receives the same scoped presentation passes.
  local aircraft={ork_fighta_bomba=UnitDefs.ork_fighta_bomba}
  uiMetadata.Apply(aircraft)
  VFS.Include('40k_configs/audio_profiles.lua').Apply(aircraft)
  VFS.Include('40k_configs/terrain_orientation.lua').Apply(aircraft)
 end
 if VFS.FileExists('40k_configs/ork_ranged_variant_facts.lua')then
  local variants=VFS.Include('40k_configs/ork_ranged_walker_variants.lua').Apply(UnitDefs,VFS.Include('40k_configs/ork_ranged_variant_facts.lua'),function(key)
   return VFS.FileExists('objects3d/'..key..'.glb')and VFS.FileExists('scripts/generated/'..key..'_anim.lua')and VFS.FileExists('unittextures/'..key..'_tex1.png')and VFS.FileExists('unittextures/'..key..'_tex2.png')
  end)
  assert(#variants.definitions==4,'Complete genuine ranged walker package required')
  -- These weapons are registered after the earlier global audio pass.
  -- Apply native weapon sounds only; preserve inherited actor voice profiles.
  local rangedAudio={};for _,key in ipairs(variants.definitions)do rangedAudio[key]=UnitDefs[key]end
  VFS.Include('40k_configs/audio_profiles.lua').ApplyWeaponAudio(rangedAudio)
  VFS.Include('40k_configs/ork_ranged_weapon_fixture.lua').Apply(UnitDefs,sourceOptions)
 end
end

-- Native generator salvage remains opt-in until the paid appearance/reclaim review.
local scrap=VFS.Include('40k_configs/ordinary_generator_scrap.lua')
local scrapReport=scrap.Apply(UnitDefs,sourceOptions,VFS)
assert(not scrapReport.enabled or scrapReport.applied,'Generator scrap refused: '..tostring(scrapReport.reason))

-- Atomic paired geometry pilot follows all real-member and domain definitions.
local scalePilot=VFS.Include('40k_configs/scale_pilot.lua')
if scalePilot.Enabled(sourceOptions)then
 local closure=VFS.Include('40k_configs/scale_pilot_ceg_closure.lua').New(VFS,scalePilot)
 closure.ValidateActors(UnitDefs)
 scalePilot.ApplyUnits(UnitDefs,sourceOptions,VFS,VFS.Include('40k_configs/natural_locomotion_tuning.lua'),
  {bank='scale_animation_bank_v1',features=1,effects=1,effectReady=closure.Ready})
 VFS.Include('40k_configs/terminator_scale_pair.lua').FinalizeUnits(UnitDefs,sourceOptions,scalePilot)
end

-- Native local feature binding owns the final paid vehicle salvage exactly once.
local russWreck=VFS.Include('40k_configs/russ_wreck.lua')
if russWreck.Enabled(sourceOptions)then
 assert(fourFaction.Enabled(sourceOptions),'Russ wreck pilot requires ordinary source progression')
 local d=assert(UnitDefs.imp_russ,'Missing ordinary Russ')
 local factor=tonumber((d.customparams or{}).scale_pilot_factor)or 1
 local ok,why=russWreck.AttachLocalFeature(UnitDefs,sourceOptions,function(model)
  for _,path in ipairs({'objects3d/'..model,'objects3d/'..d.objectname,'scripts/'..d.script,
   'unittextures/leman_russ_tex1.png','unittextures/leman_russ_tex2.png'})do
   if not VFS.FileExists(path)then return false end
  end
  return true
 end,factor)
 assert(ok,'Russ native wreck refused: '..tostring(why))
end


-- Scoped matched metal-panel material pilot after final presentation passes.
VFS.Include('40k_configs/guard_metal_lamp_isolation.lua').Apply(UnitDefs,sourceOptions,VFS,fixedExtractorPilot)

-- Default-off scoped Guard energy material pilot.
VFS.Include('40k_configs/guard_energy_blue_pilot.lua').Apply(UnitDefs,sourceOptions,VFS)


-- Final v1.3 availability pass must follow every legacy menu/domain adapter.
if fourFaction.Enabled(sourceOptions)then
 if VFS.FileExists('40k_configs/ork_v13_airfield_geometry.lua')then
  local geometry=VFS.Include('40k_configs/ork_v13_airfield_geometry.lua')
  for key,g in pairs(geometry)do
   for _,p in ipairs({'objects3d/'..g.objectname,'unittextures/'..key..'_tex1.png','unittextures/'..key..'_tex2.png','scripts/generated/'..key..'_anim.lua','scripts/40k_ork_static_factory.lua'})do
    assert(VFS.FileExists(p),'Ork airfield closure absent: '..p)
   end
  end
  for _,p in ipairs({'objects3d/twisted_metal.glb','unittextures/twisted_metal_tex1.png','unittextures/twisted_metal_tex2.png'})do
   assert(VFS.FileExists(p),'Ork airfield genuine scrap closure absent: '..p)
  end
  VFS.Include('40k_configs/ork_v13_airfields.lua').Apply(UnitDefs,geometry)
  VFS.Include('40k_configs/ork_v13_air3.lua').Apply(UnitDefs,geometry)
 end
 if VFS.FileExists('40k_configs/ork_v13_gunship_geometry.lua')then
  local gunshipFacts=VFS.Include('40k_configs/ork_v13_gunship_geometry.lua')
  for key,g in pairs(gunshipFacts)do
   for _,p in ipairs({'objects3d/'..g.objectname,'objects3d/'..g.objectname..'.lua','unittextures/'..key..'_tex1.png','unittextures/'..key..'_tex2.png','unitpics/40k_'..key..'.png','scripts/40k_ork_gunship.lua'})do
    assert(VFS.FileExists(p),'Exact Gunship closure absent: '..p)
   end
  end
  VFS.Include('40k_configs/ork_v13_gunship.lua').Apply(UnitDefs,gunshipFacts)
 end
 local groundFacts={}
 if VFS.FileExists('40k_configs/ork_v13_ground_factory_facts.lua')then groundFacts=VFS.Include('40k_configs/ork_v13_ground_factory_facts.lua')end
 local groundReport=VFS.Include('40k_configs/ork_v13_ground_factories.lua').Apply(UnitDefs,groundFacts,VFS)
 if Spring and Spring.Echo then for _,why in ipairs(groundReport.missing)do Spring.Echo('40K ORK GROUND FACTORY PENDING',why)end end
 local airConstructors=VFS.Include('40k_configs/ork_v13_air_constructors.lua').Apply(UnitDefs,VFS)
 if Spring and Spring.Echo then for _,why in ipairs(airConstructors.pending)do Spring.Echo('40K AIR CONSTRUCTOR PENDING',why)end end
 -- Insert immediately after the existing ork_v13_air_constructors Apply/report,
 -- before fixed economy/artillery/generator passes and sole final faction graph.
 for _,key in ipairs({'ork_mek_kopta','ork_big_mek_kopta'})do
  local factsPath='40k_configs/'..key..'_source_facts.lua'
  if VFS.FileExists(factsPath)then
   local presentation=VFS.Include('40k_configs/'..key..'_source_presentation.lua')
   local facts=VFS.Include(factsPath)
   local scope=presentation.ReviewEnabled(Spring.GetModOptions()or{})and'isolated_root_native_presentation_review'or nil
   local report=presentation.Apply(UnitDefs,VFS,facts,scope)
   if Spring and Spring.Echo then
    for _,why in ipairs(report.pending)do Spring.Echo('40K SMERTOLET PRESENTATION PENDING',key,why)end
   end
  end
 end
 if fixedExtractorPilot then
  local economyReady={}
  if VFS.FileExists('scripts/generated/ork_v13_economy_ready.lua')then economyReady=VFS.Include('scripts/generated/ork_v13_economy_ready.lua')end
  VFS.Include('40k_configs/ork_v13_economy.lua').Apply(UnitDefs,VFS,economyReady)
 end
 local artilleryReady={}
 if VFS.FileExists('scripts/generated/ork_v13_artillery_ready.lua')then artilleryReady=VFS.Include('scripts/generated/ork_v13_artillery_ready.lua')end
 VFS.Include('40k_configs/ork_v13_artillery.lua').Apply(UnitDefs,VFS,artilleryReady)
 local generatorReady={}
 if VFS.FileExists('scripts/generated/generator_visual_scale_ready.lua')then generatorReady=VFS.Include('scripts/generated/generator_visual_scale_ready.lua')end
 local generatorReport=VFS.Include('40k_configs/generator_visual_scale.lua').Apply(UnitDefs,VFS,generatorReady)
 if Spring and Spring.Echo then for key,why in pairs(generatorReport.pending)do Spring.Echo('40K GENERATOR SCALE PENDING',key,why)end end
 local report=VFS.Include('40k_configs/ork_v13_build_graph.lua').Apply(UnitDefs,sourceOptions,VFS)
 if not report.active and Spring and Spring.Echo then Spring.Echo('40K ORK V1.3 GRAPH HELD',table.concat(report.blockers,','))end
 VFS.Include('40k_configs/ork_v13_audio.lua').Apply(UnitDefs)
end

-- Final metadata-only salvage policy; preserve native costs, chains and reclaim.
if fourFaction.Enabled(sourceOptions)then VFS.Include('40k_configs/persistent_salvage.lua').ApplyUnitWrecks(UnitDefs)end

-- Original BAR comparisons are distinct, explicit diagnostic/capture aliases.
-- Register after faction overlays so the source model identity remains intact.
local originalGenerators=VFS.Include('40k_configs/generator_original_references.lua')
if originalGenerators.Enabled(sourceOptions)then
 originalGenerators.Apply(UnitDefs,VFS,sourceOptions,VFS.Include('scripts/generated/generator_original_reference_ready.lua'))
end

-- Final T1 Banner/Hut minimum tiles; preserve every other model/yard owner.
VFS.Include('40k_configs/ork_t1_structure_footprints.lua').Apply(UnitDefs,VFS)


-- Final cosmetic impact completion after all roster/presentation adapters.
VFS.Include('40k_configs/weapon_impact_completion.lua').Apply(UnitDefs,VFS.Include('40k_configs/ork_v13_build_graph.lua'))
if fourFaction.Enabled(sourceOptions)then commanderShield.Apply(UnitDefs,commanderShieldReference)end
-- The replaced native model's seasonal hat count is not part of these GLBs.
VFS.Include('40k_configs/native_hat_piece_guard.lua').ApplyRaw(UnitDefs)

-- Release-only commander discovery uses RandomGuy Hosting's startunit customparam.
-- Additive commander markers are set only at final export.
