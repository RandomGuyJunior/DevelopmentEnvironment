-- Source-derived native adaptation. Caller owns genuine paid research and Relic placement.
local M={Command=34576,ResearchKey='nec_night_invulnerability',SourceHealth=15000,
 Duration=15,Recharge=90,BaseRegen=15,UpgradeRegen=5,
 AbilitySource='attrib/abilities/races/necrons/ua_necron_invulnerability.lua',
 AbilitySHA='d7a6e84efa14ba3e0e831a87026118a93d959618c08f09d4ec7a9d24611f057c'}
M.Research={name='Nightbringer Invulnerability',producer='nec_archive',cost={metal=0,energy=750},time=90,
 requires={buildings={},research={'nec_ctan_manifestation'},tier=2},
 source='attrib/research/races/necrons/ua_necron_ctan_nightbringer_ability_research.lua',
 source_sha256='964c0b8b8fcf0888ed73cd4971ba3d8d06aa66c2ad4dcd244f5408f9381233d5',
 source_owned_relic={entity='relic_struct',count=1,requires_live_reviewed_objective=true},
 requires_effect_handler=true,implementation='night_invulnerability_and_regeneration'}
function M.New(S,Q)
 assert(type(Q)=='table' and type(Q.Ready)=='function' and type(Q.HasResearch)=='function')
 local A={};local states={};local fps=Q.fps or 30;local lastFrame
 local function live(id,team)
  if not S.ValidUnitID(id) or S.GetUnitIsDead(id) or S.GetUnitDefID(id)~=Q.nightDef then return false end
  if team and S.GetUnitTeam(id)~=team then return false end
  local hp,max,_,_,built=S.GetUnitHealth(id)
  return hp and hp>0 and max and max>0 and built==1
 end
 local function write(id,t)
  for k,v in pairs({active=t.active or 0,ready=t.ready or 0,team=t.team})do
   S.SetUnitRulesParam(id,'40k_night_ability_'..k,v,{private=true})
  end
 end
 function A.EffectSupported(key)return key==M.ResearchKey and Q.Ready()==true end
 -- Called inside the real controller's paid completion transaction. This profile
 -- has no primitive/no-op completion: regeneration and the command share this reader.
 function A.EffectsCompleted(team,key,producer)
  return A.EffectSupported(key) and Q.PaidCompletionValid and Q.PaidCompletionValid(team,key,producer)==true
 end
 function A.CanActivate(id,frame)
  if Q.Ready()~=true or not live(id) then return false,'not_ready_live_finished' end
  if frame+M.Recharge*fps>16777216 then return false,'frame_receipt_range' end
  local team=S.GetUnitTeam(id);if Q.HasResearch(team,M.ResearchKey)~=true then return false,'paid_research' end
  if S.GetUnitIsStunned(id) or S.GetUnitTransporter(id) then return false,'stunned_or_transport' end
  local t=states[id];if t and t.team~=team then states[id]=nil;t=nil end
  if t and frame<t.ready then return false,'cooldown' end
  return true
 end
 function A.Activate(id,frame)
  local ok,reason=A.CanActivate(id,frame);if not ok then return false,reason end
  states[id]={team=S.GetUnitTeam(id),active=frame+M.Duration*fps,ready=frame+M.Recharge*fps}
  write(id,states[id]);return true
 end
 function A.IsActive(id,frame)
  local t=states[id];return t and live(id,t.team) and frame<t.active or false
 end
 function A.UnitPreDamaged(id,damage,frame)
  -- Preserve negative healing and native impulse only on ordinary damage.
  if damage>=0 and A.IsActive(id,frame)then return 0,0 end
  return damage,1
 end
 function A.UnitTransferred(id)
  -- Capture cannot transfer an old team's active effect or refresh its cooldown.
  local t=states[id];if t then t.team=S.GetUnitTeam(id);t.active=0;write(id,t)end
 end
 function A.OnReplacement(old,new,team)
  local t=states[old];states[old]=nil
  if not t or t.team~=team or not S.ValidUnitID(new) or S.GetUnitTeam(new)~=team then return false end
  states[new]={team=team,active=0,ready=t.ready};write(new,states[new]);return true
 end
 function A.UnitDestroyed(id)states[id]=nil end
 function A.Frame(frame)
  if frame==lastFrame then return end;lastFrame=frame
  if frame%fps~=0 or Q.Ready()~=true then return end
  for _,id in ipairs(S.GetAllUnits() or {})do
   if live(id)then
    local hp,max=S.GetUnitHealth(id)
    local rate=M.BaseRegen+(Q.HasResearch(S.GetUnitTeam(id),M.ResearchKey)==true and M.UpgradeRegen or 0)
    -- Explicit native per-second interpretation; current XP/maximum health scales
    -- the source health basis. No compounded stat mutation, damage-dealt heal or
    -- guessed degeneration modifier. Native leech remains independent.
    if hp<max then
     local target=math.min(max,hp+rate*max/M.SourceHealth);local exp=S.GetUnitExperience and S.GetUnitExperience(id)
     S.SetUnitHealth(id,{health=target})
     local after,newMax=S.GetUnitHealth(id);local newExp=S.GetUnitExperience and S.GetUnitExperience(id)
     if Q.Regenerated then Q.Regenerated(id,frame,hp,max,exp,after,newMax,newExp,target-hp,rate)end
    end
   end
  end
 end
 function A.Restore(id)
  if not S.ValidUnitID(id) or S.GetUnitIsDead(id)then return false end
  local def=S.GetUnitDefID(id);if def~=Q.nightDef and def~=Q.lordDef then return false end
  local team=S.GetUnitTeam(id);local old=S.GetUnitRulesParam(id,'40k_night_ability_team')
  local a=S.GetUnitRulesParam(id,'40k_night_ability_active');local r=S.GetUnitRulesParam(id,'40k_night_ability_ready')
  if old~=team or type(a)~='number' or type(r)~='number' or a%1~=0 or r%1~=0 or a<0 or r<a or r>16777216 then return false end
  states[id]={team=team,active=a,ready=r};return true
 end
 return A
end
return M
