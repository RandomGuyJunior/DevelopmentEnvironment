-- Reuse the ordinary source animation and real native weapon callbacks.
-- Framework include injects the LUS header (local StartThread/Move/Turn/etc.).
-- A raw VFS include skips it, including inside saved callback closures.
include('40k_roster.lua')
local cp=UnitDefs[unitDefID].customParams
local fixed=tostring(cp.listening_post_version)=='2'
local fixedStage=tonumber(cp.listening_post_stage)
local stageReady=false
local metadata=VFS.Include('scripts/generated/'..cp.listening_post_key..'_post.lua')
local handles={};local map=Spring.GetUnitPieceMap(unitID)or{}
for _,name in ipairs(metadata.pieces)do if map[name]then handles[name]=piece(name)end end
function ListeningPostReady(level)
 if type(level)~='number'or not metadata.stages[level]or(fixed and level~=fixedStage)then return false end
 for _,name in ipairs(metadata.pieces)do if handles[name]==nil then return false end end
 return true
end
function SetListeningPostStage(level)
 if not ListeningPostReady(level)then return false end
 local visible={};for _,name in ipairs(metadata.stages[level])do visible[name]=true end
 for _,name in ipairs(metadata.pieces)do if visible[name]then Show(handles[name])else Hide(handles[name])end end
 stageReady=true
 return true
end
local function allowed(n)
 if fixed then
  local entry=UnitDefs[unitDefID].weapons[n];local w=entry and WeaponDefs[entry.weaponDef]
  local _,_,_,_,progress=Spring.GetUnitHealth(unitID)
  return stageReady and progress==1 and w~=nil and tonumber(w.customParams.listening_post_level)==fixedStage
 end
 local c=GG.Recoil40KResearch
 return c and c.listeningPosts and c.listeningPosts.WeaponAllowed(unitID,n)==true
end
local create,aim,block=script.Create,script.AimWeapon,script.BlockShot
function script.Create()
 if fixed then
  SetListeningPostStage(fixedStage)
 else
 local value=Spring.GetUnitRulesParam(unitID,'40k_post_level');local level=tonumber(value)or 0
 if not SetListeningPostStage(level)then SetListeningPostStage(0)end
 end
 return create()
end
function script.AimWeapon(n,...)
 if not allowed(n)then return false end
 local result=aim(n,...);return result and allowed(n)or false
end
function script.BlockShot(n,...)
 if not allowed(n)then return true end
 return block(n,...)
end
