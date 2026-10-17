-- Numeric native UnitRules persistence only. Native cargo and squad births remain engine/owner responsibilities.
local M={Version=1,Prefix='40k_squad_transport_save_',MaxRecords=128,MaxSlots=64}
local phases={loading=1,embarked=2,unloading=3,cancelled=4};local byPhase={[1]='loading',[2]='embarked',[3]='unloading',[4]='cancelled'}
local function finite(v)return type(v)=='number'and v==v and v<math.huge and v> -math.huge end
local function integer(v,min,max)return finite(v)and v%1==0 and v>=min and v<=max end
local function keys(t)local a={};for k in pairs(t)do a[#a+1]=k end;table.sort(a);return a end
function M.New(S,P,profiles)
 for _,k in ipairs({'GetAllUnits','ValidUnitID','GetUnitIsDead','GetUnitDefID','GetUnitTeam','GetGameFrame','GetUnitRulesParam','SetUnitRulesParam'})do assert(type(S[k])=='function',k)end
 assert(type(P.State)=='function'and type(P.Body)=='function');assert(profiles and profiles.byID and profiles.profiles)
 local A={};local busy=false;local baseline={};local activeKeys
 local function signature(r)return r.carrier..":"..r.started..":"..r.profile end
 local function alive(id)return integer(id,0,16777215)and S.ValidUnitID(id)and not S.GetUnitIsDead(id)end
 local function get(id,key)return S.GetUnitRulesParam(id,M.Prefix..key)end
 local function put(id,key,v)assert(finite(v));S.SetUnitRulesParam(id,M.Prefix..key,v,{private=true});if activeKeys and key~='complete'and key~='checksum'then activeKeys[key]=true end end
 local function checksum(id,fields)
  local h=0;for _,key in ipairs(keys(fields))do local value=get(id,key);if not finite(value)then return nil end;local text=key..':'..string.format('%.9g',value);for i=1,#text do h=(h*31+text:byte(i))%16777213 end end;return h
 end
 local function field(row,k)return 'r'..row..'_'..k end
 local function rowValid(r)
  if type(r)~='table'or not integer(r.seed,1,16777215)or not alive(r.carrier)or not integer(r.capacity,1,M.MaxSlots)or not phases[r.phase]
   or not integer(r.team,0,16777215)or not integer(r.carrierTeam,0,16777215)or not integer(r.started,0,math.min(S.GetGameFrame(),16777215))or type(r.everLoaded)~='boolean'
   or not integer(r.lastHeld,0,r.capacity)or not finite(r.size)or r.size<=0 or not finite(r.mass)or r.mass<=0 then return nil,'record'end
  local profile=profiles.profiles[r.profile];local s=P.State(r.seed)
  if not profile or profile.capacity~=r.capacity or not integer(profile.id,1,16777215)or profiles.byID[profile.id]~=r.profile or not s or s.profile~=r.profile
   or type(s.generations)~='table'or type(r.members)~='table'or type(r.slots)~='table'then return nil,'squad'end
  local generations={};local live=0
  for slot=1,r.capacity do
   local v=r.slots[slot];local id=r.members[slot];local generation=s.generations[slot]
   if not v or not integer(v.def,1,16777215)or not finite(v.size)or v.size<=0 or not finite(v.mass)or v.mass<=0 or not integer(generation,1,16777215)then return nil,'slot'end
   if id then
    local b=P.Body(id)
    if not alive(id)or not b or not b.alive or s.slots[slot]~=id or S.GetUnitDefID(id)~=v.def or(b.transporter and b.transporter~=r.carrier)then return nil,'member'end
    live=live+1
   elseif s.slots[slot]then return nil,'missing_member'end
   generations[slot]=generation
  end
  if live==0 then return nil,'wiped'end
  return {profile=profile.id,generations=generations}
 end
 -- Call only after a completed policy mutation/Tick. Changed marks dirty; must not reenter Save.
 function A.Save(R)
  if busy then return false,'reentrant'end;busy=true
  if S.GetGameFrame()>16777215 then busy=false;return false,'numeric_frame_precision'end
  local snapshot=R.Snapshot();if R.Version~=M.Version or type(snapshot)~='table'or snapshot.version~=M.Version or type(snapshot.records)~='table'then busy=false;return false,'policy_version'end;local groups={};local prepared={};local n=0
  for _,seed in ipairs(keys(snapshot.records))do
   local r=snapshot.records[seed];local meta,why=rowValid(r)
   if not meta then busy=false;return false,why end
   n=n+1;if n>M.MaxRecords then busy=false;return false,'too_many_records'end
   local old=baseline[seed];if old and old.signature==signature(r)then for slot=1,r.capacity do if old.generations[slot]~=meta.generations[slot]then busy=false;return false,'reservation_generation_changed'end end end
   prepared[seed]=meta;groups[r.carrier]=groups[r.carrier]or{};groups[r.carrier][seed]=r
  end
  -- Validate everything before writing. Commit marker remains 0 for any interrupted carrier write.
  local units=S.GetAllUnits();table.sort(units)
  for _,carrier in ipairs(units)do
   if alive(carrier)and(groups[carrier]or get(carrier,'version')~=nil)then
    activeKeys={};put(carrier,'complete',0);put(carrier,'version',M.Version);put(carrier,'carrier_def',S.GetUnitDefID(carrier));put(carrier,'carrier_team',S.GetUnitTeam(carrier));put(carrier,'frame',S.GetGameFrame())
    local seeds=keys(groups[carrier]or{});put(carrier,'count',#seeds)
    for i,seed in ipairs(seeds)do
     local r=groups[carrier][seed];local meta=prepared[seed]
     for _,k in ipairs({'seed','team','carrierTeam','capacity','started','lastHeld','size','mass'})do put(carrier,field(i,k),r[k])end
     put(carrier,field(i,'profile'),meta.profile);put(carrier,field(i,'phase'),phases[r.phase]);put(carrier,field(i,'everLoaded'),r.everLoaded and 1 or 0)
     for slot=1,r.capacity do
      local v=r.slots[slot];local prefix=field(i,'s'..slot..'_')
      put(carrier,prefix..'member',r.members[slot]or -1);put(carrier,prefix..'generation',meta.generations[slot])
      for _,k in ipairs({'def','size','mass'})do put(carrier,prefix..k,v[k])end
     end
    end
    put(carrier,'checksum',assert(checksum(carrier,activeKeys)));put(carrier,'complete',1);activeKeys=nil
   end
  end
  baseline={};for seed,r in pairs(snapshot.records)do baseline[seed]={signature=signature(r),generations=prepared[seed].generations}end
  busy=false;return true
 end
 -- Invoke AFTER squad Restore and AFTER native carried-body relationships are readable.
 function A.Restore(R)
  if R.Version~=M.Version then return false,'policy_version'end
  if busy or next(R.records)then return false,'restore_not_empty'end
  local snapshot={version=R.Version,records={}};local restoredBaseline={};local units=S.GetAllUnits();table.sort(units);local total=0
  for _,carrier in ipairs(units)do
   local version=get(carrier,'version');local complete=get(carrier,'complete');local count=get(carrier,'count')
   if version~=nil or complete~=nil or count~=nil then
    if version~=M.Version or complete~=1 or not integer(count,0,M.MaxRecords)or not alive(carrier)or get(carrier,'carrier_def')~=S.GetUnitDefID(carrier)
     or not integer(get(carrier,'frame'),0,math.min(S.GetGameFrame(),16777215))or not integer(get(carrier,'carrier_team'),0,16777215)then return false,'partial_or_carrier'end
    local fields={version=true,carrier_def=true,carrier_team=true,frame=true,count=true}
    for i=1,count do
     total=total+1;if total>M.MaxRecords then return false,'too_many_records'end
     local r={carrier=carrier,members={},slots={}}
     for _,k in ipairs({'seed','team','carrierTeam','capacity','started','lastHeld','size','mass'})do fields[field(i,k)]=true;r[k]=get(carrier,field(i,k))end
     for _,k in ipairs({'profile','phase','everLoaded'})do fields[field(i,k)]=true end
     local profileID=get(carrier,field(i,'profile'));r.profile=profiles.byID[profileID];r.phase=byPhase[get(carrier,field(i,'phase'))]
     local loaded=get(carrier,field(i,'everLoaded'));if loaded~=0 and loaded~=1 then return false,'invalid_boolean'end;r.everLoaded=loaded==1
     if not integer(r.capacity,1,M.MaxSlots)or not integer(r.seed,1,16777215)or snapshot.records[r.seed]then return false,'identity'end
     local s=P.State(r.seed);if not s or type(s.generations)~='table'then return false,'squads_not_restored'end
     for slot=1,r.capacity do
      local prefix=field(i,'s'..slot..'_');for _,k in ipairs({'member','generation','def','size','mass'})do fields[prefix..k]=true end;local id=get(carrier,prefix..'member');local generation=get(carrier,prefix..'generation')
      if not integer(generation,1,16777215)or generation~=s.generations[slot]or not integer(id,-1,16777215)then return false,'slot_generation'end
      if id~=-1 then r.members[slot]=id end
      local v={};for _,k in ipairs({'def','size','mass'})do v[k]=get(carrier,prefix..k)end;r.slots[slot]=v
     end
     -- Native RulesParam numbers are float32; recompute exact policy sums from persisted per-slot native values.
     local size,mass=0,0;for slot=1,r.capacity do local v=r.slots[slot];if not finite(v.size)or not finite(v.mass)then return false,'slot_totals'end;size=size+v.size;mass=mass+v.mass end
     if not finite(r.size)or not finite(r.mass)or math.abs(size-r.size)>math.max(1e-6,math.abs(size)*2e-7)or math.abs(mass-r.mass)>math.max(1e-6,math.abs(mass)*2e-7)then return false,'slot_totals'end
     r.size,r.mass=size,mass
     local valid,why=rowValid(r);if not valid then return false,why end
     -- Captures cancel intent; held cargo remains held until ordinary native unload/death.
     if s.team~=r.team or S.GetUnitTeam(carrier)~=r.carrierTeam then r.phase='cancelled'end
     for _,id in pairs(r.members)do local b=P.Body(id);if b.team~=s.team then r.phase='cancelled'end end
     restoredBaseline[r.seed]={signature=signature(r),generations=valid.generations};snapshot.records[r.seed]=r
    end
    if checksum(carrier,fields)~=get(carrier,'checksum')then return false,'checksum'end
   end
  end
  local ok,why=R.Restore(snapshot);if ok then baseline=restoredBaseline end;return ok,why
 end
 return A
end
return M
