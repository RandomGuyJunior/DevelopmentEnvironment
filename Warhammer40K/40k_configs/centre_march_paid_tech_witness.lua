-- Explicit read-only observer. Observed existence is not a creation callback or acceptance.
local M={}
local function keys(t)local r={};for k in pairs(t or{})do r[#r+1]=k end;table.sort(r);return r end
local function canonical(d)local p=d and d.customParams or{};return p.prototype40k_tech_requires or p.prototype40k_donor or(d and d.name)end
local function value(v)if v==nil then return 'UNKNOWN'end;return tostring(v)end
function M.New()
 local cache,seen,rows={},{},0
 local O={}
 function O.Observe(x)
  if x.enabled~=true then return false,'inactive'end
  local S,C,D=x.Spring,x.controller,x.UnitDefs
  if not C or not S or not D or type(x.Log)~='function'then return false,'unavailable'end
  if rows>=4096 then return false,'bounded'end
  local team=x.team;local frame=x.frame or -1
  local memo=cache[team]or{};cache[team]=memo
  local function emit(key,...)
   local args={...};local strings={};for i=1,#args do strings[i]=value(args[i])end
   local signature=table.concat(strings,'|')
   if memo[key]and memo[key].signature==signature and frame-memo[key].frame<900 then return end
   if rows>=4096 then return end
   memo[key]={signature=signature,frame=frame};rows=rows+1
   x.Log('40K AI TECH WITNESS',team,frame,key,unpack(args))
  end
  local ids=S.GetTeamUnits(team)or{};table.sort(ids)
  local actors,queued={},{}
  for index,id in ipairs(ids)do
   if index>256 then emit('bound_units','truncated',#ids);break end
   local def=S.GetUnitDefID(id);local name=canonical(D[def])
   local hp,max,_,_,progress=S.GetUnitHealth(id)
   local owned=S.GetUnitTeam(id)==team
   local live=owned and hp and hp>0 and not S.GetUnitIsDead(id)
   local commands=S.GetUnitCommands(id,-1)or{}
   if live and name then actors[name]=actors[name]or{};actors[name][#actors[name]+1]={id=id,hp=hp,max=max,progress=progress,head=commands[1],count=#commands}end
   for n,cmd in ipairs(commands)do
    if n>128 then emit('bound_queue:'..id,'truncated',#commands);break end
    local target=cmd.id and cmd.id<0 and canonical(D[-cmd.id])
    if target and live then queued[target]=queued[target]or{};queued[target][#queued[target]+1]={builder=id,tag=cmd.tag,head=n==1}end
   end
  end
  local metal,_,_,mi,me=S.GetTeamResources(team,'metal');local energy,_,_,ei,ee=S.GetTeamResources(team,'energy')
  emit('economy',value(metal),value(mi),value(me),value(energy),value(ei),value(ee))
  local previous=seen[team]or{};local current={};seen[team]=current
  for id,name in pairs(previous)do
   local hp=S.GetUnitHealth(id)
   if S.GetUnitTeam(id)~=team or not hp or hp<=0 or S.GetUnitIsDead(id)then emit('lost_actor:'..id,id,name,value(S.GetUnitTeam(id)),value(S.GetUnitHealth(id)),'OBSERVED_LOST_MEMBERSHIP_OR_DEATH')end
  end
  local records=keys(C.records)
  for index,key in ipairs(records)do
   if index>128 then emit('bound_records','truncated',#records);break end
   local r=C.records[key];local row=r.row or{};local costs=row.cost or{}
   local done=(C.done[team]or{})[key];local reservation=(C.reserved[team]or{})[key]
   emit('record:'..key,r.producer,r.cmd,value(done),value(reservation),value((C.suppressed or{})[key]),#(actors[r.producer]or{}),#(queued[r.producer]or{}),value(r.frames),value(costs.metal),value(costs.energy))
   for _,q in ipairs(queued[r.producer]or{})do emit('queued:'..key..':'..q.builder,q.builder,value(q.tag),q.head,'ACTUAL_NATIVE_BUILD_COMMAND')end
   for _,u in ipairs(actors[r.producer]or{})do
    current[u.id]=r.producer
    local desc
    for _,d in ipairs(S.GetUnitCmdDescs(u.id)or{})do if d.id==r.cmd then desc=d;break end end
    emit('actor:'..key..':'..u.id,u.id,value(u.hp),value(u.max),value(u.progress),u.progress~=nil and u.progress>=1,value(u.head and u.head.id),value(u.head and u.head.tag),u.count,desc~=nil,value(desc and desc.disabled),'OBSERVED_NATIVE_EXISTENCE_NOT_CREATED_CALLBACK')
    local job=((C.jobs or{})[u.id]or{})[key]
    local prefix='40k_rjob_'..key..'_'
    emit('job:'..key..':'..u.id,job~=nil,value(job and job.team),value(job and job.steps),value(job and job.metal),value(job and job.energy),value(job and job.active),value(job and job.tag),value(S.GetUnitRulesParam(u.id,'40k_research_progress')),value(S.GetUnitRulesParam(u.id,'40k_research_paused')),value(S.GetUnitRulesParam(u.id,prefix..'steps')),value(S.GetUnitRulesParam(u.id,prefix..'metal')),value(S.GetUnitRulesParam(u.id,prefix..'energy')),value(r.frames and r.frames>0 and(costs.metal or 0)/r.frames),value(r.frames and r.frames>0 and(costs.energy or 0)/r.frames))
   end
   local req=row.requires or{}
   emit('tier:'..key,value((C.tiers or{})[team]),value(req.tier),value(req.production_method),value(req.producer_min_health_fraction))
   for _,name in ipairs(req.buildings or{})do
    emit('prerequisite:'..key..':'..name,name,value(((C.complete or{})[team]or{})[name]),#(actors[name]or{}),#(queued[name]or{}))
    for _,u in ipairs(actors[name]or{})do current[u.id]=name;emit('prerequisite_actor:'..key..':'..u.id,u.id,name,value(u.hp),value(u.progress),u.progress~=nil and u.progress>=1,value(u.head and u.head.id))end
    for _,q in ipairs(queued[name]or{})do emit('prerequisite_queue:'..key..':'..q.builder,q.builder,name,value(q.tag),q.head)end
   end
   for _,name in ipairs(req.research or{})do emit('prerequisite_research:'..key..':'..name,name,value(((C.done or{})[team]or{})[name]),value(((C.reserved or{})[team]or{})[name]))end
   -- Report exact source predicates without invoking controller methods that initialize/mutate team state.
   local source=x.source and x.source.ResearchConditions and x.source.ResearchConditions[key]
   for _,field in ipairs(keys(source))do local v=source[field]
    if type(v)=='table'then local parts={};for _,k in ipairs(keys(v))do parts[#parts+1]=value(k)..'='..value(v[k])end;v=table.concat(parts,',')end
    emit('source_condition:'..key..':'..field,field,value(v),'RAW_SOURCE_PREDICATE_NATIVE_DESCRIPTOR_AUTHORITATIVE')
   end
  end
  return true,'observed'
 end
 return O
end
return M
