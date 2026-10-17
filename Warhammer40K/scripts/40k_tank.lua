-- Lua unit scripts share LuaRules GG; only immutable source pose tables are shared.
-- Unit-specific timing, piece IDs and poses remain local to each script instance.
GG.Prototype40kAnimationCache=GG.Prototype40kAnimationCache or {}
local source="leman_russ"
local cache=GG.Prototype40kAnimationCache
if not cache[source] then cache[source]=VFS.Include("scripts/generated/"..source.."_anim.lua") end
local data=cache[source]
local flashProof={}
local clearance=VFS.Include("scripts/40k_mount_clearance.lua")
local options=Spring.GetModOptions()
local sourceEvidence=tostring(UnitDefs[unitDefID].customParams.prototype40k_source_progression)=='1' and options.prototype_diagnostic=='expandedproduction' and VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(options.prototype_source_progression) and options.prototype_source_acceptance=='imperium'
local boneIndex={};for i,name in ipairs(data.bones) do boneIndex[name]=i end
local mounts={
 {yaw=piece('aim_horz_main'),pitch=piece('aim_vert_main'),muzzle=piece('marker_turret_barrel'),clip='main_fire',bone='battlecannon_barrel',period=5},
 {yaw=piece('aim_horz_hull'),muzzle=piece('marker_small_cannon_barrel'),arc=math.rad(35),clip='hull_fire',bone='aim_horz_hull',period=.25},
 {yaw=piece('aim_horz_left'),muzzle=piece('marker_l_heavy_bolter'),arc=math.rad(100),clip='left_fire',bone='sponson_left_bone',period=.25},
 {yaw=piece('aim_horz_right'),muzzle=piece('marker_r_heavy_bolter'),arc=math.rad(100),clip='right_fire',bone='sponson_right_bone',period=.25},
}
for n,m in ipairs(mounts)do m.clearanceSide=clearance.Enabled(options)and clearance.Side(source,n)or nil;m.clearanceLimits=clearance.Limits(source,n);m.clearanceAllowed=m.clearanceSide==nil end
local testPose=false
function script.Create() end
function script.AimFromWeapon(n) return mounts[n].yaw end
function script.QueryWeapon(n) local p=mounts[n].muzzle;if GG.Recoil40KWalkerBurstWitness then GG.Recoil40KWalkerBurstWitness.Query(unitID,n,p)end;return p end
function script.AimWeapon(n,h,p)
 local m=mounts[n]
 if not m then return false end
 if m.clearanceSide then m.clearanceRequest=(m.clearanceRequest or 0)+1 end
 local request=m.clearanceRequest
 m.clearanceAllowed=m.clearanceSide==nil
 if testPose or not clearance.Allows(m.clearanceSide,h,p,m.clearanceLimits) or (m.arc and math.abs(h)>m.arc) then return false end
 Signal(2^n);SetSignalMask(2^n)
 m.heading=h;m.pitchAngle=-p
 Turn(m.yaw,y_axis,h,2)
 if m.pitch then Turn(m.pitch,x_axis,-p,1);WaitForTurn(m.pitch,x_axis) end
 WaitForTurn(m.yaw,y_axis);if request~=m.clearanceRequest then return false end
 m.clearanceAllowed=true;return true
end
function script.BlockShot(n)
 local m=mounts[n];return not m or not m.clearanceAllowed or not clearance.FireAllowed(Spring,unitID,n,m.clearanceSide,m.clearanceLimits)
end
local function recoil(n)
 local m=mounts[n];local clip=data.clips[m.clip];local index=boneIndex[m.bone];local p=piece(m.bone)
 Signal(2^(n+4));SetSignalMask(2^(n+4))
 local frames=n==1 and (clip.recovery_frames or clip.frames) or (clip.shot_frames or clip.frames)
 local fps=#clip.frames/clip.duration
 local duration=#frames/fps
 local start=Spring.GetGameFrame()
 while true do
  local age=(Spring.GetGameFrame()-start)/30
  if age>=duration then break end
  local frame=math.min(#frames,math.floor(age*fps)+1)
  local v=frames[frame][index]
  for a=1,3 do
   Move(p,a,v[a]);Turn(p,a,v[a+3]+((p==m.yaw and a==2) and (m.heading or 0) or 0))
  end
  Sleep(33)
 end
 for a=1,3 do Move(p,a,0);Turn(p,a,(p==m.yaw and a==2) and (m.heading or 0) or 0) end
end
function script.Shot(n)
 local m=mounts[n];local frame=Spring.GetGameFrame()
 if GG.Recoil40KWalkerBurstWitness then GG.Recoil40KWalkerBurstWitness.Shot(unitID,n,m.muzzle)end
 if Spring.GetModOptions().prototype_diagnostic=="six" then
  Spring.SetUnitRulesParam(unitID,"40k_last_shot",frame,{public=true})
  Spring.Echo("40K MUZZLE",unitID,n,frame,Spring.GetUnitPiecePosDir(unitID,m.muzzle))
 end
 local x,y,z,dx,dy,dz=Spring.GetUnitWeaponVectors(unitID,n)
 if dx and dy and dz then
  local length=math.sqrt(dx*dx+dy*dy+dz*dz)
  if length>1e-9 then dx,dy,dz=dx/length,dy/length,dz/length end
 end
 if x then local emitted=Spring.SpawnSFX(unitID,n==1 and 1028 or 1027,x,y,z,dx,dy,dz,true)
  if Spring.GetModOptions().prototype_diagnostic=="six" and not flashProof[n] then
   flashProof[n]=true;Spring.Echo("40K FLASH VECTOR",unitID,n,emitted,x,y,z,dx,dy,dz)
  end
 end
 if sourceEvidence then
  Spring.SetUnitRulesParam(unitID,'40k_last_shot_'..n,frame,{public=true})
  Spring.SetUnitRulesParam(unitID,'40k_last_muzzle_'..n,m.muzzle,{public=true})
  if x then
   Spring.SetUnitRulesParam(unitID,'40k_last_flash_x_'..n,x)
   Spring.SetUnitRulesParam(unitID,'40k_last_flash_y_'..n,y)
   Spring.SetUnitRulesParam(unitID,'40k_last_flash_z_'..n,z)
  end
 end
 m.lastShot=frame;StartThread(recoil,n)
 if Spring.GetModOptions().prototype_diagnostic=="six" then Spring.Echo("40K TANK SHOT",unitID,n,frame) end
end
-- Exposed only to the isolated opt-in attachment diagnostic.
function TestMountPose(h,p)
 if Spring.GetModOptions().prototype_diagnostic~="six" then return end
 testPose=true
 for n=1,4 do Signal(2^n);Signal(2^(n+4)) end
 Turn(mounts[1].yaw,y_axis,h);Turn(mounts[1].pitch,x_axis,p)
end
function script.Killed()
 local cp=UnitDefs[unitDefID].customParams or{}
 local flag=cp.prototype40k_russ_native_wreck
 if flag==true or flag==1 or flag=='1'then return 1 end
 return 0
end
