local data=include("bar40k/animation_data.lua")("bar40k/bar40k_gladius_mek_gun_animation.lua")
include("bar40k/sanctus_roster_actor.lua")(data)
-- The hidden legacy single retains its native heading-reference slot. Convert
-- Cannon direct wantedDir to the ballistic bore angle for the existing actor.
local muzzle=piece('muzzle')
local aim=include('bar40k/artillery_squad_aim.lua')({weaponSlot=2,minPitch=0,maxPitch=75,maxYaw=5,boreDegrees=4},muzzle)
local originalAim,originalBlock=script.AimWeapon,script.BlockShot
local function state()return{yaw=Spring.GetUnitHeading(unitID)*2*math.pi/65536,muzzle=muzzle}end
function script.AimWeapon(n,h,p)
 if n~=1 then return originalAim(n,h,p)end
 local yaw,pitch,allowed=aim.Angles(state())
 if not allowed then return false end
 return originalAim(n,yaw,pitch)
end
function script.BlockShot(n)
 if n==1 and not aim.Aligned(state())then return true end
 return originalBlock(n)
end
include("bar40k/first_weapon_heading.lua")()
