function gadget:GetInfo()
 return{name='40K extractor same-callback refund observer',desc='Default-off read-only budget before stock mex replacement',author='Local project',layer=-1,enabled=true}
end
local options=Spring.GetModOptions()or{}
if not VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(options.prototype_extractor_paid_fixture)or not gadgetHandler:IsSyncedCode()then return false end
local S=Spring;local rows={};local api={Read=function(id)return rows[id]end,Forget=function(id)rows[id]=nil end}
function gadget:Initialize()GG.Recoil40KExtractorRefundProbe=api end
function gadget:Shutdown()if GG.Recoil40KExtractorRefundProbe==api then GG.Recoil40KExtractorRefundProbe=nil end end
function gadget:UnitFinished(id,def,team)
 rows[id]=nil
 if tonumber((UnitDefs[def].customParams or{}).listening_post_version)~=2 then return end
 local x,_,z=S.GetUnitPosition(id)
 for _,old in ipairs(S.GetUnitsInCylinder(x,z,10)or{})do
  local oldDef=S.GetUnitDefID(old);local d=oldDef and UnitDefs[oldDef]
  if old~=id and d and d.extractsMetal>0 and S.GetUnitIsDead(old)==false then
   local m,storage=S.GetTeamResources(team,'metal');local multiplier=select(7,S.GetTeamInfo(team,false))
   rows[id]={frame=S.GetGameFrame(),old=old,oldDef=oldDef,oldTeam=S.GetUnitTeam(old),team=team,metal=m,storage=storage,
    definitionMetal=d.metalCost,multiplier=multiplier};return
  end
 end
end
function gadget:GameFrame(frame)if frame%300==0 then for id,row in pairs(rows)do if frame-row.frame>300 then rows[id]=nil end end end end
