-- Gretchin-only stance composition; shared actor remains unchanged.
local data=include("bar40k/animation_data.lua")("bar40k/bar40k_sanctus_gretchin_rifle_animation.lua")
local actor=(function()
-- One pose writer per actor; native BAR owns movement, targeting and damage.
return function(data)
 local bones,previous,unposed,poseBuffer={}, {}, {}, {}
 for i,name in ipairs(data.bones)do bones[i]=piece(name)end
 local weapons={}
 for n,w in pairs(data.weapons)do
  local row={cursor=0,yaw=0,pitch=0,wantedYaw=0,wantedPitch=0,untilFrame=0,muzzles={}}
  for i,name in ipairs(w.muzzles)do row.muzzles[i]=piece(name)end
  weapons[n]=row
 end
 local moving,building=false,false
 local aimBlend,aimPhase=0,0
 local clipName,phase,lastFrame="idle",0,0
 local lastX,lastZ,transition,transitionStart
 local fireUntil,createdFrame,travel=0,0,0
 local dt=1/Game.gameSpeed
 local function shortest(a,b,t)return a+((b-a+math.pi)%(2*math.pi)-math.pi)*t end
 local function rotation(x,y,z)
  local cx,sx,cy,sy,cz,sz=math.cos(x),math.sin(x),math.cos(y),math.sin(y),math.cos(z),math.sin(z)
  return {cy*cz+sy*sx*sz,-cy*sz+sy*sx*cz,sy*cx,cx*sz,cx*cz,-sx,-sy*cz+cy*sx*sz,sy*sz+cy*sx*cz,cy*cx}
 end
 local function mul(a,b)
  local r={}
  for i=0,2 do for j=1,3 do r[i*3+j]=a[i*3+1]*b[j]+a[i*3+2]*b[3+j]+a[i*3+3]*b[6+j]end end
  return r
 end
 local function transpose(r)return{r[1],r[4],r[7],r[2],r[5],r[8],r[3],r[6],r[9]}end
 local function point(r,p)return{r[1]*p[1]+r[2]*p[2]+r[3]*p[3],r[4]*p[1]+r[5]*p[2]+r[6]*p[3],r[7]*p[1]+r[8]*p[2]+r[9]*p[3]}end
 local function euler(r)
  local x=math.asin(math.max(-1,math.min(1,-r[6])))
  if math.abs(math.cos(x))<1e-6 then return x,math.atan2(-r[7],r[1]),0 end
  return x,math.atan2(r[3],r[9]),math.atan2(r[4],r[5])
 end
 local function approach(a,b,step)return a+math.max(-step,math.min(step,b-a))end
 local function angleDelta(a,b)return (b-a+math.pi)%(2*math.pi)-math.pi end
 local function approachAngle(a,b,step)return a+math.max(-step,math.min(step,angleDelta(a,b)))end
 local function axisRotation(axis,angle)
  local x,y,z=axis[1],axis[2],axis[3];local c,s=math.cos(angle),math.sin(angle);local v=1-c
  return{c+x*x*v,x*y*v-z*s,x*z*v+y*s,y*x*v+z*s,c+y*y*v,y*z*v-x*s,z*x*v-y*s,z*y*v+x*s,c+z*z*v}
 end
 local function rotateRow(pose,i,delta,pivot)
  local row,p=pose[i],data.canonical[i]
  local q=point(delta,{p[1]+row[1]-pivot[1],p[2]+row[2]-pivot[2],p[3]+row[3]-pivot[3]})
  row[1],row[2],row[3]=q[1]+pivot[1]-p[1],q[2]+pivot[2]-p[2],q[3]+pivot[3]-p[3]
  row[4],row[5],row[6]=euler(mul(delta,rotation(row[4],row[5],row[6])))
 end
 local function sample(clip,first,t,i,k,linear)
  local a=clip.frames[first][i][k]
  local b=clip.frames[math.min(first+1,#clip.frames)][i][k]
  if linear then return k<=3 and a+(b-a)*t or shortest(a,b,t)end
  -- Periodic cubic sampling gives idle/fire the same tangent on both sides
  -- of the loop seam. Walking stays linear to preserve planted feet.
  local n=#clip.frames-1
  local p=clip.frames[(first-2)%n+1][i][k]
  local q=clip.frames[(first+1)%n+1][i][k]
  if k>3 then p=shortest(a,p,1);b=shortest(a,b,1);q=shortest(b,q,1)end
  return .5*((2*a)+(-p+b)*t+(2*p-5*a+4*b-q)*t*t+(-p+3*a-3*b+q)*t*t*t)
 end
 local function animate()
  while true do
   local frame=Spring.GetGameFrame()
   local aiming=frame<weapons[1].untilFrame or frame<fireUntil
   local chosen=moving and "walk"or"idle"
   if chosen~=clipName then
    transition={};for i,row in ipairs(unposed)do transition[i]={unpack(row)}end
    transitionStart=frame;clipName,phase=chosen,0
   end
   local elapsed=math.max(0,frame-lastFrame)*dt
   local px,_,pz=Spring.GetUnitPosition(unitID)
   local distance=lastX and math.sqrt((px-lastX)^2+(pz-lastZ)^2)or 0
   local signedDistance=distance
   if lastX and Spring.GetUnitDirection then
    local fx,_,fz=Spring.GetUnitDirection(unitID)
    if (px-lastX)*fx+(pz-lastZ)*fz<0 then signedDistance=-distance end
   end
   travel=travel+signedDistance
   lastX,lastZ,lastFrame=px,pz,frame
   local clip=data.clips[clipName]
   phase=(phase+(clipName=="walk"and not data.aircraft and distance/data.stride*clip.duration or elapsed))%clip.duration
   local index=phase/clip.duration*(#clip.frames-1);local first=math.floor(index)+1
   local alpha=index-math.floor(index);local second=math.min(first+1,#clip.frames)
   local blend=transition and math.min(1,(frame-transitionStart)/6)or 1;blend=blend*blend*(3-2*blend)
   local pose=poseBuffer
   for i in ipairs(bones)do
    local a,b=clip.frames[first][i],clip.frames[second][i];local row=pose[i]or{}
    for k=1,6 do
     local v=sample(clip,first,alpha,i,k,clipName=="walk")
     if transition and transition[i]then v=k<=3 and transition[i][k]+(v-transition[i][k])*blend or shortest(transition[i][k],v,blend)end
     row[k]=v
    end
    pose[i]=row
   end
   if blend==1 then transition=nil end
   aimBlend=approach(aimBlend,aiming and 1 or 0,elapsed/.18)
   local fire=data.clips.fire
   aimPhase=(aimPhase+elapsed)%fire.duration
   local fi=aimPhase/fire.duration*(#fire.frames-1);local ff=math.floor(fi)+1
   for _,i in ipairs(data.aimPoseMembers)do
    for k=1,6 do
     local v=sample(fire,ff,fi-math.floor(fi),i,k,false)
     pose[i][k]=k<=3 and pose[i][k]+(v-pose[i][k])*aimBlend or shortest(pose[i][k],v,aimBlend)
    end
   end
   for i,row in ipairs(pose)do
    local saved=unposed[i]or{};for k=1,6 do saved[k]=row[k]end;unposed[i]=saved
   end
   if not data.fixedInfantryPose or building then
   for n,group in pairs(data.aimGroups)do
    local w=weapons[n]
    if building then w.untilFrame=frame+90 end
    if frame>w.untilFrame then w.wantedYaw,w.wantedPitch=math.rad(group.centerYaw or 0),0 end
    local rate=math.rad(group.speed)*math.max(dt,elapsed)
    w.yaw=approachAngle(w.yaw,w.wantedYaw,rate);w.pitch=approach(w.pitch,w.wantedPitch,rate)
    local base=pose[group.pivotJoint];local baseR=rotation(base[4],base[5],base[6]);local c=data.canonical[group.pivotJoint]
    local offset=point(baseR,group.pivotLocal);local pivot={c[1]+base[1]+offset[1],c[2]+base[2]+offset[2],c[3]+base[3]+offset[3]}
    local forward=point(baseR,group.forwardLocal)
    if group.pitchReferenceJoint then
     local row=pose[group.pitchReferenceJoint];forward=point(rotation(row[4],row[5],row[6]),group.pitchForwardLocal)
    end
    local oldYaw=math.atan2(forward[1],forward[3]);local oldPitch=math.asin(math.max(-1,math.min(1,forward[2])))
    if group.pitchMembers then
     local off=point(baseR,group.pitchPivotLocal);local pp={c[1]+base[1]+off[1],c[2]+base[2]+off[2],c[3]+base[3]+off[3]}
     local yaw=rotation(0,angleDelta(oldYaw,w.yaw)*aimBlend,0);local q=point(yaw,{pp[1]-pivot[1],pp[2]-pivot[2],pp[3]-pivot[3]});pp={q[1]+pivot[1],q[2]+pivot[2],q[3]+pivot[3]}
     for _,i in ipairs(group.members)do rotateRow(pose,i,yaw,pivot)end
     local pitch=axisRotation({math.cos(w.yaw),0,-math.sin(w.yaw)},-(w.pitch-oldPitch)*aimBlend)
     for _,i in ipairs(group.pitchMembers)do rotateRow(pose,i,pitch,pp)end
    else
     local delta=mul(rotation(-w.pitch,w.yaw,0),transpose(rotation(-oldPitch,oldYaw,0)))
     for _,i in ipairs(group.members)do rotateRow(pose,i,delta,pivot)end
    end
   end
   end -- Imported infantry fire poses have no target-driven bone overlay.
   for _,rotor in ipairs(data.rotors or{})do
    local i=rotor.bone;local row=pose[i];local r=rotation(row[4],row[5],row[6]);local p=data.canonical[i]
    local off=point(r,rotor.pivotLocal);local pivot={p[1]+row[1]+off[1],p[2]+row[2]+off[2],p[3]+row[3]+off[3]}
    rotateRow(pose,i,axisRotation(point(r,rotor.axisLocal),(frame-createdFrame)*dt*rotor.speed),pivot)
   end
   for _,wheel in ipairs(data.distanceWheels or{})do
    local i=wheel.bone;local row=pose[i];local r=rotation(row[4],row[5],row[6]);local p=data.canonical[i]
    local off=point(r,wheel.pivotLocal);local pivot={p[1]+row[1]+off[1],p[2]+row[2]+off[2],p[3]+row[3]+off[3]}
    rotateRow(pose,i,axisRotation(point(r,wheel.axisLocal),travel/wheel.radius*(wheel.sign or 1)),pivot)
   end
   for i,bone in ipairs(bones)do
    local row,old=pose[i],previous[i]or{}
    for axis=1,3 do
     local value=row[axis]
     if old[axis]==nil or math.abs(value-old[axis])>.00001 then Move(bone,axis,value,old[axis]and math.abs(value-old[axis])/(dt*(data.frameInterval or 1))or nil)end
     old[axis]=value
     local k=axis+3;value=old[k]and shortest(old[k],row[k],1)or row[k]
     if old[k]==nil or math.abs(value-old[k])>.00001 then Turn(bone,axis,value,old[k]and math.abs(value-old[k])/(dt*(data.frameInterval or 1))or nil)end;row[k]=value;old[k]=value
    end
    previous[i]=old
   end
   Sleep(33*(data.frameInterval or 1))
  end
 end
 function script.Create()
  lastFrame=Spring.GetGameFrame();createdFrame=lastFrame;local x,_,z=Spring.GetUnitPosition(unitID);lastX,lastZ=x,z
  for i,bone in ipairs(bones)do
   local row=data.clips.idle.frames[1][i];previous[i]={unpack(row)};unposed[i]={unpack(row)}
   for k=1,3 do Move(bone,k,row[k]);Turn(bone,k,row[k+3])end
  end
  if data.builder then Spring.SetUnitNanoPieces(unitID,{weapons[1].muzzles[1]})end
  StartThread(animate)
 end
 function script.StartBuilding(heading,pitch)
  building=true;SetUnitValue(COB.INBUILDSTANCE,1)
  for _,w in pairs(weapons)do w.wantedYaw,w.wantedPitch,w.untilFrame=heading or 0,pitch or 0,Spring.GetGameFrame()+90 end
 end
 function script.StopBuilding()building=false;SetUnitValue(COB.INBUILDSTANCE,0)end
 function script.QueryNanoPiece()return weapons[1].muzzles[1]end
 function script.QueryBuildInfo()return bones[1]end
 function script.StartMoving()moving=true end
 function script.StopMoving()moving=false end
 function script.AimFromWeapon(n)
  if data.builder then n=1 end
return weapons[n].muzzles[1]end
 function script.QueryWeapon(n)
  if data.builder then n=1 end
local w=weapons[n];return w.muzzles[math.max(1,w.cursor)]end
 function script.AimWeapon(n,heading,pitch)
  if data.builder then n=1 end

  if building then return false end
  if data.weapons[n].shield then return true end
  if data.fixedInfantryPose then
   local w=weapons[n];local now=Spring.GetGameFrame()
   w.fixedAligned=math.abs(heading or 0)<=math.rad(10)
   if not w.fixedAligned then return false end
   if w.untilFrame<now then w.poseReadyFrame=now+6 end
   w.untilFrame=now+30
   while Spring.GetGameFrame()<(w.poseReadyFrame or 0)do Sleep(33)end
   return true
  end
  if data.fixedAirframe then return math.abs(heading or 0)<math.rad(50)and math.abs(pitch or 0)<math.rad(80)end
  local signal=2^n;Signal(signal);SetSignalMask(signal)
  local group,w=data.aimGroups[n],weapons[n];heading,pitch=heading or 0,pitch or 0
  if math.abs(angleDelta(math.rad(group.centerYaw or 0),heading))>math.rad(group.maxYaw)or pitch<math.rad(group.minPitch)or pitch>math.rad(group.maxPitch)then return false end
  w.wantedYaw,w.wantedPitch,w.untilFrame=heading,pitch,Spring.GetGameFrame()+90
  while aimBlend<.98 or math.abs(angleDelta(w.yaw,heading))>.025 or math.abs(w.pitch-pitch)>.025 do
   if Spring.GetGameFrame()>w.untilFrame then return false end
   Sleep(33)
  end
  return true
 end
 function script.BlockShot(n)
  if data.builder then n=1 end

  if data.weapons[n].shield then return false end
  if data.fixedInfantryPose then return weapons[n].fixedAligned~=true end
  if data.fixedAirframe then return false end
  local w=weapons[n]
  return aimBlend<.98 or math.abs(angleDelta(w.yaw,w.wantedYaw))>.06 or math.abs(w.pitch-w.wantedPitch)>.06
 end
 function script.FireWeapon(n)
  if data.builder then n=1 end

  if n==1 then fireUntil=Spring.GetGameFrame()+12 end
 end
 function script.Shot(n)
  if data.builder then n=1 end

  local cfg,w=data.weapons[n],weapons[n]
  if cfg.shield then return end
  w.cursor=w.cursor%#w.muzzles+1
  if cfg.sfx then EmitSfx(w.muzzles[w.cursor],1023+cfg.sfx)end
  if n==1 then fireUntil=Spring.GetGameFrame()+12 end
 end
 function script.Activate()return 1 end
 function script.Deactivate()return 0 end
 function script.Killed(recent,maximum)return recent/maximum>.5 and 2 or 1 end
end

end)()
data.fixedInfantryPose=true
actor(data)
