local d=include("bar40k/animation_data.lua")("bar40k/grot_artillery_wagon_animation.lua")
include("bar40k/roster_gunwagon_actor.lua")(d)
-- The TTS mortar's authored bore rests above horizontal. The original single
-- pose writer receives only the additional rotation needed for native aim.
local aim=script.AimWeapon
function script.AimWeapon(n,h,p)return aim(n,h,(p or 0)-math.rad(d.sourceGunRestPitchDegrees))end
-- Shot owns recoil and flash, so failed firing attempts cannot animate a shot.
function script.FireWeapon()end
local block=script.BlockShot
function script.BlockShot(n)
 if block(n)then return true end
 local _,_,_,x,y,z=Spring.GetUnitWeaponVectors(unitID,n)
 local _,_,_,a,b,c=Spring.GetUnitPiecePosDir(unitID,piece('muzzle'))
 if not(x and y and z and a and b and c)then return true end
 local heading=Spring.GetUnitHeading(unitID)*2*math.pi/65536
 local cs,sn=math.cos(heading),math.sin(heading);local xx,zz=cs*x-sn*z,sn*x+cs*z
 local bearing=math.atan2(xx,zz);local elevation=math.atan2(y,math.sqrt(xx*xx+zz*zz))
 if math.abs(bearing)>math.rad(d.aim.yaw)or elevation<0 or elevation>math.rad(89)then return true end
 local aa=x*x+y*y+z*z;local bb=a*a+b*b+c*c
 return not(aa>1e-12 and bb>1e-12 and aa<math.huge and bb<math.huge and (x*a+y*b+z*c)/math.sqrt(aa*bb)>=math.cos(math.rad(4)))
end
