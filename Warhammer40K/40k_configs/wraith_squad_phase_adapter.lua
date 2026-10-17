-- Review-only squad adapter over the existing sole phase/damage owner.
-- No passive defense, new prerequisite, births, healing or resource accounting.
local M={Version=1,Profile='necron_wraith',ProfileID=17}
function M.New(S,Q)
 assert(Q.Base and type(Q.Squads)=='function'and type(Q.IsWraith)=='function')
 local ownerQ={};for k,v in pairs(Q)do ownerQ[k]=v end;ownerQ.PhaseOnly=true
 local B=Q.Base.New(S,ownerQ);local A={}
 local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
 local function members(id)
  local R=Q.Squads();local s=R and R.Get(id)
  if not s or s.profile~=M.Profile or s.team~=S.GetUnitTeam(id)then return end
  local list=R.Members(id);if #list<1 or #list>3 then return end
  local seen={};for _,member in ipairs(list)do
   if not finite(member)or member%1~=0 or member<0 or seen[member]or S.ValidUnitID(member)~=true or S.GetUnitIsDead(member)~=false or not Q.IsWraith(member)or S.GetUnitTeam(member)~=s.team then return end
   local hp,max,_,_,built=S.GetUnitHealth(member)
   if not finite(hp)or not finite(max)or hp<=0 or max<=0 or hp>max or built~=1 then return end
   seen[member]=true
  end
  if not seen[id]then return end;table.sort(list);return list,s.team
 end
 local function sync(id)
  local list,team=members(id);if not list then return end
  local active,ready=0,0;local rows={}
  for _,member in ipairs(list)do
   local t=B.Snapshot(member)
   if not t then
    local saved=S.GetUnitRulesParam(member,'40k_wraith_phase_ready')
    local activeSaved=S.GetUnitRulesParam(member,'40k_wraith_phase_active')
    local teamSaved=S.GetUnitRulesParam(member,'40k_wraith_phase_team')
    if(saved~=nil or activeSaved~=nil or teamSaved~=nil)and not B.Restore(member)then return end
    t=B.Snapshot(member)
   end
   if t and t.team~=team then B.Cancel(member);t=B.Snapshot(member)end
   if t then active=math.max(active,t.active);ready=math.max(ready,t.ready)end
   rows[member]=t
  end
  for _,member in ipairs(list)do
   local t=rows[member]
   if not t or t.active~=active or t.ready~=ready or t.team~=team then
    if not B.AdoptState(member,{active=active,ready=ready,team=team})then return end
   end
  end
  return list
 end
 function A.CanActivate(id,frame)
  local list=sync(id);if not list then return false,'squad_identity_or_saved_state' end
  for _,member in ipairs(list)do local ok,why=B.CanActivate(member,frame);if not ok then return false,why end end
  return true
 end
 function A.Activate(id,frame)
  local ok,why=A.CanActivate(id,frame);if not ok then return false,why end
  local list=members(id)
  -- Synced call has no yields or native births: every preflight precedes writes.
  for _,member in ipairs(list)do assert(B.Activate(member,frame),'Phase group changed inside atomic activation')end
  return true
 end
 function A.IsActive(id,frame)return sync(id)~=nil and B.IsActive(id,frame)or false end
 function A.CanAttack(id,frame)return sync(id)~=nil and B.CanAttack(id,frame)or false end
 function A.CanUseAbility(id,frame)return A.CanAttack(id,frame)end
 function A.Damage(id,damage,paralyzer,weapon,attacker,frame)
  if Q.IsWraith(id)and not sync(id)then B.Cancel(id)end
  if attacker and Q.IsWraith(attacker)and not sync(attacker)then B.Cancel(attacker)end
  return B.Damage(id,damage,paralyzer,weapon,attacker,frame)
 end
 function A.Cancel(id)
  -- Capture callback can precede/follow squad ownership propagation. Cancel all
  -- members through the actual runtime identity, even during mixed ownership.
  local R=Q.Squads();local s=R and R.Get(id)
  if s and s.profile==M.Profile then for _,member in ipairs(R.Members(id))do B.Cancel(member)end else B.Cancel(id)end
 end
 function A.Restore(id)return sync(id)~=nil end
 function A.UnitDestroyed(id)B.UnitDestroyed(id)end
 function A.Snapshot(id)if sync(id)then return B.Snapshot(id)end end
 function A.FullBoostSupported()return false end
 function A.InfiltrationSupported()return false end
 return A
end
return M
