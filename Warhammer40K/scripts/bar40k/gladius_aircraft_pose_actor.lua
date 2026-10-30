-- Ordinary native skinned geometry; one pose writer, native BAR flight/targeting.
return function(data,cfg)
 local bones,old,sourceOld={},{},{}
 for i,name in ipairs(data.bones)do bones[i]=piece(name)end
 local body=piece('body');local muzzle=piece(cfg.muzzle)
 local moving=false;local fireUntil=-1;local fireStart=0
 local active='idle';local phase=0;local last=Spring.GetGameFrame()
 local blend,blendAt;local dt=1/Game.gameSpeed
 local airPitch=0;local aimUntil=-1
 local function angle(a,b,t)return a+((b-a+math.pi)%(2*math.pi)-math.pi)*t end
 local function sample(clip,time,i)
  local n=#clip.frames;if n==1 then return clip.frames[1][i]end
  local f=(time%clip.duration)/clip.duration*(n-1)
  local a=math.floor(f)+1;local t=f-math.floor(f);local x,y=clip.frames[a][i],clip.frames[math.min(a+1,n)][i];local row={}
  for k=1,6 do row[k]=k<=3 and x[k]+(y[k]-x[k])*t or angle(x[k],y[k],t)end
  return row
 end
 local function rotation(x,y,z)
  local cx,sx,cy,sy,cz,sz=math.cos(x),math.sin(x),math.cos(y),math.sin(y),math.cos(z),math.sin(z)
  return {cy*cz+sy*sx*sz,-cy*sz+sy*sx*cz,sy*cx,cx*sz,cx*cz,-sx,-sy*cz+cy*sx*sz,sy*sz+cy*sx*cz,cy*cx}
 end
 local function euler(r)
  local x=math.asin(math.max(-1,math.min(1,-r[6])))
  if math.abs(math.cos(x))<1e-6 then return x,math.atan2(-r[7],r[1]),0 end
  return x,math.atan2(r[3],r[9]),math.atan2(r[4],r[5])
 end
 local function wanted()
  local _,_,_,x,y,z=Spring.GetUnitWeaponVectors(unitID,1)
  if not(x and y and z)then return end
  local front,up,right=Spring.GetUnitVectors(unitID)
  if not(front and up and right)then return end
  return x*right[1]+y*right[2]+z*right[3],x*up[1]+y*up[2]+z*up[3],x*front[1]+y*front[2]+z*front[3]
 end
 local function boreAligned(n)
  if cfg.bomb then return true end
  local _,_,_,x,y,z=Spring.GetUnitPiecePosDir(unitID,muzzle)
  local _,_,_,a,b,c=Spring.GetUnitWeaponVectors(unitID,n or 1)
  if not(x and y and z and a and b and c)then return false end
  local aa=x*x+y*y+z*z;local bb=a*a+b*b+c*c
  if not(aa>1e-12 and bb>1e-12 and aa<math.huge and bb<math.huge)then return false end
  return (x*a+y*b+z*c)/math.sqrt(aa*bb)>=math.cos(math.rad(cfg.boreDegrees or 7))
 end
 local function holdBurst(n)
  if cfg.bomb then return end
  -- Pinned native weapon update aims before UpdateSalvo. Hold an already
  -- started burst too; BlockShot alone checks only the first projectile.
  local nextShot=Spring.GetUnitWeaponState(unitID,n,'nextSalvo')
  if type(nextShot)=='number' then Spring.SetUnitWeaponState(unitID,n,'nextSalvo',math.max(nextShot,Spring.GetGameFrame()+1))end
 end
 local function pitchPose(pose,frame,initial)
  if not cfg.visualPitch then return end
  local index={};for i,name in ipairs(data.bones)do index[name]=i end
  local pivot=pose[index.body];local emitter=pose[index[cfg.muzzle]];local r=rotation(emitter[4],emitter[5],emitter[6])
  local sourcePitch=math.atan2(r[6],math.sqrt(r[3]*r[3]+r[9]*r[9]));local target=0
  if frame<aimUntil then
   local x,y,z=wanted()
   if x then target=math.atan2(y,math.sqrt(x*x+z*z))-sourcePitch end
  end
  target=math.max(math.rad(-65),math.min(math.rad(75),target))
  local step=math.rad(75)*dt
  airPitch=initial and 0 or airPitch+math.max(-step,math.min(step,target-airPitch))
  local c,s=math.cos(-airPitch),math.sin(-airPitch)
  -- Left multiply EVERY flat skin palette and marker by the same rigid
  -- rotation about the actual Hull pivot. Connected geometry stays connected.
  for _,row in ipairs(pose)do
   local y,z=row[2]-pivot[2],row[3]-pivot[3]
   row[2],row[3]=pivot[2]+c*y-s*z,pivot[3]+s*y+c*z
   local q=rotation(row[4],row[5],row[6])
   local rr={q[1],q[2],q[3],c*q[4]-s*q[7],c*q[5]-s*q[8],c*q[6]-s*q[9],s*q[4]+c*q[7],s*q[5]+c*q[8],s*q[6]+c*q[9]}
   row[4],row[5],row[6]=euler(rr)
  end
 end
 local function apply(role,time,frame,initial)
  local clip=data.clips[role];local f=blendAt and math.min(1,(frame-blendAt)/6)or 1
  local pose={}
  -- Blend source poses BEFORE the common airframe pitch. Blending already
  -- pitched palettes independently would bend attachments during transitions.
  for i in ipairs(bones)do
   local row=sample(clip,time,i)
   if blend and f<1 then local from=blend[i];for k=1,6 do row[k]=k<=3 and from[k]+(row[k]-from[k])*f or angle(from[k],row[k],f)end end
   pose[i]=row;sourceOld[i]={unpack(row)}
  end
  pitchPose(pose,frame,initial)
  for i,b in ipairs(bones)do
   local row=pose[i];local prev=old[i]
   for axis=1,3 do
    local k=axis+3;local a=prev and angle(prev[k],row[k],1)or row[k]
    if not prev or math.abs(prev[axis]-row[axis])>1e-5 then Move(b,axis,row[axis],not initial and math.abs(row[axis]-(prev and prev[axis]or row[axis]))/dt or nil)end
    if not prev or math.abs(prev[k]-a)>1e-5 then Turn(b,axis,a,not initial and math.abs(a-(prev and prev[k]or a))/dt or nil)end
    row[k]=a
   end
   old[i]=row
  end
  if f>=1 then blend,blendAt=nil,nil end
 end
 local function animate()
  while true do
   local frame=Spring.GetGameFrame();local elapsed=math.max(0,frame-last)*dt;last=frame
   local role=frame<fireUntil and'fire'or moving and'walk'or'idle'
   if not data.clips[role]then role='idle'end
   if role~=active then
    blend={};for i,row in ipairs(sourceOld)do blend[i]={unpack(row)}end
    blendAt=frame;active=role;phase=role=='fire'and math.max(0,frame-fireStart)*dt or 0
   else phase=phase+elapsed end
   apply(active,phase,frame,false);Sleep(33)
  end
 end
 function script.Create()apply('idle',0,last,true);if not cfg.bomb then Spring.SetUnitWeaponState(unitID,1,'reaimTime',1)end;StartThread(animate)end
 function script.StartMoving()moving=true end
 function script.StopMoving()moving=false end
 function script.QueryWeapon()return muzzle end
 function script.AimFromWeapon()return body end
 function script.AimWeapon(n,heading,pitch)
  if cfg.bomb then return true end
  aimUntil=Spring.GetGameFrame()+30
  -- Native fighter/hover-air movement owns yaw. Return aim-ready to retain
  -- native target tracking, but never release a sideways projectile.
  if not boreAligned(n)then holdBurst(n)end
  return true
 end
 function script.BlockShot(n)return not boreAligned(n)end
 function script.FireWeapon()
  local now=Spring.GetGameFrame()
  if data.clips.fire and now>=fireUntil then fireStart=now;fireUntil=now+math.ceil(data.clips.fire.duration*Game.gameSpeed)end
 end
 function script.Shot()if cfg.sfx then EmitSfx(muzzle,1023+cfg.sfx)end end
 function script.Activate()return 1 end
 function script.Deactivate()return 0 end
 function script.Killed()return 0 end
end
