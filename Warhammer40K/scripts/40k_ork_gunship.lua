-- Approved Gunship: native MG volleys and alternating recessed cannons.
-- Native Dragon movement, target selection, projectiles and damage own play.
local cp=UnitDefs[unitDefID].customParams or{}
local A=VFS.Include('40k_configs/ork_gunship_aim.lua')
local H=VFS.Include('40k_configs/ork_gunship_hover.lua')
local US=Spring.UnitScript
-- VFS.Include modules do not inherit this unit's LUS wrapper environment.
-- Pass only this instance's actual wrappers and identity to the hover helper.
local hoverContext={unitID=unitID,y_axis=y_axis,Signal=Signal,SetSignalMask=SetSignalMask,Move=Move,Sleep=Sleep,StartThread=StartThread,
 Witness=function(row)local w=GG and GG.Recoil40KStompaWeaponWitness;if w and w.HumanHover then w.HumanHover(unitID,row)end end}
assert(US and US.GetPieceRotation,'Native actual-piece rotation readback required')
assert(tonumber(cp.prototype40k_gunship_loadout_revision)==4 and cp.prototype40k_gunship_loadout_policy=='gunship_approved_kan_turrets_no_bomb_v5','Approved simultaneous Gunship loadout required')
assert(tonumber(cp.prototype40k_gunship_mount_count)==7,'Seven native turret volley owners required')
local groups=assert(A.Build(cp),'Measured Gunship aiming envelope required')
local mounts={}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function number(key)return assert(tonumber(cp['prototype40k_'..key]),'Missing measured Gunship fact '..key)end
for n,g in ipairs(groups)do
 g.kind=g.name=='nose'and'nose'or(g.name:find('gantry',1,true)and'shoota'or'cannon')
 g.yaw=piece(g.name..'_yaw');g.axis=piece(g.axis)
 local m={group=g,signal=2^(n-1),cursor=1,muzzles={},shoulders={}}
 for i,side in ipairs(g.name=='nose'and{''}or{'left','right'})do
  local stem=g.name..(side==''and''or'_'..side)
  local s={pitch=piece(stem..'_pitch'),recoilSignal=2^(n*2+i+8)}
  if g.name~='nose'or tonumber(cp.prototype40k_nose_recoil_distance)then s.recoil=piece(stem..'_recoil');s.distance=number(g.name..'_recoil_distance')end
  m.shoulders[#m.shoulders+1]=s
  for j=1,g.kind=='shoota'and 2 or 1 do
   m.muzzles[#m.muzzles+1]={piece=piece(stem..(g.kind=='shoota'and('_muzzle_'..j)or'_muzzle')),shoulder=s}
  end
 end
 mounts[n]=m
end
local function wanted(n)
 local _,_,_,x,y,z=Spring.GetUnitWeaponVectors(unitID,n)
 if not(finite(x)and finite(y)and finite(z))then return nil end
 local length=math.sqrt(x*x+y*y+z*z);if length<.999 or length>1.001 then return nil end
 local front,up,right=Spring.GetUnitVectors(unitID)
 local _,actualYaw=US.GetPieceRotation(mounts[n].group.yaw)
 return A.Angles(x,y,z,front,up,right,actualYaw)
end
local function resolve(n)
 local m=mounts[n];if not m then return nil end
 local yaw,pitch=wanted(n)
 if not yaw then return nil,nil,'invalid-native-direction' end
 if not A.Allowed(m.group,yaw,pitch)then return nil,nil,'outside-hull-safe-arc',yaw,yaw,pitch end
 return yaw,pitch,nil,yaw,yaw,pitch
end
local function witness(n,stage,result,reason,yaw,pitch,dot,ownYaw,wantedYaw,wantedPitch)
 local fn=GG.Recoil40KStompaWeaponWitness and GG.Recoil40KStompaWeaponWitness.HumanAim
 if not fn then return end
 local m=mounts[n]
 fn(unitID,n,m and m.heading,m and m.elevation,stage,result,reason,
  {resolvedYaw=yaw,resolvedPitch=pitch,dot=dot,ownYaw=ownYaw,wantedYaw=wantedYaw,wantedPitch=wantedPitch})
end
local function pose(m,barrel)
 local _,_,_,x,y,z=Spring.GetUnitPiecePosDir(unitID,barrel.piece)
 if not(finite(x)and finite(y)and finite(z))then return nil end
 local length=math.sqrt(x*x+y*y+z*z);if length<.999 or length>1.001 then return nil end
 local front,up,right=Spring.GetUnitVectors(unitID)
 local yaw,pitch=A.Angles(x,y,z,front,up,right,m.lastYaw or m.group.center)
 return yaw,pitch,x,y,z,length
end
local function holdBurst(n)
 if mounts[n].group.kind=='shoota'then
  -- Pinned Update runs UpdateAim BEFORE UpdateSalvo. nextSalvo is a
  -- supported native state field: hold the next real volley for one frame
  -- while ANY physical barrel is unsafe, without creating shots or refunds.
  local deadline=Spring.GetUnitWeaponState(unitID,n,'nextSalvo')
  assert(finite(deadline),'Native salvo deadline readback required')
  Spring.SetUnitWeaponState(unitID,n,'nextSalvo',math.max(deadline,Spring.GetGameFrame()+1))
 end
end
function script.Create()
 for n,m in ipairs(mounts)do
  Turn(m.group.yaw,y_axis,m.group.center)
  for _,s in ipairs(m.shoulders)do Turn(s.pitch,x_axis,-math.max(0,A.PitchFloor(m.group,m.group.center)));if s.recoil then Move(s.recoil,z_axis,0)end end
  Spring.SetUnitWeaponState(unitID,n,'reaimTime',1)
 end
 H.Start(piece('root'),hoverContext)
end
function script.AimFromWeapon(n)return mounts[n]and mounts[n].group.axis end
function script.QueryWeapon(n)
 local m=mounts[n];if not m then return nil end;local muzzle=m.muzzles[m.cursor].piece
 if GG.Recoil40KStompaWeaponWitness then GG.Recoil40KStompaWeaponWitness.Query(unitID,n,muzzle)end
 return muzzle
end
function script.AimWeapon(n,heading,elevation)
 local m=mounts[n];if not m then return false end
 Signal(m.signal);SetSignalMask(m.signal);m.ready=false;m.heading=heading;m.elevation=elevation
 if not(finite(heading)and finite(elevation))then holdBurst(n);witness(n,'aim',false,'invalid-callback');return false end
 local yaw,pitch,reason,ownYaw,wantedYaw,wantedPitch=resolve(n)
 if not yaw then holdBurst(n);witness(n,'aim',false,reason,nil,nil,nil,ownYaw,wantedYaw,wantedPitch);return false end
 local _,actualYaw=US.GetPieceRotation(m.group.yaw)
 if not finite(actualYaw)then holdBurst(n);return false end
 actualYaw=A.Wrap(actualYaw)
 local actualPitch,highestPitch=math.pi*.5,-math.pi*.5
 for _,s in ipairs(m.shoulders)do local rx=US.GetPieceRotation(s.pitch);if not finite(rx)then holdBurst(n);return false end;local p=-A.Wrap(rx);actualPitch=math.min(actualPitch,p);highestPitch=math.max(highestPitch,p)end
 local aimPitch=pitch
 if m.group.floors or m.group.ceilings then
  -- Raise clear of every obstructed sector crossed by the shortest real yaw
  -- path BEFORE rotating; lower only after arrival. A target above the hull
  -- can use full azimuth without sweeping lowered barrels through the ship.
  local floor,ceiling=A.TraverseEnvelope(m.group,actualYaw,yaw)
  if math.abs(A.Wrap(yaw-actualYaw))>A.angleEpsilon then
   if not floor then
    -- A disconnected safe sector is not permission to sweep through the
    -- hull. Native shortest-path Turn has no legal constant-pitch passage.
    Turn(m.group.yaw,y_axis,actualYaw,math.rad(m.group.kind=='shoota'and 120 or 45))
    holdBurst(n);witness(n,'aim',false,'blocked-traverse-envelope',yaw,pitch);return false
   end
   aimPitch=math.max(floor,math.min(ceiling,pitch))
   if actualPitch<floor-A.angleEpsilon or highestPitch>ceiling+A.angleEpsilon then
    -- Cancel a previous native yaw Turn while raising for a NEW target.
    -- Otherwise that still-running animation could cross an obstructed sector.
    Turn(m.group.yaw,y_axis,actualYaw,math.rad(m.group.kind=='shoota'and 120 or 45))
    for _,s in ipairs(m.shoulders)do Turn(s.pitch,x_axis,-aimPitch,math.rad(m.group.kind=='shoota'and 90 or 35))end
    holdBurst(n);witness(n,'aim',false,'adjusting-for-traverse',yaw,aimPitch);return false
   end
  end
 end
 m.lastYaw=yaw
 Turn(m.group.yaw,y_axis,yaw,math.rad(m.group.kind=='shoota'and 120 or 45))
 for _,s in ipairs(m.shoulders)do Turn(s.pitch,x_axis,-aimPitch,math.rad(m.group.kind=='shoota'and 90 or 35))end
 m.ready=true
 if m.group.kind=='shoota'and script.BlockShot(n)then
  -- BlockShot already emitted its precise physical refusal. Preserve that
  -- read-only witness instead of overwriting it with a generic tracking pass.
  holdBurst(n);return true
 end
 witness(n,'aim',true,'tracking',yaw,pitch,nil,ownYaw,wantedYaw,wantedPitch);return true
end
function script.BlockShot(n)
 local m=mounts[n];if not m then return true end
 if not m.ready then witness(n,'block',false,'not-ready');return true end
 local yaw,pitch,reason,ownYaw,wantedYaw,wantedPitch=resolve(n)
 if not yaw then witness(n,'block',false,reason,nil,nil,nil,ownYaw,wantedYaw,wantedPitch);return true end
 local front,up,right=Spring.GetUnitVectors(unitID)
 local tx,ty,tz=A.Direction(yaw,pitch,front,up,right);local minDot=1
 -- CWeapon calls BlockShot before each native burst. Check EVERY real barrel,
 -- conservatively including both alternating cannons, not only the previous
 -- Query muzzle. No projectile may launch while its assembly is still turning.
 for _,barrel in ipairs(m.muzzles)do
  local ay,ap,x,y,z,length=pose(m,barrel)
  if not ay then witness(n,'block',false,'invalid-muzzle-direction',yaw,pitch);return true end
  if not A.Allowed(m.group,ay,ap)then witness(n,'block',false,'physical-barrel-outside-arc',yaw,pitch);return true end
  local dot=(tx*x+ty*y+tz*z)/length;minDot=math.min(minDot,dot)
  if dot<math.cos(A.trackingTolerance)then witness(n,'block',false,'muzzle-misaligned',yaw,pitch,dot,ownYaw,wantedYaw,wantedPitch);return true end
 end
 witness(n,'block',true,'aligned',yaw,pitch,minDot,ownYaw,wantedYaw,wantedPitch);return false
end
local function recoil(s)
 Signal(s.recoilSignal);SetSignalMask(s.recoilSignal)
 Move(s.recoil,z_axis,-s.distance,s.distance*12);WaitForMove(s.recoil,z_axis);Move(s.recoil,z_axis,0,s.distance*3)
end
function script.Shot(n)
 local m=mounts[n];if not m then return end
 -- Exact pinned native loop: Shot -> QueryWeapon -> Fire for EACH projectile
 -- in the SAME simulation frame. Four MG muzzles cycle within each salvo;
 -- two cannon muzzles alternate across successive native single shots.
 -- Each shoulder receives its own recoil and each barrel its own muzzle
 -- flash; the engine alone creates/damages with projectiles.
 if m.hasShot then m.cursor=m.cursor%#m.muzzles+1 else m.hasShot=true end
 local barrel=m.muzzles[m.cursor]
 if m.group.kind=='shoota'and m.cursor==1 and m.burstSoundPending then
  m.burstSoundPending=false
  if GG.Recoil40KGunshipSalvoSound then GG.Recoil40KGunshipSalvoSound(unitID,n,barrel.piece,Spring.GetGameFrame())end
 end
 if GG.Recoil40KStompaWeaponWitness then GG.Recoil40KStompaWeaponWitness.Shot(unitID,n,Spring.GetGameFrame())end
 EmitSfx(barrel.piece,m.group.kind=='nose'and 1026 or m.group.kind=='shoota'and 1024 or 1025)
 if barrel.shoulder.recoil then StartThread(recoil,barrel.shoulder)end
end
function script.FireWeapon(n)
 -- Native UpdateFire calls this once per accepted burst, before UpdateSalvo.
 -- Consume on its first real projectile, not on a free-running audio timer.
 local m=mounts[n];if m and m.group.kind=='shoota'then m.burstSoundPending=true end
end
function script.Killed()H.Stop(piece('root'),hoverContext);return 1 end
