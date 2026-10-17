-- Read-only synced state observer. Explicit bounded common frames only.
local M={Version=1}
-- Pinned native log_record_t.msg is32768 bytes; hex payload stays below it.
local LIMIT={frames=8,units=128,squads=32,teams=8,queue=24,nodes=20000,bytes=15360,depth=16}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function ordered(t)
 local r={};for k in pairs(t)do assert(type(k)=='number'or type(k)=='string','unsupported_key_type');r[#r+1]=k end
 table.sort(r,function(a,b)if type(a)~=type(b)then return type(a)<type(b)end;return a<b end);return r
end
-- Typed, length-prefixed serialization; numbers keep full double precision.
-- No field omission, tolerance, key renaming, value rebasing or queue rewriting.
function M.Encode(value)
 local stack={};local nodes,bytes=0,0;local out={}
 local function put(v)bytes=bytes+#v;assert(bytes<=LIMIT.bytes,'serialized_byte_cap');out[#out+1]=v end
 local function visit(v,depth)
  nodes=nodes+1;assert(nodes<=LIMIT.nodes,'node_cap');assert(depth<=LIMIT.depth,'depth_cap')
  local t=type(v)
  if t=='table'then
   assert(not stack[v],'cyclic_state');stack[v]=true;local keys=ordered(v);put('t'..#keys..':')
   for _,key in ipairs(keys)do visit(key,depth+1);visit(v[key],depth+1)end;stack[v]=nil
  elseif t=='string'then put('s'..#v..':'..v)
  elseif t=='number'then assert(finite(v),'nonfinite_number');local text=string.format('%.17g',v);put('n'..#text..':'..text)
  elseif t=='boolean'then put(v and'b1'or'b0')
  elseif t=='nil'then put('z')else error('unsupported_value_type:'..t)end
 end
 visit(value,0);return table.concat(out)
end
function M.Checksum(encoded)
 local h=0;for i=1,#encoded do h=(h*65599+encoded:byte(i))%4294967296 end
 return string.format('%08x',h) -- Reader additionally SHA256-hashes exact bytes.
end
function M.Frames(text)
 assert(type(text)=='string'and #text<=80 and text:match('^%d[%d,]*$')and not text:find(',,',1,true)and text:sub(-1)~=',' ,'invalid_frame_list')
 local frames={};local last=-1
 for word in text:gmatch('[^,]+')do local n=tonumber(word);assert(n and n==math.floor(n)and n>=1 and n<=36000 and n>last,'invalid_common_frame');frames[#frames+1]=n;last=n end
 assert(#frames>0 and #frames<=LIMIT.frames,'frame_count_cap');return frames
end
function M.New(S,GG,metadata,frameText,notify)
 for _,name in ipairs({'GetGameFrame','GetAllUnits','ValidUnitID','GetUnitIsDead','GetUnitDefID','GetUnitTeam','GetUnitHealth','GetUnitCosts','GetUnitExperience','GetUnitCommands','GetUnitPosition','GetUnitVelocity','GetUnitHeading','GetUnitStates','GetTeamList','GetTeamResources'})do assert(type(S[name])=='function','missing_api:'..name)end
 assert(type(notify)=='function'and type(metadata)=='table','explicit_observer_interfaces')
 assert(type(metadata.source)=='string'and metadata.source:match('^%x+$')and #metadata.source==40,'source_pin_missing')
 assert(type(metadata.engine)=='string'and #metadata.engine>0 and type(metadata.engineFull)=='string'and #metadata.engineFull>0,'engine_identity_missing')
 for _,key in ipairs({'gameChecksum','mapChecksum'})do assert(type(metadata[key])=='string'and #metadata[key]==128 and metadata[key]:match('^%x+$'),'native_sha512_checksum_missing:'..key)end
 local frames=M.Frames(frameText);local nextIndex=1;local failed=false
 local function count(table_,max)local n=0;for _ in pairs(table_)do n=n+1;assert(n<=max,'state_count_cap')end;return n end
 local function tuple(fn,id,n)local values={fn(id)};assert(#values==n,'native_tuple_incomplete');for _,v in ipairs(values)do assert(finite(v),'native_tuple_nonfinite')end;return values end
 local function capture(frame)
  assert(frame==S.GetGameFrame(),'native_frame_mismatch')
  local R,C=GG.Recoil40KSquads,GG.Recoil40KResearch
  assert(R and type(R.Snapshot)=='function'and R.squads and R.repair and R.pending,'squad_owner_missing')
  assert(C and C.jobs and C.done and C.tiers and C.reserved,'research_owner_missing')
  count(R.squads,LIMIT.squads);count(R.repair,LIMIT.squads);count(R.pending,LIMIT.squads);count(C.jobs,LIMIT.units)
  local ids=S.GetAllUnits();assert(type(ids)=='table'and #ids<=LIMIT.units and count(ids,LIMIT.units)==#ids,'native_unit_cap_or_missing');for k in pairs(ids)do assert(type(k)=='number'and k>=1 and k<=#ids and k==math.floor(k),'native_unit_array_malformed')end;table.sort(ids)
  local bodies={};local seen={}
  for _,id in ipairs(ids)do
   assert(type(id)=='number'and id==math.floor(id)and not seen[id]and S.ValidUnitID(id)and not S.GetUnitIsDead(id),'native_living_identity_invalid');seen[id]=true
   local def,team=S.GetUnitDefID(id),S.GetUnitTeam(id);assert(type(def)=='number'and type(team)=='number','native_owner_or_definition_missing')
   local queue=S.GetUnitCommands(id,LIMIT.queue+1);assert(type(queue)=='table'and #queue<=LIMIT.queue and count(queue,LIMIT.queue)==#queue,'queue_cap_or_missing')
   for k in pairs(queue)do assert(type(k)=='number'and k>=1 and k<=#queue and k==math.floor(k),'native_queue_array_malformed')end
   local xp,heading,states=S.GetUnitExperience(id),S.GetUnitHeading(id),S.GetUnitStates(id);assert(finite(xp)and finite(heading)and type(states)=='table','native_body_fields_missing')
   bodies[id]={id=id,def=def,team=team,health=tuple(S.GetUnitHealth,id,5),cost=tuple(S.GetUnitCosts,id,3),xp=xp,heading=heading,states=states,
    position=tuple(S.GetUnitPosition,id,3),velocity=tuple(S.GetUnitVelocity,id,4),queue=queue}
  end
  local teams=S.GetTeamList();assert(type(teams)=='table'and #teams<=LIMIT.teams and count(teams,LIMIT.teams)==#teams,'team_cap_or_missing');for k in pairs(teams)do assert(type(k)=='number'and k>=1 and k<=#teams and k==math.floor(k),'native_team_array_malformed')end;table.sort(teams)
  local resources={};for _,team in ipairs(teams)do assert(finite(team)and team>=0 and team==math.floor(team),'native_team_identity_invalid');assert(not resources[team],'duplicate_native_team');local m={S.GetTeamResources(team,'metal')};local e={S.GetTeamResources(team,'energy')};assert(#m>=5 and #e>=5,'resource_tuple_incomplete');for _,row in ipairs({m,e})do for _,v in ipairs(row)do assert(finite(v),'resource_nonfinite')end end;resources[team]={metal=m,energy=e}end
  return{schema=M.Version,frame=frame,metadata=metadata,squads=R.Snapshot(),productionReservations=R.pending,research={jobs=C.jobs,done=C.done,tiers=C.tiers,reserved=C.reserved},native=bodies,resources=resources}
 end
 local A={}
 function A.Frame(frame)
  if failed or not frames[nextIndex]then return end
  if frame<frames[nextIndex]then return end
  if frame~=frames[nextIndex]then failed=true;notify({status='refused',frame=frame,reason='missed_common_frame'});return end
  local ok,record=pcall(capture,frame)
  if not ok then failed=true;notify({status='refused',frame=frame,reason=tostring(record)});return end
  local encoded;ok,encoded=pcall(M.Encode,record)
  if not ok then failed=true;notify({status='refused',frame=frame,reason=tostring(encoded)});return end
  notify({status='sample',frame=frame,checksum=M.Checksum(encoded),payload=encoded});nextIndex=nextIndex+1
  if not frames[nextIndex]then notify({status='complete',frame=frame,samples=#frames})end
 end
 return A
end
return M
