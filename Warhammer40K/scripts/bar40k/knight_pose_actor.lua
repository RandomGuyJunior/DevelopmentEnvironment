-- One writer for new hierarchical source rigs. Native BAR owns motion,
-- target selection, projectiles, damage, economy and transport lifecycle.
return function(data)
 local bones,byname,previous={}, {}, {}
 for i,name in ipairs(data.bones)do bones[i]=piece(name);byname[name]=i end
 local weapons={}
 for n,cfg in pairs(data.weaponMounts or{})do
  local w={cursor=0,yaw=0,pitch=0,ready=false,untilFrame=0,fireFrame=-10000,lastShot=-10000,loopStart=0,loopTime=0,muzzles={}}
  for i,name in ipairs(cfg.muzzles)do w.muzzles[i]=piece(name)end
  if cfg.yaw then w.yawPiece=piece(cfg.yaw)end
  if cfg.pitch then w.pitchPiece=piece(cfg.pitch)end
  weapons[n]=w
 end
 local moving=false
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
  if w.yawPiece then local _,a=Spring.UnitScript.GetPieceRotation(w.yawPiece);if math.abs(delta(a,w.yaw))>math.rad(2)then return true end end
  if w.pitchPiece then local a=Spring.UnitScript.GetPieceRotation(w.pitchPiece);if math.abs(delta(a,-w.pitch+math.rad(cfg.pitchOffset or 0)))>math.rad(2)then return true end end
  return false
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
     if cfg.loopFireClip and clip then
      if frame-w.lastShot<6 then w.loopTime=(frame-w.loopStart)*dt*(cfg.loopSpeed or 1)end
      for _,name in ipairs(clip.active_bones or{})do local i=byname[name];if i then pose[i]=sample(clip,w.loopTime,i)end end
     elseif clip and frame-w.fireFrame>=0 and(frame-w.fireFrame)*dt<clip.duration then
      for _,name in ipairs(clip.active_bones or{})do local i=byname[name];if i then pose[i]=sample(clip,(frame-w.fireFrame)*dt,i)end end
     end
     if not cfg.poseOwner and not cfg.dummy then
      if cfg.yaw then local i=byname[cfg.yaw];pose[i][5]=w.yaw end
      if cfg.pitch then local i=byname[cfg.pitch];pose[i][4]=-w.pitch+math.rad(cfg.pitchOffset or 0)end
     end
    end
   end
   for i,bone in ipairs(bones)do
    local row,old=pose[i],previous[i]or{}
    for axis=1,3 do
     if old[axis]==nil or math.abs(row[axis]-old[axis])>1e-5 then Move(bone,axis,row[axis],old[axis]and math.abs(row[axis]-old[axis])/dt or nil)end
     local k=axis+3;local value=old[k]and old[k]+delta(old[k],row[k])or row[k]
     if old[k]==nil or math.abs(value-old[k])>1e-5 then
      local speed=old[k]and math.abs(value-old[k])/dt or nil
      for n,cfg in pairs(data.weaponMounts or{})do if(cfg.yaw==data.bones[i]and axis==2)or(cfg.pitch==data.bones[i]and axis==1)then speed=math.max(speed or 0,math.rad(180))end end
      Turn(bone,axis,value,speed)
     end
     old[axis],old[k]=row[axis],value
    end
    previous[i]=old
   end
   Sleep(33)
  end
 end
 function script.Create()StartThread(animate)end
 function script.StartMoving()moving=true end
 function script.StopMoving()moving=false end
 function script.AimFromWeapon(n)return weapons[n].muzzles[1]end
 function script.QueryWeapon(n)local w=weapons[n];return w.muzzles[math.max(1,w.cursor)]end
 function script.AimWeapon(n,heading,pitch)
  local cfg,w=data.weaponMounts[n],weapons[n];heading,pitch=heading or 0,pitch or 0
  if cfg.dummy then return true end
  local aligned=math.abs(heading)<=math.rad(cfg.maxYaw or(data.infantry and 10 or 180))and pitch>=math.rad(cfg.minPitch or -15)and pitch<=math.rad(cfg.maxPitch or 80)
  w.ready=aligned;if not aligned then return false end
  local now=Spring.GetGameFrame();local initial=w.untilFrame<now;w.untilFrame=now+60
  if not data.infantry then w.yaw,w.pitch=heading,pitch end
  local untilFrame=now+60
  if data.infantry and initial then for i=1,6 do Sleep(33)end end
  while errors(n)do if Spring.GetGameFrame()>untilFrame then return false end;Sleep(33)end
  return true
 end
 function script.BlockShot(n)if data.weaponMounts[n].dummy then return false end;return errors(n)end
 function script.FireWeapon(n)weapons[n].fireFrame=Spring.GetGameFrame()end
 function script.Shot(n)
  local cfg,w=data.weaponMounts[n],weapons[n];w.cursor=w.cursor%#w.muzzles+1;w.fireFrame=Spring.GetGameFrame()
  if w.fireFrame-w.lastShot>6 then w.loopStart=w.fireFrame end;w.lastShot=w.fireFrame
  if cfg.dummy then return end
  if cfg.sfx then EmitSfx(w.muzzles[w.cursor],1023+cfg.sfx)end
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
