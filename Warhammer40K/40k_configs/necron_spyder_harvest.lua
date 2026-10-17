-- Review adapter: source harvest transactions, no ordinary factory-cost override.
local M={Capacity=9,PickupSeconds=3,PickupRadius=5,SearchRadius=120,
 ActorSource='attrib/ebps/races/necrons/troops/necron_tomb_spyder.lua',
 Slots={{name='Warriors',entity='nec_warrior',bodies=5,count=3},
 {name='Flayed Ones',entity='nec_flayed',bodies=7,count=3},
 {name='Immortals',entity='nec_immortal',bodies=9,count=3}}}
function M.New(S,Q)
 for _,k in ipairs({'Ready','IsPaidSpyder','Eligible','BodyIdentity','OutputReady','PlanOutput','CreateOutput','RollbackOutput','OutputIdentity','Witness'})do assert(type(Q[k])=='function',k)end
 assert(type(Q.scale)=='number'and Q.scale>0 and type(Q.fps)=='number'and Q.fps>0)
 local A={};local bodies,actors,reservations,removals={},{},{},{}
 local function validFrame(f)return type(f)=='number'and f>=0 and f%1==0 end
 local function live(id,team)
  if not S.ValidUnitID(id)or S.GetUnitIsDead(id)or team~=S.GetUnitTeam(id)then return false end
  local hp,_,_,_,built=S.GetUnitHealth(id)
  return hp and hp>0 and built==1 and not S.GetUnitIsStunned(id)and not S.GetUnitTransporter(id)and Q.IsPaidSpyder(id,team)==true
 end
 local function state(id)
  local t=actors[id];local team=S.GetUnitTeam(id)
  if t and t.team~=team then A.Cancel(id);actors[id]=nil;t=nil end
  if not t then t={team=team,balance=0};actors[id]=t end
  return t
 end
 local function cancel(id)
  local t=actors[id];if t and t.feature then if Q.ReleaseBody then Q.ReleaseBody(t.feature,id)end;reservations[t.feature]=nil;t.feature=nil;t.start=nil end
 end
 function A.Cancel(id)cancel(id)end
 function A.ActorLost(id)cancel(id);actors[id]=nil end -- no captured-body balance transfer
 function A.Balance(id)local t=actors[id];return t and t.team==S.GetUnitTeam(id)and t.balance or 0 end
 -- Called only from gadget's genuine UnitDestroyed->native feature birth route.
 function A.ObserveDeathBody(feature,deadID,deadDef,team,source,frame,lifetime)
  if Q.Ready()~=true or not validFrame(frame)or type(lifetime)~='number'or lifetime<=0 or bodies[feature]or removals[feature]or not S.ValidFeatureID(feature)then return false end
  if Q.BodyIdentity(feature,deadDef,source)~=true then return false end
  bodies[feature]={deadID=deadID,deadDef=deadDef,team=team,source=source,expires=frame+lifetime*Q.fps}
  Q.Witness('BODY_BIRTH',feature,deadID,team,source);return true
 end
 function A.FeatureLost(feature)
  -- Pinned native FeatureDestroyed precedes ID invalidation. Confirm the event
  -- here, then verify absence/credit in GameFramePost after FeatureHandler.Update.
  if removals[feature]then removals[feature].confirmed=true end
  local owner=reservations[feature];if owner then cancel(owner)end
  bodies[feature]=nil;reservations[feature]=nil
 end
 function A.FindBody(id,frame)
  if Q.Ready()~=true or not validFrame(frame)then return end
  local team=S.GetUnitTeam(id);if not live(id,team)then return end
  local x,y,z=S.GetUnitPosition(id);local best,distance
  if not x then return end
  for fid,b in pairs(bodies)do
   if frame<b.expires and not removals[fid]and S.ValidFeatureID(fid)and not reservations[fid]and Q.Eligible(team,b.team,b.source)==true and(not Q.BodyAvailable or Q.BodyAvailable(fid,id))then
    local bx,by,bz=S.GetFeaturePosition(fid);local d=bx and ((x-bx)^2+(z-bz)^2)
    if d and d<=(M.SearchRadius*Q.scale)^2 and (not distance or d<distance or d==distance and fid<best)then best,distance=fid,d end
   end
  end
  return best
 end
 function A.Pickup(id,feature,frame)
  if Q.Ready()~=true or not validFrame(frame)then return false,'not_ready' end
  local t=state(id);local b=bodies[feature]
  if not live(id,t.team)or t.consuming or t.balance>=M.Capacity or not b or removals[feature]or frame>=b.expires or not S.ValidFeatureID(feature)or Q.Eligible(t.team,b.team,b.source)~=true or(Q.BodyAvailable and not Q.BodyAvailable(feature,id))then return false,'ineligible' end
  if reservations[feature]and reservations[feature]~=id then return false,'reserved' end
  local x,y,z=S.GetUnitPosition(id);local bx,by,bz=S.GetFeaturePosition(feature)
  if not x or not bx or (x-bx)^2+(z-bz)^2>(M.PickupRadius*Q.scale)^2 then return false,'range' end
  if t.feature==feature then return true end
  cancel(id);if Q.ReserveBody and not Q.ReserveBody(feature,id)then return false,'claimed'end
  t.feature=feature;t.start=frame;reservations[feature]=id;Q.Witness('PICKUP_START',id,feature,frame);return true
 end
 function A.Tick(frame)
  local ids={};for id in pairs(actors)do ids[#ids+1]=id end;table.sort(ids)
  for _,id in ipairs(ids)do
   local t=actors[id];local feature=t.feature;local b=feature and bodies[feature]
   if feature then
    local x,y,z=S.GetUnitPosition(id);local bx,by,bz=S.GetFeaturePosition(feature)
    if Q.Ready()~=true or not live(id,t.team)or not b or frame>=b.expires or not S.ValidFeatureID(feature)or Q.Eligible(t.team,b.team,b.source)~=true or not x or not bx or (x-bx)^2+(z-bz)^2>(M.PickupRadius*Q.scale)^2 or(Q.BodyAvailable and not Q.BodyAvailable(feature,id))then cancel(id)
    elseif frame-t.start>=M.PickupSeconds*Q.fps then
     if Q.ConsumeBody and not Q.ConsumeBody(feature,id)then cancel(id)
     else
     cancel(id);t.consuming=feature
     removals[feature]={actor=id,state=t,frame=frame,kind='consume'}
     S.DestroyFeature(feature)
     end
    end
   end
  end
  local expired={};for fid,b in pairs(bodies)do if frame>=b.expires and not removals[fid]then expired[#expired+1]=fid end end;table.sort(expired)
  for _,fid in ipairs(expired)do
   local owner=reservations[fid];if owner then cancel(owner)end
   if S.ValidFeatureID(fid)then
    removals[fid]={frame=frame,kind='expire'}
    local ok,reason;if Q.ExpireBody then ok,reason=Q.ExpireBody(fid)else S.DestroyFeature(fid)end
    if ok and reason=='salvage_retained'then
     removals[fid]=nil;bodies[fid]=nil;Q.Witness('BODY_HARVEST_EXPIRED_SALVAGE_RETAINED',fid,frame)
    end
   else A.FeatureLost(fid)end
  end
 end
 function A.PostFrame(frame)
  local ids={};for fid in pairs(removals)do ids[#ids+1]=fid end;table.sort(ids)
  for _,fid in ipairs(ids)do local r=removals[fid]
   if r.confirmed and not S.ValidFeatureID(fid)then
    removals[fid]=nil;bodies[fid]=nil
    if r.kind=='consume'then
     local t=r.state;if t.consuming==fid then t.consuming=nil end
     if actors[r.actor]==t and live(r.actor,t.team)and t.balance<M.Capacity then
      t.balance=t.balance+1;Q.Witness('BODY_CONSUMED',r.actor,fid,t.balance)
     end
    else Q.Witness('BODY_EXPIRED',fid,frame)end
   elseif frame>r.frame then
    -- A refused/missing native deletion never mints currency or an expiry receipt.
    removals[fid]=nil;bodies[fid]=nil
    if r.state and r.state.consuming==fid then r.state.consuming=nil end
    Q.Witness('BODY_REMOVAL_FAILED',fid,frame)
   end
  end
 end
 function A.ClaimBodyBirth(id,entity,team)
  local t=actors[id];local row=t and t.outputRow
  if Q.Ready()~=true or not t or not t.producing or not row or row.entity~=entity or t.team~=team or t.balance<row.bodies or not live(id,team)or not t.outputIndex or t.claimedIndex==t.outputIndex then return false end
  t.claimedIndex=t.outputIndex;return true
 end
 function A.Produce(id,slot,frame)
  if Q.Ready()~=true or not validFrame(frame)then return false,'not_ready'end
  local row=M.Slots[slot];if not row then return false,'slot'end
  local t=state(id);if t.producing or not live(id,t.team)or t.balance<row.bodies or Q.OutputReady(id,row,t.team)~=true then return false,'body_cost_or_output'end
  -- Plan all three collision-safe positions before creating any actors.
  local plan=Q.PlanOutput(id,row,t.team);if type(plan)~='table'or #plan~=row.count then return false,'blocked'end
  t.producing=true;t.outputRow=row;local made,seen={},{};for i=1,row.count do
   t.outputIndex=i;t.claimedIndex=nil
   local unit=Q.CreateOutput(id,row,t.team,plan[i])
   if actors[id]~=t or not live(id,t.team)or not unit or seen[unit]or not S.ValidUnitID(unit)or S.GetUnitIsDead(unit)or S.GetUnitTeam(unit)~=t.team or Q.OutputIdentity(unit,row)~=true then
    if unit and not seen[unit]then Q.RollbackOutput(unit)end
    for _,u in ipairs(made)do Q.RollbackOutput(u)end
    t.producing=nil;t.outputRow=nil;t.outputIndex=nil;t.claimedIndex=nil;Q.Witness('OUTPUT_ROLLBACK',id,slot,#made);return false,'spawn_failed'
   end
   seen[unit]=true;made[#made+1]=unit
  end
  t.producing=nil;t.outputRow=nil;t.outputIndex=nil;t.claimedIndex=nil;cancel(id);t.balance=t.balance-row.bodies;Q.Witness('OUTPUT_PAID',id,slot,row.bodies,row.count,t.balance);return true,made
 end
 return A
end
return M
