-- Native queue tags belong to individual bodies, never to the whole squad.
-- Pure preflight: the caller must issue no orders unless a plan is returned.
local M={}
local function integer(v)return type(v)=='number'and v==v and v>=0 and v<math.huge and v%1==0 end
local function flag(value,bit)return math.floor(value/bit)%2==1 end
function M.ByID(opts)return opts and((opts.alt==true)or(integer(opts.coded)and flag(opts.coded,128)))or false end
local function intent(opts)
 if opts==nil then return 0 end
 if type(opts)~='table'or not integer(opts.coded)then return nil end
 -- orders() intentionally adds native SHIFT while replaying a leader queue.
 return opts.coded-(flag(opts.coded,32)and 32 or 0)
end
local function same(a,b)
 if a.id~=b.id or a.intent~=b.intent or #a.params~=#b.params then return false end
 for i=1,#a.params do if a.params[i]~=b.params[i]then return false end end
 return true
end
local function read(queue)
 if type(queue)~='table'then return nil end
 local result,tags={},{}
 for i,row in ipairs(queue)do
  if type(row)~='table'or type(row.id)~='number'or not integer(row.tag)or tags[row.tag]or type(row.params)~='table'then return nil end
  local options=intent(row.options);if options==nil then return nil end
  local params={};for j,v in ipairs(row.params)do
   if type(v)~='number'or v~=v or math.abs(v)==math.huge then return nil end
   params[j]=v
  end
  for k in pairs(row.params)do if not integer(k)or k<1 or k>#params then return nil end end
  result[i]={id=row.id,tag=row.tag,params=params,intent=options};tags[row.tag]=i
 end
 for k in pairs(queue)do if not integer(k)or k<1 or k>#result then return nil end end
 return result,tags
end
function M.Plan(leaderQueue,memberQueues,requested)
 if type(requested)~='table'or type(memberQueues)~='table'then return nil,'invalid_request'end
 local leader,leaderTags=read(leaderQueue);if not leader then return nil,'unreadable_leader_queue'end
 local wanted,seen={},{}
 for _,tag in ipairs(requested)do
  if not integer(tag)then return nil,'invalid_tag'end
  local index=leaderTags[tag]
  if index and not seen[index]then wanted[#wanted+1]=index;seen[index]=true end
 end
 for k in pairs(requested)do if not integer(k)or k<1 or k>#requested then return nil,'invalid_request'end end
 local plan={}
 for n,entry in ipairs(memberQueues)do
  local member=read(entry.queue);if not member then return nil,'unreadable_member_queue'end
  local aligned=#leader==#member
  if aligned then for i=1,#leader do if not same(leader[i],member[i])then aligned=false;break end end end
  local tags={}
  for _,index in ipairs(wanted)do
   local target
   if aligned then target=member[index]else
    local matches=0
    for _,row in ipairs(member)do if same(leader[index],row)then matches=matches+1;target=row end end
    if matches>1 then return nil,'ambiguous_member_queue'end
    if matches==1 then
     local leaderMatches=0
     for _,row in ipairs(leader)do if same(leader[index],row)then leaderMatches=leaderMatches+1 end end
     if leaderMatches>1 then return nil,'ambiguous_leader_queue'end
    end
   end
   if target then tags[#tags+1]=target.tag end
  end
  plan[n]={id=entry.id,tags=tags}
 end
 return plan
end
return M
