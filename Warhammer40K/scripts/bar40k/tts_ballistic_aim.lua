-- Presentation adapter only: the existing walker actor remains the sole pose
-- writer. Native weapons still own target acquisition, ballistics and damage.
return function(data,boreDegrees)
 local aim,block,query=script.AimWeapon,script.BlockShot,script.QueryWeapon
 local function finite(x)return type(x)=='number'and x==x and math.abs(x)<math.huge end
 local function cannon(n)
  local unit=UnitDefs[unitDefID];local slot=unit and unit.weapons[n];local wd=slot and WeaponDefs[slot.weaponDef]
  return wd and wd.type=='Cannon'
 end
 local function launch(n)
  local _,_,_,dx,dy,dz=Spring.GetUnitWeaponVectors(unitID,n)
  if not(finite(dx)and finite(dy)and finite(dz))then return end
  local length=math.sqrt(dx*dx+dy*dy+dz*dz);if length<1e-9 then return end
  dx,dy,dz=dx/length,dy/length,dz/length
  -- Pinned Cannon.h overrides UpdateWantedDir with GetWantedDir, and the Lua
  -- getter exposes that ALREADY BALLISTIC vector. Consume it exactly once:
  -- never reconstruct a target or solve ballistics again in this adapter.
  local f,up,right=Spring.GetUnitVectors(unitID)
  if not(f and up and right)then return end
  -- Native rightdir is NEGATIVE model X. Project the world launch vector into
  -- native piece axes, including native slope/airframe orientation.
  local x=-(dx*right[1]+dy*right[2]+dz*right[3]);local y=dx*up[1]+dy*up[2]+dz*up[3];local z=dx*f[1]+dy*f[2]+dz*f[3]
  return math.atan2(x,z),math.atan2(y,math.sqrt(x*x+z*z)),dx,dy,dz
 end
 function script.AimWeapon(n,h,p)
  if data.weapons[n].shield then return aim(n,h,p)end
  -- Missile/Torpedo getters expose current weaponDir instead of wantedDir;
  -- retain native incoming aim angles for those and other non-Cannon guns.
  if not cannon(n)then return aim(n,h,p)end
  local heading,pitch=launch(n)
  if not heading then return false end
  return aim(n,heading,pitch)
 end
 function script.BlockShot(n)
  if data.weapons[n].shield then return block(n)end
  if block(n)then return true end
  local _,_,tx,ty,tz=launch(n);if not tx then return true end
  local _,_,_,x,y,z=Spring.GetUnitPiecePosDir(unitID,query(n))
  if not(finite(x)and finite(y)and finite(z))then return true end
  local a=x*x+y*y+z*z;local b=tx*tx+ty*ty+tz*tz
  return not(a>1e-12 and b>1e-12 and(x*tx+y*ty+z*tz)/math.sqrt(a*b)>=math.cos(math.rad(boreDegrees or 6)))
 end
end
