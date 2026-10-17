function gadget:GetInfo()
 return {name="40K paid native technology",desc="Stock command research and source build requirements",author="Local project",layer=50,enabled=true}
end
if not gadgetHandler:IsSyncedCode()then return false end
local options=Spring.GetModOptions()or{}
-- Source-graph review opt-in. Baseline ordinary matches remain unchanged until
-- coordinator enables acceptance-backed source progression for normal play.
if not VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(options.prototype_source_progression)then return false end
local mode=options.prototype_diagnostic
local mixedAdapter=VFS.Include('40k_configs/mixed_v2_adapter.lua')
local mixedEnabled=mixedAdapter.Enabled(options)
if mode and mode~="normal" and mode~="roster" and mode~="expandedproduction" and not mixedEnabled then return false end
local sourceGraphPresent=false
for _,def in pairs(UnitDefs)do
 if tostring((def.customParams or{}).prototype40k_source_progression)=="1"then sourceGraphPresent=true;break end
end
if not sourceGraphPresent then return false end
local hybrid=VFS.Include('40k_configs/four_faction_playtest.lua')
local hybridEnabled=hybrid.Enabled(options)
local fixedExtractorPilot=VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(options.prototype_extractor_fixed_tier_pilot)
assert(not fixedExtractorPilot or hybridEnabled,'Fixed extractor pilot requires ordinary four-faction graph')
local graphs={}
local primaryPaidReview=VFS.Include('40k_configs/ork_primary_paid_review.lua')
graphs[#graphs+1]=primaryPaidReview.Graph(options)
for _,path in ipairs({"40k_configs/imperium_release_graph.lua","40k_configs/ork_release_graph.lua","40k_configs/necron_release_graph.lua"})do
 if VFS.FileExists(path)then graphs[#graphs+1]=VFS.Include(path)end
end
local sourceProduction=VFS.Include("40k_configs/source_production.lua")
graphs[#graphs+1]={Requires=sourceProduction.SupplementalRequirements}
-- Explicit adaptation, not inferred from prerequisites: Ork array predates tier grants.
local grants={ork_mek_technology=2,ork_ard_technology=2,ork_big_waaagh=3,ork_apocalypse=4}
for _,graph in ipairs(graphs)do for key,row in pairs(graph.Research or{})do
 local name=type(key)=="number" and (row.id or row.name)or key
 if grants[name]and row.grants_tier==nil then row.grants_tier=grants[name]end
end end
-- Append exact source graphs last so older generic gates cannot override them.
local marine,marineGraph,variants,variantGraph
local nukklearReview
if not mixedEnabled then
 marine=VFS.Include('40k_configs/marine_infrastructure_candidates.lua')
 marineGraph=marine.Graph();graphs[#graphs+1]=marineGraph
 variants=VFS.Include('40k_configs/primary_variant_progression.lua')
 if tostring(options.prototype_ork_primary_roles)=='1' then VFS.Include('40k_configs/ork_primary_research_graph_extend.lua').Extend(variants,UnitDefs,VFS.Include('40k_configs/ork_primary_research_facts.lua'))end
 if primaryPaidReview.Enabled(options)and VFS.FileExists('scripts/generated/ork_nukklear_tech_facts.lua')then
  local why;nukklearReview,why=VFS.Include('40k_configs/ork_nukklear_tech_review.lua').Extend(variants,UnitDefs,VFS.Include('scripts/generated/ork_nukklear_tech_facts.lua'),options)
  assert(nukklearReview and nukklearReview.applied,'Exact source Nukklear technology refused: '..tostring(why))
 end
 variantGraph=variants.Graph(marine.Bindings);graphs[#graphs+1]=variantGraph
end
local bikeRegistry,bikeGraph
if not mixedEnabled and VFS.FileExists('40k_configs/40k_tactical_bike_registry.lua')then
 bikeRegistry=VFS.Include('40k_configs/40k_tactical_bike_registry.lua')
 bikeGraph=bikeRegistry.Graph();graphs[#graphs+1]=bikeGraph
end
local nightConfig
if not mixedEnabled and VFS.FileExists('40k_configs/necron_night_ability.lua')then
 nightConfig=VFS.Include('40k_configs/necron_night_ability.lua');graphs[#graphs+1]={Research={[nightConfig.ResearchKey]=nightConfig.Research}}
end
if hybridEnabled then
 local byName={};for _,d in pairs(UnitDefs)do byName[d.name]=d end
 local hybridGraph=hybrid.Graph(byName)
 if fixedExtractorPilot then VFS.Include('40k_configs/extractor_fixed_tier_candidate.lua').ApplyGraph(hybridGraph,byName)end
 graphs={hybridGraph}
 if nightConfig then graphs[#graphs+1]={Research={[nightConfig.ResearchKey]=nightConfig.Research}}end
 -- Ordinary hybrid production replaces historical source addon/population gates.
 -- Explicit source acceptance fixtures keep their existing whole-effect paths.
 marineGraph=nil;variantGraph=nil;bikeGraph=nil
end
local runtime=VFS.Include("40k_configs/paid_research_runtime.lua")
local diagnosticPolicy
if mixedEnabled then
 local cfg=VFS.Include('40k_configs/mixed_v2.lua')
 local selected=cfg.Selected(options)
 diagnosticPolicy=function(team,defID,caller)
  local d=UnitDefs[defID];local cp=d and d.customParams or {};local ownedTeam=false
  for _,t in ipairs(cfg.teams)do if t.id==team and cp.faction==t.faction then ownedTeam=true;break end end
  return {mode=mode,mixedV2=options.prototype_mixed_v2,sourceProgression=options.prototype_source_progression,
   selected=d and selected[d.name]==true or false,ownedTeam=ownedTeam,team=team,def=defID,
   caller=caller,maxSeeds=1717}
 end
end
local controller=runtime.New(Spring,UnitDefs,UnitDefNames,WeaponDefs,Game.armorTypes,graphs,CMD,CMDTYPE,diagnosticPolicy)
if nukklearReview then controller.sourceNukklearTechReview=nukklearReview end
-- The ordinary hybrid graph uses common additive health research; explicit
-- source variants keep their already-composed health owner below.
if hybridEnabled then
 local policy=VFS.Include('40k_configs/40k_experience_policy.lua').Read()
 controller.nativeHealthEffects=VFS.Include('40k_configs/paid_health_experience.lua').New(Spring,UnitDefs,policy.healthScale)
end
local sourceModifiers
local nativeReview,orkReview
local orkConsumerModule=VFS.Include('40k_configs/ork_source_consumers_native.lua')
if not mixedEnabled and orkConsumerModule.Enabled(options)then orkReview=VFS.Include(VFS.FileExists('scripts/generated/ork_source_consumer_bundle_evidence.lua')and 'scripts/generated/ork_source_consumer_bundle_evidence.lua'or '40k_configs/ork_source_consumer_bundle_evidence.lua')end
-- Only the root-owned proof-backed review registry can enable this composition.
if not mixedEnabled and mode=='expandedproduction' and options.prototype_source_acceptance=='imperium'
 and VFS.FileExists('40k_configs/40k_tactical_bike_registry.lua')then
 local registry=VFS.Include('40k_configs/40k_tactical_bike_registry.lua')
 if type(registry.NativeReviewConfig)=='function'then
  local reason;nativeReview,reason=registry.NativeReviewConfig(UnitDefs,options)
  Spring.Echo('40K MARINE NATIVE REGISTRY',nativeReview and 'READY_SOURCE_ONLY'or 'REFUSED',reason or 'none')
  if not nativeReview then for _,name in ipairs({'imp_scout','imp_marine','imp_tactical_bike','armcom','imp_mex','imp_generator','imp_hq','imp_marine_hq','imp_marine_barracks','imp_marine_armoury'})do
   local d=UnitDefNames[name];local cp=d and d.customParams or{}
   Spring.Echo('40K MARINE NATIVE CONTRACT',name,d and d.id or 'missing',d and d.metalCost or 'nil',d and d.energyCost or 'nil',d and d.buildTime or 'nil',d and tostring(d.isBuilding)or 'nil',cp.animsource or 'nil',cp.prototype40k_donor or 'nil',cp.prototype40k_source_progression or 'nil',cp.faction or 'nil',cp.source_entity or 'nil')
  end end
 end
end
if variantGraph then
 sourceModifiers=VFS.Include('40k_configs/primary_variant_native.lua').Attach(
  controller,Spring,UnitDefs,variants,variantGraph,marine,marineGraph,CMD,Game.gameSpeed,nativeReview,orkReview)
end
if nativeReview and bikeRegistry then bikeRegistry.AttachInitialGate(controller,Spring,UnitDefs,bikeGraph,nativeReview)end
if nightConfig then VFS.Include('40k_configs/necron_night_paid.lua').Attach(controller,Spring,nightConfig)end
local lifecycle=controller.sourceMarineLifecycle
local orkLifecycle=controller.sourceOrkLifecycle
local orkProducerCosts
if orkConsumerModule.Enabled(options)then
 orkProducerCosts=VFS.Include('40k_configs/ork_source_producer_costs.lua').New(Spring,UnitDefs,options,VFS.Include('scripts/generated/ork_source_producer_work_profiles.lua'))
 controller.sourceOrkProducerCosts=orkProducerCosts
end
if primaryPaidReview.Enabled(options)then primaryPaidReview.Attach(controller,Spring,UnitDefs,variants,options,VFS.Include('scripts/generated/ork_primary_role_contract.lua'),VFS.Include('scripts/generated/ork_aircraft_source_facts.lua'))end
local function register(id,def,team)
 if not def or not team then return end
 local health,_,_,_,progress=Spring.GetUnitHealth(id)
 controller.Register(id,def,team,health~=nil and health>0 and progress~=nil and progress>=1)
end
function gadget:Initialize()
 if lifecycle then gadgetHandler:RegisterCMDID(lifecycle.command)end
 gadgetHandler:RegisterCMDID(controller.CommandBase)
 for id in pairs(controller.commands)do gadgetHandler:RegisterCMDID(id)end
 for _,id in ipairs(Spring.GetAllUnits())do
  local def,team=Spring.GetUnitDefID(id),Spring.GetUnitTeam(id)
  if orkProducerCosts then local ok,why=orkProducerCosts.RestoreExisting(id,def,team);assert(ok,'Ork producer saved birth refused: '..tostring(why))end
  register(id,def,team)
 end
 -- Registering after Initialize also reserves the native command ID.
 local registerHandler=controller.RegisterEffectHandler
 controller.RegisterEffectHandler=function(key)
  local ok,cmd=registerHandler(key);if ok then gadgetHandler:RegisterCMDID(cmd)end;return ok
 end
 if lifecycle then lifecycle.RestoreSaved()end
 if orkLifecycle and not orkLifecycle.RestoreSaved()then Spring.Echo('40K ORK SOURCE CONSUMERS','saved_snapshot_refused')end
 controller.RestorePending()
 GG.Recoil40KResearch=controller
end
function gadget:Shutdown()if lifecycle then lifecycle.Save()end;if orkLifecycle then orkLifecycle.Save()end;if GG.Recoil40KResearch==controller then GG.Recoil40KResearch=nil end end
function gadget:UnitCreated(id,def,team,builder)
 if orkProducerCosts then local ok,why=orkProducerCosts.Birth(id,def,team,builder);assert(ok,'Ork producer actual birth refused: '..tostring(why))end
 if orkLifecycle then orkLifecycle.Birth(id,def,team,builder)end
 if lifecycle then lifecycle.Birth(id,def,team,builder)end
 if sourceModifiers and (UnitDefs[def].customParams or{}).source_entity then sourceModifiers.UnitCreated(id,def,team)end
 register(id,def,team)
end
function gadget:UnitExperience(id)if sourceModifiers then sourceModifiers.UnitExperience(id)end end
function gadget:UnitFinished(id)controller.Finished(id)end
function gadget:UnitDestroyed(id)if orkProducerCosts then orkProducerCosts.Destroyed(id)end;if orkLifecycle then orkLifecycle.Removed(id,false)end;if lifecycle then lifecycle.Removed(id)end;controller.Remove(id,true)end
function gadget:UnitTaken(id)if orkProducerCosts then orkProducerCosts.Transferred(id)end;if orkLifecycle then orkLifecycle.Removed(id,true)end;if lifecycle then lifecycle.Transferred(id)end;controller.Remove(id,false)end
function gadget:UnitGiven(id,def,newTeam)if orkProducerCosts then orkProducerCosts.Transferred(id)end;if orkLifecycle then orkLifecycle.Removed(id,true)end;if lifecycle then lifecycle.Transferred(id)end;register(id,def,newTeam)end
function gadget:UnitFromFactory(id,def,team,factory)if orkLifecycle then orkLifecycle.Factory(id,def,team,factory)end;if lifecycle then lifecycle.Factory(id,def,team,factory)end end
function gadget:UnitDamaged(id,def,team,damage,paralyzer,weapon,projectile,attacker)if orkLifecycle then orkLifecycle.Damaged(id,damage,attacker)end;if lifecycle then lifecycle.Damaged(id,damage,attacker)end end
function gadget:GameFrame(frame)if controller.NightRefreshHandlers then controller.NightRefreshHandlers()end;controller.Frame(frame);if lifecycle then lifecycle.Save()end end
function gadget:AllowCommand(id,def,team,cmd,params,opts)
 if lifecycle and cmd==lifecycle.command then return lifecycle.Allow(id,def,team,cmd)end
 local allowed=controller.Allow(id,def,team,cmd,params,opts)
 if options.prototype_source_acceptance and options.prototype_source_acceptance~='' and controller.commands[cmd]then
  local u=controller.units[id];Spring.Echo('40K PAID RESEARCH COMMAND',Spring.GetGameFrame(),id,cmd,allowed,'registered',u and u.name or 'absent','finished',u and tostring(u.finished) or 'absent')
 end
 return allowed
end
function gadget:CommandFallback(id,def,team,cmd,params,opts,tag)
 if lifecycle and cmd==lifecycle.command then return lifecycle.Fallback(id,def,team,cmd,tag)end
 return controller.Fallback(id,cmd,tag)
end
function gadget:AllowUnitCreation(def,builder,team)
 if orkProducerCosts and not orkProducerCosts.Allow(def,team,builder)then return false end
 if not controller.CanBuild(team,def,builder,builder==nil and Spring.GetGameFrame()==0)then return false end
 if orkLifecycle and not orkLifecycle.AllowCreation(team,def,builder)then return false end
 return not lifecycle or lifecycle.AllowCreation(team,def,builder)
end

function gadget:UnitPreDamaged(id,def,team,damage,paralyzer,weapon)
 local p=controller.sourcePrimaryResearch
 return p and p.PreDamage(id,damage,paralyzer,weapon)or damage,1
end
