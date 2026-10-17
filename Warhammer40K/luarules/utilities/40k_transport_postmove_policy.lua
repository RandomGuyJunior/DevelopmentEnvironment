-- Opted transport function fixture policy only; no actors/state changes here.
local M={Version=3,Name='native_footprint_spaced_3x2_aggregate_idle_v3'}
local function finite(n)return type(n)=='number'and n==n and math.abs(n)<math.huge end
function M.Plan(S,D,lane,list,base,mapX,mapZ)
 if #list~=6 then return nil,'requires_six_individuals'end
 local goals={};local samples={{0,0},{32,0},{-32,0},{0,32},{0,-32},{22,22},{22,-22},{-22,22},{-22,-22}}
 for i,id in ipairs(list)do
  local d=D[base[id].def];local md=d and d.moveDef
  if not md or not finite(md.xsize)or not finite(md.zsize)or md.xsize<=0 or md.zsize<=0 then return nil,'native_movedef_footprint_unreadable'end
  if md.xsize~=md.zsize then return nil,'square_native_footprint_policy_required'end
  -- Square/cylindrical native ground collision separation; not visual/model radius.
  local radius=math.max(md.xsize,md.zsize)*4
  if radius*2+64>128 then return nil,'native_footprint_exceeds_spaced_policy'end
  local g={x=lane.x+600+math.floor((i-1)/2)*128,z=lane.z+(i%2==1 and -96 or 96),radius=radius}
  for _,o in ipairs(samples)do local x,z=g.x+o[1],g.z+o[2]
   if x-radius<0 or z-radius<0 or x+radius>mapX or z+radius>mapZ then return nil,'post_move_goal_outside_map'end
   local y=S.GetGroundHeight(x,z);if not finite(y)or y<0 or S.TestMoveOrder(base[id].def,x,y,z,0,0,0,true,true,false)~=true then return nil,'post_move_goal_native_terrain_or_solids_refused'end
  end
  goals[id]=g
 end
 for i=1,6 do for j=i+1,6 do local a,b=goals[list[i]],goals[list[j]]
  if (a.x-b.x)^2+(a.z-b.z)^2<(a.radius+b.radius+64)^2 then return nil,'post_move_arrival_disks_crowded'end
 end end
 return goals
end
-- A fresh native MOVE is permitted only after the original native queue finished
-- outside the unchanged arrival disk. No active/failed/unknown path is replaced.
function M.Retry(S,id,goal,frame,state)
 if not state or not finite(frame)or not finite(state.started)or frame-state.started<150 or(state.count or 0)>=2 then return false end
 if state.last and frame-state.last<150 then return false end
 local mt=S.GetUnitMoveTypeData(id);if not mt or mt.progressState~='done'then return false end
 if not S.GetUnitCommandCount or S.GetUnitCommandCount(id)~=0 then return false end
 if S.GetUnitTransporter(id)then return false end
 local hp,_,_,_,progress=S.GetUnitHealth(id);if not finite(hp)or hp<=0 or progress~=1 then return false end
 local x,_,z=S.GetUnitPosition(id);if not finite(x)or not finite(z)or not goal or not finite(goal.x)or not finite(goal.z)then return false end
 if(x-goal.x)^2+(z-goal.z)^2<=32^2 then return false end
 return true
end
-- Read-only aggregate admission for the opted six-actor fixture renewal.
function M.AllIdle(S,list,base)
 if type(list)~='table'or #list~=6 or type(base)~='table'then return false,'requires_six_baselines'end
 for _,key in ipairs({'GetUnitMoveTypeData','GetUnitCommandCount','GetUnitCommands','GetUnitTransporter','GetUnitHealth','GetUnitDefID','GetUnitTeam','ValidUnitID','GetUnitIsDead'})do
  if type(S[key])~='function'then return false,'unknown_'..key end
 end
 local seen={}
 for i=1,6 do local id=list[i]
  local b=base[id];if seen[id]or not b then return false,'missing_or_duplicate_baseline'end;seen[id]=true
  if S.ValidUnitID(id)~=true or S.GetUnitIsDead(id)~=false or S.GetUnitDefID(id)~=b.def or S.GetUnitTeam(id)~=b.team then return false,'identity_or_owner_refused'end
  if S.GetUnitTransporter(id)~=nil then return false,'not_detached'end
  local hp,_,_,_,progress=S.GetUnitHealth(id);if not finite(hp)or hp<=0 or progress~=1 then return false,'not_alive_finished'end
  local mt=S.GetUnitMoveTypeData(id);if type(mt)~='table'or mt.progressState~='done'then return false,'not_native_done'end
  local q=S.GetUnitCommands(id,1);if S.GetUnitCommandCount(id)~=0 or type(q)~='table'or next(q)~=nil then return false,'not_native_empty'end
 end
 return true,'six_native_done_empty_owned'
end
return M
