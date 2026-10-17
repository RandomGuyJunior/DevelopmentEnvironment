-- Exact crewed bike only. Native collision is the sole damage witness.
-- Native own-unit navigation/physics; no target motion, grants or extra actor.
local M={Command=34593,Period=3,Damage=180,MinImpactSpeed=60,MinRunUp=48,Cooldown=90,MaxLegFrames=600}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function integer(v)return finite(v)and v>=0 and v==math.floor(v)end
local function distance(x,z,a,b)return math.sqrt((x-a)^2+(z-b)^2)end
local function keys(t)local out={};for k in pairs(t)do out[#out+1]=k end;table.sort(out);return out end
function M.New(P)
 local C={};local active,finished={},{}
 local function valid(r)
  return P.Live(r.id)and P.Live(r.target)and P.Team(r.id)==r.team and P.Team(r.target)==r.targetTeam
   and P.Definition(r.id)==r.def and P.Definition(r.target)==r.targetDef and not P.Allied(r.team,r.targetTeam)
   and not P.Neutral(r.target)and P.Ground(r.target)and not P.Busy(r.id)and not P.Busy(r.target)and P.Visible(r.id,r.target)
 end
 local function head(r)
  local q=P.Head(r.id)
  return q and q.id==M.Command and q.tag==r.tag and q.params and #q.params==1 and q.params[1]==r.target
 end
 local function release(r)
  if r.goal then P.ReleaseGoal(r.id,r.goal)end
  P.ReleaseTarget(r.id,r.target)
  P.ReleaseWatch(r.def);P.ReleaseWatch(r.targetDef)
 end
 function C.Cancel(id,reason)
  local r=active[id];if not r then return end
  active[id]=nil;finished[id]=r.tag;release(r);P.Report(id,reason or'cancelled')
 end
 local function orbit(r,frame,x,z,tx,tz)
  r.phase='orbit';r.orbitStep=1;r.armed=false;r.runup=0;r.legFrame=frame
  r.angle=math.atan2(z-tz,x-tx);r.radius=math.max(120,P.Radius(r.id)+P.Radius(r.target)+80)
 end
 local function goal(r,x,z,raw,frame)
  if not finite(x)or not finite(z)then return false end
  if not r.goal or r.goal.raw~=raw or distance(x,z,r.goal.x,r.goal.z)>12 or frame-r.goal.frame>=15 then
   if not P.Goal(r.id,x,z,raw)then return false end
   r.goal={x=x,z=z,raw=raw,frame=frame}
  end
  return true
 end
 function C.Fallback(id,target,tag)
  if not integer(target)or not integer(tag)or id==target or finished[id]==tag then return true,true end
  local r=active[id]
  if r and(r.tag~=tag or r.target~=target)then C.Cancel(id,'replaced_attack');r=nil end
  if not r then
   r={id=id,target=target,tag=tag,team=P.Team(id),targetTeam=P.Team(target),def=P.Definition(id),targetDef=P.Definition(target),phase='charge',runup=0,armed=false,legFrame=P.Frame()}
   if not head(r)or not valid(r)then return true,true end
   local x,y,z=P.Position(id);local tx,ty,tz=P.Position(target)
   if not finite(x)or not finite(y)or not finite(z)or not finite(tx)or not finite(ty)or not finite(tz)then return true,true end
   active[id]=r;r.previous={x=x,z=z,frame=P.Frame()};P.Watch(r.def);P.Watch(r.targetDef)
   if distance(x,z,tx,tz)<P.Radius(id)+P.Radius(target)+M.MinRunUp then orbit(r,P.Frame(),x,z,tx,tz)end
   P.Target(id,target);P.Report(id,'attack_started')
  end
  if not valid(r)or not head(r)then C.Cancel(id,'target_or_order_unavailable');return true,true end
  return true,false
 end
 local function update(r,frame)
  if not valid(r)or not head(r)then C.Cancel(r.id,'target_or_order_unavailable');return end
  if frame-r.legFrame>M.MaxLegFrames then C.Cancel(r.id,'native_route_timeout');return end
  local md=P.MoveData(r.id);if not md or md.name~='ground'or md.progressState=='failed'then C.Cancel(r.id,'native_route_failed');return end
  local x,_,z=P.Position(r.id);local tx,_,tz=P.Position(r.target)
  if not finite(x)or not finite(z)or not finite(tx)or not finite(tz)then C.Cancel(r.id,'invalid_native_position');return end
  local dx,dz=tx-x,tz-z;local d=math.sqrt(dx*dx+dz*dz)
  if d<.01 then dx,dz=0,1 else dx,dz=dx/d,dz/d end
  local prev=r.previous;local elapsed=math.max(1,frame-prev.frame);local step=distance(x,z,prev.x,prev.z)
  -- A transport/teleport/discontinuity is not a run-up or an impact.
  if step>P.MaxSpeed(r.id)*elapsed/30*2+8 then C.Cancel(r.id,'native_motion_discontinuity');return end
  r.previous={x=x,z=z,frame=frame}
  P.Target(r.id,r.target)
  if r.phase=='charge'then
   r.runup=r.runup+step;r.armed=r.runup>=M.MinRunUp
   local vx,vz=P.Velocity(r.id);local tvx,tvz=P.Velocity(r.target)
   r.approach={frame=frame,closing=((vx-tvx)*dx+(vz-tvz)*dz)*30}
   local sum=P.Radius(r.id)+P.Radius(r.target)
   local raw=d<sum+96
   local gx,gz
   if raw then gx,gz=tx+dx*(sum+32),tz+dz*(sum+32)
   else gx,gz=tx-dx*(sum+64),tz-dz*(sum+64)end
   if not goal(r,gx,gz,raw,frame)then C.Cancel(r.id,'native_goal_refused')end
  else
   -- Three finite native waypoints peel off and circle to the other side.
   -- The target is never pushed, repositioned or suspended by this owner.
   local side=r.id%2==0 and 1 or-1
   local angle=r.angle+side*r.orbitStep*math.pi/3
   local gx,gz=tx+math.cos(angle)*r.radius,tz+math.sin(angle)*r.radius
   if distance(x,z,gx,gz)<24 then
    r.orbitStep=r.orbitStep+1;r.legFrame=frame
    if r.orbitStep>3 then r.phase='charge';r.runup=0;r.armed=false;r.approach=nil;r.goal=nil;return end
   elseif not goal(r,gx,gz,false,frame)then C.Cancel(r.id,'native_loop_goal_refused')end
  end
 end
 function C.Frame(frame)
  if frame%M.Period~=0 then return end
  for _,id in ipairs(keys(active))do local r=active[id];if r then update(r,frame)end end
 end
 function C.Collision(id,target)
  local r=active[id];local frame=P.Frame()
  if not r or r.target~=target or r.phase~='charge'or not valid(r)or not head(r)then return false end
  local x,y,z=P.Position(id);local tx,ty,tz=P.Position(target)
  if not finite(x)or not finite(y)or not finite(z)or not finite(tx)or not finite(ty)or not finite(tz)then return false end
  -- Extra rejection of bogus/far callbacks; the real engine collision event,
  -- not this radius, is the authority permitting contact damage.
  if distance(x,z,tx,tz)>P.Radius(id)+P.Radius(target)+16 or math.abs(y-ty)>P.Height(id)+P.Height(target)+8 then return false end
  local approach=r.approach;local last=P.LastHit(id)
  if not r.armed or not approach or frame-approach.frame>6 or approach.closing<M.MinImpactSpeed
   or(finite(last)and frame-last<M.Cooldown)then
   -- A weak/too-early real bump peels away without damage, instead of
   -- remaining pinned against the target until a timer grants a free hit.
   orbit(r,frame,x,z,tx,tz);P.Report(id,'contact_no_damage_loop');return false
  end
  -- Consume entitlement BEFORE native damage/callbacks; duplicate or reversed
  -- event delivery cannot pay again for this approach or the cooldown.
  P.SetLastHit(id,frame);orbit(r,frame,x,z,tx,tz);P.Report(id,'contact_hit')
  P.Damage(target,M.Damage,id)
  return true
 end
 function C.Removed(id,purge)
  C.Cancel(id,'unit_removed')
  for _,bike in ipairs(keys(active))do if active[bike].target==id then C.Cancel(bike,'target_removed')end end
  if purge then finished[id]=nil end
 end
 function C.Get(id)local r=active[id];if not r then return end;return{target=r.target,tag=r.tag,phase=r.phase,runup=r.runup,armed=r.armed}end
 return C
end
return M
