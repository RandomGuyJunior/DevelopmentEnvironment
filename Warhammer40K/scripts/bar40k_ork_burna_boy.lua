-- Standard Lua unit-script callbacks; legacy artwork/clip data only.
local x_axis, y_axis, z_axis = 1, 2, 3
local data=include("bar40k/animation_data.lua")("bar40k/bar40k_ork_burna_boy_animation.lua")
local bones = {}
for i, name in ipairs(data.bones) do bones[i] = piece(name) end
local muzzle = piece(data.muzzle)
local pelvis = bones[1]
for i,name in ipairs(data.bones)do if name=="bip01 pelvis"then pelvis=bones[i]end end
local spine, upper
for i, name in ipairs(data.bones) do
 if name == "bip01 spine" then spine = i end
 if name == "bip01 spine2" or name == "bip01 spine1" then upper = i end
end
local moving, building = false, false
local aimHeading, aimPitch, aimUntil, fireUntil = 0, 0, 0, 0
local firePoseReady=0
local previous, clipName, clipStart = {}, "idle", 0
local phase, lastFrame = 0, 0
local frameSeconds = 1 / Game.gameSpeed
local function shortest(a, b, alpha)
 return a + ((b - a + math.pi) % (2 * math.pi) - math.pi) * alpha
end
local function animation()
 while true do
  local frame = Spring.GetGameFrame()
  local chosen = building and (data.clips.build and "build" or "fire") or moving and "walk" or (frame < fireUntil or frame < aimUntil) and "fire" or "idle"
  if not building and frame>aimUntil then aimHeading,aimPitch=0,0 end
  if chosen ~= clipName then clipName, clipStart, phase = chosen, frame, 0 end
  local clip = data.clips[clipName]
  local playback = 1
  if moving and not building then
   local _, _, _, velocity = Spring.GetUnitVelocity(unitID)
   playback = math.max(0.25, (velocity or 0) * Game.gameSpeed / data.walkspeed)
  end
  phase = (phase + math.max(0,frame-lastFrame)*frameSeconds*playback) % clip.duration
  lastFrame = frame
  local index = phase / clip.duration * (#clip.frames - 1)
  local first = math.floor(index) + 1
  local second = math.min(first + 1, #clip.frames)
  local alpha = index - math.floor(index)
  for i, bone in ipairs(bones) do
   local a, b = clip.frames[first][i], clip.frames[second][i]
   local old = previous[i] or {}
   previous[i] = old
   for axis = 1, 3 do
    local value = a[axis] + (b[axis] - a[axis]) * alpha
    if old[axis] == nil or math.abs(old[axis] - value) > 0.0001 then
     Move(bone, axis, value, old[axis] and math.abs(value - old[axis]) / frameSeconds or nil)
     old[axis] = value
    end
    local channel = axis + 3
    value = shortest(a[channel], b[channel], alpha)
    if building then
     if i == spine and axis == y_axis then value = value + aimHeading end
     if i == upper and axis == x_axis then value = value - aimPitch end
    end
    if old[channel] == nil or math.abs(old[channel] - value) > 0.0001 then
     Turn(bone, axis, value, old[channel] and math.abs((value - old[channel] + math.pi) % (2 * math.pi) - math.pi) / frameSeconds or nil)
     old[channel] = value
    end
   end
  end
  Sleep(33)
 end
end

function script.Create()
 Spring.SetUnitNanoPieces(unitID, {muzzle})
 StartThread(animation)
end
function script.StartMoving() moving = true end
function script.StopMoving() moving = false end
function script.StartBuilding(heading, pitch)
 building, aimHeading, aimPitch = true, heading or 0, pitch or 0
 SetUnitValue(COB.INBUILDSTANCE, 1)
end
function script.StopBuilding()
 building = false
 SetUnitValue(COB.INBUILDSTANCE, 0)
end
function script.QueryNanoPiece() return muzzle end
function script.QueryBuildInfo() return pelvis end
function script.AimFromWeapon() return muzzle end
function script.QueryWeapon() return muzzle end
function script.AimWeapon(number, heading, pitch)
 if building then return false end
 -- The native unit turns; the imported fire clip alone poses arms/gun.
 local now=Spring.GetGameFrame()
 local aligned=math.abs(heading or 0)<=math.rad(10)
 if not aligned then return false end
 if aimUntil<now then firePoseReady=now+6 end
 aimHeading,aimPitch=0,0
 aimUntil=now+30
 while Spring.GetGameFrame()<(firePoseReady or 0)do Sleep(33)end
 return true
end
function script.FireWeapon()
 fireUntil = Spring.GetGameFrame() + 12
end
function script.Activate() return 1 end
function script.Deactivate() return 0 end
function script.Killed(recentDamage, maximumHealth)
 return recentDamage / maximumHealth > 0.5 and 2 or 1
end
