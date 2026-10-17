-- Passive receipts only: no commands, resources, creation, simulation or UI writes.
local M={MaxHWT=64,MaxSensors=128,MaxContacts=128,MaxReceipts=1024,ProjectileSamples=12,SensorPeriod=15}
local function enabled(v)return v==true or v==1 or v=='1'end
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function sorted(t)local out={};for k in pairs(t)do out[#out+1]=k end;table.sort(out);return out end
function M.Enabled(o)
 return o and enabled(o.prototype_normal_native_observer)and enabled(o.prototype_development_playtest)and enabled(o.prototype_source_progression)
  and(o.prototype_diagnostic==nil or o.prototype_diagnostic=='normal')or false
end
function M.New(S,U,W,Names,Watch,JSON)
 local O={};local hwts,sensors,contacts,seeded,watched={},{},{},{},{}
 local countH,countS,countC,receipts=0,0,0,0;local limits={};local frame=0;local sensorRevision=0
 -- Native invalid/absent objects return ZERO Lua results; normalize here.
 local function read(k,...)local f=S[k];if type(f)~='function'then return{}end;return{f(...)}end
 local function one(k,...)local a=read(k,...);return a[1]end
 local function vector(k,...)local a=read(k,...);if finite(a[1])and finite(a[2])and finite(a[3])then return{x=a[1],y=a[2],z=a[3]}end end
 local function distance(a,b)if a and b then return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2)end end
 local function emit(kind,data)
  if receipts>=M.MaxReceipts then
   if not limits.receipts then limits.receipts=true;S.Echo('40K_NORMAL_NATIVE '..JSON.Encode({kind='LIMIT',scope='receipts',frame=frame,limit=M.MaxReceipts,incomplete=true}))end
   return
  end
  receipts=receipts+1;data.kind=kind;data.frame=frame;data.sequence=receipts;S.Echo('40K_NORMAL_NATIVE '..JSON.Encode(data))
 end
 local function limit(scope,n)if not limits[scope]then limits[scope]=true;emit('LIMIT',{scope=scope,limit=n,incomplete=true})end end
 local function identity(id)
  local def=one('GetUnitDefID',id);return{unit=id,def=def,name=def and U[def]and U[def].name,team=one('GetUnitTeam',id),ally=one('GetUnitAllyTeam',id)}
 end
 local function transition(id)
  local clip=one('GetUnitRulesParam',id,'40k_transition_clip')
  local start=tonumber(one('GetUnitRulesParam',id,'40k_transition_start'));local finish=tonumber(one('GetUnitRulesParam',id,'40k_transition_end'))
  return{clip=clip,start=start,finish=finish,active=finite(start)and finite(finish)and frame>=start and frame<finish or false}
 end
 local function weaponReadback(id,slot)
  local v=read('GetUnitWeaponState',id,slot);local t=read('GetUnitWeaponTarget',id,slot)
  return{known=type(v[1])=='boolean',angleGood=v[1],loaded=v[2],reloadFrame=v[3],salvoLeft=v[4],stockpiled=v[5],target={type=t[1],user=t[2],value=t[3]}}
 end
 local function weaponStates(id)
  local def=one('GetUnitDefID',id);local out={}
  for slot in ipairs(def and U[def]and U[def].weapons or{})do out[slot]=weaponReadback(id,slot)end
  return out
 end
 local function hwtState(id)
  local h=hwts[id];if not h then return end
  local t=transition(id);local key=JSON.Encode(t)
  if key~=h.key then
   if h.state and h.state.active then emit('HWT_TRANSITION_END',{actor=identity(id),interval=h.state,projectileBirths=h.births,watchReady=h.watchReady,complete=frame>=h.state.finish and h.state.start>=h.firstFrame,reason='state_changed'})end
   h.key=key;h.state=t;h.births=0;emit('HWT_STATE',{actor=identity(id),transition=t,watchReady=h.watchReady,weapons=weaponStates(id)})
  end
  return h,t
 end
 local function sourceState(id)
  local s=identity(id);local stun=read('GetUnitIsStunned',id)
  s.active=one('GetUnitIsActive',id);s.stunned=stun[2];s.beingBuilt=stun[3]
  s.radar=one('GetUnitSensorRadius',id,'radar');s.sonar=one('GetUnitSensorRadius',id,'sonar');s.los=one('GetUnitSensorRadius',id,'los')
  s.jammer=one('GetUnitSensorRadius',id,'radarJammer');s.array=sensors[id].array
  s.eligible='unknown'
  if type(s.active)=='boolean'and type(s.stunned)=='boolean'and type(s.beingBuilt)=='boolean'then s.eligible=s.active and not s.stunned and not s.beingBuilt end
  s.commander700=(s.name=='armcom'or s.name=='smcom'or s.name=='corcom'or s.name=='nec_lord')and s.radar==700
  return s
 end
 local function hasArray(ally)
  for id,s in pairs(sensors)do if s.array and one('GetUnitAllyTeam',id)==ally then return true end end
  return false
 end
 function O.Contact(id,team,ally,def)
  if not finite(ally)or ally<0 or not hasArray(ally)or one('GetUnitAllyTeam',id)==ally then return end
  local key=ally..':'..id
  if not contacts[key]then
   if countC>=M.MaxContacts then limit('contacts',M.MaxContacts);return end
   contacts[key]={unit=id,ally=ally};countC=countC+1
  end
  contacts[key].dirty=true
 end
 local function seed(ally)
  if not finite(ally)or seeded[ally]then return end;seeded[ally]=true
  local all=one('GetAllUnits')or{};table.sort(all)
  -- Retain current contacts only; future contact events add their own pairs.
  for _,id in ipairs(all)do local t=one('GetUnitLosState',id,ally,false)
   if type(t)=='table'and(t.radar or t.los)then O.Contact(id,nil,ally)end
  end
 end
 function O.Register(id)
  frame=one('GetGameFrame')or frame
  local def=one('GetUnitDefID',id);local u=def and U[def];if not u then return end
  if u.name=='imp_heavy_weapon_team'or u.name=='imp_heavy_weapon_team_deployed'then
   if not hwts[id]then
    if countH>=M.MaxHWT then limit('hwts',M.MaxHWT)else
     countH=countH+1;local ready=true
     for _,mount in ipairs(u.weapons or{})do if not watched[mount.weaponDef or mount.weaponDefID]then ready=false end end
     hwts[id]={firstFrame=frame,births=0,samples=0,watchReady=ready};hwtState(id)
    end
   end
  end
  local array=u.name=='imp_comms_array'or u.name=='imp_marine_comms_array'
  if array or(tonumber(u.radarRadius)or 0)>0 or(tonumber(u.sonarRadius)or 0)>0 or(tonumber(u.jammerRadius)or 0)>0 then
   if not sensors[id]then
    if countS>=M.MaxSensors then limit('sensors',M.MaxSensors);return end
    sensors[id]={array=array};countS=countS+1;sensorRevision=sensorRevision+1
   end
   if array then seed(one('GetUnitAllyTeam',id))end
  end
 end
 function O.Remove(id)
  frame=one('GetGameFrame')or frame
  local h=hwts[id]
  if h then
   if h.state and h.state.active then emit('HWT_TRANSITION_END',{actor=identity(id),unit=id,interval=h.state,projectileBirths=h.births,watchReady=h.watchReady,complete=frame>=h.state.finish and h.state.start>=h.firstFrame,reason='removed_or_morphed'})end
   emit('HWT_REMOVED',{unit=id});hwts[id]=nil;countH=countH-1
  end
  if sensors[id]then emit('SENSOR_REMOVED',{unit=id,previous=sensors[id].state});sensors[id]=nil;countS=countS-1;sensorRevision=sensorRevision+1 end
  for k,c in pairs(contacts)do if c.unit==id then emit('CONTACT_REMOVED',{unit=id,ally=c.ally});contacts[k]=nil;countC=countC-1 end end
 end
 function O.Initialize()
  frame=one('GetGameFrame')or 0
  for _,name in ipairs({'imp_heavy_weapon_team','imp_heavy_weapon_team_deployed'})do
   local def=Names[name];local u=def and U[def.id]
   for _,mount in ipairs(u and u.weapons or{})do
    local w=mount.weaponDef or mount.weaponDefID
    if w and W[w]and type(Watch.SetWatchProjectile)=='function'then Watch.SetWatchProjectile(w,true);watched[w]=true end
   end
  end
  emit('READY',{version=1,passive=true,limits={hwts=M.MaxHWT,sensors=M.MaxSensors,contacts=M.MaxContacts,receipts=M.MaxReceipts,projectileSamplesPerUnit=M.ProjectileSamples},commanderConfound='Starting commander radar 700; all allied sensor sources must be considered',projectileWatch=next(watched)~=nil})
  local all=one('GetAllUnits')or{};table.sort(all);for _,id in ipairs(all)do O.Register(id)end
  O.Frame(frame);O.PostFrame(frame)
 end
 function O.Projectile(projectile,owner,weapon)
  frame=one('GetGameFrame')or frame
  if not hwts[owner]then O.Register(owner)end
  local h,t=hwtState(owner);if not h then return end
  if not weapon or weapon<0 then weapon=one('GetProjectileDefID',projectile)end
  if not watched[weapon]then return end
  if t.active then h.births=h.births+1 end
  if h.samples>=M.ProjectileSamples and not t.active then return end;h.samples=h.samples+1
  local actor=identity(owner);local u=actor.def and U[actor.def];local slot,matches=nil,0
  for n,m in ipairs(u and u.weapons or{})do if(m.weaponDef or m.weaponDefID)==weapon then slot=n;matches=matches+1 end end
  if matches~=1 then emit('HWT_PROJECTILE',{actor=actor,projectile=projectile,weapon=weapon,transition=t,status='unknown_mount',mountMatches=matches});return end
  local p=vector('GetProjectilePosition',projectile);local v=read('GetUnitWeaponVectors',owner,slot)
  local muzzle=finite(v[1])and finite(v[2])and finite(v[3])and{x=v[1],y=v[2],z=v[3]}or nil
  local cp=W[weapon].customParams or{};local pieces=one('GetUnitPieceMap',owner)or{};local piece=pieces[cp.source_muzzle]
  local marker=piece and vector('GetUnitPiecePosDir',owner,piece);local ground=p and one('GetGroundHeight',p.x,p.z)
  emit('HWT_PROJECTILE',{actor=actor,projectile=projectile,weapon=weapon,slot=slot,weaponReadback=weaponReadback(owner,slot),transition=t,transitionViolation=t.active,position=p,muzzle=muzzle,
   muzzleDirection={x=v[4],y=v[5],z=v[6]},sourceMuzzle=cp.source_muzzle,piece=piece,marker=marker,birthMuzzleDistance=distance(p,muzzle),birthMarkerDistance=distance(p,marker),
   birthAboveGround=p and finite(ground)and p.y-ground or nil,positionKnown=p~=nil and muzzle~=nil,status=t.active and 'birth_during_transition'or 'observed_birth'})
 end
 function O.Frame(f)
  frame=f;for _,id in ipairs(sorted(hwts))do hwtState(id)end
  if f%M.SensorPeriod~=0 then return end
  for _,id in ipairs(sorted(sensors))do
   local s=sourceState(id);local key=JSON.Encode(s)
   if key~=sensors[id].key then sensors[id].key=key;sensors[id].state=s;sensorRevision=sensorRevision+1;emit('SENSOR_STATE',{source=s})
    for _,c in pairs(contacts)do c.dirty=true end
   end
  end
 end
 function O.PostFrame(f)
  frame=f
  for _,key in ipairs(sorted(contacts))do local c=contacts[key]
   if c.dirty or f%M.SensorPeriod==0 then
    c.dirty=false;local t=one('GetUnitLosState',c.unit,c.ally,false);local raw=one('GetUnitLosState',c.unit,c.ally,true)
    local state={known=type(t)=='table',raw=raw,globalLos=one('GetGlobalLos',c.ally),targetAlly=one('GetUnitAllyTeam',c.unit)}
    if state.known then state.los=t.los==true;state.radar=t.radar==true;state.typed=t.typed==true;state.radarOnly=state.radar and not state.los end
    local stamp=JSON.Encode(state)..':'..sensorRevision
    if stamp~=c.key then
    c.key=stamp;local sources={};local p=vector('GetUnitPosition',c.unit)
    for _,id in ipairs(sorted(sensors))do if one('GetUnitAllyTeam',id)==c.ally then
     local s=sourceState(id);local pos=vector('GetUnitPosition',id);s.position=pos
     if p and pos then s.horizontalDistance=math.sqrt((p.x-pos.x)^2+(p.z-pos.z)^2)end
     sources[id]=s
    end end
    -- Positions are context on a native state change, never polling triggers.
    emit('RADAR_CONTACT',{actor=identity(c.unit),ally=c.ally,state=state,targetPosition=p,alliedSources=sources,sensorInventoryIncomplete=limits.sensors==true,
     attribution='Native ally-team contact; source attribution requires paired array on/off and exclusion of other sensors, sonar, jamming and global LOS'})end
   end
  end
 end
 return O
end
return M
