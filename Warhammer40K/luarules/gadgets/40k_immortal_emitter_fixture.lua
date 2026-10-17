function gadget:GetInfo()return{name='40K paid Immortal native emitter diagnostic',desc='Default-off observed paid cohort and funded enemy only',author='Local project',layer=160,enabled=true}end
local M=VFS.Include('40k_configs/immortal_native_emitter_fixture.lua')
if not M.Enabled(Spring.GetModOptions()or{})or not gadgetHandler:IsSyncedCode()then return false end
local S=Spring;local origin;local finished={};local C,O;local start;local closed=false
local function emit(...)S.Echo('40K_IMMORTAL_EMITTER',...)end
local function complete(result)
 if closed then return end;closed=true;if C then C.Close()end
 if GG.Recoil40KWalkerBurstWitness==O then GG.Recoil40KWalkerBurstWitness=nil end
 emit('COMPLETE',result,'native_visual_acceptance=false','paid_economy_acceptance=false')
end
function gadget:Initialize()
 -- Initialize frame zero is source admission only; root excludes SSF/replay.
 if type(S.GetGameFrame)~='function'or S.GetGameFrame()~=0 then complete('REFUSED fresh_native_frame_zero_required');return end
 start=S.GetGameFrame()
 assert(not GG.Recoil40KWalkerBurstWitness,'Existing sole burst observer; refuse overwrite')
 assert(Script and type(Script.SetWatchProjectile)=='function','Native projectile subscription required')
 emit('WAIT_PAID_PRODUCT','factory=nec_advanced_factory','capacity=3','own_factory_and_cohort_not_granted=true','ordinary_construction_or_external_owned_paid_driver_required=true')
end
function gadget:UnitCreated(id,def,team,builder)
 if closed or origin or not builder then return end
 local d=UnitDefs[def];local factory=UnitDefs[S.GetUnitDefID(builder)]
 if not d or d.name~='nec_immortal'or not factory or factory.name~='nec_advanced_factory'or S.GetUnitTeam(builder)~=team then return end
 local work,metal,energy=S.GetUnitCosts(id)
 origin={product=id,productDefinition=def,factory=builder,team=team,created=S.GetGameFrame(),createdWork=work,createdMetal=metal,createdEnergy=energy,finished=finished}
 emit('OBSERVED_NATIVE_PRODUCT_BIRTH','product='..id,'factory='..builder,'bill='..tostring(metal)..','..tostring(energy)..','..tostring(work))
end
function gadget:UnitFinished(id,def,team)
 -- Nested internal native completions precede public squad-row linkage.
 if not closed then finished[id]={def=def,team=team,frame=S.GetGameFrame()}end
end
function gadget:UnitFromFactory(id,def,team,factory,factoryDef,userOrders)
 if closed or not origin or id~=origin.product then return end
 if def~=origin.productDefinition or factory~=origin.factory or team~=origin.team or origin.released or userOrders
  or S.GetUnitDefID(factory)~=factoryDef then complete('FAIL mismatched_or_duplicate_native_release');return end
 origin.released=S.GetGameFrame()
end
function gadget:GameFrame(frame)
 if closed then return end
 if not C and origin and origin.released and frame>origin.released+30 then
  if not GG.Recoil40KSquads then complete('FAIL existing_paid_squad_owner_required');return end
  local physical=VFS.Include('40k_configs/guard_factory_egress_geometry.lua')
  local R=GG.Recoil40KSquads;local row=R.Get(origin.product)
  local ready=row and row.slots and #R.Members(origin.product)==3
  if ready then for _,id in ipairs(R.Members(origin.product))do if not finished[id]or physical.Outside(S,UnitDefs,origin.factory,id)~=true then ready=false end end end
  if ready then
   C=M.New(S,UnitDefs,WeaponDefs,R,origin,emit,physical)
   if C.result then complete(C.result);return end
   -- Reuse existing Shot/Query/native PID observer; no duplicate implementation.
   O=VFS.Include('40k_configs/walker_burst_observer.lua').New(S,UnitDefs,function(row)C.Telemetry(row)end,64,{nec_immortal=true})
   assert(not GG.Recoil40KWalkerBurstWitness,'Existing observer acquired meanwhile')
   GG.Recoil40KWalkerBurstWitness=O
   for id,body in pairs(C.bodies)do assert(O.Register(id),'Immortal observation scope unavailable');for _,mount in pairs(body.mounts)do Script.SetWatchProjectile(mount.weapon,true)end end
  end
 end
 if C then local result=C.Step(frame);if result then complete(result)end end
 if frame-start>=18000 then complete('INCONCLUSIVE paid_production_context_timeout')end
end
function gadget:ProjectileCreated(pid,owner,wd)if O and not closed then O.Projectile(pid,owner,wd)end end
function gadget:UnitDamaged(id,def,team,damage,paralyzer,wd,pid,attacker)if C and not closed then C.Damaged(id,damage,paralyzer,wd,pid,attacker)end end
function gadget:Shutdown()
 complete('SHUTDOWN')
 -- Only this diagnostic's unpaid enemy target is cleanup-owned; paid cohort stays.
 if C and C.target and S.ValidUnitID(C.target)and not S.GetUnitIsDead(C.target)
  and S.GetUnitTeam(C.target)==C.enemy and S.GetUnitDefID(C.target)==C.targetDefinition then S.DestroyUnit(C.target,false,true)end
end
