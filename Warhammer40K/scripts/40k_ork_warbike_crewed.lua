-- Native orders/damage own simulation; source wheel radius owns visible travel.
GG.Recoil40KWarbikeArtCache=GG.Recoil40KWarbikeArtCache or{}
local cache=GG.Recoil40KWarbikeArtCache
if not cache.facts then cache.facts=VFS.Include('40k_configs/ork_warbike_crewed_facts.lua')end
local facts=cache.facts;local m=facts.mounts
local wheels={piece(m.wheel_front),piece(m.wheel_back)}
local radii={facts.wheelRadii[m.wheel_front],facts.wheelRadii[m.wheel_back]}
local guns={piece(m.gun_left),piece(m.gun_right)}
local muzzles={piece(m.muzzle_left),piece(m.muzzle_right)}
local body=piece(m.body);local moving=false;local angles={0,0}
local function wrap(v)return(v+math.pi)%(2*math.pi)-math.pi end
local function motion()
 while true do
  local vx,_,vz=Spring.GetUnitVelocity(unitID)
  local h=(Spring.GetUnitHeading(unitID)or 0)*2*math.pi/65536
  local forward=(vx or 0)*math.sin(h)+(vz or 0)*math.cos(h)
  if moving and math.abs(forward)>.0001 then
   for i,wheel in ipairs(wheels)do
    local delta=forward/radii[i];angles[i]=wrap(angles[i]+delta)
    Turn(wheel,x_axis,angles[i],math.max(.001,math.abs(delta)*30))
   end
  end
  Sleep(33)
 end
end
function script.Create()StartThread(motion)end
function script.StartMoving()moving=true end
function script.StopMoving()moving=false end
function script.AimFromWeapon(n)return guns[n]or body end
function script.QueryWeapon(n)return muzzles[n]end
function script.AimWeapon(n,heading,pitch)
 if(n~=1 and n~=2)or math.abs(wrap(heading))>math.rad(15)or math.abs(pitch)>math.rad(16)then return false end
 Signal(2^n);SetSignalMask(2^n)
 Turn(guns[n],y_axis,heading,2.5);Turn(guns[n],x_axis,-pitch,2)
 WaitForTurn(guns[n],y_axis);WaitForTurn(guns[n],x_axis)
 return true
end
function script.Shot(n)if muzzles[n]then EmitSfx(muzzles[n],1024)end end
function script.Killed()
 local _,_,_,_,progress=Spring.GetUnitHealth(unitID)
 return type(progress)=='number'and progress>=1 and 1 or 0
end
