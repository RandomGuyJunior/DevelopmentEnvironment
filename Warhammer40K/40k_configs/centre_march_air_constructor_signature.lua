-- Existing ground signature remains authoritative; recognize actual ready air donors.
local M={}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local donors={[1]='corca',[2]='coraca'}
function M.Air(ud)
 if type(ud)~='table'then return nil end
 local cp=ud.customParams or{};local tier=tonumber(cp.prototype40k_constructor_tier)
 if cp.prototype40k_constructor_domain~='air'or not donors[tier]
  or cp.prototype40k_native_donor~=donors[tier]or cp.rosterrole~='constructor'
  or ud.isBuilder~=true or ud.canFly~=true or not finite(ud.speed)or ud.speed<=0
  or type(ud.buildOptions)~='table'or #ud.buildOptions==0 then return nil end
 return 'air:'..tier
end
-- nil means the actual full native queue is unavailable/malformed; never fake
-- a reservation. Caller suppresses new air admission until queue is knowable.
function M.Queue(queue)
 if type(queue)~='table'then return false end
 local count=0
 for key,row in pairs(queue)do
  if not finite(key)or key%1~=0 or key<1 or type(row)~='table'
   or not finite(row.id)or row.id%1~=0 or math.abs(row.id)>2147483647 then return false end
  count=count+1
 end
 for i=1,count do if queue[i]==nil then return false end end
 return true
end
function M.Pending(ud,product,queue,ownFaction)
 if not M.Air(ud)or (ud.customParams or{}).faction~=ownFaction then return false end
 if not M.Queue(queue)then return nil end
 local count=#queue
 for i=1,count do if queue[i].id==-product then return true end end
 return false
end
return M
