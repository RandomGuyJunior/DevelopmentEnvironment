function gadget:GetInfo()return{name='40K Gunship physical target eligibility',desc='Native opportunity targets within the approved hull-safe gun sectors',author='Local project',layer=0,enabled=true}end
local SOUND_ACTION='40k_gunship_mg_burst96'
local SOUND_FILE='sounds/40k/weapon_big_shoota_1.wav'
if not gadgetHandler:IsSyncedCode()then
 local heard={}
 local function sound(_,id,n,muzzle,frame)
  local def=UnitDefs[Spring.GetUnitDefID(id)or -1];local cp=def and def.customParams or{}
  if cp.bar40k_donor~='ork_gunship'or tonumber(cp.bar40k_gunship_runtime_revision)~=1 or cp.bar40k_gunship_mg_salvo_sound~=SOUND_FILE or(n~=6 and n~=7)then return end
  -- Only local cosmetics inspect local visibility. Positional PlaySoundFile
  -- itself does NOT perform LOS checks; hidden/radar-only enemies stay silent.
  local spec,full=Spring.GetSpectatingState()
  if not(spec and full)then
   local los=Spring.GetUnitLosState(id,Spring.GetMyAllyTeamID(),false)
   if not(type(los)=='table'and los.los)then return end
  end
  local key=id..':'..n
  if heard[key]and frame<=heard[key]then return end
  local x,y,z=Spring.GetUnitPiecePosDir(id,muzzle)
  if type(x)~='number'or type(y)~='number'or type(z)~='number'then return end
  heard[key]=frame
  Spring.PlaySoundFile(SOUND_FILE,.85,x,y,z,'sfx')
 end
 function gadget:Initialize()gadgetHandler:AddSyncAction(SOUND_ACTION,sound)end
 function gadget:Shutdown()gadgetHandler:RemoveSyncAction(SOUND_ACTION)end
 function gadget:UnitDestroyed(id)heard[id..':6']=nil;heard[id..':7']=nil end
 return
end
local A=VFS.Include('scripts/bar40k/gunship_aim.lua')
local scopes,unitPieces={},{}
for id,d in pairs(UnitDefs)do
 local cp=d.customParams or{}
 if cp.bar40k_donor=='ork_gunship'and(tonumber(cp.bar40k_gunship_runtime_revision)or 0)>=1 then scopes[id]=A.Build(cp)end
end
local function group(id,n)
 local d=scopes[Spring.GetUnitDefID(id)];return d and d[n]
end
local eligible
local function salvoSound(id,n,muzzle,frame)
 local g=group(id,n)
 if not g or(n~=6 and n~=7)then return end
 local def=UnitDefs[Spring.GetUnitDefID(id)];local cp=def and def.customParams or{}
 if tonumber(cp.bar40k_gunship_runtime_revision)~=1 then return end
 local pieces=unitPieces[id];if not pieces then pieces=Spring.GetUnitPieceMap(id);unitPieces[id]=pieces end
 if not pieces or pieces[g.name..'_left_muzzle_1']~=muzzle then return end
 SendToUnsynced(SOUND_ACTION,id,n,muzzle,frame)
end
function gadget:Initialize()
 -- The exact pinned engine dispatches these callbacks only for watched defs.
 -- Register this aircraft's seven turret-volley defs, not unrelated weapons.
 for id in pairs(scopes)do for _,w in ipairs(UnitDefs[id].weapons or{})do Script.SetWatchAllowTarget(w.weaponDef,true)end end
 assert(not GG.BAR40KGunshipTargetEligible,'Gunship eligibility hook already owned')
 GG.BAR40KGunshipTargetEligible=eligible
 assert(not GG.BAR40KGunshipSalvoSound,'Gunship actual-salvo sound hook already owned')
 GG.BAR40KGunshipSalvoSound=salvoSound
end
function gadget:Shutdown()
 if GG.BAR40KGunshipTargetEligible==eligible then GG.BAR40KGunshipTargetEligible=nil end
 if GG.BAR40KGunshipSalvoSound==salvoSound then GG.BAR40KGunshipSalvoSound=nil end
end
function gadget:UnitDestroyed(id)unitPieces[id]=nil end
function gadget:AllowWeaponTargetCheck(id,n)
 local g=group(id,n);if not g or g.primary~=n then return nil,true end
 local fire=Spring.GetUnitStates(id,false,false,false)
 if fire~=2 and fire~=3 then return nil,true end
 local kind=Spring.GetUnitWeaponTarget(id,n);if kind~=1 and kind~=2 then return nil,true end
 local _,_,_,x,y,z=Spring.GetUnitWeaponVectors(id,n)
 local yaw,pitch=A.Angles(x,y,z,Spring.GetUnitVectors(id))
 -- Native circular cones cannot represent this rectangular yaw/pitch sector.
 -- If its current manual/unit/ground target is physically impossible, allow
 -- the existing native opportunity search in Fire At Will(2)/At Neutral(3).
 -- Hold(0), Return(1) and unknown states keep native policy. No target or
 -- command is written; Hold/Return Fire and normal cases keep native policy.
 if yaw and not A.Allowed(g,yaw,pitch)then return true,false end
 return nil,true
end
eligible=function(id,target,n,weapon)
 local g=group(id,n);if not g then return true end
 local pieces=unitPieces[id];if not pieces then pieces=Spring.GetUnitPieceMap(id);unitPieces[id]=pieces end
 local axis=pieces and pieces[g.axis];if not axis then return false end
 local x,y,z=Spring.GetUnitPiecePosDir(id,axis)
 local _,_,_,_,_,_,tx,ty,tz=Spring.GetUnitPosition(target,true,true)
 if not(A.Finite(x)and A.Finite(y)and A.Finite(z)and A.Finite(tx)and A.Finite(ty)and A.Finite(tz))then return false end
 ty=math.max(ty,Spring.GetGroundHeight(tx,tz)+2,0)
 local wd=WeaponDefs[weapon];if not wd then return false end
 -- LaserCannon MG rounds are direct native tracers, not Cannon parabolas.
 local gravity=wd.type=='LaserCannon'and 0 or((wd.myGravity or 0)~=0 and-wd.myGravity or-Game.gravity/(Game.gameSpeed*Game.gameSpeed))
 local dx,dy,dz=A.LaunchDirection(tx-x,ty-y,tz-z,wd.projectilespeed,gravity,wd.type=='Cannon'and wd.highTrajectory==1)
 local yaw,pitch=A.Angles(dx,dy,dz,Spring.GetUnitVectors(id))
 return A.Allowed(g,yaw,pitch)
end

function gadget:AllowWeaponTarget(id,target,n,weapon,priority)
 if not group(id,n)then return true,priority end
 return eligible(id,target,n,weapon),priority
end
