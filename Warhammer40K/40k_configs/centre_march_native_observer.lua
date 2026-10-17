-- Read-only native evidence. AI, research and squad owners retain all mutations.
local M={AI='40K Test AI - Centre March'}
local function finite(x)return type(x)=='number'and x==x and math.abs(x)<math.huge end
local function sorted(t)local a={};for k in pairs(t or{})do a[#a+1]=k end;table.sort(a);return a end
function M.New(S,defs,profile,controllers,ready,emit,probe)
 local O={rows=0,failed=false};local team;local births={};local products={};local signatures={};local original={};local missing={}
 local function refuse(why)if not O.failed then emit('REFUSED',why)end;O.failed=true;return false,why end
 local function log(key,...)
  local a={...};for i=1,#a do a[i]=tostring(a[i])end;local sig=table.concat(a,' ')
  if signatures[key]==sig then return end
  if O.rows>=2048 then return refuse('log_cap_2048')end
  signatures[key]=sig;O.rows=O.rows+1;emit(key,sig)
 end
 function O.Initialize()
  for _,key in ipairs({'GetTeamList','GetTeamLuaAI','GetTeamUnits','GetUnitDefID','GetUnitTeam','GetUnitHealth','GetUnitIsDead','ValidUnitID','GetUnitCommands','GetTeamResources','GetUnitCmdDescs'})do if type(S[key])~='function'then return refuse('missing_api_'..key)end end
  if not profile or profile.capacity~=8 or profile.product~='imp_guardsman'or profile.research~='guard_squad_flamer'then return refuse('current_full_guard_flamer_profile_required')end
  local teams=S.GetTeamList();if type(teams)~='table'then return refuse('team_list_unreadable')end
  for _,id in ipairs(teams)do if S.GetTeamLuaAI(id)==M.AI then if team then return refuse('exactly_one_centremarch_required')end;team=id end end
  if team==nil then return refuse('centremarch_absent')end
  local units=S.GetTeamUnits(team)
  if type(units)~='table'or #units~=1 or not defs[S.GetUnitDefID(units[1])]or defs[S.GetUnitDefID(units[1])].name~='imp_field_commander'then return refuse('natural_single_guard_commander_required')end
  local m=S.GetTeamResources(team,'metal');local e=S.GetTeamResources(team,'energy')
  if not finite(m)or not finite(e)or math.abs(m-1000)>5 or math.abs(e-1000)>5 then return refuse('ordinary_1000_start_required')end
  log('AI_ADMISSION','team='..team,'name='..M.AI,'commander='..units[1],'initial_metal='..m,'initial_energy='..e,'observer_orders=false grants=false');return true
 end
 function O.Birth(id,def,t,builder)
  if O.failed or t~=team then return end
  local d=defs[def];if not d then return refuse('birth_definition_missing')end
  births[id]={def=def,builder=builder};if d.name==profile.product then
   local b=builder and defs[S.GetUnitDefID(builder)];local h,_,_,_,progress=S.GetUnitHealth(id)
   if not b or b.name~='imp_barracks'or S.GetUnitTeam(builder)~=team or not h or not finite(progress)or progress>=1 then return refuse('product_not_native_incomplete_factory_birth')end
   products[id]={factory=builder,def=def};log('PAID_PRODUCT_BIRTH:'..id,'factory='..builder,'def='..def,'progress='..progress,'native_creation_callback=true cost_acceptance_requires_finished_receipt=true')
  end
 end
 function O.Destroyed(id,def,t,R)
  if O.failed or t~=team then return end
  if R and R.mutating and R.mutating[id]then log('OWNER_REPLACEMENT:'..id,'owner_mutation=true casualty_not_inferred=true');return end
  for seed,slots in pairs(original)do for slot,body in pairs(slots)do if body==id then missing[seed]=missing[seed]or{};missing[seed][slot]=id;log('CASUALTY:'..id,'seed='..seed,'slot='..slot,'native_destroyed_callback=true cause_not_inferred=true')end end end
 end
 function O.Command(event,id,def,t,cmd,params,opts,tag,player,synced,lua,insert)
  if O.failed or t~=team then return end
  local C=controllers();local record=C and C.records and C.records[profile.research]
  if cmd~=34591 and cmd~=40 and not(cmd<0)and not(record and cmd==record.cmd)then return end
  local p={};for i,v in ipairs(params or{})do if not finite(v)or i>16 then return refuse('command_params_unreadable')end;p[i]=v end
  log(event..':'..id..':'..tostring(tag),'id='..id,'cmd='..cmd,'tag='..tostring(tag),'coded='..tostring(opts and opts.coded),'params='..table.concat(p,','),'player='..tostring(player),'fromSynced='..tostring(synced),'fromLua='..tostring(lua),'fromInsert='..tostring(insert~=nil),'raw_origin_only=true')
 end
 function O.Frame(frame,R)
  if O.failed or team==nil then return false end
  if S.GetTeamLuaAI(team)~=M.AI then return refuse('ai_identity_changed')end
  local C=controllers();if not C or not R or type(C.jobs)~='table'or type(C.reserved)~='table'or type(C.records)~='table'or type(C.HasResearch)~='function'then return refuse('actual_controller_unavailable')end
  local ids=S.GetTeamUnits(team);if type(ids)~='table'or #ids>256 then return refuse('team_unit_cap_or_unreadable')end;table.sort(ids)
  local rec=C.records[profile.research];local ok,why=ready.Ready(team,profile.research,rec,C,ids)
  if probe then local success=pcall(probe.Step,team,frame);if not success then return refuse('research_probe_native_state_unreadable')end end
  log('RESEARCH_READINESS','ready='..tostring(ok),'reason='..tostring(why),'read_only_existing_helper=true')
  local m,_,_,mi,me=S.GetTeamResources(team,'metal');local e,_,_,ei,ee=S.GetTeamResources(team,'energy')
  if not finite(m)or not finite(e)then return refuse('resources_unreadable')end
  if frame%900==0 then log('ECONOMY:'..frame,m,e,mi,me,ei,ee,'income_present=true resource_delta_not_exact_bill=true')end
  for _,id in ipairs(ids)do
   local q=S.GetUnitCommands(id,-1);if type(q)~='table'or #q>64 then return refuse('queue_unreadable_or_cap64')end
   local jobs=C.jobs[id];if jobs~=nil and type(jobs)~='table'then return refuse('research_jobs_unreadable')end
   local job=jobs and jobs[profile.research]
   if job then
    local reserved=C.reserved[team];local cost=type(rec)=='table'and type(rec.row)=='table'and rec.row.cost
    if type(job)~='table'or type(reserved)~='table'or type(cost)~='table'or not finite(rec.frames)or rec.frames<1 or rec.frames~=math.floor(rec.frames)then return refuse('research_job_metadata_unreadable')end
    local producer=defs[S.GetUnitDefID(id)];local health,_,_,_,built=S.GetUnitHealth(id)
    local cp=producer and producer.customParams or{};local producerName=producer and(cp.prototype40k_tech_requires or cp.prototype40k_donor or producer.name)
    if not S.ValidUnitID(id)or S.GetUnitIsDead(id)or producerName~=rec.producer or not finite(health)or health<=0 or built~=1 then return refuse('research_job_native_producer')end
    if job.team~=team or S.GetUnitTeam(id)~=team or job.record~=rec or job.cmd~=rec.cmd or not finite(job.steps)or job.steps<0 or job.steps~=math.floor(job.steps)or job.steps>=rec.frames or not finite(job.metal)or not finite(job.energy)or job.metal<0 or job.energy<0 or reserved[profile.research]~=id then return refuse('research_job_identity_or_bill')end
    if not finite(cost.metal)or not finite(cost.energy)or cost.metal<0 or cost.energy<0 or math.abs(job.metal-cost.metal*job.steps/rec.frames)>1e-5 or math.abs(job.energy-cost.energy*job.steps/rec.frames)>1e-5 then return refuse('research_job_paid_bill_mismatch')end
    local owned,index;for i,entry in ipairs(q)do if type(entry)~='table'then return refuse('research_queue_entry_unreadable')end;if entry.id==rec.cmd and entry.tag==job.tag then if owned then return refuse('research_queue_owner_ambiguous')end;owned=entry;index=i end end
    if not owned or not finite(job.tag)or job.tag<0 or job.tag~=math.floor(job.tag)or type(job.active)~='boolean'or(job.active and index~=1)then return refuse('research_job_native_queue_owner')end
    log('RESEARCH_JOB:'..id,'steps='..job.steps,'metal='..job.metal,'energy='..job.energy,'tag='..tostring(job.tag),'head='..tostring(q[1]and q[1].id),'reservation='..id)
   end
  end
  log('RESEARCH_DONE','done='..tostring(C.HasResearch(team,profile.research)),'research_key='..profile.research)
  local count=0
  for _,seed in ipairs(sorted(R.squads))do local s=R.squads[seed]
   if s.team==team and s.profile=='guard_line'then
    count=count+1;if count>16 then return refuse('squad_cap16')end
    local members=R.Members(s.leader);local first=not original[seed]
    if first then
     local product=s.slots[1];local b=products[product];local d=b and defs[b.def]
     if not b or not d or #members~=8 then return refuse('full_squad_not_observed_paid_factory_product')end
     local factoryBirth=births[b.factory];local fh,_,_,_,fb=S.GetUnitHealth(b.factory)
     if not factoryBirth or not factoryBirth.builder or S.GetUnitTeam(factoryBirth.builder)~=team or not fh or fb~=1 then return refuse('factory_paid_birth_or_finished_receipt_missing')end
     local body;for _,value in pairs(defs)do if value.name==profile.member then body=value;break end end
     if not body or math.abs(d.metalCost-body.metalCost*8)>.001 or math.abs(d.energyCost-body.energyCost*8)>.001 or math.abs(d.buildTime-body.buildTime*8)>.001 then return refuse('aggregate_product_cost_not_eight_bodies')end
     original[seed]={};log('FULL_SQUAD:'..seed,'product='..product,'factory='..b.factory,'capacity=8 living=8 native_full_delivery=true actual_native_cost_metal='..d.metalCost,'actual_native_cost_energy='..d.energyCost)
    end
    for _,slot in ipairs(sorted(s.slots))do local id=s.slots[slot];local h,max,_,_,built=S.GetUnitHealth(id);local inv=s.investments[slot]
     if not S.ValidUnitID(id)or S.GetUnitIsDead(id)or S.GetUnitTeam(id)~=team or not h or not max or built~=1 or not inv then return refuse('body_identity_health_investment')end
     if first then original[seed][slot]=id end
     log('BODY:'..seed..':'..slot,'id='..id,'def='..S.GetUnitDefID(id),'generation='..s.generations[slot],'health='..h,'max='..max,'metal='..inv.metal,'energy='..inv.energy,'work='..inv.work,'leader='..s.leader)
     if missing[seed]and missing[seed][slot]and id~=missing[seed][slot]then log('RESTORED_SLOT:'..seed..':'..slot,'old='..missing[seed][slot],'new='..id,'generation='..s.generations[slot],'owner_investment_receipt_only=true native_paid_repair_acceptance_requires_job_bill=true');missing[seed][slot]=nil end
     original[seed][slot]=id -- Track actual current role bodies for later natural casualties.
    end
    local job=R.repair[seed];if job then
     if type(job)~='table'or not finite(job.slot)or job.slot~=math.floor(job.slot)or job.slot<1 or job.slot>profile.capacity or s.slots[job.slot]or type(job.def)~='string'or not finite(job.work)or not finite(job.metal)or not finite(job.energy)or job.work<0 or job.metal<0 or job.energy<0 then return refuse('repair_job_identity_or_bill')end
     -- Retain a partially paid ordinary bill across later specialist research,
     -- exactly as the runtime does; a specialist bill requires its actual slot
     -- and permanent team research. Neither permits a building/foreign role.
     if job.def~=profile.member and not(job.slot==profile.specialSlot and job.def==profile.special and C.HasResearch(team,profile.research)==true)then return refuse('repair_job_ineligible_profile_role')end
     local d;for _,value in pairs(defs)do if value.name==job.def then d=value;break end end
     if not d or not finite(d.buildTime)or d.buildTime<=0 or not finite(d.metalCost)or not finite(d.energyCost)or job.work>d.buildTime+1e-7 or math.abs(job.metal-d.metalCost*job.work/d.buildTime)>1e-5 or math.abs(job.energy-d.energyCost*job.work/d.buildTime)>1e-5 then return refuse('repair_job_paid_bill_mismatch')end
     log('REPAIR_JOB:'..seed,'slot='..job.slot,'def='..job.def,'work='..job.work,'metal='..job.metal,'energy='..job.energy,'read_actual_owner=true')
    end
    log('MEMBERS:'..seed,'living='..#members,'capacity=8')
   end
  end;return true
 end
 return O
end
return M
