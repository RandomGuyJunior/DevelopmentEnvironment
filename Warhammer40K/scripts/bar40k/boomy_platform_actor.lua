-- One articulated cannon. Native Gauntlet aim rates, source shot-cue recoil.
-- The native engine owns target selection, trajectories, shots and damage.
return function(data)
 local bones={}
 for i,name in ipairs(data.bones)do bones[i]=piece(name)end
 local cfg=data.weaponMounts[1]
 local yaw,pitch,muzzle=piece(cfg.yaw),piece(cfg.pitch),piece(cfg.muzzles[1])
 local barrel=4 -- verified original basilisk_barrel joint
 assert(data.bones[barrel]=='basilisk_barrel')
 local idle=data.clips.idle
 local fire=data.clips.fire
 local cue=(fire.shot_cue or 0)/(fire.source_fps or 30)
 local shot=-10000
 local heading,elevation,ready=0,0,false
 local active={}
 for _,name in ipairs(fire.active_bones or{})do active[name]=true end
 local function delta(a,b)return(b-a+math.pi)%(2*math.pi)-math.pi end
 local function sample(clip,time,i,loop)
  time=loop and time%clip.duration or math.min(clip.duration,time)
  local f=time/clip.duration*(#clip.frames-1);local k=math.floor(f)+1
  local a,b=clip.frames[k][i],clip.frames[math.min(k+1,#clip.frames)][i];local row={}
  for n=1,6 do row[n]=a[n]+(n<=3 and b[n]-a[n]or delta(a[n],b[n]))*(f-math.floor(f))end
  return row
 end
 local function animate()
  while true do
   local frame=Spring.GetGameFrame();local age=(frame-shot)/Game.gameSpeed
   for i,bone in ipairs(bones)do
    if bone~=yaw and bone~=pitch then
     local row=sample(idle,frame/Game.gameSpeed,i,true)
     if age>=0 and age<fire.duration-cue and active[data.bones[i]]then row=sample(fire,cue+age,i,false)end
     -- Raising the gun in the source fire clip is aiming, not recoil.
     -- Native pitch owns elevation; preserve the original recoil translations.
     if i==barrel then for k=4,6 do row[k]=fire.frames[1][i][k]end end
     local move={Spring.UnitScript.GetPieceTranslation(bone)}
     local turn={Spring.UnitScript.GetPieceRotation(bone)}
     for axis=1,3 do
      Move(bone,axis,row[axis],math.abs(row[axis]-move[axis])*Game.gameSpeed)
      Turn(bone,axis,row[axis+3],math.abs(delta(turn[axis],row[axis+3]))*Game.gameSpeed)
     end
    end
   end
   Sleep(33)
  end
 end
 local function aligned()
  if not ready then return false end
  local _,h=Spring.UnitScript.GetPieceRotation(yaw)
  local p=Spring.UnitScript.GetPieceRotation(pitch)
  return math.abs(delta(h,heading))<math.rad(1)and math.abs(delta(p,-elevation+math.rad(cfg.pitchOffset or 0)))<math.rad(1)
 end
 function script.Create()
  for i,bone in ipairs(bones)do
   local row=idle.frames[1][i]
   for axis=1,3 do Move(bone,axis,row[axis]);Turn(bone,axis,row[axis+3])end
  end
  for axis=1,3 do Turn(bones[barrel],axis,fire.frames[1][barrel][axis+3])end
  Turn(pitch,1,math.rad(cfg.pitchOffset or 0))
  StartThread(animate)
 end
 function script.AimFromWeapon()return muzzle end
 function script.QueryWeapon()return muzzle end
 function script.AimWeapon(n,h,p)
  Signal(2);SetSignalMask(2);ready=false
  if math.abs(h)>math.rad(cfg.maxYaw or 180)or p<math.rad(cfg.minPitch or -10)or p>math.rad(cfg.maxPitch or 80)then return false end
  heading,elevation=h,p
  Turn(yaw,2,h,math.rad(30));Turn(pitch,1,-p+math.rad(cfg.pitchOffset or 0),math.rad(45))
  WaitForTurn(yaw,2);WaitForTurn(pitch,1)
  ready=true;return aligned()
 end
 function script.BlockShot()
  if not aligned()then return true end
  local _,_,_,dx,dy,dz=Spring.GetUnitPiecePosDir(unitID,muzzle)
  local _,_,_,tx,ty,tz=Spring.GetUnitWeaponVectors(unitID,1)
  if not(dx and tx)then return true end
  local a=dx*dx+dy*dy+dz*dz;local b=tx*tx+ty*ty+tz*tz
  return a<1e-12 or b<1e-12 or(dx*tx+dy*ty+dz*tz)/math.sqrt(a*b)<math.cos(math.rad(3))
 end
 function script.FireWeapon()shot=Spring.GetGameFrame()end
 function script.Shot()
  shot=Spring.GetGameFrame()
  if cfg.sfx then EmitSfx(muzzle,1023+cfg.sfx)end
 end
 function script.Activate()return 1 end
 function script.Deactivate()return 0 end
 function script.Killed(recent,max)return recent/max>.5 and 2 or 1 end
end
