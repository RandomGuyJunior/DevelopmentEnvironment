-- Whole fixed-slot intent over real native bodies. No engine mutation or births.
local M={Version=1}
local function finite(n)return type(n)=='number'and n==n and n<math.huge and n> -math.huge end
local function copy(v)if type(v)~='table'then return v end;local t={};for k,x in pairs(v)do t[k]=copy(x)end;return t end
local function keys(t)local r={};for k in pairs(t)do r[#r+1]=k end;table.sort(r);return r end
function M.New(P)
 for _,name in ipairs({'State','Capacity','SlotDef','Body','Definition','Carrier','Allied','Frame','Changed'})do assert(type(P[name])=='function',name)end
 local R={Version=M.Version,records={},carriers={},member={}}
 local function release(seed)
  local r=R.records[seed];if not r then return end
  for _,id in pairs(r.members)do if R.member[id]==seed then R.member[id]=nil end end
  local c=R.carriers[r.carrier];if c then c[seed]=nil;if not next(c)then R.carriers[r.carrier]=nil end end
  R.records[seed]=nil;P.Changed(seed)
 end
 local function spent(carrier,except)
  local size,mass,actors=0,0,0;local c=P.Carrier(carrier)
  if not c then return end
  -- Cargo covered by any reservation is already charged its full-slot budget.
  for _,id in ipairs(c.cargo or{})do if not R.member[id]then local b=P.Body(id);if not b then return end;size=size+b.size;mass=mass+b.mass;actors=actors+1 end end
  for seed in pairs(R.carriers[carrier]or{})do if seed~=except then local r=R.records[seed];size=size+r.size;mass=mass+r.mass;actors=actors+r.capacity end end
  return size,mass,actors,c
 end
 function R.Request(carrier,seed)
  if R.records[seed]then return nil,'already_reserved' end
  local s=P.State(seed);local size,mass,actors,c=spent(carrier)
  if not s or not c or not c.alive or not P.Allied(s.team,c.team)then return nil,'owner_or_carrier' end
  if c.requiredProfile and s.profile~=c.requiredProfile then return nil,'carrier_profile' end
  if c.squadLimit then
   local n=0;for _ in pairs(R.carriers[carrier]or{})do n=n+1 end
   if n>=c.squadLimit then return nil,'carrier_squad_limit' end
  end
  local cap=P.Capacity(seed);if not cap or cap<1 or cap~=math.floor(cap)then return nil,'capacity' end
  local r={seed=seed,carrier=carrier,team=s.team,carrierTeam=c.team,profile=s.profile,capacity=cap,
   members={},slots={},size=0,mass=0,phase='loading',started=P.Frame(),everLoaded=false,lastHeld=0}
  local seen={};local live=0
  for slot=1,cap do
   local def=P.SlotDef(seed,slot);local template=def and P.Definition(def);local id=s.slots[slot]
   local body=id and P.Body(id)or template
   if not body or not template or not finite(body.size)or not finite(body.mass)or body.size<=0 or body.mass<=0
    or body.size>c.maxSize or body.size<(c.minSize or 0)or body.mass<(c.minMass or 0)
    or body.mass>=100000 or template.cantBeTransported then return nil,'body_native_limits' end
   if id then
    if body.jumpBusy then return nil,'jump_busy' end
    if seen[id]or R.member[id]or not body.alive or body.team~=s.team or body.transporter then return nil,'member_not_available' end
    seen[id]=true;live=live+1;r.members[slot]=id
   end
   r.slots[slot]={def=def,size=body.size,mass=body.mass}
   r.size=r.size+body.size;r.mass=r.mass+body.mass
  end
  if live==0 then return nil,'wiped' end
  if size+r.size>c.capacity or mass+r.mass>c.massCapacity or(c.actorLimit and actors+cap>c.actorLimit)then return nil,'full_fixed_slots_do_not_fit' end
  R.records[seed]=r;R.carriers[carrier]=R.carriers[carrier]or{};R.carriers[carrier][seed]=true
  local ordered={};for _,slot in ipairs(keys(r.members))do local id=r.members[slot];R.member[id]=seed;ordered[#ordered+1]=id end
  P.Changed(seed);return ordered
 end
 function R.Permit(carrier,id)
  local seed=R.member[id];local r=seed and R.records[seed];local b=P.Body(id)
  if b and b.jumpBusy then return false end
  if r then return r.carrier==carrier and r.phase=='loading'and b and b.alive and b.team==r.team and not b.transporter or false end
  -- Unrelated native cargo must not steal reserved footprint/mass capacity.
  local size,mass,actors,c=spent(carrier)
  if c and c.requiredProfile then return false end
  if not next(R.carriers[carrier]or{})then return true end
  return b and c and b.alive and size+b.size<=c.capacity and mass+b.mass<=c.massCapacity
   and(not c.actorLimit or actors+1<=c.actorLimit)or false
 end
 function R.Busy(id)return R.member[id]~=nil end
 function R.Reserved(seed)return R.records[seed]~=nil end
 function R.Cancel(carrier)
  for _,seed in ipairs(keys(R.carriers[carrier]or{}))do local r=R.records[seed];r.phase='cancelled';P.Changed(seed)end
  R.Tick()
 end
 function R.CancelSeed(seed)
  local r=R.records[seed];if r then r.phase='cancelled';P.Changed(seed);R.Tick()end
 end
 function R.BeginUnload(carrier)
  for _,seed in ipairs(keys(R.carriers[carrier]or{}))do R.records[seed].phase='unloading' end
 end
 function R.Tick()
  for _,seed in ipairs(keys(R.records))do
   local r=R.records[seed];local s=P.State(seed);local c=P.Carrier(r.carrier);local held,live=0,0
   local priorPhase,priorHeld,removed=r.phase,r.lastHeld,false
   if not s or not c or not c.alive then release(seed)
   else
    if s.team~=r.team or c.team~=r.carrierTeam or s.profile~=r.profile or P.Capacity(seed)~=r.capacity then r.phase='cancelled' end
    for slot,id in pairs(r.members)do
     local b=P.Body(id)
     if b and b.alive then
      live=live+1
      if b.transporter==r.carrier then held=held+1
      elseif b.transporter then r.phase='cancelled' end
      if s.slots[slot]~=id or b.team~=r.team then r.phase='cancelled' end
     else R.member[id]=nil;r.members[slot]=nil;removed=true end
    end
    -- No repair/replacement may inject a newly born body into an old reservation.
    for slot,id in pairs(s.slots)do local b=P.Body(id);if b and b.alive and r.members[slot]~=id then r.phase='cancelled' end end
    if held<r.lastHeld then r.phase='unloading' end
    if held>0 then r.everLoaded=true end
    if r.phase=='loading'and held==live and live>0 then r.phase='embarked' end
    if r.phase=='loading'and P.Frame()-r.started>5400 then r.phase='cancelled' end
    r.lastHeld=held
    if live==0 or(held==0 and(r.phase=='cancelled'or r.phase=='unloading'))then release(seed)
    elseif removed or r.phase~=priorPhase or r.lastHeld~=priorHeld then P.Changed(seed)end
   end
  end
 end
 function R.Snapshot()R.Tick();return{version=M.Version,records=copy(R.records)}end
 function R.Restore(snapshot)
  if next(R.records)or type(snapshot)~='table'or snapshot.version~=M.Version or type(snapshot.records)~='table'then return false end
  local records,member,carriers={},{},{}
  for seed,saved in pairs(snapshot.records)do
   if type(saved)~='table'or type(saved.members)~='table'or type(saved.slots)~='table'
    or not finite(saved.size)or not finite(saved.mass)or not finite(saved.capacity)or saved.capacity<1 or saved.capacity~=math.floor(saved.capacity)then return false end
   local s=P.State(seed);local c=P.Carrier(saved.carrier)
   if type(seed)~='number'or saved.seed~=seed or not s or not c or not c.alive
    or s.profile~=saved.profile or P.Capacity(seed)~=saved.capacity
    or not ({loading=true,embarked=true,unloading=true,cancelled=true})[saved.phase]
    or not finite(saved.started)or saved.started<0 or saved.started>P.Frame()then return false end
   for slot in pairs(saved.slots)do if not finite(slot)or slot<1 or slot>saved.capacity or slot~=math.floor(slot)then return false end end
   for slot in pairs(saved.members)do if not finite(slot)or slot<1 or slot>saved.capacity or slot~=math.floor(slot)then return false end end
   local size,mass=0,0;local r=copy(saved);local held=0
   for slot=1,r.capacity do
    local v=r.slots and r.slots[slot];local d=v and P.Definition(v.def)
    if not d or not finite(v.size)or not finite(v.mass)or v.size<=0 or v.mass<=0 or v.size>c.maxSize then return false end
    size=size+v.size;mass=mass+v.mass
    local id=r.members and r.members[slot]
    if id then
     local b=P.Body(id);if member[id]or not b or not b.alive or s.slots[slot]~=id or(b.transporter and b.transporter~=r.carrier)then return false end
     if math.abs(v.size-b.size)>1e-6 or math.abs(v.mass-b.mass)>1e-3 then return false end
     if b.transporter==r.carrier then held=held+1 end
     member[id]=seed
    elseif s.slots[slot]or math.abs(v.size-d.size)>1e-6 or math.abs(v.mass-d.mass)>1e-3 then return false end
   end
   if math.abs(size-r.size)>1e-6 or math.abs(mass-r.mass)>1e-6 then return false end
   if s.team~=r.team or c.team~=r.carrierTeam then r.phase='cancelled' end
   r.lastHeld=held;records[seed]=r;carriers[r.carrier]=carriers[r.carrier]or{};carriers[r.carrier][seed]=true
  end
  R.records,R.member,R.carriers=records,member,carriers
  for carrier in pairs(carriers)do local sz,m,actors,c=spent(carrier)
   if not c or sz>c.capacity or m>c.massCapacity or(c.actorLimit and actors>c.actorLimit)then R.records,R.member,R.carriers={},{},{};return false end
   local n=0;for seed in pairs(carriers[carrier])do
    n=n+1;if c.requiredProfile and records[seed].profile~=c.requiredProfile then R.records,R.member,R.carriers={},{},{};return false end
   end
   if c.squadLimit and n>c.squadLimit then R.records,R.member,R.carriers={},{},{};return false end
  end
  R.Tick();return true
 end
 return R
end
return M
