-- Model +X is the authored left side. Native mainDir X is inverted by rightdir.
-- Conservative outward/front sectors; no opposite-side or over-hull aim pose.
local M={Version=1,MaxYaw=math.rad(80),MaxPitch=math.rad(12)}
function M.Enabled(o)
 local function yes(v)return v==true or v==1 or v=='1'end
 return o and yes(o.prototype_mount_clearance_review)and yes(o.prototype_development_playtest)or false
end
function M.Side(source,n,assembly)
 if source=='leman_russ' then return n==3 and 1 or n==4 and -1 or nil end
 if source=='ork_kan_twin_shoota'or source=='ork_kan_twin_kmb'or source=='ork_kan_twin_rokkit'or source=='ork_dread_ranged_fourarm'then
  if assembly=='left'or assembly=='upper_l'or assembly=='lower_l'then return 1 end
  if assembly=='right'or assembly=='upper_r'or assembly=='lower_r'then return -1 end
 end
end
function M.Limits(source,n,assembly)
 if source=='leman_russ'then return{minYaw=math.rad(-4),maxYaw=math.rad(75),minPitch=math.rad(-12),maxPitch=math.rad(12),yawOnly=true}end
 local minYaw,maxYaw,minPitch,maxPitch=-4,12,-12,12
 if source=='ork_kan_twin_kmb'then maxYaw=assembly=='left'and 6 or 8
 elseif source=='ork_kan_twin_rokkit'then maxYaw=14;minPitch=assembly=='left'and -3 or -12;maxPitch=12
 elseif source=='ork_dread_ranged_fourarm'then maxYaw=assembly=='lower_l'and 6 or assembly=='lower_r'and 30 or 22
  if assembly=='lower_r'then minYaw=-2;minPitch=-3 elseif assembly=='upper_l'or assembly=='lower_l'then maxPitch=3 end
 end
 return{minYaw=math.rad(minYaw),maxYaw=math.rad(maxYaw),minPitch=math.rad(minPitch),maxPitch=math.rad(maxPitch)}
end
function M.Allows(side,h,p,limits)
 if not side then return true end
 if type(h)~='number'or type(p)~='number'or h~=h or p~=p or math.abs(h)==math.huge or math.abs(p)==math.huge then return false end
 h=(h+math.pi)%(2*math.pi)-math.pi
 limits=limits or{minYaw=0,maxYaw=M.MaxYaw,minPitch=-M.MaxPitch,maxPitch=M.MaxPitch}
 return side*h>=limits.minYaw-1e-9 and side*h<=limits.maxYaw+1e-9 and p>=limits.minPitch-1e-9 and p<=limits.maxPitch+1e-9
end
function M.NativeCone(side,limits)
 limits=limits or{minYaw=0,maxYaw=M.MaxYaw,minPitch=-M.MaxPitch,maxPitch=M.MaxPitch}
 local yaw=math.max(math.abs(limits.minYaw),math.abs(limits.maxYaw));local pitch=math.max(math.abs(limits.minPitch),math.abs(limits.maxPitch))
 -- GroundMoveType turns owner against weapon1.mainDir. Keep common forward
 -- heading so both opposed side assemblies retain practical forward overlap.
 return '0 0 1',2*math.acos(math.cos(yaw)*math.cos(pitch))*180/math.pi
end
function M.FireAllowed(S,id,n,side,limits)
 if not side then return true end
 if not S.GetUnitWeaponVectors or not S.GetUnitVectors then return false end
 local _,_,_,dx,dy,dz=S.GetUnitWeaponVectors(id,n)
 local front,up,right=S.GetUnitVectors(id)
 if not dx or not dy or not dz or not front or not up or not right then return false end
 local length=math.sqrt(dx*dx+dy*dy+dz*dz);if length<=1e-9 then return false end
 local function dot(v)return(dx*v[1]+dy*v[2]+dz*v[3])/length end
 -- Native nonmissile vectors expose wantedDir; missiles expose weaponDir.
 -- These are nominal aim vectors, not final muzzle-origin/randomized projectile vectors.
 -- BlockShot invokes this only at burst admission; native salvo dispatch bypasses it.
 local h=-math.atan2(dot(right),dot(front));local p=math.asin(math.max(-1,math.min(1,dot(up))))
 return M.Allows(side,h,p,limits)
end
return M
