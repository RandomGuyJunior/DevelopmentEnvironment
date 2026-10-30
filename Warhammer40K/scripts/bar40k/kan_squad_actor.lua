-- One native mover/target. Member facing, gait phase and recoil are presentation.
local cp = UnitDefs[unitDefID].customParams
local data = include('bar40k/animation_data.lua')(cp.squad_bank)
local prefix = cp.squad_prefix or (cp.tenguard_squad and 'tenguard' or 'tenboy')
local capacity = tonumber(cp.squad_capacity) or #data.members
assert(capacity==#data.members and capacity>=1, 'Squad capacity/bank mismatch')
local members, alive, dead = {}, capacity, false
-- Each full squad is centred on its native mover. A prefix of the ten-member
-- scatter is not a balanced formation for a three- or five-member squad.
local capacityLayouts={
  [3]={{-10,-4},{9,-6},{1,10}},
  [5]={{-12,7},{1,11},{13,3},{-8,-10},{6,-11}},
}
local layout = data.layout or capacityLayouts[capacity] or include('bar40k/squad_scatter.lua')
assert(#layout>=capacity, 'Missing squad formation slots')
local spread = tonumber(cp.squad_spread) or data.spread or (cp.tenguard_squad and 1.14 or .965)
local formationScale = math.max(.01,tonumber(cp.squad_formation_scale) or 1)
local spacing = tonumber(cp.squad_spacing) or 8.3
local mirror = unitID%2==0 and 1 or -1
local activeMuzzle, nextMuzzle, shots = 1, 1, 0
local nextAllowed, cadenceFraction = 0, 0
local salvoPeriod=tonumber(cp.squad_salvo_period)
local salvoSpacing=tonumber(cp.squad_salvo_spacing) or .18
local salvoStart,salvoSpent=-10000,{}
local lastSound=-1000
local memberCooldown=tonumber(cp.squad_member_cooldown) or (cp.tenboy_squad and 27 or 14)
local aimCenter = piece('squad_aim')
local tau, fps = 2 * math.pi, Game.gameSpeed
local aimUntil, targetYaw, formationYaw, heading = 0, 0, 0, 0
local targetX,targetZ
local combat = include('bar40k/animation_data.lua')(cp.squad_combat_profile or 'bar40k/squad_combat_pose.lua')
if type(combat)=='function' then combat=combat(cp.squad_bank) end
local contactSlots=data.contactSlots or {{-9,1},{1,-.5},{22,-2},{-19,-1},{-12,-9.5},{12,2},{-22,-11},{-2,-11},{19,-12},{8,-8}}
local meleeTarget
local function airborne() return cp.squad_jetpack and Spring.GetUnitRulesParam(unitID,'squad_jetpack_airborne')==1 end
local function engaged() return not airborne() and GG.SquadMelee and GG.SquadMelee[unitID] end
local travel, speed, oldX, oldZ = 0, 0
local definition = UnitDefs[unitDefID]
local baseReload = tonumber(cp.squad_shot_interval) or 0.1
local rules = {inlos=true}
local function publish(k,v) Spring.SetUnitRulesParam(unitID,prefix..'_'..k,v,rules) end
local function angle(v) return (v+math.pi)%tau-math.pi end
-- Each native slot belongs to one physical Kan, never a random soldier.
local function memberTarget(m)
 local kind,_,target=Spring.GetUnitWeaponTarget(unitID,m.weaponSlot)
 if kind==1 then m.fireX,m.fireY,m.fireZ=Spring.GetUnitPosition(target)
 elseif kind==2 and target then m.fireX,m.fireY,m.fireZ=target[1],target[2],target[3]
 else m.fireX,m.fireY,m.fireZ=nil,nil,nil end
 return m.fireX~=nil
end
local function rangedTarget()
 for _,m in ipairs(members)do
  if m.state=='alive' and memberTarget(m)then targetX,targetZ=m.fireX,m.fireZ;return true end
 end
 targetX,targetZ=nil,nil;return false
end
local function barrelAligned(m)
 local _,_,_,x,y,z=Spring.GetUnitPiecePosDir(unitID,m.muzzle)
 local _,_,_,tx,ty,tz=Spring.GetUnitWeaponVectors(unitID,m.weaponSlot)
 if not(x and y and z and tx and ty and tz)then return false end
 local a=x*x+y*y+z*z;local b=tx*tx+ty*ty+tz*tz
 return a>1e-12 and b>1e-12 and(x*tx+y*ty+z*tz)/math.sqrt(a*b)>=math.cos(math.rad(6))
end
local function readyToFire(m,f)
 if engaged() then return false end
 if not memberTarget(m)or m.state~='alive' or f-(m.transitionFrame or f)<12 then return false end
 if speed>.5 then return m.mode=='runfire' and barrelAligned(m)end
 return m.mode=='ready' and barrelAligned(m)
end
-- Six native slots, one ranged and one claw weapon per physical owner.
local function cancelMelee(m)
 m.meleeStart=nil;m.meleeTarget=nil;m.meleeHit=false;m.meleeAuthorized=nil;m.meleeReloadAt=nil
end
local function meleeEligible(m,target)
 if dead or m.state~='alive' or not target or speed>=2 or(m.slotSpeed or 0)>.5 then return false end
 local kind,_,nativeTarget=Spring.GetUnitWeaponTarget(unitID,m.meleeSlot)
 if kind~=1 or nativeTarget~=target then return false end
 local tx,ty,tz=Spring.GetUnitPosition(target);if not tx then return false end
 local x,y,z=Spring.GetUnitPiecePosDir(unitID,m.meleeMuzzle)
 local radius=Spring.GetUnitRadius and Spring.GetUnitRadius(target)or 0
 if (tx-x)^2+(ty-y)^2+(tz-z)^2>(60+radius)^2 then return false end
 local px,_,pz=Spring.GetUnitPiecePosDir(unitID,m.root)
 return math.abs(angle(math.atan2(tx-px,tz-pz)-m.yaw))<=math.rad(15)
end
local function maintainMelee(m,frame)
 if m.meleeReloadAt and frame>=m.meleeReloadAt then
  Spring.SetUnitWeaponState(unitID,m.meleeSlot,{reloadState=m.meleeNextCycle});m.meleeReloadAt=nil
 end
 local target=engaged()
 if m.meleeStart and (target~=m.meleeTarget or not meleeEligible(m,target))then cancelMelee(m)end
end
local function apply(m,row,seconds,instant)
  if not instant and m.appliedRow==row then return end
  m.appliedRow=row
  for b,pose in ipairs(row) do
    local previous=m.previous[b];local handle=m.bones[b]
    for axis=1,3 do
      local delta=previous and math.abs(pose[axis]-previous[axis]) or 1
      if instant or delta>0.0001 then
        if true then Move(handle,axis,pose[axis]) else Move(handle,axis,pose[axis],delta/seconds) end
      end
      delta=previous and math.abs(angle(pose[axis+3]-previous[axis+3])) or 1
      if instant or delta>0.0001 then
        if true then Turn(handle,axis,pose[axis+3]) else Turn(handle,axis,pose[axis+3],delta/seconds) end
      end
    end
    m.previous[b]=pose
  end
end
-- Immutable walk interpolation shared across squads. 512 phase samples keep
-- maximum phase error below 1/1024 stride; combat/aim/recoil remain continuous.
GG.SquadWalkPoseCache=GG.SquadWalkPoseCache or {}
GG.SquadWalkPoseCache[cp.squad_bank]=GG.SquadWalkPoseCache[cp.squad_bank] or {}
local walkCache=GG.SquadWalkPoseCache[cp.squad_bank]
-- Exact-time shared flight samples: at most 512 immutable rows per looping
-- clip. Unlike a quantized phase cache this never approximates source motion.
local flightCache
if data.clips.fly_idle or data.clips.fly_climb or data.clips.fly_descend then
  GG.SquadFlightPoseCache=GG.SquadFlightPoseCache or {}
  GG.SquadFlightPoseCache[cp.squad_bank]=GG.SquadFlightPoseCache[cp.squad_bank] or {}
  flightCache=GG.SquadFlightPoseCache[cp.squad_bank]
end
GG.SquadSourceLocalPose=GG.SquadSourceLocalPose or {}
local sourcePose=GG.SquadSourceLocalPose[cp.squad_bank]
if not sourcePose then
 local meta=include('bar40k/animation_data.lua')(cp.squad_source_hierarchy or 'bar40k/kan_source_hierarchy.lua')
 sourcePose=include('bar40k/source_local_pose.lua')(meta)
 GG.SquadSourceLocalPose[cp.squad_bank]=sourcePose
end
local function sample(clip,t,loop)return sourcePose.sample(clip,t,loop)end
local function blend(a,b,t)
 t=math.max(0,math.min(1,t));t=t*t*(3-2*t)
 return sourcePose.blend(a,b,t)
end
-- BEGIN PHYSICAL ARM BLEND
-- Corrected immutable source rows are shared; weak keys discard transient
-- recoil/transition rows while the bounded walk cache keeps common phases.
GG.SquadConnectedPoseCache=GG.SquadConnectedPoseCache or {}
GG.SquadConnectedPoseCache[cp.squad_bank]=GG.SquadConnectedPoseCache[cp.squad_bank] or setmetatable({},{__mode='k'})
local connectedCache=GG.SquadConnectedPoseCache[cp.squad_bank]
local function posedPoint(row,p)
  local cx,sx=math.cos(row[4]),math.sin(row[4])
  local cy,sy=math.cos(row[5]),math.sin(row[5])
  local cz,sz=math.cos(row[6]),math.sin(row[6])
  local x,y=cz*p[1]-sz*p[2],sz*p[1]+cz*p[2]
  local z=sx*y+cx*p[3];y=cx*y-sx*p[3]
  return {row[1]+cy*x+sy*z,row[2]+y,row[3]-sy*x+cy*z}
end
local function keepArmsConnected(source)
  if combat.preserveSourceMuzzle and not combat.hierarchy then return source end
  if combat.hierarchy and connectedCache[source] then return connectedCache[source] end
  local row={}
  for i,v in ipairs(source) do row[i]={v[1],v[2],v[3],v[4],v[5],v[6]} end
  local function attach(index,pivot,parent,anchor)
    local target=posedPoint(row[parent],anchor);local current=posedPoint(row[index],pivot)
    local d={target[1]-current[1],target[2]-current[2],target[3]-current[3]}
    for k=1,3 do row[index][k]=row[index][k]+d[k] end
    return d
  end
  if combat.hierarchy then
    for _,c in ipairs(combat.hierarchy) do attach(c.index,c.pivot,c.parent,c.parentAnchor) end
    local muzzle=combat.muzzleAttachment
    if muzzle then
      local p=posedPoint(row[muzzle.parent],muzzle.indexPivot)
      for k=1,3 do row[#row][k]=p[k] end
    end
    connectedCache[source]=row
    return row
  end
  for _,c in ipairs(combat.armChains) do
    attach(c.shoulder,c.shoulderPivot,c.torso,c.shoulderInTorso)
    attach(c.elbow,c.elbowPivot,c.shoulder,c.elbowInUpper)
    local d=attach(c.hand,c.handPivot,c.elbow,c.handInLower)
    for _,j in ipairs(c.followers) do for k=1,3 do row[j][k]=row[j][k]+d[k] end end
  end
  local p=posedPoint(row[combat.muzzleHand],combat.muzzleInHand)
  for k=1,3 do row[#row][k]=p[k] end
  return row
end
-- END PHYSICAL ARM BLEND
local function strength(count)
 alive=count;publish('alive',count)
 -- Weapon damage/cadence is not survivor-scaled: each living owner retains
 -- its original weapon, and each dead owner loses only that weapon.
end
local function remains(m)
  if m.corpse then return end
  local x,_,z=Spring.GetUnitPiecePosDir(unitID,m.root)
  if GG.SquadRemains then m.corpse=GG.SquadRemains(unitID,m.index,x,z,m.yaw) end
end
local function updateMembers(frame)
  local hp,maxhp,_,_,build=Spring.GetUnitHealth(unitID);if not hp then return end
  local count=build and build<1 and capacity or math.max(1,math.min(capacity,math.ceil(hp/maxhp*capacity-0.000001)))
  if count~=alive then strength(count) end
  for i,m in ipairs(members) do
    if i<=count and m.state~='alive' then
      if m.corpse and GG.SquadRemoveRemains then GG.SquadRemoveRemains(m.corpse) end
      m.corpse=nil;m.state='alive';m.previous={};m.basePrevious=nil;m.shotFrame=-1000;cancelMelee(m)
      Spring.SetUnitWeaponState(unitID,m.weaponSlot,{nextSalvo=frame+1,reloadState=frame+1})
      Spring.SetUnitWeaponState(unitID,m.meleeSlot,{nextSalvo=frame+1,reloadState=frame+1})
      Move(m.root,y_axis,0);apply(m,m.ready,0.1,true)
      publish('member_'..i,1);publish('hidden_'..i,0)
    elseif i>count and m.state=='alive' then
      m.state='dying';m.instantWalk=false;m.deathFrame=frame;cancelMelee(m);publish('member_'..i,0)
      Spring.SetUnitWeaponState(unitID,m.weaponSlot,{nextSalvo=frame+1000000,reloadState=frame+1000000})
      Spring.SetUnitWeaponState(unitID,m.meleeSlot,{nextSalvo=frame+1000000,reloadState=frame+1000000})
    end
  end
end
local lastFrame=-1
local function facing()
  if GG.SquadPerfFreeze then return end
  if not dead then
    local f=Spring.GetGameFrame();local x,_,z=Spring.GetUnitPosition(unitID)
    local dt=math.max(1,f-lastFrame)/fps;lastFrame=f
    heading=Spring.GetUnitHeading(unitID)*tau/65536
    local dx,dz=x-(oldX or x),z-(oldZ or z);oldX,oldZ=x,z
    local distance=math.sqrt(dx*dx+dz*dz);speed=distance/dt
    if distance<8 then travel=travel+distance end -- don't run through teleports
    meleeTarget=engaged()
    if not meleeTarget and rangedTarget() then aimUntil=f+fps end
    if meleeTarget then targetX,_,targetZ=Spring.GetUnitPosition(meleeTarget);aimUntil=f+fps end
    -- The squad now turns as one formation. Every member shares this heading;
    -- slots and roots rotate together about the unchanged native unit centre.
    local wanted=heading
    if not airborne() and speed<=.5 and f<aimUntil and targetX then wanted=math.atan2(targetX-x,targetZ-z) end
    local turn=angle(wanted-formationYaw);local limit=dt*8.5
    formationYaw=formationYaw+math.max(-limit,math.min(limit,turn))
    local c,s=math.cos(formationYaw-heading),math.sin(formationYaw-heading)
    for _,m in ipairs(members) do
      -- Counter-rotate the slot around the mover, preserving its world offset.
      local hx,hz=m.homeSlot[1],m.homeSlot[2]
      if meleeTarget and targetX then
        local vx,vz=targetX-x,targetZ-z;local distance=math.sqrt(vx*vx+vz*vz)
        if distance>.1 then
          vx,vz=vx/distance,vz/distance
          local lateral=contactSlots[m.index][1]
          local front=math.min(25,distance*.5-9)+contactSlots[m.index][2]
          local wx,wz=vx*front+vz*lateral,vz*front-vx*lateral
          local fc,fs=math.cos(formationYaw),math.sin(formationYaw)
          hx,hz=fc*wx-fs*wz,fs*wx+fc*wz
          m.faceX=x+vx*(distance*.5+9)+vz*lateral;m.faceZ=z+vz*(distance*.5+9)-vx*lateral
        end
      else m.faceX=nil end
      local sx,sz=hx-m.slot[1],hz-m.slot[2];local remaining=math.sqrt(sx*sx+sz*sz)
      local step=math.min(remaining,dt*(26+(m.index*7+unitID)%13))
      if remaining>.001 then
        local nx,nz=m.slot[1]+sx/remaining*step,m.slot[2]+sz/remaining*step
        -- Slide around living squadmates; do not pass through their body discs.
        -- This is presentation spacing, not ten extra pathfinders.
        for _,other in ipairs(members)do
          if other~=m and other.state=='alive' then
            local dx,dz=nx-other.slot[1],nz-other.slot[2];local d=math.sqrt(dx*dx+dz*dz)
            if d<spacing and d>.001 then nx=other.slot[1]+dx/d*spacing;nz=other.slot[2]+dz/d*spacing end
          end
        end
        local dx,dz=nx-m.slot[1],nz-m.slot[2];local length=math.sqrt(dx*dx+dz*dz)
        if length>step then nx=m.slot[1]+dx/length*step;nz=m.slot[2]+dz/length*step end
        local after=math.sqrt((nx-hx)^2+(nz-hz)^2)
        if after>=remaining-.01 then nx,nz=m.slot[1],m.slot[2]end
        step=math.sqrt((nx-m.slot[1])^2+(nz-m.slot[2])^2);m.slot={nx,nz}
      end
      m.slotSpeed=step/dt;m.localTravel=(m.localTravel or 0)+step
      local ox,oz=m.slot[1],m.slot[2]
      local rx,rz=c*ox+s*oz-m.offset[1],-s*ox+c*oz-m.offset[3]
      if not m.rx or math.abs(rx-m.rx)>.0001 then Move(m.root,x_axis,rx);m.rx=rx end
      if not m.rz or math.abs(rz-m.rz)>.0001 then Move(m.root,z_axis,rz);m.rz=rz end
      local desired=formationYaw
      if meleeTarget then
       local tx,_,tz=Spring.GetUnitPosition(meleeTarget);local px,_,pz=Spring.GetUnitPiecePosDir(unitID,m.root)
       if tx then desired=math.atan2(tx-px,tz-pz)end
      elseif speed<=.5 and memberTarget(m)then
       local px,_,pz,bx,_,bz=Spring.GetUnitPiecePosDir(unitID,m.muzzle)
       local actual=math.atan2(bx,bz);local wanted=math.atan2(m.fireX-px,m.fireZ-pz)
       desired=(m.yaw or formationYaw)+angle(wanted-actual)
      end
      m.targetYaw=desired
      m.yaw=(m.yaw or formationYaw)+math.max(-dt*2.1,math.min(dt*2.1,angle(desired-(m.yaw or formationYaw))))
      if not m.publishedYaw or math.abs(angle(m.yaw-m.publishedYaw))>.005 then publish('lod_yaw_'..m.index,m.yaw);m.publishedYaw=m.yaw end
      local ry=angle(m.yaw-heading)
      if not m.ry or math.abs(angle(ry-m.ry))>.0001 then Turn(m.root,y_axis,ry);m.ry=ry end
    end
  end
end
local function upperAim(m,row,turn,shift)
  local out={};for j,r in ipairs(row) do out[j]=r end
  local pivot=m.ready[combat.chest];local c,s=math.cos(turn),math.sin(turn)
  for _,j in ipairs(combat.upper) do
    local a=row[j];local x,z=a[1]-pivot[1],a[3]-pivot[3]
    out[j]={pivot[1]+c*x+s*z+shift[1],a[2]+shift[2],pivot[3]-s*x+c*z+shift[3],a[4],a[5]+turn,a[6]}
  end
  return out
end
local function pitchWeapon(m,source)
 local group=combat.weaponPitch;if not group then return source end
 local out={};for i,row in ipairs(source)do out[i]={unpack(row)}end
 local pivot=posedPoint(out[group.pivotJoint],group.pivot)
 local muzzle=out[data.memberMuzzleRows[m.index]]
 -- Native Ry*Rx*Rz forward is independent of local Z roll.
 local oldPitch=math.asin(math.max(-1,math.min(1,-math.sin(muzzle[4]))))
 local a=-((m.aimPitch or 0)-oldPitch);local c,s=math.cos(a),math.sin(a)
 local function rot(x,y,z)return x,c*y-s*z,s*y+c*z end
 local function matrix(row)
  local x,y,z=row[4],row[5],row[6];local cx,sx,cy,sy,cz,sz=math.cos(x),math.sin(x),math.cos(y),math.sin(y),math.cos(z),math.sin(z)
  return {cy*cz+sy*sx*sz,-cy*sz+sy*sx*cz,sy*cx,cx*sz,cx*cz,-sx,-sy*cz+cy*sx*sz,sy*sz+cy*sx*cz,cy*cx}
 end
 for _,i in ipairs(group.members)do
  local row=out[i];local x,y,z=rot(row[1]-pivot[1],row[2]-pivot[2],row[3]-pivot[3]);row[1],row[2],row[3]=x+pivot[1],y+pivot[2],z+pivot[3]
  local r=matrix(row);local t={r[1],r[2],r[3],c*r[4]-s*r[7],c*r[5]-s*r[8],c*r[6]-s*r[9],s*r[4]+c*r[7],s*r[5]+c*r[8],s*r[6]+c*r[9]}
  local rx=math.asin(math.max(-1,math.min(1,-t[6])));local ry,rz
  if math.abs(math.cos(rx))<1e-6 then ry,rz=math.atan2(-t[7],t[1]),0 else ry,rz=math.atan2(t[3],t[9]),math.atan2(t[4],t[5])end
  row[4],row[5],row[6]=rx,ry,rz
 end
 return out
end
local function animate()
  Sleep((unitID%2)*1000/fps)
  while not dead do
    if GG.SquadPerfFreeze then Sleep(100) else
    local f=Spring.GetGameFrame();updateMembers(f);meleeTarget=engaged()
    for _,m in ipairs(members)do maintainMelee(m,f)end
    local interval=(speed>0.5 or f<aimUntil) and 2 or 3
    for _,m in ipairs(members) do if m.state=='dying' then interval=2;break end end
    if engaged() then interval=1 else
      for _,m in ipairs(members) do if f<(m.armTransitionUntil or -1) then interval=1;break end end
    end
    if speed>.5 and f>=aimUntil and not meleeTarget then interval=1 end
    interval=1 -- Three heavy members: source-local commands at every simulation frame.
    local seconds=interval/fps
    for _,m in ipairs(members) do
      if m.state=='alive' then
        local row,mode
        local movingFire=speed>0.5 and f<aimUntil and not meleeTarget
        -- Immediate melee presentation, with running legs while closing contact.
        if airborne() then
          mode='flight'
          local phase=Spring.GetUnitRulesParam(unitID,'squad_jetpack_phase') or 1
          local start=Spring.GetUnitRulesParam(unitID,'squad_jetpack_frame') or f
          local vertical=Spring.GetUnitRulesParam(unitID,'squad_jetpack_vertical') or 0
          local key=phase==0 and 'fly_launch' or phase==2 and 'fly_land' or vertical>0 and 'fly_climb' or vertical<0 and 'fly_descend' or 'fly_idle'
          local clip=data.clips[key] or data.clips.fly_idle
          row=clip and sample(clip,(f-start)/fps+(phase==1 and m.phase*clip.duration or 0),phase~=0 and phase~=2) or data.clips.idle.frames[1]
        elseif meleeTarget and speed<2 and((m.slotSpeed or 0)<.5 or m.meleeStart)then
          mode='melee'
          row=m.meleeStart and sample(m.meleeClip,(f-m.meleeStart)/fps,false)or m.meleeClip.frames[1]
        elseif speed>0.5 or (m.slotSpeed or 0)>.5 then
          mode=movingFire and 'runfire' or 'walk'
          row=sample(data.clips.walk,(travel+(m.localTravel or 0))/data.stride*data.clips.walk.duration+m.phase*data.clips.walk.duration,true)
          if movingFire and not combat.wholePaletteSource then
            local walking=row;row={};for j,r in ipairs(walking) do row[j]=r end
            m.walkShift={walking[combat.chest][1]-m.ready[combat.chest][1],walking[combat.chest][2]-m.ready[combat.chest][2],walking[combat.chest][3]-m.ready[combat.chest][3]}
            for _,j in ipairs(combat.upper) do row[j]=m.ready[j] end
          end
        elseif f<aimUntil then
          mode='ready';row=m.ready
        else
          mode='idle';row=data.clips.idle.frames[1]
        end
        if mode=='runfire' and not combat.wholePaletteSource then
          local tx,tz=targetX,targetZ;local wanted=0
          if tx then local px,_,pz=Spring.GetUnitPiecePosDir(unitID,m.root);wanted=angle(math.atan2(tx-px,tz-pz)-m.yaw) end
          m.fireArc=math.abs(wanted)<1.15
          local limited=math.max(-1.15,math.min(1.15,wanted))
          local old=m.upperYaw or 0;m.upperYaw=old+math.max(-seconds*5,math.min(seconds*5,angle(limited-old)))
          row=upperAim(m,row,m.upperYaw,m.walkShift)
          m.upperReady=math.abs(angle(wanted-m.upperYaw))<.12
        else m.upperYaw=0;m.upperReady=false;m.fireArc=false end
        if m.mode~=mode then
          if m.mode=='melee' or mode=='melee' then m.armTransitionUntil=f+12 end
          publish('lod_mode_'..m.index,mode=='melee' and 3 or (mode=='ready' or mode=='runfire') and 2 or mode=='walk' and 1 or 0)
          m.mode=mode;m.transitionFrame=f;m.transitionFrom={}
          for j,v in ipairs(m.basePrevious or m.previous) do m.transitionFrom[j]=v end
        end
        row=blend(m.transitionFrom,row,(f-m.transitionFrame)/(mode=='melee' and 8 or 12))
        m.basePrevious=row
        -- Recoil is an actual-shot overlay, so starting to walk or changing
        -- pose cannot silently cancel the firing soldier's reaction.
        local age=(f-m.shotFrame)/fps
        if mode=='flight' or mode=='melee' then
          -- Genuine whole-source claw motion is never overlaid with gun recoil.
        elseif age>=0 and age<m.recoil.duration then
          row=sourcePose.recoil(row,sample(m.recoil,age,false),m.ready)
        end
        m.connectedPose=combat.hierarchy~=nil or mode=='melee' or f<(m.armTransitionUntil or -1)
        if m.connectedPose and not combat.preserveSourceTranslations then row=keepArmsConnected(row);m.basePrevious=row end
        m.instantWalk=mode=='walk'
        if mode~='melee'then row=pitchWeapon(m,row)end
        apply(m,row,seconds)
      elseif m.state=='dying' then
        local clip=data.clips[(m.index%3==0 and 'die_alt2') or (m.index%3==1 and 'die') or 'die_alt']
        local age=(f-m.deathFrame)/fps
        if age>=clip.duration then
          remains(m);Move(m.root,y_axis,-1000);m.state='hidden';publish('hidden_'..m.index,1)
        else apply(m,sample(clip,age+seconds,false),seconds) end
      end
    end
    publish('travel',travel);publish('gait_phase',travel/data.stride)
    Sleep(interval*1000/fps)
    end
  end
end
function script.Create()
  -- Recenter after spread/mirror, preserving the authored irregular shape and
  -- pairwise spacing. Fixed home slots are retained when members become casualties.
  local centreX,centreZ=0,0
  for i=1,capacity do centreX=centreX+layout[i][1]*spread*mirror;centreZ=centreZ+layout[i][2]*spread end
  centreX,centreZ=centreX/capacity,centreZ/capacity
  heading=Spring.GetUnitHeading(unitID)*tau/65536;formationYaw=heading;targetYaw=heading
  for i,spec in ipairs(data.members) do
    local m={index=i,root=piece(spec.root),offset=spec.offset,bones={},muzzle=piece(spec.muzzle),
      previous={},state='alive',phase=(i-1)*0.137,yaw=heading,shotFrame=-1000,kneels=false,weaponSlot=i,ready=(data.memberClips and data.memberClips[i].ready)or data.ready,recoil=(data.memberClips and data.memberClips[i].recoil)or data.recoil}
    m.meleeSlot=i+3;m.meleeMuzzle=piece(spec.meleeMuzzle);m.meleeClip=data.memberMeleeClips[i]
    for b,name in ipairs(spec.bones) do m.bones[b]=piece(name) end
    m.slot={(layout[i][1]*spread*mirror-centreX)*formationScale,(layout[i][2]*spread-centreZ)*formationScale}
    m.homeSlot={m.slot[1],m.slot[2]};m.localTravel=0
    members[i]=m;apply(m,data.clips.idle.frames[1],0.1,true)
    publish('member_'..i,1);publish('hidden_'..i,0)
  end
  publish('capacity',capacity);publish('shots',0);strength(capacity)
  facing();GG.SquadPresentation[unitID]=function() Spring.UnitScript.CallAsUnit(unitID,facing) end;StartThread(animate)
end
function script.StartMoving() end
function script.StopMoving() end
local function owner(n)return members[(n-1)%3+1]end
function script.AimFromWeapon(n)local m=owner(n);return n>3 and m.meleeMuzzle or m.muzzle end
function script.QueryWeapon(n)local m=owner(n);return n>3 and m.meleeMuzzle or m.muzzle end
function script.AimWeapon(n,h,pitch)
 local m=owner(n);if dead or not m or m.state~='alive'then return false end
 if n>3 then return meleeEligible(m,engaged())end
 m.aimPitch=pitch or 0;aimUntil=Spring.GetGameFrame()+fps*3
 memberTarget(m);return readyToFire(m,Spring.GetGameFrame())
end
function script.BlockShot(n)
 local m=owner(n);if dead or not m or m.state~='alive'then return true end
 local f=Spring.GetGameFrame()
 if n<=3 then return not readyToFire(m,f)end
 maintainMelee(m,f);local target=engaged()
 if not meleeEligible(m,target)then cancelMelee(m);return true end
 local duration=math.floor(m.meleeClip.duration*fps+.5)
 if not m.meleeStart or f>=m.meleeStart+duration then
  m.meleeStart=f;m.meleeTarget=target;m.meleeHit=false;m.meleeAuthorized=nil;m.meleeNextCycle=f+duration;publish('melee_start_'..m.index,f)
 end
 local age=f-m.meleeStart;local cue=m.meleeClip.hitFrame30
 if m.meleeHit or m.meleeAuthorized==f or age<cue-2 or age>cue+2 then return true end
 m.meleeAuthorized=f;return false
end
function script.Shot(n)
 local m=owner(n);if dead or not m or m.state~='alive'then return end
 local f=Spring.GetGameFrame()
 if n>3 then
  if m.meleeAuthorized~=f or m.meleeHit or not meleeEligible(m,engaged())then return end
  m.meleeHit=true;m.meleeAuthorized=nil;m.meleeReloadAt=f+1
  publish('melee_shots',(Spring.GetUnitRulesParam(unitID,prefix..'_melee_shots')or 0)+1)
  publish('melee_owner',m.index);publish('melee_hitframe',f);return
 end
 m.shotFrame=f;aimUntil=f+fps*3
 shots=shots+1;publish('shots',shots);publish('shooter',n);publish('shotframe',f)
 EmitSfx(m.muzzle,1023+n)
end
function script.Killed()
  dead=true
  for _,m in ipairs(members)do m.instantWalk=false end
  local duration=0
  for _,m in ipairs(members) do
    if m.state=='alive' then
      m.deathClip=data.clips[(m.index%3==0 and 'die_alt2') or (m.index%3==1 and 'die') or 'die_alt']
      apply(m,m.deathClip.frames[1],0.1,true)
      duration=math.max(duration,m.deathClip.duration)
    end
  end
  for f=1,math.ceil(duration*fps),3 do
    for _,m in ipairs(members) do if m.state=='alive' then apply(m,sample(m.deathClip,f/fps,false),0.1) end end
    Sleep(100)
  end
  for _,m in ipairs(members) do if m.state~='hidden' then remains(m) end end
  GG.SquadPresentation[unitID]=nil
  return 0
end
