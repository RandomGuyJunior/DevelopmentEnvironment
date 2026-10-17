-- Exact Night research transaction adapter; never changes other research records.
local M={}
function M.Attach(C,S,Config)
 local key=Config.ResearchKey;local witness
 local function captureOwned(team)return GG.Recoil40KRelicCapture and GG.Recoil40KRelicCapture.Owned(team)==true end
 local function supported()return GG.Recoil40KNightAbility and GG.Recoil40KNightAbility.EffectSupported(key)==true end
 local function eligible(id,team)
  local u=C.units[id];local hp,_,_,_,p=S.GetUnitHealth(id)
  return u and u.name=='nec_archive'and u.team==team and u.finished and S.GetUnitTeam(id)==team
   and hp and hp>0 and p==1 and C.HasResearch(team,'nec_ctan_manifestation')and captureOwned(team)and supported()or false
 end
 local function exactHead(id,job)
  local d=UnitDefs[S.GetUnitDefID(id)];local rows=d and d.isFactory and S.GetFactoryCommands(id,-1)or S.GetUnitCommands(id,-1)
  local row=rows and rows[1];return row and row.id==job.cmd and row.tag==job.tag
 end
 function C.NightPaidCompletion(team,k,producer)
  local w=witness;return k==key and w and w.team==team and w.id==producer and w.job
   and w.job.steps==w.job.record.frames and w.job.record.frames==90*(Game.gameSpeed or 30)
   and w.job.metal==0 and w.job.energy==750 and eligible(producer,team)==true or false
 end
 GG.Recoil40KNightPaidCompletion=C.NightPaidCompletion
 local allow=C.Allow
 function C.Allow(id,def,team,cmd,params,opts)
  local r=C.commands[cmd];if r and r.key==key and not eligible(id,team)then return false end
  return allow(id,def,team,cmd,params,opts)
 end
 local fallback=C.Fallback
 function C.Fallback(id,cmd,tag)
  local r=C.commands[cmd];if r and r.key==key then
   local u=C.units[id];if not u or not eligible(id,u.team)then C.Cancel(id);return true,true end
  end
  return fallback(id,cmd,tag)
 end
 local refresh=C.Refresh
 function C.Refresh(id)
  refresh(id);local r=C.records[key];local u=C.units[id]
  if r and u and u.name==r.producer and not eligible(id,u.team)then
   local idx=S.FindUnitCmdDesc(id,r.cmd);if idx then S.EditUnitCmdDesc(id,idx,{disabled=true,tooltip='Requires actual captured Relic, paid Ctan research and complete Night effects'})end
  end
 end
 local frame=C.Frame
 function C.Frame(f)
  local pending={}
  for id,jobs in pairs(C.jobs)do local j=jobs[key]
   if j then
    if not eligible(id,j.team)then C.Cancel(id)
    elseif j.active and j.steps==j.record.frames-1 and exactHead(id,j)then pending[#pending+1]={id=id,team=j.team,job=j}end
   end
  end
  frame(f)
  for _,w in ipairs(pending)do
   if C.HasResearch(w.team,key)then
    witness=w;local ok,result=pcall(GG.Recoil40KNightAbility.EffectsCompleted,w.team,key,w.id);witness=nil
    if not ok or result~=true then
     -- Never expose an unsupported partial completion. Payment remains actual;
     -- failure is explicit, not refunded or silently marked accepted.
     C.done[w.team][key]=nil;S.SetTeamRulesParam(w.team,'40k_research_'..key,0,{allied=true})
     S.SetTeamRulesParam(w.team,'40k_night_effect_failed',1,{allied=true})
     C.NightEffectFailure={team=w.team,id=w.id,frame=f,reason=tostring(result)}
    end
   end
  end
 end
 function C.NightRefreshHandlers()
  if supported()and C.suppressed[key]then C.RegisterEffectHandler(key)end
 end
 return M
end
return M
