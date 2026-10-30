-- Tankwagon only. The native engine owns targeting, ballistics and chassis movement.
-- Current accepted mesh has one static source pose; no invented recoil or wheel motion.
return function(data)
 local bones={};for i,name in ipairs(data.bones)do bones[i]=piece(name)end
 local yaw,pitch,muzzle=piece('mount_yaw','mount_pitch','muzzle')
 local reach=include("bar40k/tankwagon_facing.lua")()
 local aim=data.aim;local desiredYaw,desiredPitch=0,0;local ready=false
 local SIG_AIM=1
 local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
 local function delta(a,b)return(b-a+math.pi)%(2*math.pi)-math.pi end
 local function settled()
  local _,y=Spring.UnitScript.GetPieceRotation(yaw);local p=Spring.UnitScript.GetPieceRotation(pitch)
  return math.abs(delta(y,desiredYaw))<math.rad(1)and math.abs(delta(p,-desiredPitch))<math.rad(1)
 end
 function script.Create()
  StartThread(reach.Run)
  for i,b in ipairs(bones)do local row=data.clips.idle.frames[1][i]
   for axis=1,3 do Move(b,axis,row[axis]);Turn(b,axis,row[axis+3])end
  end
 end
 function script.StartMoving()end
 function script.StopMoving()end
 function script.Activate()return 1 end
 function script.Deactivate()return 0 end
 function script.AimFromWeapon()return pitch end
 function script.QueryWeapon()return muzzle end
 function script.AimWeapon(n,h,p)
  if n~=1 then return false end
  Signal(SIG_AIM);SetSignalMask(SIG_AIM);ready=false
  if not finite(h)or not finite(p)or math.abs(h)>math.rad(aim.yaw)or p<math.rad(aim.minPitch)or p>math.rad(aim.maxPitch)then return false end
  desiredYaw=h;desiredPitch=p
  local timeout=Spring.GetGameFrame()+240
  -- Avoid the native shortest yaw path crossing the forbidden rear sector.
  local _,current=Spring.UnitScript.GetPieceRotation(yaw)
  current=(current+math.pi)%(2*math.pi)-math.pi
  if math.abs(h-current)>math.pi then
   Turn(yaw,y_axis,0,math.rad(aim.yawRate))
   while true do local _,y=Spring.UnitScript.GetPieceRotation(yaw)
    if math.abs(delta(y,0))<math.rad(1)then break end
    if Spring.GetGameFrame()>timeout then return false end;Sleep(33)
   end
  end
  Turn(yaw,y_axis,h,math.rad(aim.yawRate));Turn(pitch,x_axis,-p,math.rad(aim.pitchRate))
  while not settled()do if Spring.GetGameFrame()>timeout then return false end;Sleep(33)end
  ready=true;return true
 end
 function script.BlockShot(n)return n~=1 or not ready or not settled()end
 function script.FireWeapon()end
 function script.Shot(n)if n==1 and ready and settled()then EmitSfx(muzzle,1024)end end
 function script.Killed()return 0 end
end
