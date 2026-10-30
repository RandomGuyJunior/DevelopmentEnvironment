local shared=include("bar40k/animation_data.lua")("bar40k/bar40k_knight_lancer_animation.lua")
local data=setmetatable({clips={}}, {__index=shared})
for k,v in pairs(shared.clips)do data.clips[k]=v end
include("bar40k/knight_repaired_actor.lua")(data)
local nextMuzzle={};local oldQuery,oldShot=script.QueryWeapon,script.Shot
function script.QueryWeapon(n)local list=data.weapons[n].muzzles;return piece(list[nextMuzzle[n]or 1])end
function script.Shot(n)oldShot(n);nextMuzzle[n]=(nextMuzzle[n]or 1)%#data.weapons[n].muzzles+1 end
local oldAim,oldBlock=script.AimWeapon,script.BlockShot
local function rangedTooClose()
  local kind,_,target=Spring.GetUnitWeaponTarget(unitID,1)
  local x,_,z=Spring.GetUnitPosition(unitID)
  local tx,tz
  if kind==1 and target and Spring.ValidUnitID(target)and not Spring.GetUnitIsDead(target)then
   local y;tx,y,tz=Spring.GetUnitPosition(target)
  elseif kind==2 and type(target)=='table'then tx,tz=target[1],target[3]end
  local minimum=WeaponDefs[UnitDefs[unitDefID].weapons[2].weaponDef].range
  if tx and (tx-x)^2+(tz-z)^2<=minimum*minimum then return true end
  return false
end
local ranged=data.clips.fire;local pending,exclusive=nil,0
function script.AimWeapon(n,h,p)if n==1 and rangedTooClose()then return false end;return oldAim(n==2 and 1 or n,h,p)end
local oldFire=script.FireWeapon
function script.FireWeapon(n)if n~=2 then oldFire(n)end end
function script.BlockShot(n)
 if n==3 then return false end
 local frame=Spring.GetGameFrame()
 if n==1 then
  -- Minimum ranged distance is enforced for aiming and each actual shot.
  -- Ground attacks cannot bypass it, and the melee slot has its own target.
  if rangedTooClose()then return true end
  if frame<exclusive then return true end;data.clips.fire=ranged;return oldBlock(1)
 end
 if not pending then
  pending=frame;exclusive=frame+46;script.BeginSourceAction(data.clips.melee,46)
  return true
 end
 if frame-pending<18 then return true end
 if frame-pending>25 then pending=nil;return true end
 local kind,_,target=Spring.GetUnitWeaponTarget(unitID,2)
 if kind~=1 or not target or not Spring.ValidUnitID(target)or Spring.GetUnitIsDead(target)then pending=nil;return true end
 local x,y,z=Spring.GetUnitPiecePosDir(unitID,piece('muzzle_lance'))
 local tx,ty,tz,mx,my,mz=Spring.GetUnitPosition(target,true)
 tx,ty,tz=mx or tx,my or ty,mz or tz
 if not(x and tx)then return true end
 local radius=Spring.GetUnitRadius(target)or 0
 return (x-tx)^2+(y-ty)^2+(z-tz)^2>(radius+35)^2
end
local baseShot=script.Shot
function script.Shot(n)baseShot(n);if n==2 then pending=nil end end

local nativeFacing=include("bar40k/knight_primary_facing.lua")()
local originalCreate=script.Create
function script.Create()originalCreate();StartThread(nativeFacing.Run)end

include("bar40k/knight_ion_shield_bind.lua")()
