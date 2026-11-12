local shared=include("bar40k/animation_data.lua")("bar40k/bar40k_knight_lancer_animation.lua")
local data=setmetatable({clips={}}, {__index=shared})
for k,v in pairs(shared.clips)do data.clips[k]=v end
-- Ranged lance shots use the finite arm aim only; explicit melee actions
-- still call BeginSourceAction and retain the original whole-body strike.
data.independentWeaponActions=true
include("bar40k/knight_repaired_actor.lua")(data)
local nextMuzzle={};local oldQuery,oldShot=script.QueryWeapon,script.Shot
function script.QueryWeapon(n)if n==2 then return piece('pivot_lance')end;local list=data.weapons[n].muzzles;return piece(list[nextMuzzle[n]or 1])end
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
local contact=include('bar40k/knight_lancer_contact.lua')(data)
local ranged=data.clips.fire;local pending,exclusive,nextAttempt=nil,0,0
local oldAimFrom=script.AimFromWeapon
-- A moving spear tip is not a stable native range/aim origin during a thrust.
function script.AimFromWeapon(n)if n==2 then return piece('ion_shield_center')end;return oldAimFrom(n)end
function script.AimWeapon(n,h,p)
 if n==2 then return contact.Target()~=nil and math.abs(h or 0)<=math.rad(70)end
 if n==1 and rangedTooClose()then return false end;return oldAim(n,h,p)
end
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
 local target=contact.Target()
 if pending and target~=pending.target then pending=nil;return true end
 if not target then return true end
 local x,y,z=Spring.GetUnitPiecePosDir(unitID,piece('muzzle_lance'))
 if not x then return true end
 local tip={x,y,z}
 if not pending then
  if frame<nextAttempt then return true end
  local clip=contact.Prepare(target);if not clip then return true end
  pending={frame=frame,target=target,lastTip=tip};exclusive=frame+46;nextAttempt=exclusive
  script.BeginSourceAction(clip,46)
  return true
 end
 local age=frame-pending.frame;local previous=pending.lastTip;pending.lastTip=tip
 if age<18 then return true end
 if age>25 then pending=nil;return true end
 -- Check the actual tip sweep against the target collision bounds, with only
 -- three units for the blade thickness. The native invisible beam still owns
 -- collision, armour, damage, experience and its existing three-second reload.
 return not contact.Touches(target,previous,tip)
end
local baseShot=script.Shot
function script.Shot(n)baseShot(n);if n==2 then pending=nil end end

local nativeFacing=include("bar40k/knight_primary_facing.lua")()
local originalCreate=script.Create
function script.Create()originalCreate();StartThread(nativeFacing.Run)end

include("bar40k/knight_ion_shield_bind.lua")()
