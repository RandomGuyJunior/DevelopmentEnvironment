-- Read-only target-local dispatch prerequisites; never claims the AI visited them.
local M={Version=1,Research='guard_squad_flamer',Producer='imp_research'}
local function finite(n)return type(n)=='number'and n==n and n>=0 and n<math.huge end
function M.New(S,D,ready,getController,emit)
 assert(type(ready)=='table'and type(ready.Ready)=='function'and type(getController)=='function'and type(emit)=='function')
 local A={};local previous
 function A.Step(team,frame)
  assert(finite(team)and team%1==0 and finite(frame)and frame%1==0)
  local c=getController();local record=c and c.records and c.records[M.Research]
  assert(record and record.key==M.Research and record.producer==M.Producer and record.frames==1050,'Actual Guard research identity required')
  assert(record.row.cost.metal==200 and record.row.cost.energy==1000,'Actual Guard research bill required')
  local owned=S.GetTeamUnits(team);assert(type(owned)=='table');table.sort(owned)
  local budget,why=ready.Ready(team,M.Research,record,c,owned)
  local r={frame=frame,team=team,budgetReady=budget==true,budgetReason=why or 'none',producers=0,finished=0,idle=0,requirement=0,enabledDescriptor=0,nativeOrdersIssued=false,AIVisitedTargetProven=false,paidResearchAccepted=false}
  for _,id in ipairs(owned)do
   assert(finite(id)and id%1==0,'Native ID required')
   if S.ValidUnitID(id)and not S.GetUnitIsDead(id)and S.GetUnitTeam(id)==team then
    local d=D[S.GetUnitDefID(id)];local cp=d and d.customParams or{};local name=d and(cp.prototype40k_tech_requires or cp.prototype40k_donor or d.name)
    if name==M.Producer then
     r.producers=r.producers+1
     local hp,_,_,_,built=S.GetUnitHealth(id);local u=c.units and c.units[id]
     if finite(hp)and hp>0 and built==1 and u and u.team==team and u.finished and u.name==M.Producer then
      r.finished=r.finished+1;local q=S.GetUnitCommands(id,1);assert(type(q)=='table','Actual producer queue required')
      if #q==0 then
       r.idle=r.idle+1
       if c.Requirement(team,record.row.requires,id,false)==true then
        r.requirement=r.requirement+1;local descriptors=S.GetUnitCmdDescs(id);assert(type(descriptors)=='table','Actual command descriptors required')
        for _,desc in ipairs(descriptors)do if desc.id==record.cmd and not desc.disabled then r.enabledDescriptor=r.enabledDescriptor+1;break end end
       end
      end
     end
    end
   end
  end
  r.targetLocalNecessaryGatesReady=r.budgetReady and r.enabledDescriptor>0
  local signature=table.concat({tostring(r.budgetReady),r.budgetReason,r.producers,r.finished,r.idle,r.requirement,r.enabledDescriptor},':')
  if signature~=previous then previous=signature;emit(r)end
  return r
 end
 return A
end
return M
