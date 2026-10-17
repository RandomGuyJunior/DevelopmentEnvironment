-- Read-only pending ordinary Guard research save witness; no gameplay writes.
local M={}
function M.Capture(c,f,S,R,C,p,unit,copy)
 if c.phase~='research'or not c.pendingResearch or not c.pendingReady then return end
 local s=R.squads[c.seed];local rec=C.records[p.research];local paid=c.research;local producer=paid and paid.producer;local j=producer and C.jobs[producer]and C.jobs[producer][p.research]
 if not s or s.team~=c.team or s.profile~='guard_line'or R.repair[c.seed]then return nil,'pending_cohort_or_repair_changed'end
 if not c.proof or not c.proof.paid_factory or not c.proof.paid_full_squad or not c.proof.ordinary_start then return nil,'pending_paid_proof_missing'end
 if not rec or rec.producer~='imp_research'or rec.frames~=35*Game.gameSpeed or rec.row.cost.metal~=200 or rec.row.cost.energy~=1000 then return nil,'pending_registered_bill_missing'end
 if C.HasResearch(c.team,p.research)or S.GetTeamRulesParam(c.team,'40k_research_'..p.research)==1 then return nil,'pending_research_already_done'end
 if not j or j.team~=c.team or j.cmd~=rec.cmd or not j.active or C.reserved[c.team][p.research]~=producer or j.steps<=0 or j.steps>=rec.frames then return nil,'pending_paid_job_missing'end
 if paid.lastSteps~=j.steps or paid.lastMetal~=j.metal or paid.lastEnergy~=j.energy or math.abs(j.metal-200*j.steps/rec.frames)>.000001 or math.abs(j.energy-1000*j.steps/rec.frames)>.000001 then return nil,'pending_partial_bill_mismatch'end
 local producerBody=unit(producer);if not producerBody or producerBody.team~=c.team or producerBody.def~=UnitDefNames.imp_research.id then return nil,'pending_producer_captured_or_missing'end
 local head=producerBody.orders and producerBody.orders[1];if not head or head.id~=j.cmd or head.tag~=j.tag then return nil,'pending_owned_native_head_missing'end
 local bodies={};local preserved={};local n=0
 for slot,id in pairs(s.slots)do
  n=n+1;bodies[slot]=unit(id);if not bodies[slot]or bodies[slot].team~=c.team or not(bodies[slot].def==UnitDefNames[p.member].id or slot==1 and bodies[slot].def==UnitDefNames[p.product].id)then return nil,'pending_eight_ordinary_bodies_missing'end
  preserved[slot]={heading=S.GetUnitHeading(id),states=copy(S.GetUnitStates(id))}
 end
 if n~=8 or not bodies[8]or bodies[8].hp<=0 or bodies[8].hp/bodies[8].max>=.999 or bodies[8].xp<=0 then return nil,'pending_wounded_current_eight_missing'end
 local commander=unit(c.commander);if not commander or commander.team~=c.team or commander.def~=UnitDefNames.armcom.id then return nil,'pending_real_commander_missing'end
 return{frame=f,seed=s.id,team=s.team,profile=s.profile,commander=commander,missingSlot=8,originalMembers=copy(c.originalMembers),proof=copy(c.proof),snapshot=R.Snapshot(),bodies=bodies,
  resources={metal={S.GetTeamResources(c.team,'metal')},energy={S.GetTeamResources(c.team,'energy')}},research={jobs=copy(C.jobs),done=copy(C.done),tiers=copy(C.tiers),reserved=copy(C.reserved)},
  pendingResearch={key=p.research,producer=producer,producerBody=producerBody,job=copy(j),preserved=preserved,remainingSteps=rec.frames-j.steps,remainingMetal=200-j.metal,remainingEnergy=1000-j.energy}}
end
function M.Observe(old,f,S,R,C,p,unit,same)
 local s=R.squads[old.seed];local q=old.pendingResearch;local prior=old.snapshot.squads[old.seed]
 if not s or s.team~=old.team then return nil,'pending_restored_owner_lost'end
 local producer=unit(q.producer);if not producer or producer.team~=old.team or producer.def~=UnitDefNames.imp_research.id then return nil,'pending_producer_captured_or_missing'end
 local n=0;for _ in pairs(s.slots)do n=n+1 end;if n~=8 or R.repair[old.seed]then return nil,'pending_missing_birth_or_repair'end
 for slot,row in pairs(old.bodies)do
  local id=s.slots[slot];local b=unit(id);if not b or b.team~=old.team or s.generations[slot]~=prior.generations[slot]or not same(s.investments[slot],prior.investments[slot])then return nil,'pending_slot_or_investment_changed'end
  if slot~=8 and id~=row.id then return nil,'pending_survivor_replaced'end
  local state=q.preserved[slot]
  if math.abs(b.hp/b.max-row.hp/row.max)>.003 or math.abs(b.xp-row.xp)>.003 or math.abs((S.GetUnitHeading(id)-state.heading+32768)%65536-32768)>1 or not same(S.GetUnitStates(id),state.states)or not same(b.cost,row.cost)then return nil,'pending_research_heal_xp_or_native_state_changed'end
 end
 local j=C.jobs[q.producer]and C.jobs[q.producer][q.key]
 if not C.HasResearch(old.team,q.key)then
  if not j or j.team~=old.team or j.steps<q.job.steps or j.metal<q.job.metal or j.energy<q.job.energy or C.reserved[old.team][q.key]~=q.producer then return nil,'pending_remaining_job_restarted_cancelled_or_captured'end
  if math.abs(j.metal-200*j.steps/j.record.frames)>.000001 or math.abs(j.energy-1000*j.steps/j.record.frames)>.000001 then return nil,'pending_remaining_job_bill_changed'end
  for slot,row in pairs(old.bodies)do if s.slots[slot]~=row.id then return nil,'pending_early_role_replace'end end
  return false
 end
 if j or C.reserved[old.team][q.key]~=nil or S.GetTeamRulesParam(old.team,'40k_research_'..q.key)~=1 then return nil,'pending_completion_owner_not_cleared'end
 if s.slots[8]==old.bodies[8].id and S.GetUnitDefID(s.slots[8])==UnitDefNames[p.member].id then return false end -- existing scheduled squad refresh may follow research completion
 local id=s.slots[8];if id==old.bodies[8].id or S.ValidUnitID(old.bodies[8].id)and not S.GetUnitIsDead(old.bodies[8].id)or S.GetUnitDefID(id)~=UnitDefNames[p.special].id then return nil,'pending_permanent_role_not_transformed'end
 return true
end
return M
