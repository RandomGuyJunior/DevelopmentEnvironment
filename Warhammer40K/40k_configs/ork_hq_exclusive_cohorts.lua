-- Authored native adaptation: identical HQ exclusive slots apply once per team.
-- No registration, creation, health or resource grants. Complete native transaction
-- binds Plans to the existing health/price/population consumers before admission.
local M={key='ork_source_hq_addon',version=1}
local hq='attrib/ebps/races/orks/structures/ork_hq.lua'
local storm='attrib/ebps/races/orks/troops/ork_stormboy.lua'
local slugga='attrib/ebps/races/orks/troops/ork_slugga_boy.lua'
local squad='attrib/sbps/races/orks/ork_squad_stormboy.lua'
function M.Supported(V,P,entities,verified,hooks)
 if not P.ProfileMatches(V)then return false,'source_profile_changed'end
 local mapped={}
 for def,path in pairs(entities or{})do if verified(def,path)==true then mapped[path]=true end end
 for _,path in ipairs({hq,storm,slugga})do if not mapped[path]then return false,'unmapped_genuine_target:'..path end end
 for _,name in ipairs({'localHealth','stormboyHealth','futureSluggaPrice','hardpoint3','hardpoint4','population20','genuineStormboyCohort','paidBirth','paidReinforcement','capture','save','rollback'})do
  if not hooks or hooks[name]~=true then return false,'whole_handler_missing:'..name end
 end
 return true
end
function M.New(S,C,D,V,P,H)
 assert(P.ProfileMatches(V),'Exact HQ source profile required')
 for _,name in ipairs({'Ready','Verified','PaidAddon','RestoreAddon','PaidCohort','PaidReinforcement','RestoreCohort'})do assert(type(H[name])=='function',name..' required')end
 local receipts,cohorts,members,tokens={},{},{},{}
 local R={}
 local function actor(id,team,path)
  local a=C.units[id];local d=S.GetUnitDefID(id);local hp,_,_,_,built=S.GetUnitHealth(id)
  return a and a.team==team and a.def==d and a.finished and S.GetUnitTeam(id)==team and hp and hp>0 and built and built>=1
   and ((D[d]or{}).customParams or{}).source_entity==path and H.Verified(d,path)==true and a or nil
 end
 local function ready()return P.ProfileMatches(V)==true and H.Ready()==true end
 local function live(id,r)return ready()and actor(id,r.team,hq)==r.actor end
 function R.Active(team)
  for id,r in pairs(receipts)do if r.team==team and live(id,r)then return true end end
  return false
 end
 function R.Prepare(id,team,paid)
  local a=actor(id,team,hq)
  if not ready()or not a or receipts[id]or H.PaidAddon(paid,id,team,V.SourceProfiles[M.key])~=true then return nil,'whole_paid_profile_required'end
  local token={};tokens[token]={id=id,team=team,actor=a,paid=paid};return token
 end
 function R.Validate(token)
  local t=tokens[token];return t and ready()and actor(t.id,t.team,hq)==t.actor and H.PaidAddon(t.paid,t.id,t.team,V.SourceProfiles[M.key])==true
   and (not t.committed and not receipts[t.id]or t.committed and receipts[t.id]==t)or false
 end
 -- Root commits only after all seven native effects and cohort capacity validate.
 function R.Commit(token)
  if not R.Validate(token)then return false end
  local t=tokens[token];receipts[t.id]=t;t.committed=true;return true
 end
 function R.Abort(token)
  local t=tokens[token];if not t then return false end
  if receipts[t.id]==t then receipts[t.id]=nil end;tokens[token]=nil;return true
 end
 function R.Plan(id,team,birth,prospective)
  if not ready()then return nil,'whole_profile_closed'end
  local d=S.GetUnitDefID(id);local path=((D[d]or{}).customParams or{}).source_entity
  if S.GetUnitTeam(id)~=team or H.Verified(d,path)~=true then return nil,'unknown_source_actor'end
  local t=tokens[prospective];local pending=t and R.Validate(prospective)and t.team==team
  local active=R.Active(team)or pending
  local own=receipts[id];local localHQ=(own and live(id,own))or(pending and t.id==id)
  return {healthAddition=path==hq and localHQ and 3500 or path==storm and active and 60 or 0,
   -- Future paid birth price only; existing actor cost/investment stays locked.
   requisitionAddition=path==slugga and active and birth==true and -20 or 0,
   hardpoint3=localHQ and 2 or 1,hardpoint4=localHQ and 2 or 1,
   localCapacity=localHQ and 20 or 0}
 end
 function R.CohortBirth(seed,team,ids,paid)
  if not ready()or cohorts[seed]or type(ids)~='table'or #ids~=4 then return false end
  local seen={};local actors={}
  for _,id in ipairs(ids)do local a=actor(id,team,storm);if seen[id]or members[id]or not a then return false end;seen[id]=true;actors[id]=a end
  if H.PaidCohort(paid,seed,team,ids,squad)~=true then return false end
  local row={team=team,actors=actors,source=squad};cohorts[seed]=row
  for id in pairs(actors)do members[id]=seed end;return true
 end
 function R.Capacity(seed)
  local c=cohorts[seed];if not c or not ready()then return nil end
  for id,a in pairs(c.actors)do if actor(id,c.team,storm)~=a then return nil,'cohort_ownership_changed'end end
  return R.Active(c.team)and 10 or 8 -- No free actor materialization.
 end
 function R.ReinforcementBirth(seed,id,paid)
  local c=cohorts[seed];local cap=R.Capacity(seed)
  if not c or not cap or members[id]then return false end
  local count=0;for _ in pairs(c.actors)do count=count+1 end
  local a=actor(id,c.team,storm)
  if not a or count>=cap or H.PaidReinforcement(paid,seed,id,c.team,{metal=50,energy=0,time=7,population=1,combat_time_multiplier=2})~=true then return false end
  c.actors[id]=a;members[id]=seed;return true
 end
 function R.Remove(id,captured)
  receipts[id]=nil
  for token,t in pairs(tokens)do if t.id==id then tokens[token]=nil end end
  local seed=members[id];if seed then
   if captured then
    -- Mixed ownership invalidates the originating paid squad receipt.
    for member in pairs(cohorts[seed].actors)do members[member]=nil end;cohorts[seed]=nil
   else
    cohorts[seed].actors[id]=nil;members[id]=nil
    if not next(cohorts[seed].actors)then cohorts[seed]=nil end
   end
  end
 end
 function R.Snapshot()
  local out={version=M.version,addons={},cohorts={}}
  for id,t in pairs(receipts)do if live(id,t)then out.addons[id]={team=t.team}end end
  for seed,c in pairs(cohorts)do local ids={};for id in pairs(c.actors)do ids[#ids+1]=id end;table.sort(ids);out.cohorts[seed]={team=c.team,ids=ids,source=squad}end
  return out
 end
 function R.Restore(snapshot,proof)
  if not ready()or type(snapshot)~='table'or snapshot.version~=M.version then return false end
  local nextReceipts,nextCohorts,nextMembers={},{},{}
  for id,t in pairs(snapshot.addons or{})do
   local a=actor(id,t.team,hq);if not a or H.RestoreAddon(proof,id,t.team,V.SourceProfiles[M.key])~=true then return false end
   nextReceipts[id]={id=id,team=t.team,actor=a,committed=true}
  end
  for seed,c in pairs(snapshot.cohorts or{})do
   if c.source~=squad or type(c.ids)~='table'or (#c.ids<1 or #c.ids>10)or H.RestoreCohort(proof,seed,c.team,c.ids,squad)~=true then return false end
   local row={team=c.team,source=squad,actors={}}
   for _,id in ipairs(c.ids)do local a=actor(id,c.team,storm);if not a or nextMembers[id]then return false end;row.actors[id]=a;nextMembers[id]=seed end
   nextCohorts[seed]=row
  end
  receipts,cohorts,members,tokens=nextReceipts,nextCohorts,nextMembers,{};return true
 end
 return R
end
return M
