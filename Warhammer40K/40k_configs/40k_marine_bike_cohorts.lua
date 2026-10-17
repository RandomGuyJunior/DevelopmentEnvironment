-- Paid genuine Tactical Bike cohort mechanics. Caller binds native events/APIs.
-- No initial/free births, global actor cap, research grants or native quality edits.
local M={Version=1}
local function sorted(t)local r={};for k in pairs(t or{})do r[#r+1]=k end;table.sort(r);return r end
local function copy(t)local r={};for k,v in pairs(t or{})do r[k]=type(v)=='table'and copy(v)or v end;return r end
local function integer(v)return type(v)=='number'and v>=0 and v<math.huge and v==math.floor(v)end
local function near(a,b)return type(a)=='number'and math.abs(a-b)<=1e-7 end
function M.New(S,F,P)
 assert(F.bike.initial_size==1 and F.bike.maximum_size==3,'Exact genuine Bike cohort profile required')
 assert(F.bike.reinforcement_disabled_value==-1 and F.bike.addon_enable_value==2,'Enable is source offset, not additional slots')
 local cost=F.bike.reinforcement_cost
 assert(cost.metal==80 and cost.energy==40 and cost.time==10 and F.bike.combat_time_multiplier==2,'Exact source reinforcement economy required')
 for _,name in ipairs({'ProveInitialProduct','Enabled','PopulationAllowed','InCombat','Placement','CreatePaid','BirthMatches','Ready'})do assert(type(P[name])=='function','Native integration required: '..name)end
 assert(integer(P.defID)and integer(P.command)and integer(P.removeCommand)and integer(P.fps)and P.fps>0,'Explicit native definition/command/game speed required')
 local R={cohorts={},member={},jobs={},failures={}};local permit;local busy=false
 local prefix='40k_bike_cohort_';local stamp=tonumber(F.source_hashes.bike_squad.sha256:sub(1,6),16)
 local function alive(id,team)
  local hp,_,_,_,built=S.GetUnitHealth(id)
  return hp and hp>0 and built and built>=1 and S.GetUnitDefID(id)==P.defID and S.GetUnitTeam(id)==team
 end
 local function put(id,k,v)S.SetUnitRulesParam(id,prefix..k,v,{private=true})end
 local function jobReceipt(c,j)
  local values={job=j and 1 or 0,tag=j and j.tag or -1,steps=j and j.steps or 0,metal=j and j.metal or 0,energy=j and j.energy or 0,paid=j and j.paid or 0,team=c.team,seed=c.seed,source=stamp}
  for k,v in pairs(values)do put(c.leader,k,v)end
 end
 local function count(c)local n=0;for _ in pairs(c.members)do n=n+1 end;return n end
 local function eligible(c)
  return P.Ready()==true and alive(c.leader,c.team)and P.Enabled(c.team)==true and count(c)<F.bike.maximum_size and P.PopulationAllowed(c.team,c.seed)==true
 end
 local function ownedHead(c,j)
  local q=S.GetUnitCommands(c.leader,-1)or{};local row=q[1]
  if row and row.id==P.command and integer(row.tag)and(j.tag==nil or row.tag==j.tag)and not j.excluded[row.tag]then return row end
 end
 local function removeTag(id,tag)
  if tag and alive(id,S.GetUnitTeam(id))then S.GiveOrderToUnit(id,P.removeCommand,{tag},0)end
 end
 function R.Cancel(seed,reason)
  local c=R.cohorts[seed];local j=R.jobs[seed];if not c then return end
  R.jobs[seed]=nil;jobReceipt(c,nil);if j then removeTag(c.leader,j.tag)end
  if reason then R.failures[seed]=reason end
 end
 function R.RegisterInitial(id,team,producer,event)
  if busy or not P.Ready()or R.member[id]or not alive(id,team)or not P.ProveInitialProduct(id,team,producer,event)then return false end
  local seed=id
  -- Native actor IDs can be reused while the original leader's cohort survives.
  -- Keep that surviving cohort independent instead of overwriting its membership.
  while R.cohorts[seed]do seed=seed+1 end
  assert(seed<16777216,'Native float cohort receipt namespace exhausted')
  local c={seed=seed,leader=id,team=team,members={[id]=true}}
  R.cohorts[seed]=c;R.member[id]=seed;put(id,'member',seed);put(id,'member_team',team);put(id,'member_source',stamp);jobReceipt(c,nil)
  return true
 end
 function R.Allow(id,team,command)
  local seed=R.member[id];local c=seed and R.cohorts[seed]
  if command~=P.command or not c or c.leader~=id or c.team~=team or R.jobs[seed]or not eligible(c)then return false end
  local excluded={};for _,row in ipairs(S.GetUnitCommands(id,-1)or{})do if row.id==command then excluded[row.tag]=true end end
  local j={tag=nil,steps=0,metal=0,energy=0,paid=0,excluded=excluded};R.jobs[seed]=j;jobReceipt(c,j);return true
 end
 function R.Fallback(id,team,command,tag)
  local seed=R.member[id];local c=seed and R.cohorts[seed];local j=seed and R.jobs[seed]
  if command~=P.command or not c or c.leader~=id or c.team~=team or not j then return false end
  local row=ownedHead(c,j)
  if not row or row.tag~=tag then return true,true end
  j.tag=tag;jobReceipt(c,j);return true,false
 end
 -- Explicit preflight consumed inside CreatePaid before Spring.CreateUnit.
 -- Pinned Lua CreateUnit does NOT emit native AllowUnitCreation; its actual
 -- synchronous UnitCreated is the independent post-creation witness below.
 function R.AuthorizeBirth(def,team,builder)
  local p=permit
  if not p or p.used or p.invalid or p.def~=def or p.team~=team or p.builder~=builder then if p then p.invalid=true end;return false end
  p.used=true;return true
 end
 function R.UnitCreated(id,def,team,builder)
  local p=permit
  if not p or not p.used or p.invalid or p.created or p.def~=def or p.team~=team or p.builder~=builder then if p then p.invalid=true end;return false end
  p.created=id;return true
 end
 local function spawn(c,j)
  local valid,position=pcall(P.Placement,c.leader,P.defID,c.team)
  if not valid or type(position)~='table'or #position~=3 then return false end
  for _,value in ipairs(position)do if type(value)~='number'or value~=value or math.abs(value)==math.huge then return false end end
  local token={def=P.defID,team=c.team,builder=c.leader,used=false,created=nil,invalid=false}
  permit=token;busy=true
  local okay,id=pcall(P.CreatePaid,P.defID,c.team,c.leader,position)
  busy=false;permit=nil
  if not okay or not integer(id)or token.invalid or not token.used or token.created~=id or R.member[id]or not P.BirthMatches(id,P.defID,c.team,position)then
   R.Cancel(c.seed,'paid_birth_unverified');return false
  end
  c.members[id]=true;R.member[id]=c.seed;put(id,'member',c.seed);put(id,'member_team',c.team);put(id,'member_source',stamp)
  local tag=j.tag;R.jobs[c.seed]=nil;jobReceipt(c,nil);removeTag(c.leader,tag);return true
 end
 function R.Frame()
  if busy then return end
  for _,seed in ipairs(sorted(R.cohorts))do
   local c=R.cohorts[seed]
   for _,id in ipairs(sorted(c.members))do if not alive(id,c.team)then R.Remove(id)end end
   c=R.cohorts[seed];local j=R.jobs[seed]
   if c and j then
    if not eligible(c)then R.Cancel(seed,'eligibility_lost')
    else
     local head=ownedHead(c,j)
     if not head then
      -- A still-queued SHIFT command waits behind ordinary orders; removing its
      -- owned tag cancels before further debit. Reservation alone never pays.
      local present=false;for _,row in ipairs(S.GetUnitCommands(c.leader,-1)or{})do if row.id==P.command and(j.tag==nil and not j.excluded[row.tag]or row.tag==j.tag)then present=true end end
      if not present then R.Cancel(seed,'owned_queue_lost')end
     else
      j.tag=head.tag
      if j.paid==1 then spawn(c,j)
      else
       local multiplier=P.InCombat(c.seed,copy(c.members))and F.bike.combat_time_multiplier or 1
       local step=1/multiplier;local total=cost.time*P.fps;local progress=math.min(total,j.steps+step)
       local metal=cost.metal*progress/total;local energy=cost.energy*progress/total
       if S.UseTeamResource(c.team,{metal=metal-j.metal,energy=energy-j.energy})then
        j.steps=progress;j.metal=metal;j.energy=energy;if progress==total then j.paid=1 end;jobReceipt(c,j)
        if j.paid==1 then spawn(c,j)end
       end
      end
     end
    end
   end
  end
 end
 function R.Remove(id)
  local seed=R.member[id];local c=seed and R.cohorts[seed];if not c then return end
  R.Cancel(seed,'member_removed_or_captured');c.members[id]=nil;R.member[id]=nil
  -- Captured actors keep their genuine native body but are not silently made
  -- into free fresh squads. Only genuine initial factory products seed cohorts.
  put(id,'member',0);put(id,'member_team',-1);put(id,'member_source',0)
  if not next(c.members)then R.cohorts[seed]=nil;return end
  c.leader=sorted(c.members)[1];jobReceipt(c,nil)
 end
 function R.Members(id)local c=R.cohorts[R.member[id]];return c and sorted(c.members)or{}end
 function R.PopulationUsage(team)
  local n=0;for _,c in pairs(R.cohorts)do if c.team==team then n=n+1 end end
  -- Genuine SBP cohort cap is 2 infantry / 1 support; reinforcement cost's
  -- population is zero. Native BAR team actor limit remains independently enforced.
  return n*2,n
 end
 function R.Snapshot()return {version=M.Version,source=stamp,cohorts=copy(R.cohorts),jobs=copy(R.jobs)}end
 function R.Restore(snapshot)
  if busy or next(R.cohorts)or type(snapshot)~='table'or snapshot.version~=M.Version or snapshot.source~=stamp then return false end
  if type(snapshot.cohorts)~='table'or type(snapshot.jobs)~='table'then return false end
  local seen={}
  for seed,c in pairs(snapshot.cohorts or{})do
   if not integer(seed)or type(c)~='table'or type(c.members)~='table'or not integer(c.leader)or not integer(c.team)then return false end
   if c.seed~=seed or not c.members[c.leader]or count(c)<1 or count(c)>F.bike.maximum_size then return false end
   for id in pairs(c.members)do
    if not integer(id)or c.members[id]~=true then return false end
    if seen[id]or not alive(id,c.team)or S.GetUnitRulesParam(id,prefix..'member')~=seed or S.GetUnitRulesParam(id,prefix..'member_team')~=c.team or S.GetUnitRulesParam(id,prefix..'member_source')~=stamp then return false end;seen[id]=seed
   end
   local j=(snapshot.jobs or{})[seed]
   if j then
    if type(j)~='table'or type(j.excluded)~='table'or(j.tag~=nil and not integer(j.tag))then return false end
    local total=cost.time*P.fps
    if not eligible(c)or type(j.steps)~='number'or j.steps<0 or j.steps>total or not near(j.metal,cost.metal*j.steps/total)or not near(j.energy,cost.energy*j.steps/total)or(j.paid~=0 and j.paid~=1)or(j.paid==1)~=(j.steps==total)then return false end
    for k,v in pairs({job=1,tag=j.tag or -1,steps=j.steps,metal=j.metal,energy=j.energy,paid=j.paid})do if S.GetUnitRulesParam(c.leader,prefix..k)~=v then return false end end
    local present=false;for _,row in ipairs(S.GetUnitCommands(c.leader,-1)or{})do if row.id==P.command and(j.tag==nil and not j.excluded[row.tag]or row.tag==j.tag)then present=true end end;if not present then return false end
   elseif S.GetUnitRulesParam(c.leader,prefix..'job')~=0 then return false end
  end
  for seed in pairs(snapshot.jobs or{})do if not snapshot.cohorts[seed]then return false end end
  R.cohorts=copy(snapshot.cohorts);R.jobs=copy(snapshot.jobs);R.member=seen;return true
 end
 return R
end
return M
