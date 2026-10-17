-- Source Marine squad/support ledger; opt-in caller wiring, no global actor cap.
local M={Version=1}
local function copy(t)local o={};for k,v in pairs(t or{})do o[k]=type(v)=='table'and copy(v)or v end;return o end
local function sorted(t)local a={};for k in pairs(t or{})do a[#a+1]=k end;table.sort(a);return a end
local function norm(s)return(s or''):gsub('\\','/'):lower()end
local function integer(v)return type(v)=='number'and v>=0 and v<math.huge and v==math.floor(v)end
local function sha(v)return type(v)=='string'and #v==64 and not v:find('[^0-9a-f]')end
function M.New(C,S,defs,F,Q)
 assert(F.race_sha256=='05d423da899a2119803d3bac24c58b95942c17dc8ec908ed092ec856ed6ebe6f'and F.base.infantry==10 and F.base.support==1 and F.maximum.infantry==40 and F.maximum.support==40,'Exact audited Marine race required')
 assert(type(Q.AppliedResearch)=='function'and type(Q.Ready)=='function'and type(Q.PaidReinforcementBirth)=='function','Actual source applied/ready/birth integration required')
 assert(Q.arithmetic=='additive_then_match_multiply','Explicit source modifier-order adaptation required')
 assert(integer(Q.fps)and Q.fps>0,'Native frame rate required')
 F=copy(F);local descriptors=copy(Q.descriptors);local bank=copy(F.squads);local matchRules=copy(Q.matchRules);local fps=Q.fps;local representation=Q.memberRepresentation
 local entityMappings=copy(Q.sourceEntityMappings);local costAdaptations=copy(Q.initialCostAdaptations);local outside=copy(Q.outsideDefinitions);local review=Q.sourceProgressionReview==true
 for path,p in pairs(Q.additionalSquadFacts or{})do
  assert(norm(path)==path and p.status=='copied_source_verified'and sha(p.sha256)and sha(p.entity_sha256)and integer(p.infantry)and integer(p.support)and integer(p.initial)and p.initial>0 and integer(p.maximum)and p.maximum>=p.initial
   and type(p.entity)=='string'and type(p.producer)=='string'and type(p.metal)=='number'and p.metal>=0 and type(p.energy)=='number'and p.energy>=0 and type(p.seconds)=='number'and p.seconds>0,'Genuine additional copied squad facts required')
  assert(not bank[path],'Do not replace audited source facts');bank[path]=copy(p)
 end
 local P={cohorts={},member={},reservations={},failures={}};local prefix='40k_marine_population_';local race=tonumber(F.race_sha256:sub(1,6),16)
 local function entity(def)
  local actual=norm(((defs[def]or{}).customParams or{}).source_entity);local mapped=entityMappings[def]
  local d=descriptors[def];local p=d and bank[d.squad]
  if actual==''and review and mapped and p and mapped.entity==p.entity and mapped.sha256==p.entity_sha256 and mapped.gate=='source_progression_review'then return norm(mapped.entity)end
  return actual
 end
 local function hint(def)
  local cp=((defs[def]or{}).customParams or{})
  return entity(def):find('attrib/ebps/races/space_marines/',1,true)==1 or cp.animsource=='space_marine'or cp.sourceanim=='space_marine'
 end
 local function relevant(def)
  if hint(def)then return true end
  local e=outside[def];local d=defs[def]
  if e and d and type(e.reason)=='string'and e.reason~=''and e.definition_name==d.name then return false end
  return nil
 end
 local function profile(def)
  local d=descriptors[def];local p=d and bank[d.squad]
  if not p or entity(def)~=norm(p.entity)or d.source_sha256~=p.sha256 then return nil end
  if p.initial~=1 and representation~='one_native_actor_per_source_squad' then return nil end
  return p,d.squad
 end
 local function structure(def)
  local p=F.structures[entity(def)]
  return p and sha(p.sha256)and p.population==0 and defs[def].isBuilding==true
 end
 local function living(id,team,def,complete)
  local hp,_,_,_,built=S.GetUnitHealth(id)
  return hp and hp>0 and S.GetUnitTeam(id)==team and S.GetUnitDefID(id)==def and(not complete or built and built>=1)
 end
 local function queue(builder,def,tag)
  local row=(S.GetFactoryCommands(builder,-1)or{})[1]
  return row and row.id==-def and integer(row.tag)and row.tag<=4294967295 and(not tag or row.tag==tag)and row or nil
 end
 local function factory(builder,team,p)
  local u=C.units[builder];local d=u and defs[u.def]
  return u and u.finished and u.team==team and d.isFactory==true and living(builder,team,u.def,true)and entity(u.def)==norm(p.producer)
 end
 local function costs(id,p,reinforce)
  local bt,m,e=S.GetUnitCosts(id)
  local adaptation=costAdaptations[S.GetUnitDefID(id)];local d=defs[S.GetUnitDefID(id)]
  if not reinforce and adaptation then
   if not review or adaptation.kind~='retained_native_unitdef_price'or adaptation.source_squad_sha256~=p.sha256 or type(adaptation.reason)~='string'or adaptation.reason==''then return false end
   return d and d.buildTime and d.buildTime>0 and(d.metalCost or 0)+(d.energyCost or 0)>0 and bt==d.buildTime and m==d.metalCost and e==d.energyCost
  end
  return bt==(reinforce and p.reinforcement_seconds or p.seconds)*fps and m==(reinforce and p.reinforcement_metal or p.metal)and e==(reinforce and p.reinforcement_energy or p.energy)
 end
 local function stamp(c)return tonumber(bank[c.squad].sha256:sub(1,6),16)end
 local function tagParts(tag)
  if tag==nil then return -1,-1 end
  return math.floor(tag/4096),tag%4096
 end
 local function write(id,c,kind)
  local hi,lo=tagParts(c.tag)
  local r={race=race,source=stamp(c),team=c.team,seed=c.seed,kind=kind,complete=c.complete and 1 or 0,builder=c.builder or -1,tag_hi=hi,tag_lo=lo}
  for k,v in pairs(r)do S.SetUnitRulesParam(id,prefix..k,v,{private=true})end
 end
 local function resWrite(builder,r)
  local hi,lo=tagParts(r and r.tag)
  local fields={reserved=r and 1 or 0,def=r and r.def or -1,team=r and r.team or -1,tag_hi=hi,tag_lo=lo,source=r and tonumber(r.sha256:sub(1,6),16)or 0}
  for k,v in pairs(fields)do S.SetUnitRulesParam(builder,prefix..k,v,{private=true})end
 end
 local function coverage(team,ownedNewborn)
  for _,id in ipairs(S.GetAllUnits())do local def=S.GetUnitDefID(id);local hp=S.GetUnitHealth(id)
   if S.GetUnitTeam(id)==team and hp and hp>0 then
    local scope=relevant(def);if scope==nil then return false,'unclassified_native_actor:'..tostring(def)end
    if scope and not structure(def)then
    if not profile(def)then return false,'unknown_source_squad:'..tostring(def)end
    if not P.member[id]and id~=ownedNewborn then return false,'unwitnessed_relevant_actor:'..tostring(id)end
    end
   end
  end
  return true
 end
 function P.Coverage(team)return coverage(team,nil)end
 function P.Capacity(team)
  local inf,sup,maxI,maxS=10,1,40,40
  for _,path in ipairs(sorted(F.profiles))do local p=F.profiles[path]
   local okay,applied=pcall(Q.AppliedResearch,team,path,p.sha256)
   if not okay or type(applied)~='boolean'then return nil,'applied_research_read_failed'end
   if applied then
    for _,e in ipairs(p.effects)do
     if e.usage~='type_modifierusagetype/tp_mod_usage_addition.lua'then return nil,'unsupported_cap_usage'end
     if e.type=='squad_cap_player_modifier'then inf=inf+e.value
     elseif e.type=='support_cap_player_modifier'then sup=sup+e.value
     elseif e.type=='max_squad_cap_player_modifier'then maxI=maxI+e.value
     elseif e.type=='max_support_cap_player_modifier'then maxS=maxS+e.value
     else return nil,'unsupported_cap_effect'end
    end
   end
  end
  local factor=1
  for _,selection in ipairs(matchRules)do local p=F.match_rules[selection.path]
   if not p or p.sha256~=selection.sha256 or selection.selected~=true then return nil,'unverified_match_rule'end
   if p.target=='ai_only'and type(Q.IsAI)~='function'then return nil,'unknown_ai_match_target'end
   if p.target=='all'or p.target=='ai_only'and Q.IsAI(team)==true then factor=factor*p.multiplier
   elseif p.target~='ai_only'then return nil,'unsupported_match_target'end
  end
  return math.min(inf,maxI)*factor,math.min(sup,maxS)*factor,maxI*factor,maxS*factor
 end
 function P.Usage(team)
  local inf,sup=0,0
  for _,c in pairs(P.cohorts)do if c.team==team then local p=bank[c.squad];inf=inf+p.infantry;sup=sup+p.support end end
  for _,r in pairs(P.reservations)do if r.team==team then local p=bank[r.squad];inf=inf+p.infantry;sup=sup+p.support end end
  return inf,sup
 end
 local function room(team,p)
  if Q.Ready()~=true then return false,'policy_not_ready'end
  local okay,why=P.Coverage(team);if not okay then return false,why end
  local capI,capS=P.Capacity(team);if not capI then return false,capS end
  local i,s=P.Usage(team);return i+p.infantry<=capI and s+p.support<=capS,'source_capacity'
 end
 function P.ReserveInitial(team,def,builder)
  local p,path=profile(def);if not p or not factory(builder,team,p)then return false,'unknown_squad_or_producer'end
  local row=queue(builder,def);if not row or S.GetUnitIsBuilding(builder)then return false,'not_native_idle_factory_head'end
  local old=P.reservations[builder]
  if old then return old.def==def and old.team==team and old.tag==row.tag,'already_reserved' end
  local okay,why=room(team,p);if not okay then return false,why end
  local r={team=team,def=def,tag=row.tag,squad=path,sha256=p.sha256,builder=builder};P.reservations[builder]=r;resWrite(builder,r);return true
 end
 function P.ClaimActualFactoryBirth(id,def,team,builder)
  local r=P.reservations[builder];local p,path=profile(def);local _,_,_,_,built=S.GetUnitHealth(id)
  if not r or not p or P.member[id]or r.def~=def or r.team~=team or r.squad~=path or r.sha256~=p.sha256 or not queue(builder,def,r.tag)or not factory(builder,team,p)
   or not living(id,team,def,false)or not built or built>=1 or not costs(id,p,false)then return false end
  local seed=id;while P.cohorts[seed]do seed=seed+1 end
  local c={seed=seed,team=team,def=def,squad=path,builder=builder,tag=r.tag,complete=false,captured=false,members={[id]=0}}
  P.reservations[builder]=nil;resWrite(builder,nil);P.cohorts[seed]=c;P.member[id]=seed;write(id,c,0);return seed
 end
 function P.CompleteInitial(id,def,team,builder)
  local c=P.cohorts[P.member[id]];local p=profile(def)
  if not c or c.complete or c.captured or c.def~=def or c.team~=team or c.builder~=builder or c.members[id]~=0 or not p or not factory(builder,team,p)
   or S.GetUnitIsBuilding(builder)~=id or not living(id,team,def,true)or not costs(id,p,false)then return false end
  c.complete=true;write(id,c,0);return c.seed
 end
 local function ownedBudget(team,seed,newborn)
  local c=P.cohorts[seed]
  if Q.Ready()~=true or not c or c.team~=team or not c.complete or c.captured or not coverage(team,newborn)then return false end
  -- Already committed source budget, not a demand for any additional free slots.
  for id in pairs(c.members)do if not living(id,team,c.def,true)then return false end end
  return true
 end
 function P.AuthorizeReinforcementOwnedBudget(team,seed)return ownedBudget(team,seed,nil)end
 function P.ClaimPaidReinforcementBirth(id,def,team,builder,seed)
  local c=P.cohorts[seed];local p=profile(def)
  -- Native non-beingBuilt Lua creations emit UnitCreated with progress0,
   -- then UnitFinished(progress1), then return from CreateUnit. This is only
   -- the fully paid synchronous birth claim, not a finished-product proof.
   if not c or not p or P.member[id]or c.def~=def or not c.members[builder]or not living(id,team,def,false)
    or not S.GetUnitIsBeingBuilt or S.GetUnitIsBeingBuilt(id)~=false or not costs(id,p,true)
   or Q.PaidReinforcementBirth(id,def,team,builder,seed)~=true or not ownedBudget(team,seed,id)then return false end
  local n=0;for _ in pairs(c.members)do n=n+1 end;if n>=p.maximum then return false end
  c.members[id]=1;P.member[id]=seed;write(id,c,1);return true
 end
 function P.CancelReservation(builder)
  P.reservations[builder]=nil;resWrite(builder,nil)
 end
 function P.UnitRemoved(id)
  if P.reservations[id]then P.CancelReservation(id)end
  local seed=P.member[id];local c=seed and P.cohorts[seed];if not c then return end
  c.members[id]=nil;P.member[id]=nil;if not next(c.members)then P.cohorts[seed]=nil end
 end
 function P.UnitTransferred(id)
  local c=P.cohorts[P.member[id]];local team=S.GetUnitTeam(id)
  if c and team==c.team then return false end
  if not c or not living(id,team,c.def,true)then P.UnitRemoved(id);return false end
  local def,squad=c.def,c.squad;P.UnitRemoved(id)
  local seed=id;while P.cohorts[seed]do seed=seed+1 end
  -- Explicit individual-capture adaptation: charge a source cohort to the new
  -- owner, but NEVER grant a fresh source reinforcement eligibility/cohort.
  local captured={seed=seed,team=team,def=def,squad=squad,complete=true,captured=true,members={[id]=2}}
  P.cohorts[seed]=captured;P.member[id]=seed;write(id,captured,2);return true
 end
 function P.Frame()
  for _,builder in ipairs(sorted(P.reservations))do local r=P.reservations[builder];local p=profile(r.def)
   if not p or not factory(builder,r.team,p)or not queue(builder,r.def,r.tag)then P.CancelReservation(builder)end
  end
  for _,id in ipairs(sorted(P.member))do local c=P.cohorts[P.member[id]]
   if not living(id,c.team,c.def,false)then
    if S.GetUnitTeam(id)and S.GetUnitTeam(id)~=c.team then P.UnitTransferred(id)else P.UnitRemoved(id)end
   end
  end
 end
 function P.Snapshot()return{version=M.Version,source=F.race_sha256,cohorts=copy(P.cohorts),reservations=copy(P.reservations)}end
 function P.Restore(s)
  if type(s)~='table'or s.version~=M.Version or s.source~=F.race_sha256 or next(P.cohorts)or next(P.reservations)then return false end
  local members={}
  for seed,c in pairs(s.cohorts or{})do local p,path=profile(c.def)
   if not integer(seed)or c.seed~=seed or not integer(c.team)or not p or c.squad~=path or type(c.complete)~='boolean'or type(c.captured)~='boolean'or type(c.members)~='table'or not next(c.members)then return false end
   if c.tag~=nil and(not integer(c.tag)or c.tag>4294967295)then return false end
   if not c.captured and c.tag==nil then return false end
   local n=0;for id,kind in pairs(c.members)do
    n=n+1;if not integer(id)or members[id]or(kind~=0 and kind~=1 and kind~=2)or not living(id,c.team,c.def,c.complete)then return false end
    local hi,lo=tagParts(c.tag)
    local fields={race=race,source=stamp(c),team=c.team,seed=seed,kind=kind,complete=c.complete and 1 or 0,builder=c.builder or -1,tag_hi=hi,tag_lo=lo}
    for k,v in pairs(fields)do if S.GetUnitRulesParam(id,prefix..k)~=v then return false end end
    if kind~=2 and not costs(id,p,kind==1)then return false end;members[id]=seed
   end
   if n>p.maximum or c.captured and(n~=1 or c.members[next(c.members)]~=2)then return false end
   if not c.complete then local id=next(c.members)
    if n~=1 or not factory(c.builder,c.team,p)or S.GetUnitIsBuilding(c.builder)~=id or not queue(c.builder,c.def,c.tag)then return false end
   end
  end
  for builder,r in pairs(s.reservations or{})do local p,path=profile(r.def)
   if not integer(builder)or r.builder~=builder or not p or r.squad~=path or r.sha256~=p.sha256 or not factory(builder,r.team,p)or not queue(builder,r.def,r.tag)or S.GetUnitIsBuilding(builder)then return false end
   local hi,lo=tagParts(r.tag)
   for k,v in pairs({reserved=1,def=r.def,team=r.team,tag_hi=hi,tag_lo=lo,source=tonumber(r.sha256:sub(1,6),16)})do if S.GetUnitRulesParam(builder,prefix..k)~=v then return false end end
  end
  P.cohorts=copy(s.cohorts);P.reservations=copy(s.reservations);P.member=members
  for _,team in ipairs(S.GetTeamList())do if not P.Coverage(team)then P.cohorts={};P.reservations={};P.member={};return false end end
  return true
 end
 return P
end
return M
