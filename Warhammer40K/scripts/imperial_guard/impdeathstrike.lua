include('imperial_guard/roster_actor.lua')('imperial_guard/impdeathstrike_animation.lua')
local baseCreate,baseShot,baseKilled=script.Create,script.Shot,script.Killed
local loaded=piece('rig_missile_03')
local alive=true
local hiddenUntil=-1
local function reloadVisibility()
 while alive do
  local frame=Spring.GetGameFrame()
  local ready=Spring.GetUnitWeaponState(unitID,1,'reloadState')
  if frame>hiddenUntil and(not ready or ready<=frame)then Show(loaded)else Hide(loaded)end
  Sleep(100)
 end
end
function script.Create()
 baseCreate()
 Show(loaded)
 StartThread(reloadVisibility)
end
function script.Shot(n)
 baseShot(n)
 if n==1 then hiddenUntil=Spring.GetGameFrame()+1;Hide(loaded)end
end
function script.Killed(...)
 alive=false
 return baseKilled(...)
end
