-- Dedicated diagnostic command policy; no damage/health/weapon mutations.
local M={}
function M.New(S,defs,C,log)
 local rows,teams={},{}
 local H={}
 function H.Restore(reason)
  local ok=true
  for id,r in pairs(rows)do
   if S.GetUnitDefID(id)then
    S.GiveOrderToUnit(id,C.FIRE_STATE,{r.fire},{})
    local state=S.GetUnitStates(id);local read=state and state.firestate
    log('STARTER_FIRE_RESTORE',reason,id,r.team,r.fire,read or'UNKNOWN')
    if read~=r.fire then ok=false else rows[id]=nil;teams[r.team]=nil end
   else log('STARTER_FIRE_RESTORE',reason,id,r.team,'DEAD_NO_WRITABLE_STATE');rows[id]=nil;teams[r.team]=nil end
  end
  return ok
 end
 function H.Created(id,def,team,builder)
  if builder~=nil or S.GetGameFrame()>0 then return true end
  local d=defs[def];local cp=d and d.customParams
  if not cp or cp.prototype40k_vital~='commander'then return true end
  if rows[id]then return rows[id].team==team and rows[id].def==def end
  if tonumber((S.GetTeamRulesParam(team,'startUnit')))~=def then return false,'starter_rule_mismatch'end
  if teams[team]then return false,'duplicate_starter_team'end
  local states=S.GetUnitStates(id);local fire=states and states.firestate
  if fire~=0 and fire~=1 and fire~=2 then return false,'starter_firestate_unreadable'end
  rows[id]={fire=fire,team=team,def=def};teams[team]=id
  S.GiveOrderToUnit(id,C.FIRE_STATE,{0},{})
  local after=S.GetUnitStates(id)
  log('STARTER_HOLD_FIRE',S.GetGameFrame(),id,team,def,fire,after and after.firestate or'UNKNOWN','frame_zero_builder_nil_startUnit_vital')
  if not after or after.firestate~=0 then return false,'starter_hold_fire_refused'end
  return true
 end
 function H.Validate()
  local count=0
  for _,team in ipairs(S.GetTeamList())do
   local def=tonumber((S.GetTeamRulesParam(team,'startUnit')))
   if def then
    local d=defs[def];local cp=d and d.customParams;local id=teams[team]
    if not cp or cp.prototype40k_vital~='commander'or not id or S.GetUnitDefID(id)~=def or S.GetUnitTeam(id)~=team then return false,'missing_exact_initial_starter'end
    local state=S.GetUnitStates(id)
    if not state or state.firestate~=0 then return false,'starter_hold_fire_lost'end
    count=count+1
   end
  end
  if count==0 then return false,'no_initial_starter_receipt'end
  return true
 end
 function H.Changed(id)return rows[id]~=nil end
 return H
end
return M
