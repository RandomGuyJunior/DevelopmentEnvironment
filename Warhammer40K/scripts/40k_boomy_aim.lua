-- Native low-arc solver remains authoritative. Refuse unsafe/stale aim; never
-- show45 degrees while emitting a projectile in a different direction.
local M={Policy='low_arc_absolute_bind20_max45_v1',RestElevation=math.rad(20),MaximumElevation=math.rad(45),MinimumElevation=math.rad(-20)}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function valid3(v)return type(v)=='table'and finite(v[1])and finite(v[2])and finite(v[3])end
local function rotate(x,y,z,rx,ry,rz)
 local sx,cx,sy,cy,sz,cz=math.sin(rx),math.cos(rx),math.sin(ry),math.cos(ry),math.sin(rz),math.cos(rz)
 local a,b=cz*x-sz*y,sz*x+cz*y
 local c,d=cx*b-sx*z,sx*b+cx*z
 return cy*a+sy*d,c,-sy*a+cy*d
end
function M.New(source,cp,lookup,xaxis,yaxis)
 assert(source=='ork_boomy_platform'and cp.prototype40k_ork_v13_recipe=='ORK-ART-1'
  and cp.source_boomy_aim_policy==M.Policy,'Foreign Boomy aim policy')
 local yaw=assert(lookup('bone_main_aim_horz'),'Boomy yaw missing')
 local pitch=assert(lookup('bone_main_aim_vert'),'Boomy pitch missing')
 local barrel=assert(lookup('basilisk_barrel'),'Boomy barrel missing')
 local chain={}
 for _,name in ipairs({'marker_main_barrel','basilisk_barrel_tip','basilisk_barrel_mid','basilisk_barrel','bone_main_aim_vert','plattform','bone_main_aim_horz','unit_aim'})do chain[#chain+1]=assert(lookup(name),'Missing actual Boomy aim ancestry '..name)end
 local A={Barrel=barrel,BarrelRestX=-M.RestElevation}
 function A.AbsoluteAxis(piece,axis)
  return(piece==yaw and axis==yaxis)or((piece==pitch or piece==barrel)and axis==xaxis)
 end
 function A.Resolve(slot,heading,elevation)
  if slot~=1 or not finite(heading)or not finite(elevation)
   or elevation<M.MinimumElevation-1e-10 or elevation>M.MaximumElevation+1e-10 then return nil end
  return(heading+math.pi)%(2*math.pi)-math.pi,M.RestElevation-elevation
 end
 function A.BlockAllowed(S,U,id,slot)
  if type(S)~='table'or type(U)~='table'then return false end
  if slot~=1 or not S.GetUnitWeaponVectors or not S.GetUnitVectors or not S.GetUnitWeaponTarget or not U.GetPieceRotation then return false end
  local kind=S.GetUnitWeaponTarget(id,slot)
  if kind~=1 and kind~=2 then return false end
  local px,py,pz,x,y,z=S.GetUnitWeaponVectors(id,slot)
  if not(finite(px)and finite(py)and finite(pz)and finite(x)and finite(y)and finite(z))then return false end
  local front,up,right=S.GetUnitVectors(id)
  if not(valid3(front)and valid3(up)and valid3(right))then return false end
  local length=math.sqrt(x*x+y*y+z*z);if length<1e-9 then return false end
  local function dot(v)return(x*v[1]+y*v[2]+z*v[3])/length end
  -- Pinned native model matrix columns are(-rightdir,updir,frontdir).
  local tx,ty,tz=-dot(right),dot(up),dot(front)
  local elevation=math.asin(math.max(-1,math.min(1,ty)))
  if A.Resolve(slot,0,elevation)==nil then return false end
  -- Actual native piece rotations include every descendant fire/recovery
  -- channel. This also refuses a missing readback or source overwrite.
  local gx,gy,gz=0,0,1
  for _,piece in ipairs(chain)do
   local rx,ry,rz=U.GetPieceRotation(piece)
   if not(finite(rx)and finite(ry)and finite(rz))then return false end
   gx,gy,gz=rotate(gx,gy,gz,rx,ry,rz)
  end
  local actual=math.asin(math.max(-1,math.min(1,gy)))
  -- Float32 source rotations produce tiny boundary residues. This tolerance
  -- is0.000057 degrees, not permission for a visibly higher shot.
  if actual<M.MinimumElevation-1e-6 or actual>M.MaximumElevation+1e-6 then return false end
  return gx*tx+gy*ty+gz*tz>=math.cos(math.rad(.5))
 end
 return A
end
return M
