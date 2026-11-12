local data=include("bar40k/animation_data.lua")("bar40k/dow_listening_post_t2_animation.lua")
include("bar40k/dow_native_pose_actor.lua")(data)
local oldAim,oldBlock=script.AimWeapon,script.BlockShot
function script.AimFromWeapon()return piece("aim_vert_main")end
function script.AimWeapon(n,h,p)
 if Spring.GetUnitIsActive and not Spring.GetUnitIsActive(unitID)then return false end
 return oldAim(n,((h or 0)+2*math.pi)%(2*math.pi)-math.pi,-(p or 0))
end
-- Source recoil starts only after an actual projectile Shot callback.
function script.FireWeapon()end
function script.BlockShot(n)
 if oldBlock(n)then return true end
 if Spring.GetUnitIsActive and not Spring.GetUnitIsActive(unitID)then return true end
 local x,y,z,dx,dy,dz=Spring.GetUnitPiecePosDir(unitID,piece("muzzle"))
 local _,_,_,tx,ty,tz=Spring.GetUnitWeaponVectors(unitID,n)
 local a=dx*dx+dy*dy+dz*dz;local b=tx*tx+ty*ty+tz*tz
 return a<1e-10 or b<1e-10 or(dx*tx+dy*ty+dz*tz)/math.sqrt(a*b)<math.cos(math.rad(5))
end
