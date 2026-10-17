function gadget:GetInfo()return{name='40K ordinary paid Necron remains fixture',desc='Two paid cohorts, paid Scarab, funded hostile natural Cannon only',author='Local project',layer=160,enabled=true}end
local options=Spring.GetModOptions()or{}
local Observer=VFS.Include('40k_configs/necron_paid_remains_observer.lua')
if not Observer.Route(options)or not gadgetHandler:IsSyncedCode()then return false end
local S=Spring;local driver,combat,witness,plan,makeDriver;local closed=false;local start
local function emit(label,...)
 local fields={...};for i=1,#fields do fields[i]=tostring(fields[i])end
 local clock=type(S.GetGameFrame)=='function'and S.GetGameFrame()or nil;local clockText=type(clock)=='number'and clock==clock and math.abs(clock)<math.huge and clock%1==0 and tostring(clock)or'unavailable'
 S.Echo('40K_NECRON_PAID_REMAINS '..options.prototype_necron_remains_run_id..' '..clockText..' '..label..' '..table.concat(fields,' '))
end
local function close(result)
 if closed then return end;closed=true;if combat then combat.Close()end
 if GG.Recoil40KWalkerBurstWitness==witness then GG.Recoil40KWalkerBurstWitness=nil end
 emit('COMPLETE',result,'singleCreditLedgerVerified='..tostring(combat and combat.singleCreditLedgerVerified or false),'nativeVisualAccepted=false','paidEconomyAccepted=false','pairedRepeatAccepted=false')
end
function gadget:Initialize()
 -- Initialize frame zero is source admission only; root excludes SSF/replay.
 if type(S.GetGameFrame)~='function'or S.GetGameFrame()~=0 or GG.Recoil40KWalkerBurstWitness or GG.Recoil40KCorpseAccount or GG.Recoil40KSpyderHarvestReview then close('REFUSAL fresh_owned_sole_observer_required');return end
 start=S.GetGameFrame()
 if not Script or type(Script.SetWatchProjectile)~='function'or type(Script.SetWatchExplosion)~='function'then close('REFUSAL native_watch_APIs_required');return end
 local Profiles=VFS.Include('40k_configs/active_squad_profiles.lua')
 local Recipe=VFS.Include('40k_configs/necron_remains_native_recipe.lua')
 plan=Recipe.Select(options,Profiles,VFS)
 local staticOwner=VFS.Include('40k_configs/tactical_marine_remains.lua')
 VFS.Include('40k_configs/necron_remains_recipe.lua').Register(staticOwner,options,VFS)
 Recipe.ValidateOwner(plan,staticOwner,FeatureDefs) -- Table-only definition check; never a second runtime owner.
 local physical=VFS.Include('40k_configs/guard_factory_egress_geometry.lua')
 local site=VFS.Include('40k_configs/ordinary_paid_construction_site.lua')
 local endpoint=VFS.Include('40k_configs/paid_factory_egress_review.lua')
 if site.Version~=1 or type(site.Choose)~='function'or type(endpoint.Plan)~='function'then close('REFUSAL reviewed_shared_site_endpoint_required');return end
 local placement={Version=1,
  Choose=function(def,builder,metal)return site.Choose(S,UnitDefs,GG,Game,def,builder,metal,emit)end,
  Rally=function(def,factory)
   local task=driver and driver.tasks[driver.step];local child=task and task.birth
   if not child or S.GetUnitDefID(child)~=def then return end
   return endpoint.Plan(S,UnitDefs,child,factory,Game.mapSizeX,Game.mapSizeZ)
  end}
 makeDriver=function()return VFS.Include('40k_configs/necron_remains_paid_driver.lua').New(S,UnitDefs,UnitDefNames,Profiles,GG.Recoil40KSquads,physical,placement,plan,emit)end
 emit('TRACE_SCHEMA',1,plan.actor,plan.capacity,Game.mapSizeX,Game.mapSizeZ,Game.maxUnits,Game.reclaimMethod,
  'ordinaryOwnResources=true','fundedHostileOnly=true','nativeGameIDBinding=external_closed_journal_required')
end
function gadget:UnitCreated(id,def,team,builder)if closed then return end;if combat then combat.Changed()elseif driver then driver.Created(id,def,team,builder)end end
function gadget:UnitDestroyed(...)if combat and not closed then combat.Destroyed(...)end end
function gadget:UnitTaken()if combat and not closed then combat.Changed()end end
function gadget:UnitGiven()if combat and not closed then combat.Changed()end end
function gadget:AllowUnitBuildStep(builder)if combat and not closed then return combat.UnitWork(builder)end;return true end
function gadget:UnitFinished(id,def,team)if driver and not closed and not combat then driver.Finished(id,def,team)end end
function gadget:UnitFromFactory(id,def,team,factory,factoryDef,userOrders)if driver and not closed and not combat then driver.Released(id,def,team,factory,factoryDef,userOrders)end end
function gadget:FeatureCreated(fid)if combat and not closed then combat.FeatureCreated(fid)end end
function gadget:FeatureDestroyed(fid)if combat and not closed then combat.FeatureDestroyed(fid)end end
function gadget:AllowFeatureBuildStep(...)if combat and not closed then return combat.BuildStep(...)end;return true end
function gadget:ProjectileCreated(pid,owner,wd)if witness and not closed then witness.Projectile(pid,owner,wd)end end
function gadget:Explosion(...)if combat and not closed then return combat.Explosion(...)end;return false end
function gadget:UnitDamaged(...)if combat and not closed then combat.Damaged(...)end end
function gadget:GameFrame(frame)
 if closed or frame<1 then return end
 if not driver then
  if not GG.Recoil40KSquads or not GG.Recoil40KTacticalRemains then close('REFUSAL actual_runtime_owners_missing_at_first_native_frame');return end
  driver=makeDriver();if driver.result then close(driver.result);return end
 end
 if not combat then
  local result=driver.Step(frame)
  if result then
   if result~='PREPARED paid_builder_and_two_released_full_cohorts'then close(result);return end
   combat=Observer.New(S,UnitDefs,UnitDefNames,FeatureDefs,WeaponDefs,GG,VFS.Include('40k_configs/guard_factory_egress_geometry.lua'),plan,driver.contexts,emit,
    VFS.Include('40k_configs/animation_bank_loader.lua').Load(VFS,GG.Prototype40kAnimationCache or{},UnitDefs[UnitDefNames.imp_russ.id].customParams),
    VFS.Include('40k_configs/basilica_builder_reclaim_ledger.lua'))
   if combat.result then close(combat.result);return end
   if GG.Recoil40KWalkerBurstWitness then close('REFUSAL existing_native_Shot_Query_owner');return end
   witness=VFS.Include('40k_configs/walker_burst_observer.lua').New(S,UnitDefs,function(row)combat.Telemetry(row)end,128)
   GG.Recoil40KWalkerBurstWitness=witness;Script.SetWatchProjectile(combat.weapon,true);Script.SetWatchExplosion(combat.weapon,true)
   for role,context in pairs(driver.contexts)do
    if role=='builder'or role=='cohort1'or role=='cohort2'then
     emit('PAID_ORIGIN',role,context.product,context.productDefinition,context.factory,context.team,context.created,context.released,
      context.createdMetal,context.createdEnergy,context.createdWork,context.seed or 0)
     for slot,b in ipairs(context.slots or{})do local finished=context.finished[b.id]
      emit('PAID_BODY_FINISH',context.seed,slot,b.id,b.def,b.generation,finished.frame,finished.team,plan.metal,plan.energy,plan.work)
     end
    end
   end
  end
 end
 if combat then
  local result=combat.Step(frame)
  if combat.needsRegistration and not result then
   if not witness.Register(combat.enemy)then close('REFUSAL actual_genuine_Russ_Shot_observer_unavailable');return end
   combat.needsRegistration=false
  end
  if result then close(result)end
 end
 if frame-start>45000 then close('INCONCLUSIVE bounded_owned_paid_remains_timeout')end
end
function gadget:Shutdown()
 close('SHUTDOWN')
 -- Cleanup only fixture-created funded hostile units, never paid/user actors.
 if combat then for _,id in ipairs({combat.enemy or false,combat.completedEnemy or false})do
  if id and S.ValidUnitID(id)and not S.GetUnitIsDead(id)and S.GetUnitTeam(id)==combat.enemyTeam and S.GetUnitDefID(id)==combat.enemyDefinition then S.DestroyUnit(id,false,true)end
 end end
end
