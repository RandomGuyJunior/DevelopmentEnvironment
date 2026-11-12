-- One writer for new hierarchical source rigs. Native BAR owns motion,
-- target selection, projectiles, damage, economy and transport lifecycle.
return function(data)
 local footfall=include('bar40k/titan_footfalls.lua')()
 local bones,byname,previous={}, {}, {}
 for i,name in ipairs(data.bones)do bones[i]=piece(name);byname[name]=i end
 local weapons={}
 for n,cfg in pairs(data.weaponMounts or{})do
  local w={cursor=0,yaw=0,pitch=0,ready=false,untilFrame=0,fireFrame=-10000,muzzles={}}
  for i,name in ipairs(cfg.muzzles)do w.muzzles[i]=piece(name)end
  if cfg.yaw then w.yawPiece=piece(cfg.yaw)end
  if cfg.pitch then w.pitchPiece=piece(cfg.pitch)end
  weapons[n]=w
 end
 local shoulder=data.shoulderAlternation;local nextShoulder=shoulder and shoulder.first;local nextShoulderFrame=0;local lastShoulderFrame=-10000
 local moving=false;local swayBlend=0;local swayPhase=0;local bodyPitch,bodyRoll=0,0
 local lastFrame=Spring.GetGameFrame();local phase=0;local clipName='idle'
 local dt=1/Game.gameSpeed
 local function delta(a,b)return(b-a+math.pi)%(2*math.pi)-math.pi end
 local function lerp(a,b,t,k)return k<=3 and a+(b-a)*t or a+delta(a,b)*t end
 local function sample(clip,time,i)
  local n=#clip.frames;local f=(time%clip.duration)/clip.duration*(n-1);local first=math.floor(f)+1;local t=f-math.floor(f);local a,b=clip.frames[first][i],clip.frames[math.min(first+1,n)][i];local row={}
  for k=1,6 do row[k]=lerp(a[k],b[k],t,k)end
  return row
 end
 local function errors(n)
  local cfg,w=data.weaponMounts[n],weapons[n]
  if not w.ready then return true end
  if w.yawPiece then local _,a=Spring.UnitScript.GetPieceRotation(w.yawPiece);if math.abs(delta(a,w.localYaw or w.yaw))>math.rad(2)then return true end end
  if w.pitchPiece then local a=Spring.UnitScript.GetPieceRotation(w.pitchPiece);if math.abs(delta(a,-(w.localPitch or w.pitch)+math.rad(cfg.pitchOffset or 0)))>math.rad(2)then return true end end
  return false
 end
 -- Advance desired axes at fixed speed; never distance/dt to the target.
 local function advanceAngle(current,target,limit)
  local d=delta(current,target)
  return current+math.max(-limit,math.min(limit,d))
 end
 local function animate()
  while true do
   local frame=Spring.GetGameFrame();local elapsed=math.max(0,frame-lastFrame)*dt;lastFrame=frame
   local aiming=false
   for _,w in pairs(weapons)do if frame<w.untilFrame then aiming=true end end
   local chosen=(moving and data.clips.walk and'walk')or(data.infantry and aiming and'fire')or'idle'
   if chosen~=clipName then clipName,phase=chosen,0 end
   local playback=1
   if chosen=='walk'and not data.staticTravel then local _,_,_,v=Spring.GetUnitVelocity(unitID);playback=math.max(0,(v or 0)*Game.gameSpeed/(data.walkspeed or 30))end
   phase=(phase+elapsed*playback)%data.clips[chosen].duration
   -- Authored upper-body motion only; feet never descend from this parent.
   swayBlend=math.max(0,math.min(1,swayBlend+(moving and 1 or -1)*elapsed*2))
   if moving then swayPhase=(swayPhase+elapsed*playback*2*math.pi/data.clips.walk.duration)%(2*math.pi)end
   bodyPitch=math.rad(.8)*math.sin(2*swayPhase)*swayBlend
   bodyRoll=math.rad(1.4)*math.sin(swayPhase)*swayBlend
   local pose={}
   for i in ipairs(bones)do pose[i]=sample(data.clips[chosen],phase,i)end
   if data.infantry and aiming then
    -- Hold the authored firing cue between native shots. Recoil uses its
    -- original neighbouring frames; movement keeps the source leg cycle.
    local clip=data.clips.fire;local w=weapons[1];local fps=clip.source_fps or 30
    local age=math.max(0,frame-w.fireFrame)*dt;local recoil=age<5/fps and age or 0
    local time=math.min((clip.shot_cue or 0)/fps+recoil,clip.duration-dt*.01)
    for i in ipairs(bones)do if not moving or(data.fireUpperBones and data.fireUpperBones[data.bones[i]])then pose[i]=sample(clip,time,i)end end
   end
   if not data.infantry then
    for n,cfg in pairs(data.weaponMounts or{})do
     local w=weapons[n];local clip=cfg.fireClip and data.clips[cfg.fireClip]
     if frame<w.untilFrame then for _,name in ipairs(cfg.stabilizeBones or{})do local i=byname[name];pose[i]={0,0,0,0,0,0}end end
     if clip then
      local age=(frame-w.fireFrame)*dt
      local sustained=cfg.continuousFireFrames and frame-w.fireFrame<cfg.continuousFireFrames
      if age>=0 and(age<clip.duration or sustained)then
       local time=sustained and((frame-(w.fireStartFrame or w.fireFrame))*dt)%clip.duration or age
       for _,name in ipairs(clip.active_bones or{})do local i=byname[name];if i then pose[i]=sample(clip,time,i)end end
      end
     end
     if cfg.gunAlignmentBones then
      -- These source idle bones contain unrelated gun wobble. While aimed,
      -- yaw/elevation owns the bore; authored recoil translations remain.
      local target=frame<w.untilFrame and 1 or 0
      w.rigidAimBlend=math.max(0,math.min(1,(w.rigidAimBlend or 0)+(target==1 and 1 or -1)*elapsed*4))
      local blend=w.rigidAimBlend*w.rigidAimBlend*(3-2*w.rigidAimBlend)
      for _,name in ipairs(cfg.gunAlignmentBones)do local i=byname[name];if i then for k=4,6 do pose[i][k]=pose[i][k]*(1-blend)end end end
     end
     if not cfg.poseOwner and not cfg.dummy then
      if cfg.yaw then
       local i=byname[cfg.yaw]
       -- Invert authored parent Rz*Rx for the native requested direction.
       -- The actual native parent uses XYZ Euler order Rx*Ry*Rz. Ry is zero.
       local x=math.sin(w.yaw)*math.cos(w.pitch);local y=math.sin(w.pitch);local z=math.cos(w.yaw)*math.cos(w.pitch)
       local cy,sy=math.cos(bodyPitch),math.sin(bodyPitch)
       y,z=cy*y+sy*z,-sy*y+cy*z
       local cr,sr=math.cos(bodyRoll),math.sin(bodyRoll)
       x,y=cr*x+sr*y,-sr*x+cr*y
       w.localYaw=math.atan2(x,z);w.localPitch=math.asin(math.max(-1,math.min(1,y)))
       if cfg.centerYaw then local center=math.rad(cfg.centerYaw);w.localYaw=center+delta(center,w.localYaw)end
       local target=w.localYaw
       if data.boundedTurretTraverse then
        if cfg.centerYaw then
         local current=w.actualYaw or pose[i][5];local step=math.rad(cfg.yawSpeed or 60)*elapsed
         -- Traverse through the permitted sector, never the shorter inward gap.
         w.actualYaw=current+math.max(-step,math.min(step,target-current))
        else w.actualYaw=advanceAngle(w.actualYaw or pose[i][5],target,math.rad(cfg.yawSpeed or 60)*elapsed)end
        target=w.actualYaw
       end
       pose[i][5]=target
      end
      if cfg.pitch then
       local i=byname[cfg.pitch];local target=-(w.localPitch or w.pitch)+math.rad(cfg.pitchOffset or 0)
       if data.boundedTurretTraverse then
        w.actualPitch=advanceAngle(w.actualPitch or pose[i][4],target,math.rad(cfg.pitchSpeed or 45)*elapsed)
        target=w.actualPitch
       end
       pose[i][4]=target
      end
     end
    end
   end
   local body=byname.giant_body_sway
   pose[body]={0,1.2*(1-math.cos(2*swayPhase))*swayBlend,0,bodyPitch,0,bodyRoll}
   for i,bone in ipairs(bones)do
    local row,old=pose[i],previous[i]or{}
    for axis=1,3 do
     if old[axis]==nil or math.abs(row[axis]-old[axis])>1e-5 then Move(bone,axis,row[axis],old[axis]and math.abs(row[axis]-old[axis])/dt or nil)end
     local k=axis+3;local value=old[k]and old[k]+delta(old[k],row[k])or row[k]
     if old[k]==nil or math.abs(value-old[k])>1e-5 then
      local speed=old[k]and math.abs(value-old[k])/dt or nil
      for n,cfg in pairs(data.weaponMounts or{})do if(cfg.yaw==data.bones[i]and axis==2)or(cfg.pitch==data.bones[i]and axis==1)then if not data.boundedTurretTraverse then speed=math.max(speed or 0,math.rad(180))end end end
      Turn(bone,axis,value,speed)
     end
     old[axis],old[k]=row[axis],value
    end
    previous[i]=old
   end
   footfall(chosen=='walk' and phase/data.clips.walk.duration or 0,chosen=='walk' and playback>.01)
   Sleep(33)
  end
 end
 function script.Create()StartThread(animate)end
 function script.StartMoving()moving=true end
 function script.StopMoving()moving=false end
 function script.AimFromWeapon(n)return weapons[n].muzzles[1]end
 function script.QueryWeapon(n)local w=weapons[n];if data.weaponMounts[n].alternateSalvo then return w.salvoMuzzle or w.muzzles[w.cursor%#w.muzzles+1]end;w.queriedMuzzle=w.queriedMuzzle or w.muzzles[w.cursor%#w.muzzles+1];return w.queriedMuzzle end
 -- The sector describes a target bearing about the chassis, not the ray
 -- starting at a moving, offset muzzle. A target beside the walker requires
 -- several extra degrees at the arm to converge on it. Native still owns the
 -- trajectory and aiming direction; this reads its existing target only.
 local function targetBearing(n,fallback)
  if n==1 then return fallback end
  local kind,_,value=Spring.GetUnitWeaponTarget(unitID,n)
  local tx,tz
  if kind==1 and value then
   local x,y,z,mx,my,mz=Spring.GetUnitPosition(value,true)
   tx,tz=mx or x,mz or z
  elseif kind==2 and type(value)=='table'then tx,tz=value[1],value[3]end
  if not tx or not tz then return fallback end
  local x,_,z=Spring.GetUnitPosition(unitID)
  if not x or(tx-x)^2+(tz-z)^2<1 then return fallback end
  return delta(Spring.GetUnitHeading(unitID)*math.pi/32768,math.atan2(tx-x,tz-z))
 end
 function script.AimWeapon(n,heading,pitch)
  local cfg,w=data.weaponMounts[n],weapons[n];heading,pitch=heading or 0,pitch or 0
  if cfg.dummy then return true end
  local center=math.rad(cfg.centerYaw or 0)
  local relative=delta(center,targetBearing(n,heading))
  local minimum=math.rad(cfg.minPitch or -15)
  -- Wide side-centred shoulder sectors retain forward/rear fire while the
  -- excluded inward sector protects the head. At the overlapping diagonal
  -- edges the barrels must lift above the shoulder deck and main hull.
  if not(data.shoulderClearance and data.shoulderClearance[n])and cfg.foreAftMinPitch and math.abs(relative)>math.rad(65)then minimum=math.max(minimum,math.rad(cfg.foreAftMinPitch))end
  if not(data.shoulderClearance and data.shoulderClearance[n])and cfg.inboardMinPitch and math.abs(relative)>math.rad(100)then minimum=math.max(minimum,math.rad(cfg.inboardMinPitch))end
  local clearance=data.shoulderClearance and data.shoulderClearance[n]
  if clearance then
   local h=center+delta(center,heading)
   local index=(math.deg(h)-clearance.start)/clearance.step
   index=math.max(0,math.min(#clearance.values-1,index))
   local first=math.floor(index)+1;local second=math.min(first+1,#clearance.values)
   minimum=math.rad(math.max(clearance.values[first],clearance.values[second])+2)
  end
  -- Continue safe mechanical slewing even when the first muzzle-relative
  -- request is below the deck limit. Re-aim then converges from the new muzzle
  -- position. A separate strict gate forbids firing below that limit.
  w.clearanceBlocked=clearance and pitch<minimum or false
  if clearance then pitch=math.max(pitch,minimum)end
  local aligned=math.abs(relative)<=math.rad(cfg.maxYaw or(data.infantry and 10 or 180))and pitch>=minimum and pitch<=math.rad(cfg.maxPitch or 80)
  -- Slew toward the native ray without ever leaving the accepted physical
  -- sector. During the first turn the moving muzzle may request a few degrees
  -- beyond the stop; native re-aim converges as it moves. BlockShot still
  -- demands the actual bore match, so partial travel cannot fake a shot.
  if n~=1 then
   local actual=delta(center,heading)
   heading=center+math.max(-math.rad(cfg.maxYaw),math.min(math.rad(cfg.maxYaw),actual))
  end
  if cfg.centerYaw then heading=center+delta(center,heading)end
  w.ready=aligned;if not aligned then return false end
  local now=Spring.GetGameFrame();local initial=w.untilFrame<now;w.untilFrame=now+180
  if not data.infantry then w.yaw,w.pitch=heading,pitch end
  local untilFrame=now+180
  if data.infantry and initial then for i=1,6 do Sleep(33)end end
  while errors(n)do if Spring.GetGameFrame()>untilFrame then return false end;Sleep(33)end
  return not w.clearanceBlocked
 end
 function script.BlockShot(n)
  if data.weaponMounts[n].dummy then return false end
  if weapons[n].clearanceBlocked or errors(n)then return true end
  if shoulder and(n==shoulder.first or n==shoulder.second)then
   local f=Spring.GetGameFrame()
   if f<nextShoulderFrame then return true end
   if n~=nextShoulder and f-lastShoulderFrame<shoulder.fallbackFrames then return true end
  end
  local w=weapons[n];local _,_,_,dx,dy,dz=Spring.GetUnitPiecePosDir(unitID,w.queriedMuzzle or w.salvoMuzzle or w.muzzles[w.cursor%#w.muzzles+1])
  local _,_,_,tx,ty,tz=Spring.GetUnitWeaponVectors(unitID,n)
  if not(dx and dy and dz and tx and ty and tz)then return true end
  local a=dx*dx+dy*dy+dz*dz;local b=tx*tx+ty*ty+tz*tz
  if a<1e-12 or b<1e-12 then return true end
  return (dx*tx+dy*ty+dz*tz)/math.sqrt(a*b)<math.cos(math.rad(5))
 end
 function script.FireWeapon(n)
  local w=weapons[n];local frame=Spring.GetGameFrame()
  local sustain=data.weaponMounts[n].continuousFireFrames
  if sustain and frame-w.fireFrame>=sustain then w.fireStartFrame=frame end
  w.fireFrame=frame
  local cadence=data.weaponMounts[n].cadenceFrames
  if cadence then
   -- Native reloadTime truncates0.15s to4frames. Carry the half-frame so
   -- twenty pellets still occupy90frames rather than accelerating to80.
   local baseFrames=math.max(1,math.floor(cadence))
   local xpFrames=Spring.GetUnitWeaponState(unitID,n,"reloadTimeXP")*Game.gameSpeed
   local delay=math.max(1,cadence*xpFrames/baseFrames)
   if not w.nextReloadFrame or frame>math.ceil(w.nextReloadFrame)+1 then w.nextReloadFrame=frame end
   w.nextReloadFrame=w.nextReloadFrame+delay
   Spring.SetUnitWeaponState(unitID,n,"reloadState",math.ceil(w.nextReloadFrame-1e-9))
  end
  if data.weaponMounts[n].alternateSalvo then w.cursor=w.cursor%#w.muzzles+1;w.salvoMuzzle=w.muzzles[w.cursor];w.queriedMuzzle=nil end
 end
 function script.Shot(n)
  local cfg,w=data.weaponMounts[n],weapons[n]
  if cfg.alternateSalvo then
   w.fireFrame=Spring.GetGameFrame()
   if cfg.sfx then EmitSfx(w.salvoMuzzle or w.muzzles[1],1023+cfg.sfx)end
   return
  end
  w.cursor=w.cursor%#w.muzzles+1;w.fireFrame=Spring.GetGameFrame()
  if shoulder and(n==shoulder.first or n==shoulder.second)then lastShoulderFrame=w.fireFrame;nextShoulderFrame=w.fireFrame+shoulder.gapFrames;nextShoulder=n==shoulder.first and shoulder.second or shoulder.first end
  if cfg.dummy then return end
  if cfg.sfx then EmitSfx(w.queriedMuzzle or w.muzzles[w.cursor],1023+cfg.sfx)end;w.queriedMuzzle=nil
 end
 function script.Activate()return 1 end
 function script.Deactivate()return 0 end
 function script.Killed(recent,max)return recent/max>.5 and 2 or 1 end
 if data.transport then
  function script.BeginTransport(id)SetUnitValue(COB.BUSY,0)end
  function script.EndTransport()SetUnitValue(COB.BUSY,0)end
  function script.QueryTransport(id)return bones[1]end
  function script.TransportPickup(id)Spring.UnitScript.AttachUnit(0,id);SetUnitValue(COB.BUSY,0)end
  function script.TransportDrop(id,x,y,z)Spring.UnitScript.DropUnit(id);SetUnitValue(COB.BUSY,0)end
 end
end
