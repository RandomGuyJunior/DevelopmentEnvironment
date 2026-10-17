-- Synced logical membership over actual native bodies; no reinforcement menu.
local M={Version=2}
local function keys(t)local a={};for k in pairs(t)do a[#a+1]=k end;table.sort(a);return a end
local function copy(v)if type(v)~='table'then return v end;local o={};for k,x in pairs(v)do o[k]=copy(x)end;return o end
function M.New(P,profiles)
 for _,k in ipairs({'Live','Publish','Plan','Create','Destroy','Use','Health','Experience','Orders','Role','Cost','Researched','Replace','Capacity','SetInvestment','Serial','Definition','Team','Transfer'})do assert(type(P[k])=='function',k)end
 local R={Version=M.Version,squads={},member={},pending={},mutating={},serial=P.Serial()or 0,repair={},researchPending={}}
 local function lead(s)for _,slot in ipairs(keys(s.slots))do if s.slots[slot]then return s.slots[slot]end end end
 local function role(s,slot)return P.Role(s.profile,slot,P.Researched(s.team,s.profile))end
 local function count(s)local n=0;for _,id in pairs(s.slots)do if id then n=n+1 end end;return n end
 local function publish(s)
  s.leader=lead(s);local health,max=0,0
  for _,id in pairs(s.slots)do local h,m=P.Health(id);health=health+(h or 0);max=max+(m or 0)end
  for slot,id in pairs(s.slots)do P.Publish(id,s,slot,count(s),health,max)end
 end
 function R.Reserved(team,except)
  local n=0;for id,p in pairs(R.pending)do if id~=except and p.team==team then n=n+#p.plan end end;return n
 end
 function R.CanFinish(id,key,team,factory)
  local p=assert(profiles.profiles[key]);local names={}
  for slot=2,p.capacity do names[#names+1]=P.Role(key,slot,P.Researched(team,key))end
  if not P.Capacity(team,#names+R.Reserved(team,id))then R.pending[id]=nil;return false end
  local plan=P.Plan(id,names,R.pending,factory)
  if not plan or #plan~=#names then R.pending[id]=nil;return false end
  R.pending[id]={key=key,team=team,factory=factory,plan=plan};return true
 end
 function R.Finish(id,key,team,factory)
  if R.member[id]then return false end
  if not P.Live(id,team)then R.pending[id]=nil;return false,'invalid_native_product'end
  if not R.CanFinish(id,key,team,factory)then return false,'preflight_changed'end
  local delivery=R.pending[id];local p=profiles.profiles[key];local created={}
  R.creating=true
  for i,pos in ipairs(delivery.plan)do
   local def=P.Role(key,i+1,P.Researched(team,key));local child=P.Create(def,team,pos,factory)
   if not child or not P.Live(child,team)then
    -- A non-nil rejected native birth has no paid squad ownership. Roll it
    -- back as well as earlier births; never leave an independent free actor.
    if child then created[#created+1]=child end
    for _,other in ipairs(created)do R.mutating[other]=true;P.Destroy(other);R.mutating[other]=nil end
    R.creating=false;R.pending[id]=nil;return false,(child and 'unfinished_member:'or'native_create_refused:')..def
   end
   created[#created+1]=child
  end
  -- Later native creation callbacks can invalidate an earlier body.
  local complete=P.Live(id,team)
  for _,child in ipairs(created)do if not P.Live(child,team)then complete=false end end
  if not complete then
   for _,other in ipairs(created)do R.mutating[other]=true;P.Destroy(other);R.mutating[other]=nil end
   R.creating=false;R.pending[id]=nil;return false,'native_product_invalidated'
  end
  R.creating=false;R.pending[id]=nil;R.serial=R.serial+1;P.Serial(R.serial)
  local s={id=R.serial,profile=key,team=team,slots={[1]=id},generations={},investments={}}
  for i,child in ipairs(created)do s.slots[i+1]=child end
  for slot,member in pairs(s.slots)do s.generations[slot]=1;R.member[member]={squad=s.id,slot=slot};s.investments[slot]=copy(P.Cost(P.Role(key,slot,false)));P.SetInvestment(member,s.investments[slot])end
  R.squads[s.id]=s;publish(s);R.RefreshResearch(s.id)
  -- Genuine native factory rally is copied from its actual paid output, not invented.
  if P.FactoryOrders then local orders=P.FactoryOrders(factory,id);if orders then for _,child in ipairs(created)do P.Orders(child,orders)end end end
  return s.id
 end
 function R.Remove(id)
  R.pending[id]=nil;if R.mutating[id]then return end
  local m=R.member[id];local s=m and R.squads[m.squad];if not s then return end
  R.member[id]=nil;s.slots[m.slot]=nil
  if not next(s.slots)then R.squads[s.id]=nil;R.repair[s.id]=nil;R.researchPending[s.id]=nil;return end
  publish(s)
 end
 function R.Get(id)local m=R.member[id];return m and R.squads[m.squad]end
 function R.Members(id)local s=R.Get(id);local a={};if s then for _,slot in ipairs(keys(s.slots))do a[#a+1]=s.slots[slot]end end;return a end
 function R.RefreshResearch(seed)
  local s=R.squads[seed];if not s then R.researchPending[seed]=nil;return end
  local pending=false
  for _,slot in ipairs(keys(s.slots))do
   local old=s.slots[slot];local wanted=role(s,slot)
   local mismatch=P.Definition(old)~=wanted
   if mismatch and not(P.Busy and P.Busy(old))then
    local paidInvestment=s.investments[slot]
    R.mutating[old]=true;local new=P.Replace(old,wanted,s.team);R.mutating[old]=nil
    if new and P.Live(new,s.team)then
     R.member[old]=nil;s.slots[slot]=new;R.member[new]={squad=s.id,slot=slot};P.SetInvestment(new,paidInvestment)
    else
     -- Replace must retain the old body unless its returned body is live.
     if new then R.mutating[new]=true;P.Destroy(new);R.mutating[new]=nil end
     -- An unexpected casualty callback during Replace was mutation-guarded.
     if not P.Live(old,s.team)then R.Remove(old)end
    end
   end
   -- Retry only an unresolved living role; research never fills a missing slot.
   if mismatch and s.slots[slot] and P.Definition(s.slots[slot])~=wanted then pending=true end
  end
  R.researchPending[seed]=R.squads[seed]and pending or nil
  publish(s)
 end
 function R.Transfer(id,team)
  local s=R.Get(id);if not s or s.team==team or R.transferring then return end
  R.transferring=true;s.team=team;R.repair[s.id]=nil
  for _,member in ipairs(R.Members(id))do if P.Team(member)~=team then P.Transfer(member,team)end end
  R.transferring=false;R.RefreshResearch(s.id)
 end
 function R.NeedsRepair(id)
  local s=R.Get(id);if not s then return false end
  if count(s)<profiles.profiles[s.profile].capacity then return true end
  for _,member in pairs(s.slots)do local h,max=P.Health(member);if h and h<max-.01 then return true end end;return false
 end
 function R.RepairStep(seed,team,work)
  local s=R.squads[seed];if not s or(s.team~=team and not(P.Allied and P.Allied(s.team,team)))or work<=0 then return false end
  if P.Transported then for _,member in pairs(s.slots)do if P.Transported(member)then return false end end end
  if P.Busy then for _,member in pairs(s.slots)do if P.Busy(member)then return false end end end
  -- First heal existing wounded members without resetting any other member or XP.
  for _,slot in ipairs(keys(s.slots))do
   local id=s.slots[slot];local h,max=P.Health(id)
   if h and h<max-.01 then
    local c=s.investments[slot];local amount=math.min(work,c.work*(max-h)/max)
    if P.Use(team,0,c.energy*amount/c.work*.5)then P.Health(id,math.min(max,h+max*amount/c.work));publish(s)end
    return true
   end
  end
  local p=profiles.profiles[s.profile];local job=R.repair[seed];local slot
  -- Finish the existing missing-slot bill before newly missing lower slots.
  -- Leader death must not discard work/resources already paid by a builder.
  if job and not s.slots[job.slot]then slot=job.slot end
  if not slot then for i=1,p.capacity do if not s.slots[i]then slot=i;break end end end
  if not slot then R.repair[seed]=nil;return false end
  local wanted=role(s,slot)
  if not job or job.slot~=slot then job={slot=slot,work=0,metal=0,energy=0,def=wanted};R.repair[seed]=job end
  -- A research change never grants work/resources or changes the slot's original bill.
  local c=P.Cost(job.def);local amount=math.min(work,c.work-job.work)
  if amount>0 and P.Use(team,c.metal*amount/c.work,c.energy*amount/c.work)then
   job.work=job.work+amount;job.metal=job.metal+c.metal*amount/c.work;job.energy=job.energy+c.energy*amount/c.work
  end
  if job.work>=c.work-1e-7 and P.Capacity(s.team,1+R.Reserved(s.team))then
   local positions=P.Plan(s.leader,{wanted},R.pending,nil)
   if positions and positions[1]then
    R.creating=true;local member=P.Create(wanted,s.team,positions[1],nil);R.creating=false
    if member and P.Live(member,s.team)then
     local survivingLeader=s.leader;local survivingOrders=P.Orders(survivingLeader)
     if P.InheritState then P.InheritState(member,survivingLeader)end
     s.slots[slot]=member;s.generations[slot]=(s.generations[slot]or 1)+1;R.member[member]={squad=seed,slot=slot}
     s.investments[slot]={metal=job.metal,energy=job.energy,work=c.work}
     P.SetInvestment(member,s.investments[slot]);P.Experience(member,0);R.repair[seed]=nil;publish(s)
     P.Orders(member,survivingOrders)
    elseif member then
     -- Keep the paid job for a legal retry, but destroy this rejected actor.
     R.mutating[member]=true;P.Destroy(member);R.mutating[member]=nil
    end
   end
  end
  publish(s);return true
 end
 function R.Snapshot()return{version=M.Version,serial=R.serial,squads=copy(R.squads),repair=copy(R.repair)}end
 function R.Restore(snapshot)
  if type(snapshot)~='table'or snapshot.version~=M.Version or next(R.squads)then return false end
  local members={}
  -- A paid repair belongs to an extant squad; reject orphan/foreign bills.
  for seed in pairs(snapshot.repair or{})do if not(snapshot.squads or{})[seed]then return false end end
  for seed,s in pairs(snapshot.squads or{})do
   local p=profiles.profiles[s.profile];if not p or seed~=s.id or type(s.slots)~='table'or not next(s.slots)or type(s.investments)~='table'or type(s.generations)~='table'then return false end
   for slot,generation in pairs(s.generations)do if type(slot)~='number'or slot<1 or slot>p.capacity or slot~=math.floor(slot)or type(generation)~='number'or generation<1 or generation~=math.floor(generation)or generation==math.huge then return false end end
   for slot=1,p.capacity do if not s.generations[slot]then return false end end
   for slot in pairs(s.slots)do local c=s.investments[slot];if not c then return false end;for _,k in ipairs({'metal','energy','work'})do if type(c[k])~='number'or c[k]~=c[k]or c[k]<0 or c[k]==math.huge then return false end end end
   for slot,id in pairs(s.slots)do if slot<1 or slot>p.capacity or slot~=math.floor(slot)or members[id]or not P.Live(id,s.team)then return false end;members[id]={squad=seed,slot=slot}end
   local j=(snapshot.repair or{})[seed]
   if j then
    if type(j)~='table'or type(j.slot)~='number'or j.slot~=j.slot or j.slot<1 or j.slot>p.capacity or j.slot~=math.floor(j.slot)then return false end
    -- Research may have changed during paid work. Both historical ordinary
    -- bills and this slot's genuine specialist bill remain valid; current
    -- research does not rewrite the resources already invested.
    if j.def~=p.member and not(j.slot==p.specialSlot and j.def==p.special)then return false end
    local c=P.Cost(j.def);local function close(a,b,scale)return type(a)=='number'and a==a and math.abs(a-b)<=1e-6*math.max(1,scale)end
    if s.slots[j.slot]or type(j.work)~='number'or j.work~=j.work or j.work<0 or j.work>c.work*(1+1e-6)or not close(j.metal,c.metal*j.work/c.work,c.metal)or not close(j.energy,c.energy*j.work/c.work,c.energy)then return false end
    j.work=math.min(j.work,c.work)
   end
  end
  R.squads=copy(snapshot.squads);R.repair=copy(snapshot.repair or{});R.member=members;R.serial=math.max(snapshot.serial or 0,R.serial)
  for _,s in pairs(R.squads)do publish(s)end;return true
 end
 return R
end
return M
