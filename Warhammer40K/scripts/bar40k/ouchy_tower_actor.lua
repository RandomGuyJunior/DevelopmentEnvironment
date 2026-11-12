-- Ouchy source palette only. One pose writer; native weapons own every shot.
return function(data)
 local cfg=data.aim
 local meta=include('bar40k/animation_data.lua')(data.sourceHierarchy)
 local source=include('bar40k/source_local_pose.lua')(meta)
 local bones,neutral={},{};for i,name in ipairs(data.bones)do bones[i]=piece(name);neutral[i]={0,0,0,0,0,0}end
 local muzzleName=cfg.muzzleName or cfg.muzzles[1];local muzzle=piece(muzzleName)
 local yawMembers,pitchMembers,payload={},{},{}
 for _,i in ipairs(cfg.yawMembers)do yawMembers[i]=true end
 for _,i in ipairs(cfg.pitchMembers)do pitchMembers[i]=true end
 for _,i in ipairs(cfg.payloadMembers or{})do payload[i]=true end
 local fps=Game.gameSpeed;local frame=Spring.GetGameFrame();local lastFrame=frame
 local yaw,pitch=0,0;local requestedYaw,requestedPitch=0,0;local activeUntil=-1
 local shotFrame=-100000;local fireStart=-100000;local fireFrom,lastSource,idleSource
 local spinAngle=0
 local dead=false;local enabled=true;local payloadHidden=false
 local previous={};local yawRate=math.rad(cfg.yawSpeed or 90);local pitchRate=math.rad(cfg.pitchSpeed or 60)
 local unit=UnitDefs[unitDefID];local wd=WeaponDefs[unit.weapons[1].weaponDef]
 local toggle=unit.onOffable
 local function delta(a,b)return(b-a+math.pi)%(2*math.pi)-math.pi end
 local function finite(x)return type(x)=='number'and x==x and math.abs(x)<math.huge end
 local function point(m,p)return{m[1]*p[1]+m[2]*p[2]+m[3]*p[3]+m[4],m[5]*p[1]+m[6]*p[2]+m[7]*p[3]+m[8],m[9]*p[1]+m[10]*p[2]+m[11]*p[3]+m[12]}end
 local function direction(m,p)return{m[1]*p[1]+m[2]*p[2]+m[3]*p[3],m[5]*p[1]+m[6]*p[2]+m[7]*p[3],m[9]*p[1]+m[10]*p[2]+m[11]*p[3]}end
 local function inverse(m)
  local r={m[1],m[5],m[9],0,m[2],m[6],m[10],0,m[3],m[7],m[11],0}
  r[4]=-(r[1]*m[4]+r[2]*m[8]+r[3]*m[12]);r[8]=-(r[5]*m[4]+r[6]*m[8]+r[7]*m[12]);r[12]=-(r[9]*m[4]+r[10]*m[8]+r[11]*m[12])
  return r
 end
 local function rotation(axis,a,p)
  local x,y,z=axis[1],axis[2],axis[3];local c,s=math.cos(a),math.sin(a);local t=1-c
  local m={t*x*x+c,t*x*y-s*z,t*x*z+s*y,0,t*x*y+s*z,t*y*y+c,t*y*z-s*x,0,t*x*z-s*y,t*y*z+s*x,t*z*z+c,0}
  local q=point(m,p);m[4],m[8],m[12]=p[1]-q[1],p[2]-q[2],p[3]-q[3]
  return m
 end
 local function advance(a,b,step)return a+math.max(-step,math.min(step,delta(a,b)))end
 local function aimedSourcePose(rows,elevation)
  -- Source aim_vert frames12..24 form its monotonic mechanical aim sweep.
  -- The gun AND cylinder retain their own authored hinges/translations.
  -- No generic pitch rotation is imposed on the source model.
  local clip=data.clips.aim_vert;if not clip then return rows end
  local v=cfg.muzzleForwardBind;local rest=math.atan2(v[2],math.sqrt(v[1]^2+v[3]^2))
  local samples={}
  for i=13,math.min(25,#clip.frames)do
   local d=direction(source.matrix(clip.frames[i][cfg.pitchPivotJoint]),v)
   samples[#samples+1]={index=i,pitch=math.atan2(d[2],math.sqrt(d[1]^2+d[3]^2))-rest}
  end
  local time
  for i=1,#samples-1 do
   local a,b=samples[i],samples[i+1]
   if elevation>=a.pitch and elevation<=b.pitch then
    time=(a.index-1+(elevation-a.pitch)/math.max(1e-9,b.pitch-a.pitch))/clip.fps;break
   end
  end
  if not time then local q=elevation<samples[1].pitch and samples[1]or samples[#samples];time=(q.index-1)/clip.fps end
  return source.recoil(rows,source.sample(clip,time,false),neutral)
 end
 local function write(handle,row,dt)
  local old=previous[handle]
  if old then
   local a={row[4],row[5],row[6]};local b={math.pi-row[4],row[5]+math.pi,row[6]+math.pi};local ca,cb=0,0
   for k=1,3 do a[k]=old[k+3]+delta(old[k+3],a[k]);b[k]=old[k+3]+delta(old[k+3],b[k]);ca=ca+(a[k]-old[k+3])^2;cb=cb+(b[k]-old[k+3])^2 end
   local e=ca<=cb and a or b;for k=1,3 do row[k+3]=e[k]end
  end
  local stored={}
  for a=1,3 do
   if not old or math.abs(row[a]-old[a])>1e-5 then Move(handle,a,row[a],old and math.abs(row[a]-old[a])/dt or nil)end
   if not old or math.abs(row[a+3]-old[a+3])>1e-5 then Turn(handle,a,row[a+3],old and math.abs(row[a+3]-old[a+3])/dt or nil)end
   stored[a],stored[a+3]=row[a],row[a+3]
  end
  previous[handle]=stored
 end
 local function wanted()
  -- Cannon's wantedDir is ALREADY ballistic in the pinned native engine.
  -- BeamLaser's is direct. Both are consumed as-is, never converted twice.
  local _,_,_,x,y,z=Spring.GetUnitWeaponVectors(unitID,1)
  if finite(x)and finite(y)and finite(z)then
   local length=math.sqrt(x*x+y*y+z*z)
   if length>1e-8 then
    x,y,z=x/length,y/length,z/length
    local f,u,r=Spring.GetUnitVectors(unitID)
    return math.atan2(-(x*r[1]+y*r[2]+z*r[3]),x*f[1]+y*f[2]+z*f[3]),math.asin(math.max(-1,math.min(1,x*u[1]+y*u[2]+z*u[3])))
   end
  end
  return requestedYaw,requestedPitch
 end
 local function valid(h,p)return math.abs(delta(0,h))<=math.rad(cfg.maxYaw or 180)+1e-7 and p>=math.rad(cfg.minPitch or -45)-1e-7 and p<=math.rad(cfg.maxPitch or 85)+1e-7 end
 local function aligned()
  if dead or not enabled then return false end
  local h,p=wanted();if not valid(h,p)then return false end
  local _,_,_,x,y,z=Spring.GetUnitPiecePosDir(unitID,muzzle);local _,_,_,a,b,c=Spring.GetUnitWeaponVectors(unitID,1)
  if not(finite(x)and finite(y)and finite(z)and finite(a)and finite(b)and finite(c))then return false end
  local aa=x*x+y*y+z*z;local bb=a*a+b*b+c*c
  return aa>1e-12 and bb>1e-12 and(x*a+y*b+z*c)/math.sqrt(aa*bb)>=math.cos(math.rad(cfg.boreTolerance or 3))
 end
 local function sample(f)
  local idle=source.sample(data.clips.idle,(f/fps)%data.clips.idle.duration,true);idleSource=idle
  local clip=cfg.fireClip and data.clips[cfg.fireClip]
  if not clip then return idle end
  local age=(f-shotFrame)/fps;local cue=(clip.shot_cue or 0)/(clip.source_fps or fps)
  local remaining=math.max(1/fps,clip.duration-cue);local tail=.18
  if cfg.loopFire then
   if age<math.max(cfg.fireHoldSeconds or 0,2/fps)then return source.sample(clip,((f-fireStart)/fps)%clip.duration,true)end
   return idle
  end
  if age>=0 and age<remaining then
   -- Layer the authored recoil over the ongoing crew idle; unkeyed source
   -- rest rows must not snap the entire crew to its bind pose on every shot.
   local pose=source.recoil(idle,source.sample(clip,math.min(clip.duration,cue+age),false),neutral)
   if fireFrom and age<2/fps then return source.blend(fireFrom,pose,math.min(1,age*fps/2))end
   return pose
  elseif age>=remaining and age<remaining+tail then
   return source.blend(source.recoil(idle,source.sample(clip,clip.duration,false),neutral),idle,(age-remaining)/tail)
  end
  return idle
 end
 local function pose(f,dt)
  local rows=sample(f);lastSource=rows
  local base=source.matrix(rows[cfg.muzzleParent]);local forward=direction(base,cfg.muzzleForwardBind)
  local baseHeading=math.atan2(forward[1],forward[3]);local basePitch=math.atan2(forward[2],math.sqrt(forward[1]^2+forward[3]^2))
  local targetYaw,targetPitch=yaw,pitch
  if enabled and f<activeUntil then
   local h,p=wanted();p=math.max(math.rad(cfg.minPitch or -45),math.min(math.rad(cfg.maxPitch or 85),p))
   targetYaw=delta(baseHeading,h);targetPitch=p-basePitch
  end
  yaw=advance(yaw,targetYaw,yawRate*dt);pitch=advance(pitch,targetPitch,pitchRate*dt)
  local pitched=aimedSourcePose(rows,pitch)
  local pivot=point(source.matrix(rows[cfg.yawPivotJoint]),cfg.yawPivotBind)
  local turn=rotation({0,1,0},yaw,pivot)
  local aimed={}
  for i,row in ipairs(pitched)do
   -- The loaded payload returns at the REAL native reload, not at the end
   -- of a departing-bomb animation/tail. Its flight belongs to the projectile.
   local m=source.matrix(row)
   if payload[i]and cfg.payloadPoseParent then
    local relation=source.multiply(inverse(source.matrix(idleSource[cfg.muzzleParent])),source.matrix(idleSource[cfg.payloadPoseParent]))
    m=source.multiply(source.matrix(pitched[cfg.muzzleParent]),relation)
   end
   if yawMembers[i]then m=source.multiply(turn,m)end
   aimed[i]=m
  end
  if cfg.spinJoint then
   if enabled and f-shotFrame<=(cfg.spinHoldSeconds or .15)*fps then spinAngle=spinAngle+math.rad(cfg.spinDegreesPerSecond or 45)*dt end
   local m=aimed[cfg.spinJoint];local center=point(m,cfg.spinPivotBind)
   local axis=direction(aimed[cfg.muzzleParent],cfg.muzzleForwardBind)
   aimed[cfg.spinJoint]=source.multiply(rotation(axis,spinAngle,center),m)
  end
  if payloadHidden then
   local ready=Spring.GetUnitWeaponState(unitID,1,'reloadFrame')
   if not finite(ready)then ready=shotFrame+math.max(1,math.floor((wd.reload or .5)*fps+.001))end
   if f>shotFrame and f>=ready then payloadHidden=false end
  end
  for i,m in ipairs(aimed)do
   if data.bones[i]~=muzzleName then
    local row=source.row(m)
    if payloadHidden and payload[i]then row[2]=row[2]-1000 end
    write(bones[i],row,dt)
   end
  end
  local parent=aimed[cfg.muzzleParent];local q=point(parent,cfg.muzzleBind);local d=direction(parent,cfg.muzzleForwardBind)
  local h=math.atan2(d[1],d[3]);local p=math.atan2(d[2],math.sqrt(d[1]^2+d[3]^2))
  write(muzzle,{q[1],q[2],q[3],-p,h,0},dt)
 end
 local function animate()
  while not dead do
   local f=Spring.GetGameFrame();local dt=math.max(1,f-lastFrame)/fps;lastFrame=f;pose(f,dt)
   Sleep((f<activeUntil or f-shotFrame<fps)and 1000/fps or 100)
  end
 end
 function script.Create()StartThread(animate)end
 function script.AimFromWeapon()return muzzle end
 function script.QueryWeapon()return muzzle end
 function script.AimWeapon(n,h,p)
  if n~=1 or dead or not enabled then return false end
  requestedYaw,requestedPitch=h or 0,p or 0;activeUntil=Spring.GetGameFrame()+fps*10
  if not valid(requestedYaw,requestedPitch)then return false end
  local timeout=activeUntil
  while not aligned()do if dead or not enabled or Spring.GetGameFrame()>timeout then return false end;Sleep(1000/fps)end
  return true
 end
 function script.BlockShot(n)return n~=1 or not aligned()end
 function script.FireWeapon()end
 function script.Shot(n)
  if n~=1 or dead then return end
  local f=Spring.GetGameFrame()
  if f-shotFrame>math.max((cfg.fireHoldSeconds or 0)*fps,2)then fireStart=f end
  fireFrom=lastSource;shotFrame=f;payloadHidden=next(payload)~=nil
  if cfg.sfx then EmitSfx(muzzle,1023+cfg.sfx)end
 end
 function script.StartMoving()end
 function script.StopMoving()end
 function script.Activate()if toggle then enabled=true end;return 1 end
 function script.Deactivate()if toggle then enabled=false end;return 0 end
 function script.Killed(recent,max)dead=true;return recent/math.max(1,max)>.5 and 2 or 1 end
end
