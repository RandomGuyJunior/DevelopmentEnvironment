-- Explicit paid Marine/Bike review composition, never native acceptance.
local M={Command=92000,CombatEvidenceFrames=90}
local factsPath='40k_configs/40k_marine_population_facts.lua'
local squads={imp_scout='attrib/sbps/races/space_marines/space_marine_squad_scout.lua',imp_marine='attrib/sbps/races/space_marines/space_marine_squad_tactical.lua',imp_tactical_bike='attrib/sbps/races/space_marines/space_marine_squad_tactical_bike.lua'}
local baseline={imp_scout={object='imp_scout.glb',script='40k_roster.lua',animation='imp_scout',metal=30,energy=150,work=300},imp_marine={object='space_marine.glb',script='40k_infantry.lua',animation='space_marine',metal=48,energy=240,work=500}}
function M.Enabled(options)
 return options.prototype_diagnostic=='expandedproduction'and VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(options.prototype_source_progression)and options.prototype_source_acceptance=='imperium'
end
function M.Definitions(options)
 if not M.Enabled(options)then return{}end
 local F=VFS.Include('40k_configs/tactical_bike_definition_facts.lua')
 local D=VFS.Include('40k_configs/tactical_bike_candidates.lua').Definitions(F,options,{rangeScale=12,speedScale=1,meleeDiagnosticRange=24,movementClass='TANK3'})
 local d=D.imp_tactical_bike
 if d then d.customparams.prototype40k_source_progression=1;d.customparams.source_registry_review=1 end
 return D
end
function M.Graph()
 return{Requires={imp_tactical_bike={buildings={'imp_marine_barracks'},production_method='bike_native_adapter_unattached'}},Research={}}
end
function M.ApplyRaw(defs,options,ready)
 if not M.Enabled(options)then return false end
 local d=defs.imp_tactical_bike;local parent=defs.imp_marine_barracks
 if not d or not parent or not parent.builder or not ready('imp_tactical_bike')or not ready('imp_marine_barracks')then return false end
 parent.buildoptions=parent.buildoptions or{}
 for _,key in ipairs(parent.buildoptions)do if key=='imp_tactical_bike'then return true end end
 parent.buildoptions[#parent.buildoptions+1]='imp_tactical_bike';return true
end
function M.AttachInitialGate(C,S,defs,graph,Q)
 if not Q or not C.sourceMarineLifecycle or not Q.Ready()or not Q.WholeTransactionReady()then return false end
 local requirement=C.requirements.imp_tactical_bike
 assert(graph and requirement==graph.Requires.imp_tactical_bike and requirement.production_method=='bike_native_adapter_unattached','Actual closed Bike graph required')
 local profiles=VFS.Include('40k_configs/primary_variant_progression.lua').SourceProfiles
 local producer='attrib/ebps/races/space_marines/structures/space_marine_barracks.lua'
 requirement.production_method='factory'
 local old=C.CanBuild
 function C.CanBuild(team,def,builder,initial)
  local d=defs[def]
  if d and d.name=='imp_tactical_bike'then
   if initial or not builder or not Q.Ready()or not Q.WholeTransactionReady()then return false end
   local u=C.units[builder];local cp=u and(defs[u.def].customParams or{})
   if not u or not u.finished or u.team~=team or S.GetUnitTeam(builder)~=team or not cp or cp.source_entity~=producer then return false end
   for key,profile in pairs(profiles)do
    if profile.source:lower()==Q.forbiddenResearchSource:lower()and C.HasResearch(team,key)then return false end
   end
  end
  return old(team,def,builder,initial)
 end
 return true
end
function M.NativeReviewConfig(defs,options)
 if not M.Enabled(options)or not VFS.FileExists(factsPath)then return nil,'registry_contract_line_2' end
 local F=VFS.Include(factsPath);local byName={}
 for id,d in pairs(defs)do byName[d.name]={id=id,def=d}end
 local policy={descriptors={},sourceEntityMappings={},initialCostAdaptations={},outsideDefinitions={},sourceProgressionReview=true,memberRepresentation='one_native_actor_per_source_squad',arithmetic='additive_then_match_multiply'}
 for name,path in pairs(squads)do
  local row=byName[name];local p=F.squads[path];if not row or not p then return nil,'registry_contract_line_7' end
  local d,cp=row.def,row.def.customParams or{}
  if tostring(cp.prototype40k_source_progression)~='1'then return nil,'registry_contract_line_9' end
  policy.descriptors[row.id]={squad=path,source_sha256=p.sha256}
  if baseline[name]then
   local b=baseline[name]
   if cp.animsource~=b.animation or d.metalCost~=b.metal or d.energyCost~=b.energy or d.buildTime~=b.work then return nil,'registry_contract_line_13' end
   if cp.source_entity and cp.source_entity~=p.entity then return nil,'registry_contract_line_14' end
   policy.sourceEntityMappings[row.id]={entity=p.entity,sha256=p.entity_sha256,gate='source_progression_review'}
   policy.initialCostAdaptations[row.id]={kind='retained_native_unitdef_price',source_squad_sha256=p.sha256,reason='Reviewed native prototype retains original actor price/work; one physical actor represents the entire source squad population budget'}
  elseif cp.source_entity~=p.entity or cp.source_squad~=path or d.metalCost~=170 or d.energyCost~=30 or d.buildTime~=900 then return nil,'registry_contract_line_17' end
 end
 -- Narrow borrowed Guard infrastructure: no blanket Imperium/native exclusion.
 for _,name in ipairs({'imp_field_commander','imp_mex','imp_generator','imp_hq'})do
  local row=byName[name];if not row then return nil,'registry_contract_line_21' end
  local cp=row.def.customParams or{}
  local animation=cp.animsource or cp.prototype40k_donor
  if cp.faction~='Imperium'or tostring(cp.prototype40k)~='1'or not animation then return nil,'registry_contract_line_24' end
  if name=='imp_field_commander'then
   if cp.prototype40k_vital~='commander'or (cp.prototype40k_donor~='imp_commissar'and not VFS.Include('40k_configs/commander_paid_registry_alternative.lua').Force(row.def,row.id,UnitDefNames,defs))then return nil,'registry_contract_line_26' end
  elseif animation~=name then return nil,'registry_contract_line_27' end
  policy.outsideDefinitions[row.id]={definition_name=row.def.name,reason='Explicit borrowed Guard commander/economy for combined-Imperium paid Marine review'}
 end
 for _,name in ipairs({'imp_marine_hq','imp_marine_barracks','imp_marine_armoury'})do
  local row=byName[name];local cp=row and row.def.customParams or{}
  if not row or not F.structures[cp.source_entity]or row.def.isBuilding~=true then return nil,'registry_contract_line_32' end
 end
 for _,value in pairs(CMD or{})do if value==M.Command then return nil,'registry_contract_line_34' end end
 local function ready()return true end -- Static descriptor contract only; live ledger refuses unclassified bodies.
 return{Ready=ready,WholeTransactionReady=ready,PopulationFacts=F,populationPolicy=policy,command=M.Command,combatEvidenceFrames=M.CombatEvidenceFrames,
  combatEvidenceAdaptation='Three-second native damage evidence window; proprietary source combat-release duration unverified',
  forbiddenResearchSource='attrib/research/races/space_marines/UA_marine_chapter_lotd_research.lua',graph=M.Graph()}
end
return M
