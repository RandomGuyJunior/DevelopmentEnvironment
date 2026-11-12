-- Same native hover presentation/flight as the current Gunship; two real guns.
local root,yaw,pitch,recoil,muzzle,drop=piece('root','nose_yaw','nose_pitch','nose_recoil','nose_muzzle','bomb_drop')
local H=VFS.Include('scripts/bar40k/gunship_hover.lua')
local A=VFS.Include('scripts/bar40k/gunship_aim.lua')
local context={unitID=unitID,y_axis=2,Signal=Signal,SetSignalMask=SetSignalMask,Move=Move,Sleep=Sleep,StartThread=StartThread,Witness=function()end}
local function delta(a,b)return(b-a+math.pi)%(2*math.pi)-math.pi end
local function aligned()
 local _,_,_,x,y,z=Spring.GetUnitPiecePosDir(unitID,muzzle)
 local _,_,_,a,b,c=Spring.GetUnitWeaponVectors(unitID,1)
 if not(x and y and z and a and b and c)then return false end
 local aa=x*x+y*y+z*z;local bb=a*a+b*b+c*c
 return aa>1e-12 and bb>1e-12 and(x*a+y*b+z*c)/math.sqrt(aa*bb)>=math.cos(math.rad(4))
end
function script.Create()H.Start(root,context)end
function script.AimFromWeapon(n)return n==1 and piece('nose_axis')or drop end
function script.QueryWeapon(n)return n==1 and muzzle or drop end
function script.AimWeapon(n,h,p)
 if n==2 then return true end
 if n~=1 then return false end
 local _,_,_,x,y,z=Spring.GetUnitWeaponVectors(unitID,1)
 local front,up,right=Spring.GetUnitVectors(unitID)
 h,p=A.Angles(x,y,z,front,up,right,0)
 if not h then return false end
 h=delta(0,h)
 if math.abs(h)>math.rad(6)or p<math.rad(-60)or p>math.rad(10)then return false end
 Signal(2);SetSignalMask(2)
 Turn(yaw,2,h,math.rad(45));Turn(pitch,1,-p,math.rad(40))
 WaitForTurn(yaw,2);WaitForTurn(pitch,1)
 return aligned()
end
function script.BlockShot(n)return n==1 and not aligned()or(n~=1 and n~=2)end
function script.FireWeapon()end
local function kick()
 Signal(4);SetSignalMask(4)
 Move(recoil,3,-0.6140748901367188,6);WaitForMove(recoil,3)
 Move(recoil,3,0,1.2)
end
function script.Shot(n)
 if n==1 then EmitSfx(muzzle,1024);StartThread(kick)end
end
function script.StartMoving()end
function script.StopMoving()end
function script.Activate()return 1 end
function script.Deactivate()return 0 end
function script.Killed()H.Stop(root,context);return 1 end
