-- Isolated follow-on: AI owns orders, controllers own payments and restoration.
-- The sole mutation is one disclosed lethal native-damage casualty probe.
local M={Version=1,AI='40K Test AI - Centre March',Research='guard_squad_flamer'}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function integer(v)return finite(v)and v>=0 and v%1==0 end
local function same(a,b)return finite(a)and finite(b)and math.abs(a-b)<1e-6 end
function M.New(S,D,profile,getC,getR,emit)
 assert(profile.capacity==8 and profile.research==M.Research and profile.specialSlot==8)
 local O={phase='RESEARCH',failed=false};local team,command,jobSeen,researchStep,seed,victim,baseline,repairOrder,repairSeen
 local function fail(why)O.failed=true;O.phase='REFUSED';emit('REFUSED',why);return false end
 local function live(id)return integer(id)and S.ValidUnitID(id)and not S.GetUnitIsDead(id)and S.GetUnitTeam(id)==team end
 local function record(C)
  local r=C.records and C.records[M.Research]
  assert(r and r.producer=='imp_research'and r.frames==1050 and r.row.cost.metal==200 and r.row.cost.energy==1000)
  return r
 end
 function O.Initialize(t)
  if not integer(t)or S.GetTeamLuaAI(t)~=M.AI then return fail('actual_centremarch_owner_required')end
  team=t;local m=S.GetTeamResources(t,'metal');local e=S.GetTeamResources(t,'energy')
  if not finite(m)or not finite(e)or math.abs(m-1000)>5 or math.abs(e-1000)>5 then return fail('ordinary_start_required')end
  emit('ADMISSION','ordinary_AI_orders=true scripted_casualty=true grants=false exact_native_debit_accepted=false');return true
 end
 function O.Command(id,def,t,cmd,params,tag,fromLua)
  if O.failed or t~=team then return end
  local C=getC();if type(C)~='table'then return fail('actual_research_controller_unavailable')end;local r=record(C)
  if cmd==r.cmd then
   local u=C.units and C.units[id]
   if not live(id)or not u or u.team~=team or not u.finished or u.name~=r.producer or not integer(tag)or fromLua~=true then return fail('research_native_owner_or_origin')end
   if command then return fail('duplicate_research_order')end
   command={id=id,tag=tag};emit('AI_RESEARCH_ORDER','producer='..id..' tag='..tag)
  elseif seed and(cmd==40 or cmd==34591)then
   local s=getR().squads[seed];local target=params and params[1]
   if target~=(cmd==40 and s.leader or seed)then return end
   local d=D[def]
   if not live(id)or not d or not d.isBuilder or d.isFactory or(d.speed or 0)<=0 or(d.buildSpeed or 0)<=0 or fromLua~=true or not integer(tag)then return fail('repair_native_builder_or_origin')end
   -- The original CMD.REPAIR is redirected by the actual squad owner. Only
   -- its accepted custom34591 callback owns the subsequently running job.
   if cmd==34591 then repairOrder={id=id,tag=tag,def=def};emit('AI_REPAIR_ORDER','builder='..id..' tag='..tag..' native_cmd=34591')
   else emit('AI_REPAIR_PROPOSAL','builder='..id..' tag='..tag..' native_cmd=40 redirected_owner_required=true')end
  end
 end
 local function preserved(s)
  for slot,b in pairs(baseline)do
   local id=s.slots[slot];local inv=s.investments[slot]
   if id~=b.id or not live(id)or s.generations[slot]~=b.generation or not inv or not same(inv.work,b.work)or not same(inv.metal,b.metal)or not same(inv.energy,b.energy)or not same(S.GetUnitExperience(id),b.xp)then return false end
   local hp=S.GetUnitHealth(id);if not same(hp,b.hp)then return false end
  end;return true
 end
 function O.Frame(frame)
  if O.failed or O.phase=='PASS' then return false end
  if not integer(frame)or team==nil or S.GetTeamLuaAI(team)~=M.AI then return fail('frame_or_owner_changed')end
  local C,R=getC(),getR();if type(C)~='table'or type(C.jobs)~='table'or type(R)~='table'or type(R.squads)~='table'or type(R.repair)~='table'then return fail('actual_controllers_unavailable')end;local r=record(C)
  if O.phase=='RESEARCH'then
   local job=command and C.jobs[command.id]and C.jobs[command.id][M.Research]
   if job then
    local queue=S.GetUnitCommands(command.id,-1);local bound=false
    if type(queue)~='table'or not live(command.id)then return fail('research_current_native_owner_or_queue')end
    for _,q in ipairs(queue)do if q.id==r.cmd and q.tag==command.tag then if bound then return fail('duplicate_native_research_tag')end;bound=true end end
    if not bound then return fail('research_native_tag_absent')end
    if job.team~=team or job.record~=r or job.tag~=command.tag or not integer(job.steps)or job.steps>=1050 or not same(job.metal,200*job.steps/1050)or not same(job.energy,1000*job.steps/1050)then return fail('actual_research_queue_or_bill')end
    if researchStep and job.steps<researchStep then return fail('research_paid_steps_regressed')end
    researchStep=job.steps
    jobSeen=job.steps>0 or jobSeen
   end
   if C.HasResearch(team,M.Research)then
    if not command or not jobSeen then return fail('research_completion_without_observed_AI_paid_job')end
    O.phase='PROBE_READY';emit('RESEARCH_DONE','actual_controller=true final_native_boolean_debit_not_claimed=true')
   end
  end
  if O.phase=='PROBE_READY'then
   local candidates={};for k,s in pairs(R.squads)do if s.team==team and s.profile=='guard_line'then candidates[#candidates+1]=k end end;table.sort(candidates)
   for _,k in ipairs(candidates)do local s=R.squads[k];local b={};local full=true
    for slot=1,8 do local id=s.slots[slot];local inv=s.investments[slot];local hp,max,_,_,built
     if id~=nil then hp,max,_,_,built=S.GetUnitHealth(id)end
     if not live(id)or S.GetUnitTransporter(id)or not inv or not finite(hp)or hp~=max or built~=1 or not integer(s.generations[slot])or not finite(S.GetUnitExperience(id))then full=false;break end
     b[slot]={id=id,generation=s.generations[slot],hp=hp,xp=S.GetUnitExperience(id),work=inv.work,metal=inv.metal,energy=inv.energy}
    end
    local special=full and D[S.GetUnitDefID(s.slots[8])]
    if full and special and special.name==profile.special and not R.repair[k]then
     seed=k;victim=b[2];b[2]=nil;baseline=b;O.phase='CASUALTY';emit('SCRIPTED_CASUALTY','seed='..seed..' slot=2 body='..victim.id..' native_damage_probe=true combat_acceptance=false')
     S.AddUnitDamage(victim.id,victim.hp+10000,0,nil,-1);return true
    end
   end
  elseif O.phase=='CASUALTY'or O.phase=='REPAIR'then
   local s=R.squads[seed];if not s or s.team~=team or not preserved(s)then return fail('survivor_identity_HP_XP_investment_changed')end
   if s.slots[2]==victim.id then return true end
   if live(victim.id)then return fail('casualty_owner_not_removed')end
   local job=R.repair[seed]
   if job then
    local d=repairOrder and D[S.GetUnitDefID(repairOrder.id)];local queue=repairOrder and S.GetUnitCommands(repairOrder.id,-1);local head=type(queue)=='table'and queue[1]
    if not repairOrder or not live(repairOrder.id)or S.GetUnitDefID(repairOrder.id)~=repairOrder.def or not d or not d.isBuilder or d.isFactory or(d.speed or 0)<=0 or(d.buildSpeed or 0)<=0 or not head or head.id~=34591 or head.tag~=repairOrder.tag or type(head.params)~='table'or head.params[1]~=seed then return fail('current_native_builder_repair_owner_queue_tag')end
    local matches=0;for _,q in ipairs(queue)do if q.tag==repairOrder.tag then matches=matches+1 end end
    if matches~=1 then return fail('ambiguous_native_repair_tag')end
    if not repairOrder or job.slot~=2 or job.def~=profile.member or not finite(job.work)or job.work<0 or job.work>100 or not same(job.metal,8*job.work/100)or not same(job.energy,40*job.work/100)then return fail('actual_builder_paid_repair_bill')end
    if repairSeen and job.work<repairSeen then return fail('repair_paid_work_regressed')end
    repairSeen=job.work;O.phase='REPAIR'
   end
   if s.slots[2]then
    local id=s.slots[2];local inv=s.investments[2]
    if not repairOrder or not live(repairOrder.id)or S.GetUnitDefID(repairOrder.id)~=repairOrder.def or not repairSeen or repairSeen<=0 or not live(id)or id==victim.id or D[S.GetUnitDefID(id)].name~=profile.member or s.generations[2]~=victim.generation+1 or not inv or not same(inv.work,100)or not same(inv.metal,8)or not same(inv.energy,40)or not same(S.GetUnitExperience(id),0)then return fail('replacement_without_observed_paid_job_and_full_bill')end
    O.phase='PASS';emit('PASS','AI_research_and_builder_restoration_observed=true scripted_casualty=true exact_atomic_debit_render_native_combat=false');return true
   end
  end;return true
 end
 return O
end
return M
