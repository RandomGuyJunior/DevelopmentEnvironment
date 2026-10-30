-- GOH Knights only: one source-pose writer, finite physical arm aim and sword cue.
return function(data)
 local bones,byname,previous,weapons={},{},{},{}
 for i,name in ipairs(data.bones)do bones[i]=piece(name);byname[name]=i end
 for n,cfg in ipairs(data.weaponMounts)do
  local w={yaw=0,pitch=0,ready=false,cursor=0,fireFrame=-10000,lastShot=-10000,loopStart=0,loopTime=0,muzzles={}}
  for _,name in ipairs(cfg.muzzles)do w.muzzles[#w.muzzles+1]=piece(name)end
  weapons[n]=w
 end
 local frameStep=1/Game.gameSpeed;local moving=false;local lastFrame=Spring.GetGameFrame();local clipName='idle';local phase=0;local travel=0;local actionStart,actionTarget;local melee=data.meleeSpec
 local function delta(a,b)return(b-a+math.pi)%(2*math.pi)-math.pi end
 local function approach(a,b,step)return a+math.max(-step,math.min(step,delta(a,b)))end
 local function sample(clip,t,i)
  local f=(t%clip.duration)/clip.duration*(#clip.frames-1);local k=math.floor(f)+1;local t=f-math.floor(f);local a,b=clip.frames[k][i],clip.frames[math.min(k+1,#clip.frames)][i];local out={}
  for c=1,6 do out[c]=a[c]+(c<=3 and b[c]-a[c]or delta(a[c],b[c]))*t end
  return out
 end
 local function identity()return{1,0,0,0,1,0,0,0,1}end
 local function mul(a,b)local r={}for i=0,2 do for j=1,3 do r[i*3+j]=a[i*3+1]*b[j]+a[i*3+2]*b[j+3]+a[i*3+3]*b[j+6]end end return r end
 local function rot(row)
  local x,y,z=row[4],row[5],row[6];local cx,sx,cy,sy,cz,sz=math.cos(x),math.sin(x),math.cos(y),math.sin(y),math.cos(z),math.sin(z)
  return mul(mul({cy,0,sy,0,1,0,-sy,0,cy},{1,0,0,0,cx,-sx,0,sx,cx}),{cz,-sz,0,sz,cz,0,0,0,1})
 end
 local function forward(cfg,pose)
  local m=identity()
  for _,p in ipairs(cfg.aimPath)do m=mul(m,p.bone and rot(pose[p.bone])or p.rotation)end
  return m[3],m[6],m[9]
 end
 local function solve(cfg,pose,yaw,pitch)
  local yi,pi=byname[cfg.yaw],byname[cfg.pitch];local originalY,originalP=pose[yi][5],pose[pi][4];local a,b=originalY,originalP
  local tx,ty,tz=math.sin(yaw)*math.cos(pitch),math.sin(pitch),math.cos(yaw)*math.cos(pitch)
  -- Finite-difference two-axis solve accounts for the real source hierarchy,
  -- including walking torso and shoulder transforms, instead of only muzzle markers.
  for iteration=1,5 do
   pose[yi][5],pose[pi][4]=a,b;local x,y,z=forward(cfg,pose);local eps=.0001
   pose[yi][5]=a+eps;local ax,ay,az=forward(cfg,pose);pose[yi][5]=a
   pose[pi][4]=b+eps;local bx,by,bz=forward(cfg,pose);pose[pi][4]=b
   ax,ay,az=(ax-x)/eps,(ay-y)/eps,(az-z)/eps;bx,by,bz=(bx-x)/eps,(by-y)/eps,(bz-z)/eps
   local aa=ax*ax+ay*ay+az*az;local bb=bx*bx+by*by+bz*bz;local ab=ax*bx+ay*by+az*bz;local da=ax*(tx-x)+ay*(ty-y)+az*(tz-z);local db=bx*(tx-x)+by*(ty-y)+bz*(tz-z);local det=aa*bb-ab*ab
   if det<1e-8 then break end
   a=a+math.max(-.5,math.min(.5,(da*bb-db*ab)/det));b=b+math.max(-.5,math.min(.5,(db*aa-da*ab)/det))
  end
  pose[yi][5],pose[pi][4]=originalY,originalP
  return a,b
 end
 local function target(n)
  local kind,_,id=Spring.GetUnitWeaponTarget(unitID,n)
  if kind~=1 or not Spring.ValidUnitID(id)or Spring.GetUnitIsDead(id)then return end
  return id
 end
 local function reach(id)
  if not id or not Spring.ValidUnitID(id)or Spring.GetUnitIsDead(id)then return false end
  local x,y,z=Spring.GetUnitPiecePosDir(unitID,weapons[melee.slot].muzzles[1]);local tx,ty,tz,mx,my,mz=Spring.GetUnitPosition(id,true)
  if not(x and tx)then return false end
  tx,ty,tz=mx or tx,my or ty,mz or tz
  return math.sqrt((x-tx)^2+(y-ty)^2+(z-tz)^2)-(Spring.GetUnitRadius(id)or 0)<=melee.reach
 end
 local function physical(n)
  local w=weapons[n];if not w.ready then return false end
  local _,_,_,x,y,z=Spring.GetUnitPiecePosDir(unitID,w.muzzles[math.max(1,w.cursor)]);local _,_,_,a,b,c=Spring.GetUnitWeaponVectors(unitID,n)
  if not(x and a)then return false end
  local aa=x*x+y*y+z*z;local bb=a*a+b*b+c*c
  return aa>1e-10 and bb>1e-10 and(x*a+y*b+z*c)/math.sqrt(aa*bb)>=math.cos(math.rad(4))
 end
 local function animate()
  while true do
   local f=Spring.GetGameFrame();local elapsed=math.max(0,f-lastFrame)*frameStep;lastFrame=f
   local chosen=moving and'walk'or'idle';if chosen~=clipName then clipName=chosen;phase=0;travel=0 end
   if chosen=='walk'then
    local vx,vy,vz=Spring.GetUnitVelocity(unitID);local speed=math.sqrt((vx or 0)^2+(vz or 0)^2)*Game.gameSpeed
    travel=(travel+speed*elapsed)%data.walkDistanceTotal
    local map=data.walkDistanceMap;local index=1
    while index<#map-1 and map[index+1]<travel do index=index+1 end
    local t=(travel-map[index])/math.max(1e-8,map[index+1]-map[index]);phase=(index-1+t)/(#map-1)*data.clips.walk.duration
   else phase=(phase+elapsed)%data.clips.idle.duration end
   local pose={};for i in ipairs(bones)do pose[i]=sample(data.clips[chosen],phase,i)end
   for n,cfg in ipairs(data.weaponMounts)do
    local w=weapons[n];local clip=cfg.fireClip and data.clips[cfg.fireClip]
    if cfg.loopFireClip and clip then
     if f-w.lastShot<6 then w.loopTime=(f-w.loopStart)*frameStep*(cfg.loopSpeed or 1)end
     for _,name in ipairs(clip.active_bones or{})do local i=byname[name];if i then pose[i]=sample(clip,w.loopTime,i)end end
    elseif clip and f-w.fireFrame>=0 and(f-w.fireFrame)*frameStep<clip.duration then
     for _,name in ipairs(clip.active_bones or{})do local i=byname[name];if i then pose[i]=sample(clip,(f-w.fireFrame)*frameStep,i)end end
    end
    if cfg.yaw and not cfg.poseOwner then
     local yi,pi=byname[cfg.yaw],byname[cfg.pitch];local a,b=solve(cfg,pose,w.yaw,w.pitch)
     w.actualY=approach(w.actualY or pose[yi][5],a,math.rad(cfg.yawSpeed or 45)*elapsed);w.actualP=approach(w.actualP or pose[pi][4],b,math.rad(cfg.pitchSpeed or 35)*elapsed)
     pose[yi][5],pose[pi][4]=w.actualY,w.actualP
    end
   end
   if actionStart then
    local age=f-actionStart
    if age>=melee.cycleFrames or not actionTarget or not Spring.ValidUnitID(actionTarget)or Spring.GetUnitIsDead(actionTarget)then actionStart,actionTarget=nil,nil
    else
     local t=age/melee.cycleFrames;local a
     if t<.3 then a=-.9*math.sin(t/.3*math.pi/2)elseif t<.55 then a=-.9+1.0*(t-.3)/.25 else a=.1*(1-(t-.55)/.45)end
     -- Authored blade swing on the original shoulder/forearm only; legs and chassis remain source-driven.
     pose[melee.shoulder][4]=pose[melee.shoulder][4]+a
     pose[melee.shoulder][5]=pose[melee.shoulder][5]+.35*math.sin(math.pi*t)
     pose[melee.forearm][4]=pose[melee.forearm][4]+1.1*math.sin(math.pi*t)
    end
   end
   for i,bone in ipairs(bones)do
    local row,old=pose[i],previous[i]or{}
    for a=1,3 do
     if old[a]==nil or math.abs(row[a]-old[a])>1e-6 then Move(bone,a,row[a],old[a]and math.abs(row[a]-old[a])/frameStep or nil)end
     local k=a+3;local v=old[k]and old[k]+delta(old[k],row[k])or row[k]
     if old[k]==nil or math.abs(v-old[k])>1e-6 then Turn(bone,a,v,old[k]and math.abs(v-old[k])/frameStep or nil)end
     old[a],old[k]=row[a],v
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
 function script.QueryWeapon(n)return weapons[n].muzzles[math.max(1,weapons[n].cursor)]end
 function script.AimWeapon(n,h,p)
  local cfg,w=data.weaponMounts[n],weapons[n];if cfg.melee then w.ready=true;return true end
  h,p=h or 0,p or 0;w.ready=math.abs(h)<=math.rad(cfg.maxYaw or 80)and p>=math.rad(cfg.minPitch or -45)and p<=math.rad(cfg.maxPitch or 65)
  if not w.ready then return false end
  if cfg.poseOwner then local own=weapons[cfg.poseOwner];own.yaw,own.pitch=h,p else w.yaw,w.pitch=h,p end
  local stop=Spring.GetGameFrame()+180
  while not physical(n)do if Spring.GetGameFrame()>stop then return false end;Sleep(33)end
  return true
 end
 function script.BlockShot(n)
  if n~=melee.slot then return actionStart~=nil or not physical(n)end
  local f=Spring.GetGameFrame();local id=target(n)
  if not id then actionStart,actionTarget=nil,nil;return true end
  if not actionStart then actionStart,actionTarget=f,id;return true end
  if id~=actionTarget then actionStart,actionTarget=nil,nil;return true end
  local age=f-actionStart
  if age<melee.cueFrame or age>melee.lastCueFrame then return true end
  return not reach(id)
 end
 function script.FireWeapon(n)end -- actual Shot starts recoil, not a blocked firing attempt
 function script.Shot(n)
  local cfg,w=data.weaponMounts[n],weapons[n];w.cursor=w.cursor%#w.muzzles+1;w.fireFrame=Spring.GetGameFrame()
  if w.fireFrame-w.lastShot>6 then w.loopStart=w.fireFrame end;w.lastShot=w.fireFrame
  if cfg.sfx then EmitSfx(w.muzzles[w.cursor],1023+cfg.sfx)end
 end
 function script.Activate()return 1 end
 function script.Deactivate()return 0 end
 function script.Killed(recent,max)return recent/max>.5 and 2 or 1 end
end
