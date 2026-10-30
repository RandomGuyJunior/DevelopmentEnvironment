-- Private Gunwagon family actor. Native engine owns orders, flight/waterline,
-- target selection, projectiles, damage and construction. Chassis and wheels
-- have constant source-bind transforms; only the weapon/crew may animate.
return function(data)
 local bones={};for i,name in ipairs(data.bones)do bones[i]=piece(name)end
 local yaw,pitch,muzzle=piece('mount_yaw','mount_pitch','muzzle')
 local aim=data.aim;local desiredYaw,desiredPitch=0,0
 local owner,holdUntil=nil,-1;local fired=-100000
 local function delta(a,b)return(b-a+math.pi)%(2*math.pi)-math.pi end
 local function lerp(a,b,t,k)return k<=3 and a+(b-a)*t or a+delta(a,b)*t end
 local function rowAt(clip,t,i)
  local f=math.max(0,math.min(t/clip.duration,1))*(#clip.frames-1)
  local a=math.floor(f)+1;local b=math.min(a+1,#clip.frames);local s=f-math.floor(f);local out={}
  for k=1,6 do out[k]=lerp(clip.frames[a][i][k],clip.frames[b][i][k],s,k)end
  return out
 end
 local function animate()
  local previous={}
  while true do
   local f=Spring.GetGameFrame();local t=f/Game.gameSpeed
   local age=(f-fired)/Game.gameSpeed;local idle=data.clips.idle
   local firing=age>=0 and age<data.clips.fire.duration
   local blend=firing and math.min(1,age*30/3,(data.clips.fire.duration-age)*30/6)or 0
   for i,b in ipairs(bones)do
    local idleRow=rowAt(idle,t%idle.duration,i);local row=idleRow
    if firing then
     local fire=rowAt(data.clips.fire,age,i);row={}
     for k=1,6 do row[k]=lerp(idleRow[k],fire[k],blend,k)end
    end
    local old=previous[i]
    for axis=1,3 do
     if not old or math.abs(row[axis]-old[axis])>1e-6 then Move(b,axis,row[axis],old and math.abs(row[axis]-old[axis])*Game.gameSpeed or nil)end
     local k=axis+3;local value=old and old[k]+delta(old[k],row[k])or row[k]
     if not old or math.abs(value-old[k])>1e-6 then Turn(b,axis,value,old and math.abs(value-old[k])*Game.gameSpeed or nil)end
     row[k]=value
    end
    previous[i]=row
   end
   Sleep(33)
  end
 end
 local function settled()
  local _,y=Spring.UnitScript.GetPieceRotation(yaw);local p=Spring.UnitScript.GetPieceRotation(pitch)
  return math.abs(delta(y,desiredYaw))<math.rad(1.5)and math.abs(delta(p,-desiredPitch))<math.rad(1.5)
 end
 function script.Create()StartThread(animate)end
 function script.StartMoving()end
 function script.StopMoving()end
 function script.Activate()return 1 end
 function script.Deactivate()return 0 end
 function script.AimFromWeapon()return pitch end
 function script.QueryWeapon()return muzzle end
 function script.AimWeapon(n,h,p)
  local now=Spring.GetGameFrame();h,p=h or 0,p or 0
  local minimum=aim.minPitch
  if aim.forwardCabClearancePitch and math.abs(h)<math.rad(45)then minimum=math.max(minimum,aim.forwardCabClearancePitch)end
  if math.abs(h)>math.rad(aim.yaw)or p<math.rad(minimum)or p>math.rad(aim.maxPitch)then return false end
  -- A physical single turret cannot serve two different native targets at once.
  -- Primary AA can pre-empt secondary ground fire; otherwise retain a short lease.
  if owner and owner~=n and now<holdUntil and n~=1 then return false end
  owner=n;holdUntil=now+30;desiredYaw=aim.fixedBed and 0 or h;desiredPitch=p
  Turn(yaw,y_axis,desiredYaw,math.rad(aim.yawRate))
  Turn(pitch,x_axis,-desiredPitch,math.rad(aim.pitchRate))
  local timeout=now+240
  while not settled()do
   if owner~=n or Spring.GetGameFrame()>timeout then return false end
   Sleep(33)
  end
  if owner==n then holdUntil=Spring.GetGameFrame()+30 end
  return owner==n
 end
 function script.BlockShot(n)return owner~=n or not settled()end
 function script.FireWeapon(n)if owner==n then fired=Spring.GetGameFrame()end end
 function script.Shot(n)
  if owner==n then fired=Spring.GetGameFrame();EmitSfx(muzzle,1024)end
 end
 function script.Killed()return 0 end
end
