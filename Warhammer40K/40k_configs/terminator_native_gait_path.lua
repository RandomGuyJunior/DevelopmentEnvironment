-- Default-off paid driver helper. Only ordinary native MOVE/SHIFT orders; no physics.
local M={}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function same(a,b)
 if type(a)~='table'or type(b)~='table'or #a~=3 or #b~=3 then return false end
 for i=1,3 do if not finite(a[i])or not finite(b[i])or math.abs(a[i]-b[i])>.01 then return false end end
 return true
end
local function queue(S,id)
 if type(S.GetUnitCommands)~='function'then return nil end
 local q=S.GetUnitCommands(id,-1);if type(q)~='table'then return nil end
 local n=0;for k,v in pairs(q)do n=n+1;if type(k)~='number'or k%1~=0 or k<1 or k>#q or type(v)~='table'or not finite(v.id)or type(v.params)~='table'or type(v.options)~='table'or not finite(v.options.coded)or v.options.coded<0 or v.options.coded%1~=0 then return nil end end
 if n~=#q then return nil end;return q
end
function M.Plan(S,D,physical,cohort,factory,mapX,mapZ)
 if type(S.TestMoveOrder)~='function'or not finite(mapX)or not finite(mapZ)or mapX<=192 or mapZ<=192 then return nil,'native_gait_api_or_map_missing'end
 if not cohort or cohort.profile~='marine_terminator'or cohort.team~=0 or type(cohort.slots)~='table'then return nil,'native_gait_cohort_missing'end
 local leader=cohort.slots[1];local x,y,z=S.GetUnitPosition(leader);if not finite(x)or not finite(y)or not finite(z)then return nil,'native_gait_position_missing'end
 local parent=physical.Envelope(S,D,factory);if not parent then return nil,'native_gait_factory_volume_missing'end
 local definitions={};local maxSpeed=0;local seen={}
 for slot=1,3 do local id=cohort.slots[slot];local def=id and S.GetUnitDefID(id);local d=def and D[def]
  if not finite(id)or id<0 or id%1~=0 or seen[id]or S.GetUnitIsDead(id)~=false or S.GetUnitTeam(id)~=0 or not d or d.canFly or not finite(d.speed)or d.speed<=0 then return nil,'native_gait_body_missing'end
  seen[id]=true;definitions[slot]=def;maxSpeed=math.max(maxSpeed,d.speed)
 end
 local function legal(xx,zz)
  if xx<96 or zz<96 or xx>mapX-96 or zz>mapZ-96 then return false end
  if xx>=parent.minX and xx<=parent.maxX and zz>=parent.minZ and zz<=parent.maxZ then return false end
  local yy=S.GetGroundHeight(xx,zz);if not finite(yy)then return false end
  for slot=1,3 do if S.TestMoveOrder(definitions[slot],xx,yy,zz,0,0,0,true,true,false)~=true then return false end end
  return {xx,yy,zz}
 end
 -- Two native legs: 640 outward, then 512 back along the same admitted corridor.
 -- This is finite placement admission, never a pathfinding or gait acceptance claim.
 for _,dir in ipairs({{1,0},{0,1},{-1,0},{0,-1},{1,1},{-1,1},{-1,-1},{1,-1}})do
  local scale=dir[1]~=0 and dir[2]~=0 and math.sqrt(.5)or 1;local dx,dz=dir[1]*scale,dir[2]*scale;local path={};local admitted=true
  for distance=64,640,64 do local p=legal(x+dx*distance,z+dz*distance);if not p then admitted=false;break end;if distance==640 then path[1]=p elseif distance==128 then path[2]=p end end
  if admitted then return path,{leader=leader,slots={cohort.slots[1],cohort.slots[2],cohort.slots[3]},nativeDefinitionSpeed=maxSpeed,corridorSamples=10,nativePathProof=false}end
 end
 return nil,'all_eight_native_gait_corridors_refused'
end
function M.Start(S,CMD,leader,path,rally,emit)
 if not CMD or not finite(CMD.MOVE)or CMD.OPT_SHIFT~=32 or type(S.GiveOrderToUnit)~='function'then return false,'native_gait_command_api_missing'end
 local before=queue(S,leader);if not before then return false,'native_gait_queue_unknown'end
 if #before>1 or(#before==1 and(before[1].id~=CMD.MOVE or not same(before[1].params,rally)))then return false,'native_gait_foreign_queue'end
 for leg=1,2 do local coded=leg==1 and 0 or CMD.OPT_SHIFT
  if S.GiveOrderToUnit(leader,CMD.MOVE,path[leg],coded)~=true then return false,'native_gait_order_refused_'..leg end
  local actual=queue(S,leader);if not actual or #actual~=leg then return false,'native_gait_queue_readback_'..leg end
  for i=1,leg do if actual[i].id~=CMD.MOVE or not same(actual[i].params,path[i])or(math.floor(actual[i].options.coded/32)%2==1)~=(i==2)then return false,'native_gait_queue_identity_'..leg end end
  emit('GAIT_NATIVE_ORDER',S.GetGameFrame(),leader,'leg='..leg,'coded='..coded,'xyz='..table.concat(path[leg],','),'native_queue_readback=true native_path_proof=false')
 end
 return true
end
return M
