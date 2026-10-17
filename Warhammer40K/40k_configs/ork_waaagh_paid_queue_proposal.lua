-- Authored adaptation: production speed affects ONLY genuine existing paid queues.
-- Inert proposal; no paid-handler registration or native abilities are granted.
local M={rate=1.100000024,key='ork_source_waaagh'}
local targets={'ork_hq','ork_boy_hut','ork_pile_o_guns','ork_mek_shop','ork_hq_super','ork_giant_waagh_banner_sp_dxp3','ork_waagh_banner','ork_gork_totem','ork_generator','ork_boomy_platform','ork_bigger_generator','ork_bilda_pit'}
local known={};for _,name in ipairs(targets)do known[name]=true end
local function finite(v)return type(v)=='number'and v==v and v~=math.huge and v~=-math.huge end
local function integer(v)return finite(v)and v>=0 and v%1==0 end
function M.ProfileMatches(V)
 local p=V.SourceProfiles[M.key];local c=V.ResearchConditions[M.key]
 if not p or p.sha256~='ed70444194c601dfb2cb8a2e37668293bea281c4d311fcef03fae6ad95dd6e7c'
  or p.source~='attrib/research/races/orks/ua_ork_waagh_research.lua'
  or p.cost.metal~=1200 or p.cost.energy~=1200 or p.time~=300 or #p.effects~=13
  or not c or c.population~=220 or c.local_addon~='ork_source_hq_addon' then return false end
 local cap=p.effects[1]
 if cap.slot~='modifier_02'or cap.type~='population_cap_player_modifier'or cap.target~=''or cap.value~=60 or cap.exclusive~=false or cap.probability~=1 then return false end
 for n,target in ipairs(targets)do local e=p.effects[n+1]
  if e.slot~=string.format('modifier_%02d',n+2)or e.type~='production_speed_modifier'or e.target~=target
   or e.value~=M.rate or e.exclusive~=false or e.probability~=1
   or e.application_type~='type_modifierapplicationtype/tp_mod_apply_to_entity_type.lua'or e.usage_type~=nil then return false end
 end
 return true
end
function M.Target(path)
 local name=type(path)=='string'and path:match('^attrib/ebps/races/orks/structures/([^/]+)%.lua$')
 return name and known[name]and name or nil
end
function M.Supported(V,entities,verified,hooks)
 if not M.ProfileMatches(V)then return false,'source_profile_changed' end
 local mapped={}
 for def,path in pairs(entities or{})do local name=M.Target(path)
  if name and verified(def,path)==true then mapped[name]=true end
 end
 for _,name in ipairs(targets)do if not mapped[name]then return false,'unmapped_genuine_target:'..name end end
 for _,kind in ipairs({'factory','recruit','research','addon','birth','capture','rollback','save'})do
  if not hooks or hooks[kind]~=true then return false,'queue_lifecycle_hook_missing:'..kind end
 end
 return true -- Only this participant; capacity+60 and paid prerequisites remain separate.
end
function M.NativeQueueRate(base,active,applied)
 if not finite(base)or base<0 then return nil,'invalid_baseline' end
 if base==0 or active~=true or applied~=true then return base end
 return base*M.rate
end
-- Runtime calls Advance INSTEAD OF its ordinary +1 payment block, once per frame.
-- Keep existing integer job.steps/persisted payment invariants; carry gives extra
-- integer work at deterministic intervals. Failed atomic payment earns no work.
function M.Clock(S,C,D,config)
 assert(type(config)=='table'and type(config.Authorize)=='function'
  and type(config.Rate)=='function'and type(config.Contract)=='function'
  and type(config.RestoreReceipt)=='function','Paid queue/root lifecycle hooks required')
 local states={};local R={}
 local function owned(job,id,team,kind)
  if type(job)~='table'then return nil,'invalid_paid_job' end
  if kind~='research'and kind~='addon'and kind~='recruit'then return nil,'unsupported_clock_queue' end
  local actor=C.units[id];local def=S.GetUnitDefID(id);local hp,_,_,_,progress=S.GetUnitHealth(id)
  if not actor or actor.team~=team or actor.def~=def or not actor.finished or S.GetUnitTeam(id)~=team
   or not hp or hp<=0 or not progress or progress<1 or not M.Target((D[def]or{}).customParams and D[def].customParams.source_entity)
   or config.Authorize(job,id,team,kind)~=true then return nil,'not_owned_active_paid_queue' end
  return actor
 end
 local function contract(job)
  local frames,cost=config.Contract(job)
  if not integer(frames)or frames<1 or type(cost)~='table' or not finite(cost.metal)or cost.metal<0 or not finite(cost.energy)or cost.energy<0
   or not integer(job.steps)or job.steps>frames or not finite(job.metal)or not finite(job.energy)then return nil end
  if math.abs(job.metal-cost.metal*job.steps/frames)>1e-6*math.max(1,cost.metal)
   or math.abs(job.energy-cost.energy*job.steps/frames)>1e-6*math.max(1,cost.energy)then return nil end
  return frames,cost
 end
 function R.Advance(job,id,team,frame,kind)
  if not integer(frame)then return false,'invalid_frame' end
  local actor,why=owned(job,id,team,kind);if not actor then states[job]=nil;return false,why end
  local frames,cost=contract(job);if not frames then return false,'invalid_paid_work_contract' end
  if job.steps>=frames then return false,'already_complete' end
  local st=states[job]
  if st and(st.actor~=actor or st.id~=id or st.team~=team or st.kind~=kind)then states[job]=nil;return false,'stale_job_incarnation' end
  st=st or{actor=actor,id=id,team=team,kind=kind,carry=0,last=-1};states[job]=st
  if frame<=st.last then return false,'duplicate_or_old_frame' end
  st.last=frame
  local rate=config.Rate(id,team,M.key)
  if rate~=1 and rate~=M.rate then return false,'unverified_rate' end
  local credit=st.carry+rate;local work=math.min(math.floor(credit),frames-job.steps)
  local nextStep=job.steps+work
  local metal=cost.metal*nextStep/frames;local energy=cost.energy*nextStep/frames
  if not S.UseTeamResource(team,{metal=metal-job.metal,energy=energy-job.energy})then return false,'starved' end
  job.steps=nextStep;job.metal=metal;job.energy=energy;st.carry=nextStep==frames and 0 or credit-work
  return true,nextStep==frames
 end
 function R.Snapshot(job)
  local st=states[job];if not st then return nil end
  return {id=st.id,team=st.team,kind=st.kind,carry=st.carry,last=st.last}
 end
 function R.Restore(job,id,team,kind,snapshot,receipt)
  local actor=owned(job,id,team,kind)
  if not actor or not contract(job)or type(snapshot)~='table'or snapshot.id~=id or snapshot.team~=team or snapshot.kind~=kind
   or not finite(snapshot.carry)or snapshot.carry<0 or snapshot.carry>=1 or not integer(snapshot.last)
   or config.RestoreReceipt(receipt,job,id,team,kind,snapshot)~=true then return false end
  states[job]={actor=actor,id=id,team=team,kind=kind,carry=snapshot.carry,last=snapshot.last};return true
 end
 function R.Cancel(job)states[job]=nil end
 function R.Remove(id)for job,st in pairs(states)do if st.id==id then states[job]=nil end end end
 return R
end
return M
