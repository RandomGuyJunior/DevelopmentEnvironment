-- One native leader route, local raw native followers. Not a rigid engine group.
-- No position/physics/MoveCtrl takeover, collision disabling, births or payment.
local M={Version=2,FollowCommand=34592,Period=6,LocalGoal=48,SegmentStep=12,TrailLimit=96,ReplanFrames=150,MaxReplans=2}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
local function keys(t)local a={};for k in pairs(t)do a[#a+1]=k end;table.sort(a);return a end
local function distance(a,b)return math.sqrt((a.x-b.x)^2+(a.z-b.z)^2)end
function M.New(P)
 local F={};local records={};local travel={[P.MOVE]=true,[P.FIGHT]=true,[P.PATROL]=true,[P.GUARD]=true}
 local function eligible(s)
  if P.Available and not P.Available()then return false end
  local p=s and P.Profile(s.profile)
  return p and p.capacity>=2 and p.capacity<=16 and not p.movementException and not p.singleton
 end
 local function members(s)
  if not eligible(s)then return end
  local ids=P.Members(s.leader);local set={};local lateral,longitudinal=0,0
  if type(ids)~='table'or #ids<1 or #ids>16 or ids[1]~=s.leader then return end
  for _,id in ipairs(ids)do
   local d=P.Definition(id);local cp=d and d.customParams or{};local md=P.MoveData(id)
   if set[id]or not P.Live(id,s.team)or not d or d.isBuilder or d.isFactory or cp.prototype40k_squad_exception
    or not md or md.name~='ground'or not finite(md.maxSpeed)or md.maxSpeed<=0 then return end
   local width,depth=P.Envelope(id,d,s.profile)
   if not finite(width)or not finite(depth)or width<=0 or depth<=0 then return end
   lateral=math.max(lateral,width);longitudinal=math.max(longitudinal,depth);set[id]=true
  end
  return ids,set,lateral,longitudinal
 end
 local function releasePace(r)
  if not r.hold then return end
  local h=r.hold;local md=P.MoveData(h.id)
  -- Compare-and-restore: never overwrite a new research/external wanted speed.
  if P.Token(h.id)==h.token and md and finite(md.maxWantedSpeed)and math.abs(md.maxWantedSpeed-h.applied)<.001 then P.Pace(h.id,math.min(h.saved,md.maxSpeed))end
  r.hold=nil
 end
 local function pace(r,value)
  local md=P.MoveData(r.leader)
  if not md or not finite(md.maxWantedSpeed)then return false end
  if r.hold and r.hold.id~=r.leader then releasePace(r)end
  if not r.hold then
   if value>=md.maxWantedSpeed-.001 then return true end
   r.hold={id=r.leader,token=P.Token(r.leader),saved=md.maxWantedSpeed,applied=value}
  elseif math.abs(md.maxWantedSpeed-r.hold.applied)>.001 then
   -- A native queue/research update supersedes the last temporary cap.
   r.hold.saved=md.maxWantedSpeed;r.hold.applied=value
  else r.hold.applied=value end
  local applied=P.Pace(r.leader,value)==true
  if applied and value==0 and r.hold and not r.pausedQueue and r.queue and r.queue[1]and r.queue[1].id==P.MOVE then
   -- Native idling completion/failure can consume MOVE while deliberately
   -- held. Preserve only our owned pause, never an arbitrary finished order.
   r.pausedQueue=copy(r.queue);r.pauseToken=P.Token(r.leader)
  end
  return applied
 end
 local function forgetPause(r)r.pausedQueue=nil;r.pauseToken=nil;r.pauseLost=nil;r.pauseShiftPending=nil end
 local function clear(r)
  releasePace(r)
  r.regroup=nil
  r.arrival=nil
  forgetPause(r)
  for _,id in ipairs(keys(r.controlled or{}))do P.ReleaseGoal(id,r.controlled[id])end
  for _,id in ipairs(keys(r.following or{}))do if P.EndFollow then P.EndFollow(id,r.following[id])end end
  r.controlled={};r.targets={}
  r.following={}
 end
 local function track(s)
  if not eligible(s)then return end
  local r=records[s.id]
  if not r then r={leader=s.leader,team=s.team,trail={},controlled={},following={},targets={},members={},replans=0,state='idle',frame=0};records[s.id]=r end
  return r
 end
 local function signature(q)
  if not q then return 'idle'end
  local a={tostring(q.id),tostring(q.tag)};for _,v in ipairs(q.params or{})do a[#a+1]=tostring(v)end;return table.concat(a,':')
 end
 local function remainingTail(saved,actual,shiftPending)
  if #actual==0 then return true end
  if actual[1].id~=P.MOVE then return false end
  if shiftPending then return true end
  for start=2,#saved do if #actual==#saved-start+1 then
   local equal=true;for n,row in ipairs(actual)do if signature(row)~=signature(saved[start+n-1])then equal=false;break end end
   if equal then return true end
  end end
  return false
 end
 local function continuePause(r,actual,x,z,longitudinal)
  local saved=r.pausedQueue;local head=saved and saved[1]
  if not head then return actual end
  if r.pauseToken~=P.Token(r.leader)then forgetPause(r);return actual end
  local params=head.params or{}
  if not finite(params[1])or not finite(params[3])or not finite(x)or not finite(z)then forgetPause(r);return actual end
  if actual[1]and signature(actual[1])==signature(head)then
   r.pausedQueue=copy(actual);r.pauseShiftPending=nil;return actual
  end
  -- Any current WAIT/ATTACK/foreign control has priority over recovery.
  if actual[1]and actual[1].id~=P.MOVE then forgetPause(r);return actual end
  local suffix=remainingTail(saved,actual,r.pauseShiftPending)
  if not suffix or(x-params[1])^2+(z-params[3])^2<=math.max(8,longitudinal)^2 then forgetPause(r);return actual end
  -- Keep the missing head plus only the actual still-pending native tail.
  -- Already consumed state/tail entries are never copied back a second time.
  local effective={copy(head)};for _,row in ipairs(actual)do effective[#effective+1]=copy(row)end
  r.pausedQueue=copy(effective);r.pauseLost=true;r.pauseShiftPending=nil
  return effective
 end
 local function remember(r,x,y,z,dx,dz)
  local point={x=x,y=y,z=z,dx=dx,dz=dz};local old=r.trail[#r.trail]
  if not old or distance(old,point)>=4 then r.trail[#r.trail+1]=point
  else r.trail[#r.trail]=point end
  while #r.trail>M.TrailLimit do table.remove(r.trail,1)end
 end
 local function behind(r,depth,x,y,z,dx,dz)
  local remain=depth;local last={x=x,y=y,z=z,dx=dx,dz=dz}
  for index=#r.trail-1,1,-1 do
   local old=r.trail[index];local span=distance(last,old)
   if span>.001 then
    if remain<=span then local f=remain/span;return{x=last.x+(old.x-last.x)*f,y=last.y+(old.y-last.y)*f,z=last.z+(old.z-last.z)*f,dx=(last.x-old.x)/span,dz=(last.z-old.z)/span}end
    remain=remain-span
   end
   last=old
  end
  return{x=last.x-last.dx*remain,y=last.y,z=last.z-last.dz*remain,dx=last.dx,dz=last.dz}
 end
 local function segment(id,from,target,set)
  local span=distance(from,target);local length=math.min(span,M.LocalGoal)
  if span>.001 then local scale=length/span;target={x=from.x+(target.x-from.x)*scale,z=from.z+(target.z-from.z)*scale}end
  target.y=P.Ground(target.x,target.z)
  if not finite(target.y)then return end
  if length<=2 then return target,true end
  local steps=math.max(1,math.ceil(length/M.SegmentStep))
  for n=1,steps do
   local f=n/steps;local px=from.x+(target.x-from.x)*f;local pz=from.z+(target.z-from.z)*f;local py=P.Ground(px,pz)
   if not finite(py)or not P.Clear(id,px,py,pz,set)then return end
  end
  return target,false
 end
 local function cohesionLimit(count,columns,lateral,longitudinal)
  local extent=0
  for rank=2,count do
   local index=rank-1;local row=math.floor(index/columns);local col=index%columns
   local side=col==0 and 0 or(col%2==1 and -math.ceil(col/2)or math.ceil(col/2))
   extent=math.max(extent,math.sqrt((side*lateral)^2+(row*longitudinal)^2))
  end
  -- One half-spacing permits native turning/goal tolerance at the edge of
  -- the actual grid; this is movement cohesion, never an arrival gate.
  return extent+math.max(lateral,longitudinal)*.5
 end
 local function shape(r,ids,set,lateral,longitudinal,x,y,z,dx,dz,columns,recover,settled)
  local plan={};local lag=0;local spread=0
  local leaderX,_,leaderZ=P.Position(r.leader)
  if not finite(leaderX)or not finite(leaderZ)then return end
  for rank,id in ipairs(ids)do if rank>1 then
   local index=rank-1;local row=math.floor(index/columns);local col=index%columns
   if settled then
    -- Stand compactly around the stopped real leader, rather than keeping
    -- every row behind a native goal that can legitimately finish short.
    -- Skip the leader's center and alternate forward/back rows; no overlap.
    if index<columns then row=0;col=index
    else
     local slot=index-(columns-1);local band=math.ceil(slot/columns)
     row=math.ceil(band/2)*(band%2==1 and -1 or 1);col=(slot-1)%columns
    end
   end
   local side=col==0 and 0 or(col%2==1 and -math.ceil(col/2)or math.ceil(col/2))
   -- A wide or paused formation is one coherent grid. Using each body's
   -- curved/pushed breadcrumb tangent folds adjacent slots into one another.
   -- Single-file travel alone follows the observed leader breadcrumbs.
   local a
   if columns>1 or r.regroup or settled or row==0 then a={x=x-dx*row*longitudinal,y=y,z=z-dz*row*longitudinal,dx=dx,dz=dz}
   else a=behind(r,row*longitudinal,x,y,z,dx,dz)end
   local desired={x=a.x+a.dz*side*lateral,z=a.z-a.dx*side*lateral}
   local cx,cy,cz=P.Position(id);if not finite(cx)or not finite(cy)or not finite(cz)then return end
   local origin={x=cx,y=cy,z=cz};spread=math.max(spread,math.sqrt((cx-leaderX)^2+(cz-leaderZ)^2));desired.y=P.Ground(desired.x,desired.z)
   local target,stay=segment(id,origin,desired,set)
   if not target and recover then
    -- Try an earlier observed leader breadcrumb, never a new follower path.
    local best,range
    for n=1,#r.trail do local point=r.trail[n];local d=distance(origin,point)
     if not range or d<range then local p,s=segment(id,origin,point,set);if p then best={p,s};range=d end end
    end
    if not best then return end;target,stay=best[1],best[2]
   end
   if not target then return end
   lag=math.max(lag,distance(origin,desired))
   plan[#plan+1]={id=id,rank=rank,trailDepth=row*longitudinal,x=target.x,y=target.y,z=target.z,desiredX=desired.x,desiredZ=desired.z,stay=stay}
  end end
  return plan,lag,spread
 end
 local function factoryReady(r,s,ids,set,lateral,longitudinal)
  if not r.factoryReleased or not P.FactoryClear or not P.FactoryClear(r.factory,ids)then return false end
  local x,y,z=P.Position(s.leader);local dx,dz=P.Direction(s.leader)
  if not finite(x)or not finite(y)or not finite(z)or not finite(dx)or not finite(dz)then return false end
  -- Admit exactly the coherent grid that the first shared-route tick will
  -- choose, rather than approving narrower slots then selecting wider ones.
  local plan=shape(r,ids,set,lateral,longitudinal,x,y,z,dx,dz,math.min(3,#ids))
  return plan and P.FactoryClear(r.factory,ids,plan)==true or false
 end
 function F.Track(s)return track(s)~=nil end
 function F.Factory(s,factory,released)
  local r=track(s);if not r then return end
  r.factory=factory;r.factoryReleased=released==true;r.egressDone=false
 end
 function F.Command(s,cmd,params,opts)
  local r=track(s);if not r then return false end
  if P.StateCommand(cmd)then return false end
  if cmd==P.STOP then clear(r);r.state='idle';r.queue={};r.trail={};r.replans=0;r.travelled=false;r.lastTravel=nil;return false end
  if cmd==P.INSERT or cmd==P.REMOVE then releasePace(r);r.regroup=nil;r.arrival=nil;r.travelled=false;r.lastTravel=nil;forgetPause(r);return true end -- Actual queue edit takes priority.
  if travel[cmd]or(cmd==P.INSERT and travel[params[2]])or cmd==P.REMOVE then
    if not(opts and opts.shift)then releasePace(r);r.regroup=nil;r.arrival=nil;forgetPause(r);r.replans=0;r.blockedSince=nil
    elseif r.pausedQueue then r.pauseShiftPending=true end
    r.travelled=true
    local current=P.Queue(s.leader);local head=current and current[1]
    if not(opts and opts.shift)or not head or travel[head.id]then
     -- Keep native CAI nonempty while raw-following; otherwise its idle branch
     -- may generate a separate ATTACK/bugger-off MOVE route for each soldier.
     if not r.factory or r.egressDone then
      r.state='starting';for _,id in ipairs(P.Members(s.leader))do if id~=s.leader and P.BeginFollow then r.following[id]=P.Token(id);P.BeginFollow(id,s.id,s.leader)end end
     end
    end
   return true
  end
  clear(r);r.state=cmd==P.ATTACK and 'combat'or'paused_command';r.travelled=false;r.lastTravel=nil
  return false
 end
 function F.Forward(s,cmd,params)
  if not eligible(s)then return true end
  local r=records[s.id];if r and r.factory and not r.egressDone then return true end
  return not(travel[cmd]or(cmd==P.INSERT and travel[params[2]]))
 end
 function F.FilterQueue(s,id,queue)
  if not eligible(s)or id==s.leader then return queue end
  local r=track(s);if r.factory and not r.egressDone then return queue end
  local out={}
  for _,row in ipairs(queue)do if not travel[row.id]and not(row.id==P.INSERT and travel[(row.params or{})[2]])then out[#out+1]=row end end
  return out
 end
 function F.Forget(seed)local r=records[seed];if r then clear(r);records[seed]=nil end end
 function F.BeforeRemove(s,id)
  local r=s and records[s.id]
  if r and id==s.leader then local q=P.Queue(id);if type(q)=='table'then
   local saved=r.pausedQueue
   -- Native death callback occurs before logical removal, but native liveness
   -- is already false. Its existing current member owns this pause snapshot.
   if saved and saved[1]and(not q[1]or signature(q[1])~=signature(saved[1]))and remainingTail(saved,q,r.pauseShiftPending)then
    local effective={copy(saved[1])};for _,row in ipairs(q)do effective[#effective+1]=copy(row)end;q=effective
   end
   r.queue=copy(q);r.deathQueue=true
  end end
 end
 function F.Changed(s,refreshID)
  local r=s and records[s.id];if not r then return end
  if s.team~=r.team then F.Forget(s.id);return end
  if s.leader~=r.leader then
   local previous=r.leader;local oldQueue=P.Queue(previous)
   clear(r);r.leader=s.leader;r.trail={};r.signature=nil
   -- A restored lower slot may promote a new leader while the former leader
   -- is still alive. Demote that real survivor before routing its successor.
   if P.Live(previous,s.team)and P.Demote then P.Demote(previous,s)end
   -- The dead previous leader's queue was read while it was alive. Preserve
   -- shifted/current native intent on the actual paid successor, never a birth.
   local current=P.Queue(s.leader)
   local queue=r.deathQueue and r.queue or(type(oldQueue)=='table'and #oldQueue>0 and oldQueue or(type(current)=='table'and #current>0 and current or r.queue))
   if queue and #queue>0 and P.Live(s.leader,s.team)then P.Replay(s.leader,queue)end
   r.deathQueue=nil
  end
  -- Paid newborns/research replacements already have real membership here.
  -- Retain their CAI marker immediately, rather than leaving an idle window
  -- until the next six-frame movement tick. Never intercept factory egress.
  local head=(P.Queue(s.leader)or{})[1]
  if head and travel[head.id]and(not r.factory or r.egressDone)then
   for _,id in ipairs(P.Members(s.leader))do if id~=s.leader and not P.Busy(id)and(id==refreshID or r.following[id]~=P.Token(id))and P.BeginFollow then r.following[id]=P.Token(id);P.BeginFollow(id,s.id,s.leader)end end
  end
 end
 function F.Idle(s)
  if not s or records[s.id]then return end
  local queue=P.Queue(s.leader);if queue and queue[1]and travel[queue[1].id]then track(s)end
 end -- Raw followers reporting idle cannot reset an active route.
 local function faceActive(frame,squads)
  -- Native ground physics can turn toward each local offset between goal
  -- ticks. Cheap active-only heading updates use no paths/model geometry.
  for _,seed in ipairs(keys(records))do local r=records[seed];local s=squads[seed]
   local active=r.state=='moving'or r.state=='waiting_members'or r.state=='arriving'
   local head=active and s and(P.Head and P.Head(s.leader)or(P.Queue(s.leader)or{})[1])
   if s and s.leader==r.leader and s.team==r.team and r.lastTravel and r.lastTravel.id==P.MOVE
    and((head and head.id==P.MOVE)or(not head and r.state=='arriving'))
    and(r.state=='moving'or r.state=='arriving')then
    local dx,dz=P.Direction(s.leader)
    if finite(dx)and finite(dz)then local heading,up=P.Facing(s.leader,dx,dz)
     if finite(heading)and type(up)=='table'then
      r.heading=heading;r.headingFrame=frame
      for _,id in ipairs(r.members)do if P.Live(id,s.team)and not P.Busy(id)and not P.Combat(id)then
       -- Native ground movement needs its own turning to reform sideways or
       -- backwards. Share facing only when its local segment follows travel.
       local aligned=id==s.leader
       if not aligned then for _,goal in ipairs(r.targets)do if goal.id==id then
        local x,_,z=P.Position(id)
        if finite(x)and finite(z)then local gx,gz=goal.x-x,goal.z-z;local n=math.sqrt(gx*gx+gz*gz);aligned=n<=2 or(gx*dx+gz*dz)/n>=.96592582628907 end;break
       end end end
       if aligned then P.Face(id,heading,up)end
      end end
     end
    end
   end
  end
 end
 function F.Frame(frame,squads)
  if frame%M.Period~=0 then faceActive(frame,squads);return end
  for _,seed in ipairs(keys(records))do
   local r=records[seed];local s=squads[seed]
   if not s or not eligible(s)then F.Forget(seed)
   else
    F.Changed(s);r=records[seed]
    if r then
     r.frame=frame;r.leader=s.leader;r.team=s.team
     local ids,set,lateral,longitudinal=members(s)
     if not ids then clear(r);r.state='paused_invalid';r.reason='live_native_ground_members_required'
     else
      r.members=copy(ids);local busy=false
      -- Drop replaced/dead body ownership without touching a new incarnation.
      for _,id in ipairs(keys(r.controlled))do if not set[id]or P.Token(id)~=r.controlled[id].token then P.ReleaseGoal(id,r.controlled[id]);r.controlled[id]=nil end end
      for _,id in ipairs(keys(r.following))do if not set[id]or P.Token(id)~=r.following[id]then if P.EndFollow then P.EndFollow(id,r.following[id])end;r.following[id]=nil end end
      for _,id in ipairs(ids)do if P.Busy(id)then busy=true end end
      if busy then clear(r);r.state='paused_transport';r.reason='transport_jump_or_other_native_motion_owner';r.travelled=false;r.lastTravel=nil
      elseif r.factory and not r.egressDone and not factoryReady(r,s,ids,set,lateral,longitudinal)then
       clear(r);r.state='factory_egress';r.reason='native_producer_release_and_all_body_exit';r.queue=copy(P.Queue(s.leader)or{})
      else
       if r.factory and not r.egressDone then
        r.egressDone=true
        for _,id in ipairs(ids)do if id~=s.leader and P.Demote then P.Demote(id,s)end end
       end
       if P.SyncState then for _,id in ipairs(ids)do if id~=s.leader then P.SyncState(id,s.leader)end end end
       local queue=P.Queue(s.leader)or{};local lx,_,lz=P.Position(s.leader)
       queue=continuePause(r,queue,lx,lz,longitudinal)
       local q=queue[1];local arriving=false;local md=P.MoveData(s.leader)
       if q and travel[q.id]then r.lastTravel=copy(q);r.lastTravelLeader=s.leader;r.lastTravelToken=P.Token(s.leader);r.travelled=true
       elseif not q and r.travelled and r.lastTravel then
        -- An empty queue alone does not prove arrival (queued STOP/removal can
        -- also empty it). Settle only after physically reaching its last goal.
        local p=r.lastTravel.params or{};local lx,_,lz=P.Position(s.leader)
        -- Native ground completion can extend its base goal radius during
        -- idling. Trust its done state only for this real leader's exact
        -- last MOVE target; explicit queue edits/STOP invalidate that intent.
        local nativeDone=r.lastTravel.id==P.MOVE and r.lastTravelLeader==s.leader and r.lastTravelToken==P.Token(s.leader)
         and md and md.progressState=='done'and md.goalx==p[1]and md.goalz==p[3]
        if finite(p[1])and finite(p[3])and finite(lx)and finite(lz)and(nativeDone or(lx-p[1])^2+(lz-p[3])^2<=math.max(8,longitudinal)^2)then q=r.lastTravel;arriving=true end
       end
       r.queue=copy(queue or{})
       if not q or not travel[q.id]then
        clear(r);r.state=q and(q.id==P.WAIT and'paused_wait'or q.id==P.ATTACK and'combat'or'paused_command')or'idle';r.reason='native_current_command';r.signature=nil
        r.travelled=false;r.lastTravel=nil
       elseif not md or(md.progressState=='failed'and not r.pausedQueue)then
        clear(r);r.state='failed';r.reason='native_leader_path_failed'
       else
        local x,y,z=P.Position(s.leader);local dx,dz=P.Direction(s.leader);local heading,up
        if finite(dx)and finite(dz)then heading,up=P.Facing(s.leader,dx,dz)end
        if not finite(x)or not finite(y)or not finite(z)or not finite(dx)or not finite(dz)then clear(r);r.state='paused_invalid';r.reason='native_route_position_required'
        else
         if r.signature~=signature(q)then r.signature=signature(q);r.blockedSince=nil;r.regroup=nil;r.arrival=nil end
         -- Small read-only state for bounded diagnostics; no extra native
         -- queries, commands, model access or simulation ownership.
         r.nativeLeader={x=x,z=z,goalx=md.goalx,goalz=md.goalz,
          waypointx=md.currwaypointx,waypointz=md.currwaypointz,
          maxWantedSpeed=md.maxWantedSpeed,progressState=md.progressState}
         -- A zero speed cap does not prevent native collision pushes. Keep
         -- the tested regroup slots fixed until members converge; otherwise
         -- the held leader's push/turn continually moves their destination.
         if arriving then r.regroup=nil;r.arrival=r.arrival or{x=x,y=y,z=z,dx=dx,dz=dz}
         else r.arrival=nil end
         if r.arrival then
          x,y,z,dx,dz=r.arrival.x,r.arrival.y,r.arrival.z,r.arrival.dx,r.arrival.dz
         elseif r.regroup then
          x,y,z,dx,dz=r.regroup.x,r.regroup.y,r.regroup.z,r.regroup.dx,r.regroup.dz
         else remember(r,x,y,z,dx,dz)end
         local chosen,lag,columns,spread
         for n=math.min(3,#ids),1,-1 do local plan,gap,cohort=shape(r,ids,set,lateral,longitudinal,x,y,z,dx,dz,n,nil,arriving);if plan then chosen,lag,columns,spread=plan,gap,n,cohort;break end end
         -- Exact narrowing gets priority. Breadcrumb recovery is single-file
         -- only, so a denied wide formation cannot masquerade as columns=3.
         if not chosen then chosen,lag,spread=shape(r,ids,set,lateral,longitudinal,x,y,z,dx,dz,1,true,arriving);if chosen then columns=1 end end
         r.heading=heading;r.columns=columns or 0;r.targets=chosen or{};r.lateral=lateral;r.longitudinal=longitudinal;r.maxLag=lag;r.cohesion=spread;r.cohesionLimit=columns and cohesionLimit(#ids,columns,lateral,longitudinal)
         if not chosen then
          for _,id in ipairs(keys(r.controlled))do P.ReleaseGoal(id,r.controlled[id])end;r.controlled={}
          local paced=pace(r,0);r.state='blocked';r.reason='no_tested_short_segment';r.blockedSince=r.blockedSince or frame
          if not paced then clear(r);r.state='paused_invalid';r.reason='native_temporary_pace_refused'end
          if paced and not arriving and frame-r.blockedSince>=M.ReplanFrames and r.replans<M.MaxReplans then
           releasePace(r);P.Replay(s.leader,r.queue);r.replans=r.replans+1;r.blockedSince=frame
          end
         else
          r.blockedSince=nil
          local slow=md.maxSpeed;for _,id in ipairs(ids)do slow=math.min(slow,P.MoveData(id).maxSpeed)end
          local paced=true
          if arriving then releasePace(r);r.regroup=nil;r.state='arriving';r.reason='local_final_settle'
          elseif spread>r.cohesionLimit*2 or(r.regroup and spread>r.cohesionLimit)then
           r.regroup=r.regroup or{x=x,y=y,z=z,dx=dx,dz=dz}
           paced=pace(r,0);r.state='waiting_members';r.reason='local_reformation'
          else
           r.regroup=nil
           local resume=r.pausedQueue and(r.pauseLost or md.progressState=='failed')
           releasePace(r)
           if resume and r.replans>=M.MaxReplans then clear(r);paced=false;r.state='failed';r.reason='owned_pause_resume_budget_exhausted'
           else
            if resume then
             r.replans=r.replans+1
             if not P.ResumeQueue or P.ResumeQueue(s.leader,r.queue)~=true then clear(r);paced=false;r.state='failed';r.reason='owned_pause_native_goal_resume_refused'
             else r.pauseResumes=(r.pauseResumes or 0)+1 end
            end
            if paced then
             forgetPause(r)
             -- Physical cohesion permits member crossings without holding a
             -- compact whole squad until every ordinal slot is occupied.
             local cap=slow*math.min(1,r.cohesionLimit/math.max(spread,r.cohesionLimit))
             paced=pace(r,cap);r.state='moving';r.reason=resume and'owned_pause_goal_resumed'or'native_leader_path_local_raw_followers'
            end
           end
          end
          if not paced then clear(r);if r.state~='failed'then r.state='paused_invalid';r.reason='native_temporary_pace_refused'end
          else for _,p in ipairs(chosen)do
           if P.BeginFollow then r.following[p.id]=P.Token(p.id);P.BeginFollow(p.id,s.id,s.leader)end
           if p.stay then if r.controlled[p.id]then P.ReleaseGoal(p.id,r.controlled[p.id]);r.controlled[p.id]=nil end
           else P.RawGoal(p.id,p.x,p.y,p.z,2);r.controlled[p.id]={x=p.x,z=p.z,token=P.Token(p.id)}end
          end end
          if arriving and lag<=4 then clear(r);r.state='arrived';r.reason='native_leader_arrival_and_local_settle';r.travelled=false;r.lastTravel=nil end
         end
        end
       end
      end
     end
    end
   end
  end
  faceActive(frame,squads)
 end
 function F.Get(seedOrActor)
  local r=records[seedOrActor];local s=not r and P.Squad(seedOrActor);r=r or records[s and s.id or seedOrActor]
  if not r then return end
  local out=copy(r);out.ownedPace=r.hold and{id=r.hold.id,saved=r.hold.saved,applied=r.hold.applied}or nil;out.hold=nil;out.queue=nil;out.pausedQueue=nil;out.pauseToken=nil;out.controlled=nil;out.following=nil;out.signature=nil
  out.mode='one_native_leader_route_native_raw_followers';out.engineRigidGroup=false;out.nativePathRequestsCounted=false
  out.followCommand=M.FollowCommand
  return out
 end
 function F.ActiveFollower(s,id,params)
  local r=s and records[s.id]
  return r and id~=s.leader and r.following[id]==P.Token(id)and params[1]==s.id and params[2]==s.leader and not P.Busy(id)or false
 end
 return F
end
return M
