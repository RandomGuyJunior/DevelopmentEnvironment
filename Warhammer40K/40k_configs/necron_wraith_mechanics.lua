-- Bounded source-supported review. Improved defense/infiltration remain closed.
local M={Command=34578,Duration=10,Recharge=45,BaseRangedFactor=.75,
 AwakeningKey='nec_awakening_1',ActorSource='attrib/ebps/races/necrons/troops/necron_wraith.lua',
 PhaseSource='attrib/abilities/races/necrons/ua_necron_wraith_phase_shift.lua',
 PhaseSHA='bdebbd28725dfc27423caf52f35d97aef47d3c57ad9ff2aa012f53d5c1f565b9',
 BaseDefenseSHA='9ccc710bdc44062a5eac6b1975937d596b637fb9ade92bf06ca66b03426e0b70'}
function M.New(S,Q)
 assert(type(Q.Ready)=='function'and type(Q.HasResearch)=='function'and type(Q.HasHQ)=='function')
 local A={};local states={};local fps=Q.fps or 30
 local function live(id,team)
  if not S.ValidUnitID(id)or S.GetUnitIsDead(id)or not(Q.IsWraith and Q.IsWraith(id)or not Q.IsWraith and S.GetUnitDefID(id)==Q.wraithDef)then return false end
  if team and S.GetUnitTeam(id)~=team then return false end
  local hp,max,_,_,built=S.GetUnitHealth(id);return hp and hp>0 and max and max>0 and built==1
 end
 local function write(id,t)
  for k,v in pairs({active=t.active,ready=t.ready,team=t.team})do S.SetUnitRulesParam(id,'40k_wraith_phase_'..k,v,{private=true})end
 end
 function A.CanActivate(id,frame)
  if Q.Ready()~=true or not live(id)then return false,'not_ready_live_finished' end
  if type(frame)~='number'or frame<0 or frame%1~=0 or frame+M.Recharge*fps>16777216 then return false,'frame_range' end
  local team=S.GetUnitTeam(id)
  if Q.HasHQ(team)~=true or Q.HasResearch(team,M.AwakeningKey)~=true then return false,'paid_awakening_and_live_hq' end
  if S.GetUnitIsStunned(id)or S.GetUnitTransporter(id)then return false,'stunned_or_transport' end
  local t=states[id];if t and t.team~=team then A.Cancel(id);t=states[id]end
  if t and frame<t.ready then return false,'cooldown' end
  return true
 end
 function A.Activate(id,frame)
  local ok,why=A.CanActivate(id,frame);if not ok then return false,why end
  states[id]={team=S.GetUnitTeam(id),active=frame+M.Duration*fps,ready=frame+M.Recharge*fps};write(id,states[id]);return true
 end
 function A.IsActive(id,frame)
  local t=states[id];return Q.Ready()==true and t and live(id,t.team)and frame<t.active or false
 end
 function A.CanAttack(id,frame)return not A.IsActive(id,frame)end
 function A.CanUseAbility(id,frame)return not A.IsActive(id,frame)end
 function A.Cancel(id)
  local t=states[id];if t then t.active=0;t.team=S.GetUnitTeam(id);write(id,t)end
 end
 function A.Damage(id,damage,paralyzer,weapon,attacker,frame)
  -- Health/morale immunity is not an invented paralysis or negative-healing rule.
  if Q.Ready()~=true or damage<0 or paralyzer then return damage,1,'unchanged' end
  if A.IsActive(attacker,frame)then return 0,0,'phase_outgoing_refused' end
  if not live(id)then return damage,1,'unchanged' end
  if A.IsActive(id,frame)then return 0,0,'phase_incoming_refused' end
  -- Classification is explicit metadata: unknown/environment damage is not ranged.
  if not Q.PhaseOnly and Q.WeaponKind and Q.WeaponKind(weapon)=='ranged'then return damage*M.BaseRangedFactor,1,'base_ranged_defense' end
  return damage,1,'unchanged'
 end
 -- Trusted adapter state import retains the same validation and single owner.
 function A.AdoptState(id,t)
  if not live(id)or type(t)~='table'or type(t.active)~='number'or type(t.ready)~='number'
   or t.active<0 or t.ready<t.active or t.ready>16777216 or t.active%1~=0 or t.ready%1~=0 or t.team~=S.GetUnitTeam(id)then return false end
  states[id]={active=t.active,ready=t.ready,team=t.team};write(id,states[id]);return true
 end
 function A.Restore(id)
  if not live(id)then return false end
  local active=S.GetUnitRulesParam(id,'40k_wraith_phase_active');local ready=S.GetUnitRulesParam(id,'40k_wraith_phase_ready');local team=S.GetUnitRulesParam(id,'40k_wraith_phase_team')
  if type(active)~='number'or type(ready)~='number'or active<0 or ready<active or ready>16777216 or active%1~=0 or ready%1~=0 or team~=S.GetUnitTeam(id)then return false end
  states[id]={active=active,ready=ready,team=team};return true
 end
 function A.UnitDestroyed(id)states[id]=nil end
 function A.Snapshot(id)local t=states[id];if not t then return end;return{active=t.active,ready=t.ready,team=t.team}end
 function A.FullBoostSupported()return false end
 function A.InfiltrationSupported()return false end
 return A
end
return M
