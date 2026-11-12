-- Optional pure pose/gate extension. The existing squad actor remains the sole
-- piece writer; native BAR still owns commands, movement, ballistics and damage.
return function(cfg,aimCenter)
 local rad=math.rad
 local function delta(a,b)return(b-a+math.pi)%(2*math.pi)-math.pi end
 local function approach(a,b,step)return a+math.max(-step,math.min(step,delta(a,b)))end
 local function rotation(row)
  local x,y,z=row[4],row[5],row[6];local cx,sx,cy,sy,cz,sz=math.cos(x),math.sin(x),math.cos(y),math.sin(y),math.cos(z),math.sin(z)
  return{cy*cz+sy*sx*sz,-cy*sz+sy*sx*cz,sy*cx,cx*sz,cx*cz,-sx,-sy*cz+cy*sx*sz,sy*sz+cy*sx*cz,cy*cx}
 end
 local function point(r,p)return{r[1]*p[1]+r[2]*p[2]+r[3]*p[3],r[4]*p[1]+r[5]*p[2]+r[6]*p[3],r[7]*p[1]+r[8]*p[2]+r[9]*p[3]}end
 local function mul(a,b)local r={};for i=0,2 do for j=1,3 do r[i*3+j]=a[i*3+1]*b[j]+a[i*3+2]*b[3+j]+a[i*3+3]*b[6+j]end end;return r end
 local function transpose(r)return{r[1],r[4],r[7],r[2],r[5],r[8],r[3],r[6],r[9]}end
 local function euler(r)
  local x=math.asin(math.max(-1,math.min(1,-r[6])))
  if math.abs(math.cos(x))<1e-6 then return x,math.atan2(-r[7],r[1]),0 end
  return x,math.atan2(r[3],r[9]),math.atan2(r[4],r[5])
 end
 local function wanted(m)
  local slot=cfg.weaponSlot or 1
  local _,_,_,x,y,z=Spring.GetUnitWeaponVectors(unitID,slot)
  if not(x and y and z)then return end
  local norm=x*x+y*y+z*z;if not(norm>1e-12 and norm<math.huge)then return end
  -- Pinned CCannon::UpdateWantedDir already supplies GetWantedDir, i.e.
  -- the ballistic launch vector. LuaSyncedRead exposes that wantedDir here.
  -- Consume it once: another target/gravity solve would aim above the shot.
  local c,s=math.cos(m.yaw),math.sin(m.yaw);local xx,zz=c*x-s*z,s*x+c*z
  local h=math.atan2(xx,zz);local p=math.atan2(y,math.sqrt(xx*xx+zz*zz))
  return h,p,math.abs(h)<=rad(cfg.maxYaw)and p>=rad(cfg.minPitch)and p<=rad(cfg.maxPitch),x,y,z
 end
 local function apply(m,row,seconds,active)
  local current=rotation(row[cfg.muzzleRow]);local originalYaw=math.atan2(current[3],current[9]);local originalPitch=math.asin(math.max(-1,math.min(1,current[6])))
  local h,p,arc
  if active then h,p,arc=wanted(m)end
  m.artilleryInArc=active and arc or false
  if not h then h,p=originalYaw,originalPitch end
  h=math.max(-rad(cfg.maxYaw),math.min(rad(cfg.maxYaw),h));p=math.max(rad(cfg.minPitch),math.min(rad(cfg.maxPitch),p))
  m.artilleryYaw=approach(m.artilleryYaw or originalYaw,h,rad(cfg.yawRate)*seconds)
  m.artilleryPitch=approach(m.artilleryPitch or originalPitch,p,rad(cfg.pitchRate)*seconds)
  local target=rotation({0,0,0,-m.artilleryPitch,m.artilleryYaw,row[cfg.muzzleRow][6]});local transform=mul(target,transpose(current));local base=row[cfg.pivotRow];local pivot=point(rotation(base),cfg.pivot);for k=1,3 do pivot[k]=pivot[k]+base[k]end
  local out={};for i,v in ipairs(row)do out[i]=v end
  for _,i in ipairs(cfg.indices)do
   local old=row[i];local shifted=point(transform,{old[1]-pivot[1],old[2]-pivot[2],old[3]-pivot[3]});local r={shifted[1]+pivot[1],shifted[2]+pivot[2],shifted[3]+pivot[3]};r[4],r[5],r[6]=euler(mul(transform,rotation(old)));out[i]=r
  end
  return out
 end
 local function aligned(m)
  local h,p,arc,a,b,c=wanted(m);if not arc then return false end
  local _,_,_,x,y,z=Spring.GetUnitPiecePosDir(unitID,m.muzzle)
  if not(x and y and z)then return false end
  local aa=x*x+y*y+z*z;local bb=a*a+b*b+c*c
  return aa>1e-12 and bb>1e-12 and (x*a+y*b+z*c)/math.sqrt(aa*bb)>=math.cos(rad(cfg.boreDegrees))
 end
 local function ready(m)return m.artilleryInArc and aligned(m)or false end
 return{Apply=apply,Ready=ready,Aligned=aligned,Angles=wanted}
end
