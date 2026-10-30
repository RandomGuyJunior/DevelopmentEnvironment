local shared=include("bar40k/animation_data.lua")("bar40k/bar40k_dow_dakka_stompa_animation.lua")
local data={};for k,v in pairs(shared)do data[k]=v end
-- Calibrated from original sole vertices during planted/backward contact.
-- Shared actor already scales phase by actual native velocity, including stops.
-- Only playback rate changes; native unit speed and source joint poses do not.
data.walkspeed=69.58405878506522
data.weaponMounts={};for n,cfg in pairs(shared.weaponMounts)do
 data.weaponMounts[n]={};for k,v in pairs(cfg)do data.weaponMounts[n][k]=v end
end
-- The belly's existing rigid gun pivot can yaw as well as elevate. Keep this
-- override local: every other actor continues using the unmodified shared bank.
data.weaponMounts[2].minPitch=-60
data.weaponMounts[2].maxPitch=45
data.weaponMounts[2].maxYaw=15
data.weaponMounts[2].yaw="belly_gun"
-- Permit the Lifta-Droppa elbow to depress toward nearby ground targets.
-- Keep the source hierarchy, upper limit and shared actor unchanged.
data.weaponMounts[3].minPitch=-60
-- Eye weapon removed; retain its mesh but no aiming or firing mount.
data.weaponMounts[4]=nil
-- Native slot1 drives chassis heading; retain the original logical scheduler IDs.
data.weaponMounts[1],data.weaponMounts[2]=data.weaponMounts[2],data.weaponMounts[1]
include("bar40k/dow_native_pose_actor.lua")(data)
local windows=include("bar40k/stompa_weapon_windows.lua")()
local oldAim,oldBlock,oldFire,oldCreate=script.AimWeapon,script.BlockShot,script.FireWeapon,script.Create
local bellyPitch,lastBellyAim=0,-1000
function script.AimWeapon(n,heading,pitch)
 if n==1 then bellyPitch=pitch or 0;lastBellyAim=Spring.GetGameFrame() end
 return oldAim(n,heading,pitch)
end
local function chargeVisual()
 while true do
  if windows.Charging() then
   local frame=Spring.GetGameFrame()
   local kind,_,target=Spring.GetUnitWeaponTarget(unitID,1)
   if windows.Expired(frame) or (kind~=1 and kind~=2) or (kind==1 and (not Spring.ValidUnitID(target) or Spring.GetUnitIsDead(target))) or frame-lastBellyAim>15 or oldBlock(1) then
    windows.Cancel(frame)
   else EmitSfx(script.QueryWeapon(1),1025) end
  end
  Sleep(100)
 end
end
local facing=include("bar40k/stompa_belly_facing.lua")()
function script.Create()oldCreate();StartThread(chargeVisual);StartThread(facing.Run)end
function script.BlockShot(n,...)
 if oldBlock(n,...) then return true end
 return windows.Block(n==1 and 2 or n==2 and 1 or n,Spring.GetGameFrame())
end
local function bellyWindow()
 local kind,_,target=Spring.GetUnitWeaponTarget(unitID,1)
 local tx,ty,tz
 if kind==1 then tx,ty,tz=Spring.GetUnitPosition(target)
 elseif kind==2 and type(target)=="table" then tx,ty,tz=target[1],target[2],target[3] end
 local x,y,z=Spring.GetUnitPiecePosDir(unitID,script.QueryWeapon(1))
 if not tx or not x then return math.ceil(2.6*Game.gameSpeed) end
 local distance=math.sqrt((tx-x)^2+(tz-z)^2)
 local flight=distance/(500*math.max(.25,math.cos(bellyPitch)))
 return math.ceil(math.min(3,flight+.35)*Game.gameSpeed)
end
function script.FireWeapon(n,...)
 oldFire(n,...)
 windows.Fired(n==1 and 2 or n==2 and 1 or n,Spring.GetGameFrame(),n==1 and bellyWindow() or math.ceil(.75*Game.gameSpeed))
end
