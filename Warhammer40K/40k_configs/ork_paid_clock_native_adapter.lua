-- Binds the tested queue clock to actual controller-owned native jobs.
-- Installed only by root's whole-profile integration; does not register profiles.
local M={}
function M.Attach(C,S,D,V,Q,ClockModule)
 assert(not C.sourceOrkPaidClock and ClockModule.ProfileMatches(V),'Attach once with exact Waaagh source')
 for _,name in ipairs({'Ready','Applied','Verified'})do assert(type(Q[name])=='function',name..' required')end
 local restored={}
 local function authoritative(job,id,team,kind)
  local registry=kind=='research'and C.jobs or kind=='addon'and C.sourceVariantAddonJobs and C.sourceVariantAddonJobs.jobs or kind=='recruit'and Q.recruitJobs
  if not registry or type(job)~='table'or job.team~=team or job.active~=true then return false end
  local found=false;for _,j in pairs(registry[id]or{})do if j==job then found=true end end
  if not found then return false end
  local head=(S.GetUnitCommands(id,-1)or{})[1]
  local d=S.GetUnitDefID(id);local path=((D[d]or{}).customParams or{}).source_entity
  return head and head.id==job.cmd and head.tag==job.tag and Q.Verified(d,path)==true or false
 end
 local function contract(job)
  if job.record then return job.record.frames,job.record.row.cost or{}end
  return job.frames,job.cost
 end
 local clock=ClockModule.Clock(S,C,D,{Authorize=authoritative,Contract=contract,
  Rate=function(id,team,key)return Q.Ready()==true and Q.Applied(team,key)==true and ClockModule.rate or 1 end,
  RestoreReceipt=function(proof,job,id,team,kind)return proof==job and authoritative(job,id,team,kind)end})
 local R={}
 function R.Handles(id)
  local d=S.GetUnitDefID(id);local path=((D[d]or{}).customParams or{}).source_entity
  return Q.Ready()==true and ClockModule.Target(path)~=nil and Q.Verified(d,path)==true
 end
 function R.Advance(job,id,frame,kind)
  if not restored[job]then
   if job.orkClockCarry~=nil then
    local snap={id=id,team=job.team,kind=kind,carry=job.orkClockCarry,last=job.orkClockLast}
    if not clock.Restore(job,id,job.team,kind,snap,job)then return false,'invalid_saved_clock'end
   end
   restored[job]=true
  end
  local okay,result=clock.Advance(job,id,job.team,frame,kind)
  local snap=clock.Snapshot(job)
  if snap then job.orkClockCarry=snap.carry;job.orkClockLast=snap.last end
  return okay,result
 end
 function R.Remove(id)clock.Remove(id)end
 function R.Cancel(job)clock.Cancel(job);restored[job]=nil end
 C.sourceOrkPaidClock=R;return R
end
return M
