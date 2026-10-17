-- Isolated source consumer proposal. Nothing registers a paid profile here.
local M={}
local key='ork_source_hq_addon'
local source='attrib/ebps/races/orks/structures/ork_hq.lua'
local add='type_modifierusagetype/tp_mod_usage_addition.lua'
local entity='type_modifierapplicationtype/tp_mod_apply_to_entity.lua'
local entityType='type_modifierapplicationtype/tp_mod_apply_to_entity_type.lua'
-- Omitted profile fields inherit copied defaults: squad type/addition for slot6,
-- entity type for slot7. Compare authored profile representation exactly.
local effects={
 {'health_maximum_modifier','',3500,false,add,nil},
 {'default_weapon_modifier_hardpoint3','',1,false,nil,entity},
 {'default_weapon_modifier_hardpoint4','',1,false,nil,entity},
 {'population_cap_player_modifier','',20,false,nil,nil},
 {'health_maximum_modifier','ork_stormboy',60,true,add,entityType},
 {'max_troopers_squad_modifier','ork_squad_stormboy',2,true,nil,nil},
 {'cost_requisition_modifier','ork_slugga_boy',-20,true,add,nil},
}
local function exact(e,n)
 local r=effects[n]
 return r and type(e)=='table' and e.slot==string.format('modifier_%02d',n) and e.type==r[1]
  and e.target==r[2] and e.value==r[3] and e.exclusive==r[4]
  and e.usage_type==r[5] and e.application_type==r[6] and e.probability==1
end
function M.ProfileMatches(V)
 local p=V.SourceProfiles[key];local c=V.ResearchConditions[key]
 if not p or p.source~='attrib/addons/ork_hq_addon.lua'
  or p.sha256~='34dbfa6044b0758b9f45a175eaf05f572ef6bb48eab41b829b9d5aaea54f3e0a'
  or p.time~=180 or p.cost.metal~=300 or p.cost.energy~=400
  or not c or c.population~=70 or #p.effects~=7 then return false,'source_profile_changed' end
 for n=1,7 do if not exact(p.effects[n],n)then return false,'source_effect_changed:'..n end end
 return true
end
-- Data gives no arbitration algorithm. Evaluate only a fully enumerated SINGLE
-- exact candidate. Never choose strongest/latest, stack, or deduplicate overlaps.
function M.SingletonExclusive(V,target,baseline,candidates,complete)
 if not M.ProfileMatches(V)then return nil,'source_profile_changed' end
 if complete~=true then return nil,'exclusive_candidates_incomplete' end
 if type(candidates)~='table' or #candidates~=1 then return nil,'exclusive_arbitration_unknown' end
 local row=candidates[1];if type(row)~='table' then return nil,'invalid_candidate' end;local n=row.slot
 local r=effects[n]
 if row.key~=key or not r or not r[4] or not exact(row.effect,n) or target~=r[2]then return nil,'wrong_source_target_or_effect' end
 if type(baseline)~='number' or baseline~=baseline or baseline==math.huge or baseline==-math.huge then return nil,'invalid_baseline' end
 local result=baseline+r[3]
 if result<1 then return nil,'native_clamp_or_invalid_capacity' end
 return result
end
-- Prebuilt native HP3/4 contain the exact shoota weapon; the inactive source
-- dummy choice is enforced by script gates. No weapon/cadence/damage mutation.
function M.Selectors(S,C,defs,V,config)
 assert(type(config)=='table' and type(config.VerifiedModel)=='function'
  and type(config.WholeProfileSupported)=='function' and type(config.PaidJobMatches)=='function'
  and type(config.Applied)=='function' and type(config.RestoreReceipt)=='function','Whole transaction/root hooks required')
 local states,tokens={},{}
 local function actor(id,team)
  local d=S.GetUnitDefID(id);local a=C.units[id]
  local hp,_,_,_,progress=S.GetUnitHealth(id)
  if not a or not a.finished or a.team~=team or a.def~=d or S.GetUnitTeam(id)~=team
   or not hp or hp<=0 or not progress or progress<1 then return nil end
  if not defs[d] or (defs[d].customParams or{}).source_entity~=source
   or config.VerifiedModel(id,d)~=true then return nil end
  return a
 end
 local R={}
 function R.Prepare(id,team,job)
  if not M.ProfileMatches(V) or config.WholeProfileSupported(key)~=true then return nil,'whole_profile_closed' end
  local a=actor(id,team)
  if not a or config.PaidJobMatches(job,id,team,key,V.SourceProfiles[key])~=true then return nil,'invalid_owned_paid_origin' end
  if states[id]then return nil,'selector_already_committed' end
  local token={};tokens[token]={id=id,team=team,actor=a,job=job,next={team=team,actor=a}}
  return token
 end
 function R.Validate(token)
  local t=tokens[token]
  return t~=nil and not t.aborted and M.ProfileMatches(V)==true
   and config.WholeProfileSupported(key)==true and actor(t.id,t.team)==t.actor
   and config.PaidJobMatches(t.job,t.id,t.team,key,V.SourceProfiles[key])==true
   and (t.committed and states[t.id]==t.next or not t.committed and states[t.id]==nil)
 end
 function R.Commit(token)
  if not R.Validate(token)then return false end
  local t=tokens[token];if t.committed then return true end
  states[t.id]=t.next;t.committed=true;return true
 end
 function R.Abort(token)
  local t=tokens[token];if not t then return false end
  if states[t.id]==t.next then states[t.id]=nil end
  t.aborted=true;tokens[token]=nil;return true
 end
 function R.Choice(id,hardpoint)
  if hardpoint~=3 and hardpoint~=4 then return nil,'outside_selector_scope' end
  local s=states[id]
  if not M.ProfileMatches(V) or not s or actor(id,s.team)~=s.actor or config.WholeProfileSupported(key)~=true
   or config.Applied(id,s.team,key)~=true then return 1,'source_dummy_choice' end
  return 2,'source_shoota_choice'
 end
 function R.Allowed(id,hardpoint)return R.Choice(id,hardpoint)==2 end
 function R.Remove(id)
  states[id]=nil
  for token,t in pairs(tokens)do if t.id==id then tokens[token]=nil end end
 end
 function R.Restore(id,team,receipt)
  if not M.ProfileMatches(V) or config.WholeProfileSupported(key)~=true then return false end
  local a=actor(id,team)
  if not a or config.RestoreReceipt(receipt,id,team,key,V.SourceProfiles[key])~=true then return false end
  states[id]={team=team,actor=a};return true
 end
 return R
end
return M
