-- Separate observer. Candidate probes are measurements, never owner placement decisions.
local M={Version=1}
local offsets={{24,0},{0,24},{-24,0},{0,-24},{24,24},{-24,24},{24,-24},{-24,-24},{40,0},{0,40},{-40,0},{0,-40}}
local function finite(x)return type(x)=='number'and x==x and math.abs(x)<math.huge end
local function clone(t)local o={};for k,v in pairs(t)do o[k]=type(v)=='table'and clone(v)or v end;return o end
local function ids(t,cap)local n=0;for _ in pairs(t)do n=n+1 end;assert(n==#t and n<=cap,'native_array_cap_or_hole');table.sort(t);for i,v in ipairs(t)do assert(finite(v)and v>=0 and v%1==0 and(i==1 or t[i-1]~=v),'native_array_identity')end;return t end
function M.New(S,G,D,N,profiles,codec,frames,metadata,notify)
 for _,name in ipairs({'GetGameFrame','GetUnitPosition','GetUnitHealth','GetUnitExperience','GetUnitCosts','GetTeamRulesParam','GetUnitTeam','GetUnitDefID','GetUnitCommands','GetTeamUnits','GetUnitIsBuilding','GetUnitIsDead','GetGroundHeight','GetGroundNormal','Pos2BuildPos','TestBuildOrder','GetUnitsInCylinder','GetUnitCollisionVolumeData','GetTeamUnitCount','GetTeamMaxUnits'})do assert(type(S[name])=='function','missing_api:'..name)end
 assert(type(codec.Encode)=='function'and type(codec.Frames)=='function','codec_missing');assert(type(metadata.source)=='string'and #metadata.source==40 and metadata.source:match('^%x+$'),'source_pin')
 local sequence=codec.Frames(frames);local index=1;local stopped=false;local events={};local attempts={}
 local function tuple(fn,n,... )local t={fn(...)};assert(#t==n,'native_tuple_incomplete');for _,v in ipairs(t)do assert(finite(v),'native_tuple_nonfinite')end;return t end
 local function job(j)return{slot=j.slot,def=j.def,work=j.work,metal=j.metal,energy=j.energy}end
 local function owner()local R=G.Recoil40KSquads;assert(R and R.squads and R.repair and R.pending,'actual_owner_missing');return R end
 local function event(row)assert(#events<16,'event_cap');events[#events+1]=row end
 local function snapshot(frame)
  assert(S.GetGameFrame()==frame,'physical_frame_mismatch');local R=owner();local result={version=1,frame=frame,metadata=metadata,events=clone(events),jobs={},attempts={},observedCandidateScope='independent_post_controller_queries_not_owner_plan_trace'}
  for id,a in pairs(attempts)do
   local s=R.squads[a.seed];local member=R.member[id]
   local hp=S.GetUnitHealth(id);local costs=hp and tuple(S.GetUnitCosts,3,id);if costs then for _,v in ipairs(costs)do assert(v>0,'native_attempt_cost_signed')end end
   result.attempts[id]={context=clone(a),nativeAlive=hp~=nil and not S.GetUnitIsDead(id),nativeHealth=hp and tuple(S.GetUnitHealth,5,id)or false,nativeCosts=costs and {work=costs[1],metal=costs[2],energy=costs[3]}or false,
    nativeDefinition=S.GetUnitDefID(id)or false,xp=hp and S.GetUnitExperience(id)or false,ownedSlot=member and member.slot or false,ownedSquad=member and member.squad or false,
    slotIdentity=s and s.slots[a.slot]or false,currentGeneration=s and s.generations[a.slot]or false,currentJob=R.repair[a.seed]and job(R.repair[a.seed])or false}
  end
  local n=0
  for seed,j in pairs(R.repair)do
   local s=R.squads[seed];assert(s,'orphan_job');if s.profile=='guard_line'then
    n=n+1;assert(n<=2,'guard_job_cap');local p=profiles.profiles[s.profile];assert(p and p.capacity==8,'current_guard_profile');assert(s.slots[j.slot]==nil,'paid_slot_not_missing')
    for _,k in ipairs({'slot','work','metal','energy'})do assert(finite(j[k])and j[k]>=0,'invalid_paid_job')end
    assert(j.slot>=1 and j.slot<=8 and j.slot%1==0 and N[j.def],'invalid_slot_or_bill_definition')
    local generation=s.generations[j.slot];assert(finite(generation)and generation>=1 and generation%1==0,'missing_or_invalid_prior_generation')
    local upgraded=S.GetTeamRulesParam and S.GetTeamRulesParam(s.team,'40k_research_'..p.research)==1
    local wanted=j.slot==p.specialSlot and upgraded and p.special or p.member;local definition=assert(N[wanted]).id
    local row={seed=seed,leader=s.leader,team=s.team,profile=s.profile,paid=job(j),originalBill={metal=N[j.def].metalCost,energy=N[j.def].energyCost,work=N[j.def].buildTime},wanted=wanted,definition=definition,generations=clone(s.generations),builders={},survivors={},candidates={},reserved=R.Reserved(s.team),unitCount=S.GetTeamUnitCount(s.team),unitMax=S.GetTeamMaxUnits(s.team)}
    for slot,id in pairs(s.slots)do row.survivors[slot]={id=id,definition=S.GetUnitDefID(id),health=tuple(S.GetUnitHealth,5,id),xp=S.GetUnitExperience(id),investment=clone(s.investments[slot])}end
    for _,id in ipairs(ids(S.GetTeamUnits(s.team),128))do
     local bd=D[S.GetUnitDefID(id)];local q=S.GetUnitCommands(id,1);local head=q and q[1]
     if bd and bd.isBuilder and not bd.isFactory and head and head.id==34591 and head.params and head.params[1]==seed then
      assert(#row.builders<4,'repair_builder_cap');row.builders[#row.builders+1]={id=id,team=S.GetUnitTeam(id),position=tuple(S.GetUnitPosition,3,id),health=tuple(S.GetUnitHealth,5,id),command=clone(head),nativeBuildTarget=S.GetUnitIsBuilding(id)or false,buildDistance=bd.buildDistance,buildSpeed=bd.buildSpeed}
     end
    end
    local x,_,z=S.GetUnitPosition(s.leader);assert(finite(x)and finite(z),'leader_position')
    for i,off in ipairs(offsets)do
     local px,pz=x+off[1],z+off[2];local py=S.GetGroundHeight(px,pz);assert(finite(py),'terrain_height')
     local state,feature=S.TestBuildOrder(definition,px,py,pz,0);assert(finite(state),'native_build_state')
     local c={index=i,raw={px,py,pz},snapped=tuple(S.Pos2BuildPos,3,definition,px,py,pz,0),terrainNormalSlope=tuple(S.GetGroundNormal,4,px,pz),buildState=state,feature=feature or false,occupants={},reservedSites={}}
     for _,id in ipairs(ids(S.GetUnitsInCylinder(px,pz,16),16))do
      local cv={S.GetUnitCollisionVolumeData(id)};assert(#cv==10 and type(cv[10])=='boolean','native_collision_tuple');for k=1,9 do assert(finite(cv[k]),'native_collision_nonfinite')end
      c.occupants[#c.occupants+1]={id=id,definition=S.GetUnitDefID(id),team=S.GetUnitTeam(id),position=tuple(S.GetUnitPosition,3,id),collision=cv,excludedOrigin=id==s.leader}
     end
     for pending,v in pairs(R.pending)do if pending~=s.leader then for k,pos in ipairs(v.plan)do assert(#c.reservedSites<16,'reservation_site_cap');c.reservedSites[#c.reservedSites+1]={product=pending,index=k,position=clone(pos),distanceSquared=(pos[1]-px)^2+(pos[3]-pz)^2}end end end
     row.candidates[i]=c
    end
    result.jobs[seed]=row
   end
  end
  local bytes=codec.Encode(result);assert(#bytes<=15360,'payload_cap');return bytes
 end
 local function guarded(fn,... )if stopped then return end;local ok,v=pcall(fn,...);if not ok then stopped=true;notify{status='refused',frame=S.GetGameFrame(),reason=tostring(v)}end;return ok,v end
 local O={}
 function O.Frame(frame)
  if stopped then return end;if frame>sequence[index]then stopped=true;notify{status='refused',frame=frame,reason='missed_common_frame'};return end
  if frame~=sequence[index]then return end
  local ok,bytes=guarded(snapshot,frame);if not ok then return end
  notify{status='sample',frame=frame,payload=bytes,checksum=codec.Checksum(bytes)};events={};index=index+1
  if index>#sequence then stopped=true;notify{status='complete',frame=frame,samples=#sequence}end
 end
 function O.Created(id,def,team,builder)
  guarded(function()
   local R=owner();if not R.creating or builder~=nil then return end
   local matches={}
   for seed,j in pairs(R.repair)do local s=R.squads[seed];if s and s.profile=='guard_line'and s.slots[j.slot]==nil then
    local p=profiles.profiles[s.profile];local upgraded=S.GetTeamRulesParam(s.team,'40k_research_'..p.research)==1;local wanted=j.slot==p.specialSlot and upgraded and p.special or p.member
    if def==N[wanted].id and team==s.team then matches[#matches+1]={seed=seed,job=j,squad=s}end
   end end
   if #matches==0 then return end;assert(#matches==1,'ambiguous_paid_repair_birth')
   local a=matches[1];local j,s,seed=a.job,a.squad,a.seed;local generation=s.generations[j.slot]
   assert(finite(generation)and generation>=1 and generation%1==0,'missing_or_invalid_prior_generation')
   local original=assert(N[j.def],'original_paid_definition_missing')
   for k,full in pairs({work=original.buildTime,metal=original.metalCost,energy=original.energyCost})do assert(finite(j[k])and finite(full)and math.abs(j[k]-full)<.001,'birth_without_full_original_paid_bill:'..k)end
   assert(not attempts[id],'duplicate_birth');local total=0;for _ in pairs(attempts)do total=total+1 end;assert(total<8,'attempt_cap')
   attempts[id]={seed=seed,slot=j.slot,paid=job(j),generation=generation}
   event{kind='birth_during_actual_paid_job',frame=S.GetGameFrame(),id=id,def=def,team=team,nativeBuilder=false,creating=true,missingSlot=true,context=clone(attempts[id])}
  end)
 end
 function O.Destroyed(id)
  guarded(function()local a=attempts[id];if a then local R=owner();event{kind='attempt_destroyed',frame=S.GetGameFrame(),id=id,mutating=R.mutating[id]==true,currentJob=R.repair[a.seed]and job(R.repair[a.seed])or false,context=clone(a)};attempts[id]=nil end end)
 end
 return O
end
return M
