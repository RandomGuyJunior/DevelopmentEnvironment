-- Isolated genuine Relic ownership adapter; no stock capture interception or spawning.
local M={Command=34577,Radius=50,BaseCaptureSeconds=45,ScarabRate=.75,FlagSeconds=1.5,RevertSeconds=10}
function M.New(S,Q)
 assert(Q.Ready and Q.ObjectiveReviewed and Q.scarabDef and Q.relicDef and Q.gaiaTeam and Q.Frame)
 local A={};local jobs={};local receipts={};local fps=Q.fps or 30
 local function owner(id)return S.GetUnitRulesParam(id,'40k_relic_owner') or -1 end
 local function transfer(id,team)S.SetUnitRulesParam(id,'40k_relic_owner',team,{public=true})end
 local function live(id,def)
  if not S.ValidUnitID(id) or S.GetUnitIsDead(id) or S.GetUnitDefID(id)~=def then return false end
  local h,_,_,_,p=S.GetUnitHealth(id);return h and h>0 and p==1
 end
 local function eligible(id,target)
  return Q.Ready()==true and live(id,Q.scarabDef) and live(target,Q.relicDef)
   and Q.ObjectiveReviewed(target)==true and S.GetUnitTeam(target)==Q.gaiaTeam and not S.GetUnitTransporter(id) and not S.GetUnitIsStunned(id)
 end
 local function near(id,target)
  local x,_,z=S.GetUnitPosition(id);local tx,_,tz=S.GetUnitPosition(target)
  return x and tx and (x-tx)^2+(z-tz)^2<=(M.Radius+(Q.ObjectiveRadius or 110))^2
 end
 function A.Begin(id,target)
  if not eligible(id,target) then return false end
  local team=S.GetUnitTeam(id);if team==owner(target)then return false end
  -- One objective has one claimant; concurrent opposing interaction is refused,
  -- not summed into globally faster capture.
  if jobs[target]then return jobs[target].actor==id and jobs[target].team==team end
  jobs[target]={actor=id,team=team,phase=owner(target)<0 and 'capture' or 'revert',progress=0,last=Q.Frame()}
  return true
 end
 function A.Tick(id,target,frame)
  frame=frame or Q.Frame()
  local t=jobs[target];if not t or t.actor~=id or S.GetUnitTeam(id)~=t.team or not eligible(id,target)then jobs[target]=nil;return false,true end
  if not near(id,target)then
   t.progress=0;t.nearSince=nil;t.last=frame;local x,y,z=S.GetUnitPosition(target);S.SetUnitMoveGoal(id,x,y,z,M.Radius*.9);return true,false
  end
  if not t.nearSince then t.nearSince=frame;t.progress=0 end
  t.last=frame;t.progress=frame-t.nearSince
  local seconds=t.phase=='revert' and M.RevertSeconds or M.BaseCaptureSeconds/M.ScarabRate+M.FlagSeconds
  if t.progress<math.ceil(seconds*fps)then return true,false end
  if t.phase=='revert'then
   transfer(target,-1);t.phase='capture';t.progress=0;t.nearSince=frame;return true,false
  end
  transfer(target,t.team)
  local ok=owner(target)==t.team;receipts[target]={actor=id,team=t.team,nearSince=t.nearSince,finished=frame,elapsed=t.progress,owner=owner(target)};jobs[target]=nil;return true,true,ok
 end
 function A.Receipt(target)
  local t=jobs[target]or receipts[target];if not t then return end
  local out={};for k,v in pairs(t)do out[k]=v end;return out
 end
 function A.Cancel(id)for target,t in pairs(jobs)do if t.actor==id then jobs[target]=nil end end end
 function A.UnitRemoved(id)jobs[id]=nil;A.Cancel(id)end
 function A.Owned(team)
  for _,id in ipairs(S.GetAllUnits()or{})do if live(id,Q.relicDef)and S.GetUnitTeam(id)==Q.gaiaTeam and owner(id)==team and Q.ObjectiveReviewed(id)==true then return true end end
  return false
 end
 -- Reload cancels unfinished interactions; it never invents ownership or resumes
 -- an unproven command head. Exact real objective logical-owner rule persists independently; unit stays Gaia to avoid stock victory contamination.
 return A
end
return M
