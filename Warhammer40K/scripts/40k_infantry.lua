-- Lua unit scripts share LuaRules GG; only immutable source pose tables are shared.
-- Unit-specific timing, piece IDs and poses remain local to each script instance.
GG.Prototype40kAnimationCache=GG.Prototype40kAnimationCache or {}
local source=UnitDefs[unitDefID].customParams.animsource
local cache=GG.Prototype40kAnimationCache
local data=VFS.Include('40k_configs/animation_bank_loader.lua').Load(VFS,cache,UnitDefs[unitDefID].customParams)
local sourceOptions=Spring.GetModOptions()
local gaitProbe,publishGait,gaitRoot
local cp=UnitDefs[unitDefID].customParams
local gaitOption=sourceOptions.prototype_scale_native_probe
if(gaitOption==true or gaitOption==1 or gaitOption=='1')and(source=='space_marine'or source=='guardsman'or source=='imp_devastator')then
 GG.Recoil40KGaitPoseProbe=GG.Recoil40KGaitPoseProbe or VFS.Include('40k_configs/gait_pose_probe.lua').New(sourceOptions,GG)
 gaitProbe=GG.Recoil40KGaitPoseProbe
 local factor=tonumber(cp.scale_pilot_factor)or 1
 local key=cp.scale_animation_bank and('scripts/40k_anim/'..cp.scale_animation_bank..'.lua')or source
 gaitRoot=cp.root_bone or data.root_bone or data.bones[1]
 local known=false;for _,name in ipairs(data.bones)do if name==gaitRoot then known=true end end
 assert(known and(Spring.GetUnitPieceMap(unitID)or{})[gaitRoot],'Actual infantry gait root unavailable')
 publishGait=gaitProbe.Register(unitID,source,data.bones,key,factor)
end
local sourceEvidence=tostring(UnitDefs[unitDefID].customParams.prototype40k_source_progression)=='1' and sourceOptions.prototype_diagnostic=='expandedproduction' and VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(sourceOptions.prototype_source_progression) and sourceOptions.prototype_source_acceptance~=nil and sourceOptions.prototype_source_acceptance~=''
local sustainedFactory=sourceEvidence and VFS.Include('40k_configs/source_sustained_fire_phase.lua')or nil
local phaseClock
local aimReview
if sourceEvidence and sourceOptions.prototype_source_acceptance=='imperium' then
 local review=VFS.Include('40k_configs/source_infantry_aim_review.lua')
 GG.Recoil40KInfantryAimReview=GG.Recoil40KInfantryAimReview or {}
 aimReview=review.New(Spring,sourceOptions,unitID,UnitDefs[unitDefID].customParams,GG.Recoil40KInfantryAimReview)
end
local function traceAim(...)if aimReview then aimReview(...)end end
local function smoothingOptionEnabled(value)
 return value==true or value==1 or value=='1'
end
local recordWalkPhase
if smoothingOptionEnabled(Spring.GetModOptions().prototype_walk_sampling_review)
 and smoothingOptionEnabled(Spring.GetModOptions().prototype_animation_interpolation)
 and smoothingOptionEnabled(Spring.GetModOptions().prototype_fractional_walk_sampling) then
 GG.Prototype40kWalkPhaseRecorder=GG.Prototype40kWalkPhaseRecorder or VFS.Include('scripts/40k_walk_phase_review.lua')
 recordWalkPhase=GG.Prototype40kWalkPhaseRecorder
end
local function walkQualityOption(name)
 local options=Spring.GetModOptions()
 -- Source-stepped is the normal simulation path; smooth requires both options.
 return smoothingOptionEnabled(options[name])
  and smoothingOptionEnabled(options.prototype_fractional_walk_sampling)
  and smoothingOptionEnabled(options.prototype_animation_interpolation)
end
local walkQualityRole=UnitDefs[unitDefID].customParams.rosterrole or 'infantry'
local walkQualityEligible=(walkQualityRole=='infantry' or walkQualityRole=='builder') and source~='killa_kan'
local fractionalWalk=walkQualityEligible and walkQualityOption('prototype_fractional_walk_sampling')
local sampleWalk
if fractionalWalk then
 GG.Prototype40kWalkSamplerFactory=GG.Prototype40kWalkSamplerFactory or VFS.Include('scripts/40k_walk_sampler.lua')
 sampleWalk=GG.Prototype40kWalkSamplerFactory()
end
local flashProof={}
local bones={};for i,name in ipairs(data.bones) do bones[i]=piece(name) end
local muzzle=piece(data.muzzle)
local gunMuzzles={};for i,name in ipairs(data.muzzles or {data.muzzle}) do gunMuzzles[i]=piece(name) end
local nextMuzzle=1
local gunHasFired=false
local shotArmBones={}
for i,name in ipairs(data.bones) do
 local arm=name:match("^bip01 [lr] clavicle$") or name:match("^bip01 [lr] upperarm$") or name:match("^bip01 [lr] forearm$") or name:match("^bip01 [lr] hand$")
 if source=="meganob" then arm=arm and name:match("^bip01 r ") end
 shotArmBones[i]=arm or name=="bone_weapon" or name=="bone_ammo_belt"
end
GG.Prototype40kPoseFactory=GG.Prototype40kPoseFactory or VFS.Include("scripts/40k_pose.lua")
local poseBuffers=GG.Prototype40kPoseFactory(data,shotArmBones)
local aimRoot=piece("unit_aim")
local moving=false
local aimHeading=0
local blendStart=0
local blendFrom
local currentRow
local aimUntil=0
local lastShot=-1000
local fireStart
local preparingStart
local shotPeriod=tonumber(UnitDefs[unitDefID].customParams.fireperiod) or .4
local renderInterpolation=walkQualityEligible and walkQualityOption('prototype_animation_interpolation')
local function pose(row,interpolate)
 if gaitProbe then gaitProbe.Invalidate(unitID)end
 currentRow=row
 poseBuffers.Apply(row,bones,Move,Turn,interpolate)
end
local currentBase
local function sourceOverlay(clip,row,base)
 return poseBuffers.Overlay(clip,row,base,clip==data.clips.melee and "melee" or "overlay")
end
local claw
if UnitDefs[unitDefID].customParams.clawmarker then
 claw=VFS.Include("scripts/40k_claw.lua")({data=data,unitID=unitID,params=UnitDefs[unitDefID].customParams,piece=piece,pose=function(row) pose(sourceOverlay(data.clips.melee,row,currentBase or data.clips.idle.frames[1])) end,Sleep=Sleep})
end
local function fps(clip) return clip.source_fps or #clip.frames/clip.duration end
local function animate()
 local walkPhase,idlePhase=0,0;local previous="";local wasMelee=false
 local previousWalkPhase
 local fire=data.clips.fire;local cue=fire.shot_cue or 0
 while true do
  local walkReviewPhase=walkPhase
  local f=Spring.GetGameFrame()
  local targetType=Spring.GetUnitWeaponTarget(unitID,1)
  local firing=targetType and targetType~=0
  local age=fireStart and (f-fireStart)/30 or math.huge
  local prep=preparingStart and (f-preparingStart)/30
  local sourcePose=not moving and phaseClock and phaseClock.Sample(f,false)
  local mode=moving and "walk" or ((sourcePose or age<fire.duration) and "fire" or (prep and prep<cue/fps(fire) and "prepare" or ((firing or f<aimUntil) and "aim" or "idle")))
  local smoothWalk=renderInterpolation and mode=='walk' and previous=='walk'
   and previousWalkPhase~=nil and (fractionalWalk or walkPhase>=previousWalkPhase)
  previousWalkPhase=mode=='walk' and walkPhase or nil
  if mode~=previous then
   if mode=="walk" or mode=="idle" or previous=="walk" or previous=="idle" then blendStart=f;blendFrom=poseBuffers.Snapshot(currentRow) end
   previous=mode
  end
  local idle=data.clips.idle
  local base=idle.frames[math.floor(idlePhase*fps(idle))%#idle.frames+1]
  currentBase=base
  idlePhase=(idlePhase+1/30)%idle.duration
  local row
  if mode=="fire" then
   -- A complete source cycle starts at its measured cue. Burst projectiles
   -- do not restart/truncate the actor's whole-body recovery.
   row=sourceOverlay(fire,sourcePose or fire.frames[(cue+math.floor(age*fps(fire)))%#fire.frames+1],base)
  elseif mode=="prepare" then row=sourceOverlay(fire,fire.frames[math.min(cue+1,math.floor(prep*fps(fire))+1)],base)
  elseif mode=="aim" then row=sourceOverlay(fire,fire.frames[cue+1],base)
  elseif mode=="walk" then
   local clip=data.clips.walk
   row=fractionalWalk and sampleWalk(clip,walkPhase) or clip.frames[math.floor(walkPhase*fps(clip))%#clip.frames+1]
   local vx,vy,vz=Spring.GetUnitVelocity(unitID)
   local rate=math.max(.05,math.sqrt(vx*vx+vz*vz)*30/data.walkspeed)
   walkPhase=(walkPhase+rate/30)%clip.duration
  else row=base end
  -- Native Shot retriggers genuine gun-arm channels without restarting hips/legs.
  local shotAge=(f-lastShot)/30
  if not phaseClock and not moving and shotAge>=0 and shotAge<fire.duration then
   local gunRow=fire.frames[(cue+math.floor(shotAge*fps(fire)))%#fire.frames+1]
   row=poseBuffers.Arms(row,gunRow,fire)
  end
  local melee=claw and claw.UpdatePose(f)
  if melee and phaseClock then phaseClock.SetInterrupted(f,true)end
  if melee then melee=sourceOverlay(data.clips.melee,melee,base) end
  if wasMelee and not melee then blendStart=f;blendFrom=poseBuffers.Snapshot(currentRow) end
  wasMelee=melee~=nil
  if not melee and blendFrom and f-blendStart<6 then
   row=poseBuffers.Blend(row,blendFrom,(f-blendStart)/6)
  end
  if recordWalkPhase and mode=='walk' and not melee and f-blendStart>=6 then
   recordWalkPhase(unitID,source,f,walkReviewPhase,data.clips.walk,fractionalWalk)
  end
  pose(melee or row,smoothWalk and not melee and f-blendStart>=6)
  if publishGait and mode=='walk'and f-blendStart>=6 then
   local layers={'walk'}
   if melee then layers[#layers+1]='melee'end
   -- Gun overlays only run while stationary above; disclose unexpected firing state.
   if sourcePose then layers[#layers+1]='sustained_fire'end
   if not moving and shotAge>=0 and shotAge<fire.duration then layers[#layers+1]='shot_arms'end
   local vx,vy,vz=Spring.GetUnitVelocity(unitID)
   publishGait({frame=f,mode=mode,clip='walk',rootName=gaitRoot,sampleSeconds=walkReviewPhase,
    fps=fps(data.clips.walk),count=#data.clips.walk.frames,fractional=not not fractionalWalk,
    smooth=not not(smoothWalk and not melee and f-blendStart>=6),stride=data.walkspeed,
    blendAge=f-blendStart,blendAlpha=1,velocity={vx or 0,vy or 0,vz or 0},layers=layers,aim={}},melee or row)
   local gait=GG.Recoil40KGaitMovementFixture
   if gait and gait.ObservePublished then gait.ObservePublished(unitID,f)end
   if GG.Recoil40KNativeGaitObserve then GG.Recoil40KNativeGaitObserve(f)end
  end
  Sleep(33)
 end
end
function script.Create() StartThread(animate) end
function script.StartMoving() if gaitProbe then gaitProbe.Invalidate(unitID)end;traceAim("moving");if phaseClock then phaseClock.SetInterrupted(Spring.GetGameFrame(),true)end;moving=true;fireStart=nil;preparingStart=nil;if claw then claw.Cancel() end;Turn(aimRoot,y_axis,0,6) end
function script.StopMoving() traceAim("stopped");moving=false;if phaseClock then phaseClock.SetInterrupted(Spring.GetGameFrame(),false)end end
-- Keep melee acquisition on the shared body pivot; ranged review uses the gun.
function script.AimFromWeapon(n)
 -- Acquisition and whole-body rotation are independent. The synthetic root is
 -- exactly on terrain; a genuine ranged weapon marker is the native aim origin.
 local review=sourceEvidence or(sourceOptions.prototype_diagnostic=='six'and tostring(sourceOptions.prototype_runtime_library_review)=='1')
 if review and n==1 then return gunMuzzles[nextMuzzle]end
 return aimRoot -- Preserve the measured claw range/pivot behavior.
end
function script.QueryWeapon(n) return n==2 and claw and claw.Query() or gunMuzzles[nextMuzzle] end
function script.BlockShot(n) return n==1 and claw and claw.IsActive() or false end
function script.AimWeapon(num,heading,pitch)
 traceAim("aim_enter",num,heading,pitch)
 if moving or (num==1 and claw and claw.IsActive()) then traceAim(moving and "reject_moving" or "reject_claw",num);return false end
 local frame=Spring.GetGameFrame();local settle=num==1 and frame>aimUntil
 if gaitProbe then gaitProbe.Invalidate(unitID)end
 aimHeading=heading;Turn(aimRoot,y_axis,heading,6);aimUntil=frame+30
 if settle then
  preparingStart=frame
  local preparation=(data.clips.fire.shot_cue or 0)/fps(data.clips.fire)
  aimUntil=frame+math.ceil(preparation*30)+30
  Sleep(math.max(200,math.ceil(preparation*1000)))
  preparingStart=nil;traceAim("after_preparation",num)
 end
 if moving then traceAim("reject_moving_after_preparation",num);return false end
 traceAim("wait_turn",num);WaitForTurn(aimRoot,y_axis);traceAim("after_turn",num)
 if num==2 and claw then
  local ready=claw.Aim(moving)
  local targetType=Spring.GetUnitWeaponTarget(unitID,2)
  if moving or targetType~=1 then traceAim("reject_claw_target",num);claw.Cancel();return false end
  traceAim(ready and "aim_ready" or "reject_claw_aim",num);return ready
 end
 traceAim("aim_ready",num);return true
end
function script.FireWeapon(n)
 traceAim("fire",n)
 if n~=1 or not sustainedFactory or moving or(claw and claw.IsActive())then return end
 local reload=Spring.GetUnitWeaponState and Spring.GetUnitWeaponState(unitID,n,'reloadTimeXP')
 if type(reload)~='number'or reload<=0 then return end
 local interval=math.max(1,math.ceil(reload*30))
 if not phaseClock then phaseClock=sustainedFactory.New(data.clips.fire,{kind='ranged',native_fire_interval_frames=interval})end
 if not phaseClock then return end
 phaseClock.SetInterrupted(Spring.GetGameFrame(),false);phaseClock.OnFireWeapon(Spring.GetGameFrame(),interval)
end
function script.Shot(n)
 if gaitProbe then gaitProbe.Invalidate(unitID)end
 traceAim("shot",n)
 if n==2 and claw then claw.Shot(n);return end
 if claw and claw.IsActive() then return end
 -- Native Shot precedes QueryWeapon: select and hold this shot's barrel.
 if gunHasFired then nextMuzzle=nextMuzzle%#gunMuzzles+1 end
 gunHasFired=true
 local frame=Spring.GetGameFrame()
 lastShot=frame
 if not phaseClock and (not fireStart or (frame-fireStart)/30>=data.clips.fire.duration)then fireStart=frame end
 preparingStart=nil
 if Spring.GetModOptions().prototype_diagnostic=="six" then
  Spring.SetUnitRulesParam(unitID,"40k_last_shot",frame,{public=true})
  Spring.Echo("40K MUZZLE",unitID,n,frame,Spring.GetUnitPiecePosDir(unitID,gunMuzzles[nextMuzzle]))
 end
 local x,y,z,dx,dy,dz=Spring.GetUnitWeaponVectors(unitID,n)
 if #gunMuzzles>1 then
  local px,py,pz=Spring.GetUnitPiecePosDir(unitID,gunMuzzles[nextMuzzle])
  if px and py and pz then x,y,z=px,py,pz end
 end
 if dx and dy and dz then
  local length=math.sqrt(dx*dx+dy*dy+dz*dz)
  if length>1e-9 then dx,dy,dz=dx/length,dy/length,dz/length end
 end
 if x and (sourceEvidence or (sourceOptions.prototype_diagnostic=="six" and (tostring(sourceOptions.prototype_runtime_library_review)=="1" or #gunMuzzles>1))) then
  Spring.SetUnitRulesParam(unitID,"40k_last_shot_"..n,frame)
  Spring.SetUnitRulesParam(unitID,"40k_last_muzzle_"..n,gunMuzzles[nextMuzzle])
  Spring.SetUnitRulesParam(unitID,"40k_last_flash_x_"..n,x)
  Spring.SetUnitRulesParam(unitID,"40k_last_flash_y_"..n,y)
  Spring.SetUnitRulesParam(unitID,"40k_last_flash_z_"..n,z)
 end
 if x then local emitted=Spring.SpawnSFX(unitID,tonumber(UnitDefs[unitDefID].customParams.muzzlefx),x,y,z,dx,dy,dz,true)
  if Spring.GetModOptions().prototype_diagnostic=="six" and not flashProof[n] then
   flashProof[n]=true;Spring.Echo("40K FLASH VECTOR",unitID,n,emitted,x,y,z,dx,dy,dz)
  end
 end
 if Spring.GetModOptions().prototype_diagnostic=="six" then Spring.Echo("40K SHOT POSE",unitID,n,lastShot,shotPeriod,data.clips.fire.shot_cue) end
end
function script.Killed()
 if gaitProbe then gaitProbe.Clear(unitID)end
 if GG.Recoil40KTacticalRemains then GG.Recoil40KTacticalRemains.Killed(unitID,unitDefID,Spring.GetUnitTeam(unitID))end
 return 0
end
