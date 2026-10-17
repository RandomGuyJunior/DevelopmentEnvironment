-- Read-only readiness at the existing AI dispatch point; paid controller owns queue/spend.
local M={Version=1}
local function finite(v)return type(v)=='number'and v==v and v>=0 and v<math.huge end
function M.New(S,defs,profiles)
 local A={};local byResearch={}
 for _,row in ipairs({{'marine_tactical',1},{'guard_line',2},{'ork_shoota',3}})do
  local profile=profiles and profiles.profiles and profiles.profiles[row[1]]
  if profile and profile.research then
   assert(profile.id==row[2]and profiles.byID[row[2]]==row[1],'Permanent squad research profile identity drift')
   assert(not byResearch[profile.research],'Duplicate permanent squad research identity')
   byResearch[profile.research]=profile
  end
 end
 function A.Ready(team,key,record,c,owned)
  -- Only the three actual registered line-squad permanent equipment roles.
  local p=byResearch[key];if not p then return true end
  if type(record)~='table'or record.key~=key or type(p.researchRow)~='table'or record.producer~=p.researchRow.producer then return false,'profile_record' end
  if not finite(record.cmd)or record.cmd<=0 or record.cmd%1~=0 then return false,'record_command'end
  if type(c)~='table'or type(c.records)~='table'or type(c.commands)~='table'
   or c.records[key]~=record or c.commands[record.cmd]~=record then return false,'controller_record'end
  if type(c.HasResearch)~='function'or type(c.reserved)~='table'or type(c.jobs)~='table'
   or(c.reserved[team]~=nil and type(c.reserved[team])~='table')or type(owned)~='table' then return false,'controller_interface'end
  for _,name in ipairs({'ValidUnitID','GetUnitIsDead','GetUnitTeam','GetUnitCommands','GetTeamResources'})do
   if type(S)~='table'or type(S[name])~='function'then return false,'native_interface'end
  end
  if c.HasResearch(team,key)or(c.reserved[team]or{})[key]then return false,'already_owned_or_reserved'end
  for _,id in ipairs(owned)do
   if not finite(id)or id<0 or id%1~=0 then return false,'owned_unit'end
   if S.ValidUnitID(id)and not S.GetUnitIsDead(id)and S.GetUnitTeam(id)==team then
    if c.jobs[id]~=nil and type(c.jobs[id])~='table'then return false,'controller_jobs'end
    if c.jobs[id]and c.jobs[id][key]then return false,'existing_job'end
    local queue=S.GetUnitCommands(id,-1);if type(queue)~='table'then return false,'native_queue'end
    for _,entry in ipairs(queue)do
     if type(entry)~='table'or type(entry.id)~='number'or entry.id~=entry.id or math.abs(entry.id)==math.huge or entry.id%1~=0 then return false,'native_queue'end
     if entry.id==record.cmd then return false,'native_queued_copy'end
    end
   end
  end
  if type(record.row)~='table'or type(record.row.cost)~='table'then return false,'invalid_bill'end
  local cost=record.row.cost
  local m,e=cost.metal,cost.energy
  if not finite(m)or not finite(e)then return false,'invalid_bill'end
  local metal=S.GetTeamResources(team,'metal');local energy=S.GetTeamResources(team,'energy')
  if not finite(metal)or not finite(energy)or metal<m or energy<e then return false,'available_bill'end
  -- Admission is not prepayment: native atomic per-frame payment can still pause
  -- if subsequent ordinary construction changes the real economy.
  return true
 end
 return A
end
return M
