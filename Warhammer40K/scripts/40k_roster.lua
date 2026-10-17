-- Genuine source-pose runtime. Native weapons/builders/transports own simulation.
-- Generated frames are immutable; all clocks, masks and buffers are per actor.
local ud=UnitDefs[unitDefID]
local cp=ud.customParams or {}
local clearance=VFS.Include("scripts/40k_mount_clearance.lua")
local source=assert(cp.animsource,'40K roster requires animsource')
GG.Prototype40kAnimationCache=GG.Prototype40kAnimationCache or {}
local cache=GG.Prototype40kAnimationCache
local data=VFS.Include('40k_configs/animation_bank_loader.lua').Load(VFS,cache,cp)
local gaitProbe,publishGait
if tostring(Spring.GetModOptions().prototype_scale_native_probe or'0')=='1'
 and(source=='space_marine'or source=='guardsman'or source=='imp_devastator'or(source=='imp_terminator'and tostring(Spring.GetModOptions().prototype_terminator_native_observer or'0')=='1'))then
 GG.Recoil40KGaitPoseProbe=GG.Recoil40KGaitPoseProbe or VFS.Include('40k_configs/gait_pose_probe.lua').New(Spring.GetModOptions(),GG)
 gaitProbe=GG.Recoil40KGaitPoseProbe
 local factor=tonumber(cp.scale_pilot_factor)or 1
 local key=cp.scale_animation_bank and('scripts/40k_anim/'..cp.scale_animation_bank..'.lua')or source
 publishGait=gaitProbe.Register(unitID,source,data.bones,key,factor)
end
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
local walkQualityRole=cp.rosterrole or 'infantry'
local walkQualityEligible=(walkQualityRole=='infantry' or walkQualityRole=='builder') and source~='killa_kan'
local dakkaGait=VFS.Include('scripts/40k_dakka_gait.lua').New(source,cp,data,VFS)
local dakkaRecoil=VFS.Include('scripts/40k_dakka_shot_recoil.lua').New(source,cp,data)
local fractionalWalk=dakkaGait~=nil or(walkQualityEligible and walkQualityOption('prototype_fractional_walk_sampling'))
local sampleWalk
if fractionalWalk then
 GG.Prototype40kWalkSamplerFactory=GG.Prototype40kWalkSamplerFactory or VFS.Include('scripts/40k_walk_sampler.lua')
 sampleWalk=GG.Prototype40kWalkSamplerFactory()
end
GG.Prototype40kPoseFactory=GG.Prototype40kPoseFactory or VFS.Include('scripts/40k_pose.lua')
local factory=GG.Prototype40kPoseFactory
local buffers=factory(data,{})
local map=Spring.GetUnitPieceMap(unitID) or {}
local index,bones,poseIndexByPiece={},{},{}
for i,name in ipairs(data.bones) do index[name]=i;bones[i]=piece(name) end
-- Match the original ipairs first-hit search, including aliases/array holes.
for i,handle in ipairs(bones) do
 if poseIndexByPiece[handle]==nil then poseIndexByPiece[handle]=i end
end
local function lookup(name) return name and map[name] and piece(name) or nil end
local root=lookup(cp.root_bone) or lookup(data.root_bone) or bones[1]
local aimRoot=lookup('unit_aim') or root
local servoSkull
if tostring(cp.source_servoskull or '')=='attached_v1' then
 assert(cp.source_servoskull_bank=='servo_skull_attachment','Unknown servo source bank')
 GG.Recoil40KServoSkullIdle=GG.Recoil40KServoSkullIdle or VFS.Include('scripts/generated/servo_skull_attachment_anim.lua')
 servoSkull=VFS.Include('scripts/40k_servo_skull.lua').New(unitID,cp,map,lookup,
  {SetUnitNanoPieces=Spring.SetUnitNanoPieces,Move=Move,Turn=Turn},GG.Recoil40KServoSkullIdle)
end
local role=cp.rosterrole or 'infantry'
local wholeBody=role=='infantry' or role=='builder' or(role=='walker'and tostring(cp.source_independent_weapon_assemblies)~='1')
local mounts={}
-- Only the measured ART1 recipe owns these absolute axes. Other actors keep
-- their original additive source-pose aim and all torso/native weapon gates.
local boomyAim
if cp.source_boomy_aim_policy then
 boomyAim=VFS.Include('scripts/40k_boomy_aim.lua').New(source,cp,lookup,x_axis,y_axis)
end
local torso
if cp.source_torso_aim_mode=='shared_heading_local_residual' then
 local directRecipe=source=='ork_dread_ranged_fourarm'and cp.source_variant_recipe=='project_dread_direct_torso_v2'
 local pairedKan=(source=='ork_kan_twin_shoota'or source=='ork_kan_twin_kmb'or source=='ork_kan_twin_rokkit')
  and cp.source_variant_recipe=='project_kan_paired_torso_v2'and cp.source_torso_aimpiece=='project_kan_hip_yaw'
 assert(directRecipe or pairedKan,'Unknown shared torso recipe')
 local yawName,bodyName=cp.source_torso_aimpiece,cp.source_torso_bodypiece
 local yaw,body=lookup(yawName),lookup(bodyName)
 local yi=yaw and Spring.GetUnitPieceInfo(unitID,yaw)
 local bi=body and Spring.GetUnitPieceInfo(unitID,body)
 assert(yaw and body and yi and yi.parent=='bip01'and bi and bi.parent==yawName,'Actual direct torso hierarchy missing')
 assert(Spring.UnitScript and Spring.UnitScript.GetPieceRotation and Spring.UnitScript.IsInTurn,'Native torso readback missing')
 torso={piece=yaw,bodyPiece=body,parentPiece=lookup(yi.parent),parentIndex=index[yi.parent],bodyIndex=index[bodyName],epoch=0,untilFrame=0,speed=3}
 assert(torso.parentPiece and torso.parentIndex and torso.bodyIndex,'Actual torso source pose indices missing')
end
local sustainedFactory -- initialized after actual review gate below
local testMount
local sourceOptions=Spring.GetModOptions()
local aircraftReview=tostring(cp.prototype40k_ork_aircraft_review)=='1'and(source=='ork_fighta_bomba'or source=='ork_nuke_bomba')and tostring(sourceOptions.prototype_ork_aircraft_review)=='1'
local aircraftDomain=VFS.Include('scripts/40k_fighta_domain_gate.lua').Enabled(source,cp)
local aircraftAim

local wraithReview=VFS.Include('40k_configs/wraith_phase_review_gate.lua').ScriptEnabled(source,cp,sourceOptions)
local sourceEvidence=tostring(cp.prototype40k_source_progression)=='1' and sourceOptions.prototype_diagnostic=='expandedproduction' and VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(sourceOptions.prototype_source_progression) and sourceOptions.prototype_source_acceptance~=nil and sourceOptions.prototype_source_acceptance~=''
local diagnostic=cp.diagnostic=='roster' or sourceEvidence
local bodyStarts,bodyRendered={},{}
-- Opt-in actual source progression review until native presentation is accepted.
sustainedFactory=sourceEvidence and VFS.Include('40k_configs/source_sustained_fire_phase.lua')or nil
local moving,building=false,false
local currentRow,blendFrom,previousMode
local blendStart=0
local idlePhase,walkPhase=0,0
local savedSpeed,transitionWasActive
local buildStart=0
local currentMelee
local warned={}
local attachments,slots={},{}
local stockpileProps,stockpileShown={},nil
local hasStockpile=false
local function warn(key,message)
 if not warned[key] then warned[key]=true;Spring.Echo('40K ROSTER',unitID,message) end
end
local function words(value)
 local out={}
 for name in tostring(value or ''):gmatch('[^,;]+') do out[#out+1]=name:match('^%s*(.-)%s*$') end
 return out
end
local function now() return Spring.GetGameFrame() end
local function jumpState()
 local controller=GG.Recoil40KJump
 return controller and controller.states and controller.states[unitID]
end
local function fps(clip) return clip.source_fps or #clip.frames/clip.duration end
local function duration(clip) return #clip.frames/fps(clip) end
local function sample(clip,age,loop,cue)
 local i=math.floor(math.max(0,age)*fps(clip))+(cue or 0)
 i=loop and i%#clip.frames or math.min(#clip.frames-1,i)
 return clip.frames[i+1]
end
local primaryCompletedPose,primaryMinrange
if cp.source_completed_pose_profile then
 primaryMinrange=VFS.Include('40k_configs/ork_primary_native_minrange.lua')
 local profiles=VFS.Include('scripts/generated/ork_primary_pose_profiles.lua')
 local profile=assert(profiles[cp.source_completed_pose_profile],'Exact completed-pose profile missing')
 primaryCompletedPose=VFS.Include('40k_configs/ork_primary_completed_pose_layers.lua')(data,profile,sample,buffers)
end
if aircraftReview then primaryMinrange=VFS.Include('40k_configs/ork_primary_native_minrange.lua')end
-- No invented contact timing: use exported measured contact or explicit metadata.
local function contactFrame(clip,params)
 if not clip then return nil end
 local contact=tonumber(params.source_contact_frame) or tonumber(clip.contact_frame)
 if not contact and clip.marker_trajectory then
  local best=-math.huge
  for i,v in ipairs(clip.marker_trajectory) do if v[3]>best then best=v[3];contact=i end end
 end
 if contact and contact==math.floor(contact) and contact>=1 and contact<=#clip.frames then return contact end
end
for n,weapon in ipairs(ud.weapons or {}) do
 local wd=WeaponDefs[weapon.weaponDef or weapon.weaponDefID]
 local p=wd and wd.customParams or {}
 local label=p.source_fireclip
 if label==nil then label='fire' end
 local passive=wd and (wd.type=='Shield' or wd.weapontype=='Shield') or tostring(p.source_passive)=='1'
 if passive then label='' end
 local clip=label~='' and data.clips[label] or nil
 local marker=lookup(p.source_muzzle) or lookup(data.muzzle) or root
 local melee=wd and (wd.type=='Melee' or wd.weapontype=='Melee')
 local m={def=wd,params=p,clip=clip,label=label,muzzle=marker,melee=melee,passive=passive,
  pair={},pairIndex=1,pairSimultaneous=p.source_muzzle_pair_mode=='simultaneous',
  yaw=lookup(p.source_aimpiece),pitch=lookup(p.source_pitchpiece),heading=0,pitchAngle=0,
  readyUntil=0,nextWindup=0}
 m.clearanceSide=clearance.Enabled(Spring.GetModOptions())and clearance.Side(source,n,p.source_variant_assembly)or nil;m.clearanceLimits=clearance.Limits(source,n,p.source_variant_assembly);m.clearanceAllowed=m.clearanceSide==nil
 if torso then
  assert(not melee and not passive and m.yaw and m.pitch and p.source_torso_aimpiece==cp.source_torso_aimpiece,'Every direct gun must share the genuine torso')
  local info=Spring.GetUnitPieceInfo(unitID,m.yaw);assert(info and info.parent==cp.source_torso_bodypiece,'Gun pivot is not directly on torso')
  local lo,hi,down,up=tonumber(p.source_local_yaw_min),tonumber(p.source_local_yaw_max),tonumber(p.source_local_pitch_min),tonumber(p.source_local_pitch_max)
  assert(lo and hi and down and up and lo==lo and hi==hi and down==down and up==up and lo>=-3 and hi<=3 and down>=-3 and up<=3 and lo<=hi and down<=up,'Bounded direct-gun local limits missing')
  m.torsoLimits={math.rad(lo),math.rad(hi),math.rad(down),math.rad(up)}
  m.clearanceSide=nil;m.clearanceAllowed=false
 end
 if p.source_muzzle_pair then
  local names=words(p.source_muzzle_pair)
  m.pairInvalid=#names<2
  for _,name in ipairs(names) do
   local handle=lookup(name)
   if handle then m.pair[#m.pair+1]=handle else m.pairInvalid=true end
  end
  if m.pairInvalid then warn('pair'..n,'Paired gun mount '..n..' disabled: an actual source barrel is missing')
  else m.muzzle=m.pair[1] end
 end
 if passive then
  m.enabled=lookup(p.source_muzzle)~=nil;m.aimEnabled=m.enabled
  if not m.enabled then warn('field'..n,'Passive field mount '..n..' disabled: actual source field origin missing') end
 else m.aimEnabled=not m.pairInvalid and (wholeBody or melee or m.yaw~=nil or tostring(p.source_wholebodyaim)=='1') end
 -- Duration and stockpilelimit may exist on ordinary native weapons.
 hasStockpile=hasStockpile or (wd and wd.stockpile==true)
 if not m.yaw then m.yaw=aimRoot end
 if not passive and not m.aimEnabled then warn('pivot'..n,'Gun mount '..n..' disabled: source_aimpiece missing for mechanical role '..role) end
 if melee then
  m.contact=contactFrame(clip,p)
  m.enabled=clip~=nil and m.contact~=nil and lookup(p.source_muzzle)~=nil
  if not m.enabled then warn('melee'..n,'Melee mount '..n..' disabled: genuine clip/contact/marker missing') end
 end
 m.bodyRecovery=not passive and ((wholeBody and n==1 and not melee) or tostring(p.source_wholebodyfire)=='1')
 local selected={}
 for _,name in ipairs(words(p.source_weapon_bones)) do selected[name]=true end
 -- Native piece ancestry gives the gun side; stop before torso/root channels.
 local name=p.source_muzzle or data.muzzle
 local seen={}
 local exclusive=tostring(p.source_weapon_bones_only)=='1'
 while not exclusive and name and not seen[name] do
  seen[name]=true
  local lower=name:lower()
  if index[name] and (lower:find('arm',1,true) or lower:find('hand',1,true) or lower:find('clavicle',1,true) or lower:find('weapon',1,true) or lower:find('gun',1,true) or lower:find('barrel',1,true) or lower:find('turret',1,true)) then selected[name]=true end
  local info=map[name] and Spring.GetUnitPieceInfo(unitID,map[name])
  name=info and info.parent
 end
 -- Mechanical recovery affects only this actual pivot subtree, never hull
 -- or another independently mounted gun. Fixed guns provide explicit bones.
 if not wholeBody and not exclusive then
  local function descend(name)
   if not name or seen['sub:'..name] then return end
   seen['sub:'..name]=true
   if index[name] then selected[name]=true end
   local info=map[name] and Spring.GetUnitPieceInfo(unitID,map[name])
   for _,child in ipairs(info and info.children or {}) do descend(child) end
  end
  if m.pitch and p.source_pitchpiece then descend(p.source_pitchpiece)
  elseif p.source_aimpiece and p.source_aimpiece~='unit_aim' then descend(p.source_aimpiece) end
 end
 if exclusive then
  local valid=false
  for selectedName in pairs(selected) do if index[selectedName] then valid=true else selected[selectedName]=nil end end
  if not valid then m.enabled=false;m.aimEnabled=false;warn('mask'..n,'Exclusive weapon recovery disabled: no genuine exported bone selected') end
 end
 if torso then
  assert(not selected[cp.source_torso_aimpiece]and not selected[cp.source_torso_bodypiece]and not selected.bip01,'Gun shot mask contains torso or locomotion owner')
  assert(exclusive,'Direct guns require explicit exclusive recoil masks')
 end
 m.selected=selected
 mounts[n]=m
end
local function addStockpileProp(name,seen)
 local handle=lookup(name)
 if not handle or seen[handle] then return end
 seen[handle]=true;stockpileProps[#stockpileProps+1]=handle
 local info=Spring.GetUnitPieceInfo(unitID,handle)
 for _,child in ipairs(info and info.children or {}) do addStockpileProp(child,seen) end
end
if hasStockpile then
 local seen={}
 local props=words(cp.source_stockpile_pieces or cp.source_stockpile_piece)
 for _,m in ipairs(mounts) do
  for _,name in ipairs(words(m.params.source_stockpile_pieces or m.params.source_stockpile_piece)) do props[#props+1]=name end
 end
 if #props==0 then
  -- These are real loaded-ammunition names in the copied emplacement/Wartrak.
  -- Missing names do not create a prop or hide unrelated weapon geometry.
  props={'marine_missile','mesh_marine_missile','twin_linked_rokkit01','mesh_twin_linked_rokkit01'}
 end
 for _,name in ipairs(props) do addStockpileProp(name,seen) end
 if #stockpileProps==0 then warn('stockpile_props','Stockpiled weapon has no actual source ammunition prop') end
end
local function updateStockpile()
 if not hasStockpile or not Spring.GetUnitStockpile then return end
 local count=tonumber((Spring.GetUnitStockpile(unitID)))
 if not count then return end -- unavailable readback is not an empty stockpile.
 local loaded=count>0
 if loaded~=stockpileShown then
  stockpileShown=loaded
  for _,handle in ipairs(stockpileProps) do if loaded then Show(handle) else Hide(handle) end end
 end
 if diagnostic then Spring.SetUnitRulesParam(unitID,'40k_native_stockpile',count,{public=true}) end
end
local hasMelee=false
for _,m in ipairs(mounts) do if m.melee and m.enabled then hasMelee=true end end
for _,m in ipairs(mounts) do
 local mask={}
 for i,name in ipairs(data.bones) do
  local lower=name:lower()
  local arms=lower:match('^bip0%d [lr] clavicle$') or lower:match('^bip0%d [lr] upperarm$') or lower:match('^bip0%d [lr] forearm$') or lower:match('^bip0%d [lr] hand$')
  mask[i]=m.selected[name] or (not hasMelee and wholeBody and arms) or(tostring(m.params.source_weapon_bones_only)~='1'and lower:find('ammo_belt',1,true))
 end
 m.buffers=factory(data,mask)
end
local aimOffsets,aimApplied={},{}
local poseJumpActive=false
local function setOffset(p,a,value,speed)
 local v=aimOffsets[p]
 if not v then v={};aimOffsets[p]=v end
 local axis=v[a]
 if not axis then axis={};v[a]=axis end
 axis[1],axis[2]=value,speed or 3
end
-- Inserted into 40k_roster.lua after setOffset; no independent thread/callback.
local function finiteAngle(a)return type(a)=='number'and a==a and math.abs(a)<math.huge end
local function wrapAngle(a)return(a+math.pi)%(2*math.pi)-math.pi end
local function rotateYXZ(x,y,z,rx,ry,rz)
 local c,s=math.cos(rz),math.sin(rz);x,y=c*x-s*y,s*x+c*y
 c,s=math.cos(rx),math.sin(rx);y,z=c*y-s*z,s*y+c*z
 c,s=math.cos(ry),math.sin(ry);return c*x+s*z,y,-s*x+c*z
end
local function inverseYXZ(x,y,z,rx,ry,rz)
 local c,s=math.cos(ry),math.sin(ry);x,z=c*x-s*z,s*x+c*z
 c,s=math.cos(rx),math.sin(rx);y,z=c*y+s*z,-s*y+c*z
 c,s=math.cos(rz),math.sin(rz);return c*x+s*y,-s*x+c*y,z
end
local function aimVector(h,p)return math.sin(h)*math.cos(p),math.sin(p),math.cos(h)*math.cos(p)end
local function localAngles(h,p,yaw,pr,sr)
 local x,y,z=aimVector(h,p)
 x,y,z=inverseYXZ(x,y,z,pr[4],pr[5],pr[6])
 x,y,z=inverseYXZ(x,y,z,0,yaw,0)
 x,y,z=inverseYXZ(x,y,z,sr[4],sr[5],sr[6])
 return math.atan2(x,z),math.atan2(y,math.sqrt(x*x+z*z))
end
local function torsoGoal(h,p,row)
 local pr,sr=row[torso.parentIndex],row[torso.bodyIndex]
 local x,y,z=aimVector(h,p);x,y,z=inverseYXZ(x,y,z,pr[4],pr[5],pr[6])
 local sx,_,sz=rotateYXZ(0,0,1,sr[4],sr[5],sr[6])
 return wrapAngle(math.atan2(x,z)-math.atan2(sx,sz))
end
local function torsoWithin(m,h,p)
 local l=m.torsoLimits
 return finiteAngle(h)and finiteAngle(p)and h>=l[1]-1e-9 and h<=l[2]+1e-9 and p>=l[3]-1e-9 and p<=l[4]+1e-9
end
local function updateTorsoOffsets(row)
 if not torso or torso.heading==nil or poseJumpActive then return end
 local yaw=torsoGoal(torso.heading,torso.pitch,row)
 setOffset(torso.piece,y_axis,yaw,torso.speed)
 for _,m in ipairs(mounts)do
  if m.torsoHeading and m.torsoEpoch==torso.epoch then
   local h,p=localAngles(m.torsoHeading,m.torsoPitch,yaw,row[torso.parentIndex],row[torso.bodyIndex])
   if torsoWithin(m,h,p)then
    setOffset(m.yaw,y_axis,h,tonumber(m.params.source_aimspeed)or 3)
    setOffset(m.pitch,x_axis,-p,2)
   else
    -- Never aim successfully by clamping an unreachable target into the cone.
    m.clearanceAllowed=false
   end
  end
 end
end
local function claimTorso(n,m,h,p)
 if not finiteAngle(h)or not finiteAngle(p)or not currentRow then return end
 h=wrapAngle(h)
 local f=now();local owner=torso.owner
 local canOwn=not owner or owner==n or f>torso.untilFrame
 if owner and owner~=n and(Spring.GetUnitWeaponTarget(unitID,owner)or 0)==0 then canOwn=true end
 local wantedH,wantedP=canOwn and h or torso.heading,canOwn and p or torso.pitch
 local goal=torsoGoal(wantedH,wantedP,currentRow)
 local lh,lp=localAngles(h,p,goal,currentRow[torso.parentIndex],currentRow[torso.bodyIndex])
 if not torsoWithin(m,lh,lp)then return end
 if canOwn then
  if torso.owner~=n or torso.heading==nil or math.abs(wrapAngle(h-torso.heading))>1e-6 or math.abs(p-torso.pitch)>1e-6 then
   torso.epoch=torso.epoch+1
   for _,other in ipairs(mounts)do other.clearanceAllowed=false end
  end
  torso.owner,torso.heading,torso.pitch=n,h,p
  local preparation=m.clip and(m.clip.shot_cue or 0)/fps(m.clip)or 0
  torso.untilFrame=f+math.max(45,math.ceil(preparation*30)+15)
 end
 m.torsoHeading,m.torsoPitch,m.torsoEpoch=h,p,torso.epoch
 m.clearanceAllowed=false
 return torso.epoch
end
local function actualTorsoAngles(h,p)
 local US=Spring.UnitScript
 local px,py,pz=US.GetPieceRotation(torso.parentPiece)
 local _,yaw=US.GetPieceRotation(torso.piece)
 local sx,sy,sz=US.GetPieceRotation(torso.bodyPiece)
 if not(finiteAngle(px)and finiteAngle(py)and finiteAngle(pz)and finiteAngle(yaw)and finiteAngle(sx)and finiteAngle(sy)and finiteAngle(sz))then return end
 return localAngles(h,p,yaw,{0,0,0,px,py,pz},{0,0,0,sx,sy,sz})
end
-- Tracking changes tiny compensated goals continuously. Native burst admission
-- checks actual physical alignment instead of requiring compensation to stop.
-- 0.001rad (0.0573deg) is <2% of the unchanged3deg local envelope; native
-- angleGood/target/range/LOF/reload and actual local cone still own firing.
local torsoTrackingError=0.001
local function torsoReady(n,m,nativeVector)
 if not m or m.torsoEpoch~=torso.epoch or not m.torsoHeading then return false,'stale_torso_epoch' end
 local US=Spring.UnitScript
 local turning=US.IsInTurn(torso.piece,y_axis)or US.IsInTurn(m.yaw,y_axis)or US.IsInTurn(m.pitch,x_axis)
 if turning and not nativeVector then return false,'aim_turn_pending',turning end
 local h,p=m.torsoHeading,m.torsoPitch
 if nativeVector then
  local _,_,_,x,y,z=Spring.GetUnitWeaponVectors(unitID,n)
  local front,up,right=Spring.GetUnitVectors(unitID)
  if not(finiteAngle(x)and finiteAngle(y)and finiteAngle(z)and front and up and right)then return false,'native_vector_missing',turning end
  local length=math.sqrt(x*x+y*y+z*z);if length<1e-9 then return false,'native_vector_zero',turning end
  local function dot(v)return(x*v[1]+y*v[2]+z*v[3])/length end
  h=-math.atan2(dot(right),dot(front));p=math.asin(math.max(-1,math.min(1,dot(up))))
 end
 local lh,lp=actualTorsoAngles(h,p)
 if lh==nil or not torsoWithin(m,lh,lp)then return false,'actual_target_outside_local_cone',turning,lh,lp end
 if not nativeVector then return true,'aim_settled',turning,lh,lp end
 local gx,gy,gz=US.GetPieceRotation(m.yaw)
 if not(finiteAngle(gx)and finiteAngle(gy)and finiteAngle(gz))then return false,'actual_gun_rotation_missing',turning,lh,lp end
 if not torsoWithin(m,gy,-gx)then return false,'actual_gun_outside_local_cone',turning,lh,lp,gx,gy,gz end
 -- Compare full canonical YXZ physical directions; source recoil remains on
 -- its real descendant bones, and actual parent/hip/body rotations are read.
 local tx,ty,tz=aimVector(lh,lp)
 local x,y,z=rotateYXZ(0,0,1,gx,gy,gz)
 local cosine=math.max(-1,math.min(1,x*tx+y*ty+z*tz))
 local error=math.acos(cosine)
 if not finiteAngle(error)or error>torsoTrackingError then return false,'actual_tracking_error',turning,lh,lp,gx,gy,gz,error end
 return true,'actual_aligned',turning,lh,lp,gx,gy,gz,error
end
local function clearOffset(p,a) if aimOffsets[p] then aimOffsets[p][a]=nil end end
local function sourceTurn(p,a,value,speed)
 if not poseJumpActive and aimOffsets[p] and aimOffsets[p][a] then return false end
 Turn(p,a,value,speed);return true
end
if aircraftReview or aircraftDomain then aircraftAim=VFS.Include('scripts/40k_ork_aircraft_aim.lua')(lookup,setOffset,WaitForTurn,x_axis,y_axis)end
local function apply(row,interpolate)
 if gaitProbe then gaitProbe.Invalidate(unitID)end
 currentRow=row;poseJumpActive=jumpState()~=nil
 if torso then updateTorsoOffsets(row)end
 buffers.Apply(row,bones,Move,sourceTurn,interpolate)
 if poseJumpActive then aimApplied={};return end
 -- Aim-owned axes are never overwritten by source animation. Source local
 -- rotation is retained as an additive canonical-axis offset where appropriate.
 for p,axes in pairs(aimOffsets) do
  local poseIndex=poseIndexByPiece[p]
  for a,v in pairs(axes) do
   local angle=v[1]+(not(boomyAim and boomyAim.AbsoluteAxis(p,a))and poseIndex and row[poseIndex][a+3]or 0)
   aimApplied[p]=aimApplied[p] or {}
   if aimApplied[p][a]~=angle then Turn(p,a,angle,v[2]);aimApplied[p][a]=angle end
  end
 end
end
local function transition(frame)
 local mirror=GG.Prototype40kTransitionState
 local label,start,finish
 if type(mirror)=='table' and type(mirror.known)=='table' and type(mirror.values)=='table' and mirror.known[unitID] then
  local state=mirror.values[unitID]
  if state then label,start,finish=state[1],tonumber(state[2]),tonumber(state[3]) end
 else
  label=Spring.GetUnitRulesParam(unitID,'40k_transition_clip')
  start=tonumber((Spring.GetUnitRulesParam(unitID,'40k_transition_start')))
  finish=tonumber((Spring.GetUnitRulesParam(unitID,'40k_transition_end')))
 end
 local clip=type(label)=='string' and data.clips[label]
 if not start or not finish or frame<start or frame>=finish then return nil end
 if not clip then warn('transition:'..tostring(label),'Transition source clip missing: '..tostring(label)..'; holding last source pose with movement/attack locked') end
 return clip or true,start
end
local function cancelMelee()
 if currentMelee then currentMelee.pending=nil;currentMelee.pendingTarget=nil;currentMelee.contactReady=nil;currentMelee.impact=nil;currentMelee=nil end
end
-- Read the live controller at each native callback and after source windup.
local function wraithAttackAllowed()
 local A=GG.Recoil40KWraithReview
 return not wraithReview or A and A.CanAttack(unitID,now())==true or false
end
-- Read-only opt-in native execution witness; source clocks/returns are unchanged.
local function wraithBoundary(kind,n,m,pendingStart)
 if not wraithReview then return end
 local opts=Spring.GetModOptions()or{}
 if tostring(opts.prototype_wraith_witness)~='1'or not GG or type(GG.Recoil40KWraithWitness)~='function'then return end
 GG.Recoil40KWraithWitness('SCRIPT_ATTACK_BOUNDARY',unitID,kind,n,now(),pendingStart,m and m.pending,currentMelee==m,m and m.preparingStart)
end
local function wraithCancelBoundary(n,m)
 local pendingStart=m and m.pending
 wraithBoundary('phase_cancel_before',n,m,pendingStart)
 cancelMelee()
 wraithBoundary('phase_cancel_after',n,m,pendingStart)
end
local function meleePose(frame)
 local m=currentMelee
 if not m then return nil end
 local contactAge=(m.contact-1)/fps(m.clip)
 if m.impact then
  local age=contactAge+(frame-m.impact)/30
  if age<duration(m.clip) then return sample(m.clip,age,false),m end
  m.impact=nil;currentMelee=nil;return nil
 end
 if m.pending then
  local age=(frame-m.pending)/30
  if age>contactAge+1.5 then cancelMelee();return nil end
  return sample(m.clip,math.min(age,contactAge),false),m
 end
end
-- Optional authentic secondary crew actions, restricted to explicitly named
-- crew bones. Source frames stay immutable; gun/first-crew channels stay owned
-- by their existing source/aim clocks. Missing source/masks safely hold base.
local secondaryCrew={}
local secondaryPrefix=cp.source_secondarycrew_prefix
local function secondaryClip(label)
 if not label or type(secondaryPrefix)~='string' or #secondaryPrefix==0 then return nil end
 local clip=data.clips[label]
 if not clip or not clip.keyed_channels then warn('secondary:'..label,'Secondary crew source clip/mask missing: '..label);return nil end
 local filtered={keyed_channels={}}
 local count=0
 for i,name in ipairs(data.bones) do
  local m=clip.keyed_channels[i]
  local belongs=name:sub(1,#secondaryPrefix)==secondaryPrefix
  local p=belongs and m and m.position or false
  local r=belongs and m and m.rotation or false
  filtered.keyed_channels[i]={position=p,rotation=r}
  if p or r then count=count+1 end
 end
 if count==0 then warn('secondary:'..label,'Secondary crew source clip has no keyed crew channels: '..label);return nil end
 return {source=clip,mask=filtered,ticks=0}
end
secondaryCrew.idle=secondaryClip(cp.source_secondarycrew_idleclip)
secondaryCrew.fire=secondaryClip(cp.source_secondarycrew_fireclip)
local function secondaryPose(row,f)
 local firing=false
 for n,m in ipairs(mounts) do
  if not m.passive and not m.melee and m.clip and
   (m.preparingStart or f<m.readyUntil or (Spring.GetUnitWeaponTarget(unitID,n) or 0)~=0 or (m.lastShot and (f-m.lastShot)/30<duration(m.clip))) then firing=true;break end
 end
 local selected=(firing and secondaryCrew.fire) or secondaryCrew.idle
 if not selected then return row end
 local composed=buffers.Overlay(selected.mask,sample(selected.source,selected.ticks/30,true),row,'secondarycrew')
 selected.ticks=selected.ticks+1
 return composed
end
local clothPose
if cp.source_cloth_bones then
 GG.Prototype40kClothFactory=GG.Prototype40kClothFactory or VFS.Include('scripts/40k_source_cloth.lua')
 clothPose=GG.Prototype40kClothFactory(data,cp,buffers,sample,warn)
end
local orkHQNative,orkHQGate
if tostring(cp.source_ork_hq_native)=='1' then
 assert(ud.isFactory==true,'Genuine HQ must retain pinned native factory classification')
 local H=VFS.Include('40k_configs/ork_hq_allmesh_review.lua')
 local facts=VFS.Include('40k_configs/ork_hq_allmesh_review_facts.lua')
 local sourceProfiles=VFS.Include('40k_configs/primary_variant_progression.lua').SourceProfiles
 orkHQGate=H.Runtime(Spring,UnitDefs,facts,{
  WholeProfileReady=function(key)
   local C=GG.Recoil40KResearch;local manager=C and C.sourceVariantModifiers
   return manager and manager.EffectSupported(key,sourceProfiles[key])==true or false
  end,
  AppliedLocal=function(id,team,key,sourceSHA)
   local C=GG.Recoil40KResearch;local manager=C and C.sourceVariantModifiers
   return manager and Spring.GetUnitRulesParam(id,'40k_source_addon_source_'..key)==tonumber(sourceSHA:sub(1,6),16)
    and manager.IsApplied(team,key,id)==true or false
  end,
 })
 local meta=VFS.Include('scripts/generated/'..cp.source_native_pieces)
 orkHQNative=VFS.Include('scripts/40k_ork_hq_native_runtime.lua').New(meta,data,{
  resolve=lookup,show=Show,hide=Hide,frame=now,
  progress=function()local _,_,_,_,built=Spring.GetUnitHealth(unitID);return built end,
  level=function()return orkHQGate.CompletedLevel(unitID)end,
 })
end
local function weaponsBuilding()return building and not orkHQNative end
local marineNative
if cp.source_native_pieces and not orkHQNative then
 local meta=VFS.Include('scripts/generated/'..cp.source_native_pieces)
 marineNative=VFS.Include('scripts/40k_marine_native_runtime.lua').New(meta,data,{
  resolve=lookup,show=Show,hide=Hide,isFactory=ud.isFactory,
  observe=tostring(sourceOptions.prototype_factory_pose_review)=='1'and function(stage,frame,product,ready)
   Spring.SetUnitRulesParam(unitID,'40k_source_factory_stage',stage,{public=true})
   Spring.SetUnitRulesParam(unitID,'40k_source_factory_stage_frame',frame,{public=true})
   Spring.Echo('40K SOURCE FACTORY STAGE',unitID,source,stage,frame,product,ready)
  end or nil,
  stance=function(ready)SetUnitValue(COB.INBUILDSTANCE,ready and 1 or 0)end,
  product=function()return Spring.GetUnitIsBuilding(unitID)end,
  queued=function()local q=Spring.GetFactoryCommands(unitID,1);return q and q[1]and q[1].id<0 end,
  addon=function(key)
   local C=GG.Recoil40KResearch;local a=C and C.sourceVariantAdapter
   return a and a.LocalAddon(unitID,Spring.GetUnitTeam(unitID),key)or false
  end,
 })
end
local zero={}
for i=1,#bones do zero[i]={0,0,0,0,0,0} end
local renderInterpolation=dakkaGait~=nil or(walkQualityEligible and walkQualityOption('prototype_animation_interpolation'))
local previousWalkPhase
local function tick()
 local idleSamplePhase=idlePhase
 local walkSamplePhase=walkPhase
 local walkReviewPhase=walkPhase
 local f=now();local idle=data.clips.idle;local jump=jumpState()
 if servoSkull then servoSkull.Tick(f)end
 local marineClip,marineAge,orkConstruction,orkConstructionAge
 if orkHQNative then orkConstruction,orkConstructionAge,idle=orkHQNative.Tick(f);idle=idle or data.clips.idle end
 if marineNative then marineClip,marineAge,idle=marineNative.Tick(f)end
 if hasStockpile and f%6==0 then updateStockpile() end
 local base=idle and sample(idle,idlePhase,true) or zero
 if primaryCompletedPose then base=primaryCompletedPose(base,idleSamplePhase,'idle')end
 if idle and not jump then idlePhase=(idlePhase+1/30)%duration(idle) end
 if jump or transition(f)or weaponsBuilding()then
  for _,m in ipairs(mounts)do if m.phaseClock then m.phaseClock.SetInterrupted(f,true)end end
 end
 local row,mode=base,'idle'
 local change,start=transition(f)
 if jump then
  mode='jump';cancelMelee()
  local label=cp['jump_'..tostring(jump.stage)..'_clip']
  local clip=label and data.clips[label]
  if clip then row=sample(clip,(f-jump.stageStart)/30,jump.stage=='air')
  else warn('jump:'..tostring(label),'Genuine jump source pose missing; holding last pose and inhibiting weapons');row=currentRow or base end
 elseif change then
  mode='transition';cancelMelee()
  if not transitionWasActive and COB.MAX_SPEED and GetUnitValue then savedSpeed=GetUnitValue(COB.MAX_SPEED);SetUnitValue(COB.MAX_SPEED,0) end
  transitionWasActive=true;row=type(change)=='table' and sample(change,(f-start)/30,false) or currentRow or base
 else
  if transitionWasActive then
   if savedSpeed then SetUnitValue(COB.MAX_SPEED,savedSpeed);savedSpeed=nil end
   transitionWasActive=false;blendStart=f;blendFrom=buffers.Snapshot(currentRow)
  end
  local walk=data.clips.walk
  if moving and walk then
   mode='walk';row=dakkaGait and dakkaGait.Sample(walkPhase)or(fractionalWalk and sampleWalk(walk,walkPhase)or sample(walk,walkPhase,true))
   local vx,_,vz=Spring.GetUnitVelocity(unitID);vx,vz=vx or 0,vz or 0
   local speed=math.sqrt(vx*vx+vz*vz)*30
   walkPhase=(walkPhase+speed/(dakkaGait and dakkaGait.StrideSpeed or math.max(.001,tonumber(data.walkspeed)or 24))/30)%duration(walk)
  end
  if weaponsBuilding()and not marineNative then
   if ud.isFactory then
    -- Construction belongs to the nanoframe/native construction controller.
    -- A completed factory uses genuine production, or continues its idle clock.
    local clip=data.clips[cp.source_productionclip or 'production']
    if clip then mode='build';row=buffers.Overlay(clip,sample(clip,(f-buildStart)/30,true),base,'build') end
   else
    mode='build';local clip=data.clips[cp.source_buildclip or 'build'] or data.clips.repair
    if clip then row=buffers.Overlay(clip,sample(clip,(f-buildStart)/30,true),base,'build') end
   end
  end
  if(not moving or torso)and not weaponsBuilding()then
   for n,m in ipairs(mounts) do
    if not m.melee and m.clip then
     local sourcePose=m.phaseClock and m.phaseClock.Sample(f,false)
     local bodyStart=bodyStarts[m.clip]
     local recovering=bodyStart and (f-bodyStart)/30<duration(m.clip)
     if sourcePose then
      mode='fire'
      if m.bodyRecovery and bodyRendered[m.clip]~=f then row=buffers.Overlay(m.clip,sourcePose,row,'sustainedbody'..n);bodyRendered[m.clip]=f end
      row=m.buffers.Arms(row,sourcePose,m.clip,'sustainedarms')
     elseif recovering and m.bodyRecovery then
      mode='fire'
      if bodyRendered[m.clip]~=f then row=buffers.Overlay(m.clip,sample(m.clip,(f-bodyStart)/30,true,m.clip.shot_cue or 0),row,'body'..n);bodyRendered[m.clip]=f end
     elseif m.preparingStart then
      mode='prepare';local prepared=sample(m.clip,math.min((f-m.preparingStart)/30,(m.clip.shot_cue or 0)/fps(m.clip)),false)
      if m.bodyRecovery then row=buffers.Overlay(m.clip,prepared,row,'prepare'..n) else row=m.buffers.Arms(row,prepared,m.clip,'prepare') end
     elseif f<m.readyUntil or (Spring.GetUnitWeaponTarget(unitID,n) or 0)~=0 then
      mode='aim'
      local hold=sample(m.clip,0,false,m.clip.shot_cue or 0)
      if m.bodyRecovery then
       if bodyRendered[m.clip]~=f then row=buffers.Overlay(m.clip,hold,row,'hold'..n);bodyRendered[m.clip]=f end
      else row=m.buffers.Arms(row,hold,m.clip,'hold') end
     elseif orkHQNative and not orkConstruction then
      local sourceIdle=data.clips[m.params.source_idleclip or '']
      if sourceIdle then row=m.buffers.Arms(row,sample(sourceIdle,(f-orkHQNative.created)/30,true),sourceIdle,'orkidle'..n)end
     end
     if not m.phaseClock and m.lastShot and (f-m.lastShot)/30<duration(m.clip) then
      row=m.buffers.Arms(row,sample(m.clip,(f-m.lastShot)/30,true,m.clip.shot_cue or 0),m.clip,'shot')
     end
    end
   end
  end
  if torso and moving and walk then mode='walk'end
  if (secondaryCrew.idle or secondaryCrew.fire) and not moving and not weaponsBuilding()then row=secondaryPose(row,f) end
  if orkConstruction then row=buffers.Overlay(orkConstruction,sample(orkConstruction,orkConstructionAge,false),base,'orkconstruction');mode='build' end
  if marineNative then
   row=marineClip and buffers.Overlay(marineClip,sample(marineClip,marineAge,false),base,'marineproduction')or base
   mode=marineClip and'marineproduction'or'idle'
  end
  local melee,m=meleePose(f)
  if melee then mode='melee';row=buffers.Overlay(m.clip,melee,base,'melee') end
 end
 if primaryCompletedPose and(mode=='idle'or mode=='walk')then row=primaryCompletedPose(row,idleSamplePhase,'anchors')end
 local smoothWalk=renderInterpolation and (role=='infantry' or role=='builder'or dakkaGait~=nil)
  and mode=='walk' and previousMode=='walk' and previousWalkPhase~=nil
  and (fractionalWalk or walkSamplePhase>=previousWalkPhase)
 previousWalkPhase=mode=='walk' and walkSamplePhase or nil
 if mode~=previousMode then
  if mode~='melee' and mode~='transition' and mode~='jump' and (mode=='walk' or mode=='idle' or previousMode=='walk' or previousMode=='idle' or previousMode=='melee' or previousMode=='build' or previousMode=='transition') then blendStart=f;blendFrom=buffers.Snapshot(currentRow) end
  previousMode=mode
 end
 if mode~='melee' and mode~='transition' and mode~='jump' and blendFrom and f-blendStart<6 then row=buffers.Blend(row,blendFrom,(f-blendStart)/6) end
 if recordWalkPhase and mode=='walk' and f-blendStart>=6 then
  recordWalkPhase(unitID,source,f,walkReviewPhase,data.clips.walk,fractionalWalk)
 end
 if clothPose then
  local age=mode=='walk' and walkSamplePhase or idleSamplePhase
  if mode=='melee' and currentMelee then
   local m=currentMelee
   age=m.impact and (m.contact-1)/fps(m.clip)+(f-m.impact)/30 or math.min((f-(m.pending or f))/30,(m.contact-1)/fps(m.clip))
  end
  row=clothPose(row,mode,age)
 end
 if dakkaRecoil then row=dakkaRecoil.Overlay(row,f)end
 apply(row,smoothWalk and f-blendStart>=6)
 if publishGait and mode=='walk'and f-blendStart>=6 then
  local aim={};local layers={'walk'}
  if clothPose then layers[#layers+1]='cloth'end
  if primaryCompletedPose then layers[#layers+1]='completed_anchors'end
  local aimed=false
  for p,axes in pairs(aimOffsets)do
   local i=poseIndexByPiece[p]
   if i then
    local witness={}
    for a,v in pairs(axes)do witness[a]={offset=v[1],submitted=row[i][a+3]+v[1]};aimed=true end
    if next(witness)then aim[data.bones[i]]=witness end
   end
  end
  if aimed then layers[#layers+1]='aim_offsets'end
  local vx,vy,vz=Spring.GetUnitVelocity(unitID)
  publishGait({frame=f,mode=mode,clip='walk',rootName=cp.root_bone or data.root_bone or data.bones[1],
   sampleSeconds=walkSamplePhase,fps=fps(data.clips.walk),count=#data.clips.walk.frames,
   fractional=not not fractionalWalk,smooth=not not(smoothWalk and f-blendStart>=6),
   stride=math.max(.001,tonumber(data.walkspeed)or 24),blendAge=f-blendStart,blendAlpha=1,
   velocity={vx or 0,vy or 0,vz or 0},layers=layers,aim=aim},row)
  local gait=GG.Recoil40KGaitMovementFixture
  if gait and gait.ObservePublished then gait.ObservePublished(unitID,f)end
  if GG.Recoil40KNativeGaitObserve then GG.Recoil40KNativeGaitObserve(f)end
 end
 if primaryCompletedPose and GG.Recoil40KPrimaryPoseWitness then GG.Recoil40KPrimaryPoseWitness(unitID,source,f,row,mode)end
end
local function animate() while true do tick();Sleep(33) end end
function script.Create()
 if servoSkull then servoSkull.Create()end
 if orkHQNative then orkHQNative.Create()end
 updateStockpile()
 for n,m in ipairs(mounts) do
  if m.passive then
   if not m.enabled and Spring.SetUnitShieldState then Spring.SetUnitShieldState(unitID,n,false) end
   if diagnostic then Spring.SetUnitRulesParam(unitID,'40k_passive_mount_'..n,m.enabled and 1 or -1,{public=true}) end
  end
 end
 for _,name in ipairs(words(cp.transport_slots)) do local p=lookup(name);if p then slots[#slots+1]=p end end
 if #slots==0 then slots[1]=lookup(cp.source_transportpiece) or lookup('marker_compartment') or root end
 StartThread(animate)
end
function script.StartMoving()
 moving=true;cancelMelee()
 for clip in pairs(bodyStarts) do bodyStarts[clip]=nil end
 for _,m in ipairs(mounts) do if not torso then m.lastShot=nil;m.preparingStart=nil;if m.phaseClock then m.phaseClock.SetInterrupted(now(),true)end end end
 if wholeBody or dakkaRecoil then setOffset(aimRoot,y_axis,0,6) end
 if transition(now()) and COB.MAX_SPEED and GetUnitValue and not savedSpeed then savedSpeed=GetUnitValue(COB.MAX_SPEED);SetUnitValue(COB.MAX_SPEED,0);transitionWasActive=true end
end
function script.StopMoving() moving=false;for _,m in ipairs(mounts)do if m.phaseClock then m.phaseClock.SetInterrupted(now(),false)end end end
function script.QueryWeapon(n)
 local m=mounts[n];if not m then return root end
 local handle=(not m.pairInvalid and m.pair[m.pairIndex]) or m.muzzle
 m.queriedMuzzle=handle -- repeated queries hold this barrel until a real Shot.
 if GG.Recoil40KStompaWeaponWitness then GG.Recoil40KStompaWeaponWitness.Query(unitID,n,handle)end
 if GG.Recoil40KSentinelWeaponWitness then GG.Recoil40KSentinelWeaponWitness.Query(unitID,n,handle)end
 if GG.Recoil40KWalkerBurstWitness then GG.Recoil40KWalkerBurstWitness.Query(unitID,n,handle)end
 return handle
end
function script.AimFromWeapon(n)
 local m=mounts[n]
 -- Explicit normal-play emitter origin: native aim/terrain tests must start at
 -- the actual mounted weapon, not the ground-level whole-body yaw node.
 if m and tostring(m.params.source_aimfrom_muzzle)=='1' and not m.passive and not m.melee then
  return(not m.pairInvalid and m.pair[m.pairIndex])or m.muzzle
 end
 local review=sourceEvidence or(sourceOptions.prototype_diagnostic=='six'and tostring(sourceOptions.prototype_runtime_library_review)=='1')
 if m and review and not m.passive and not m.melee and(wholeBody or tostring(m.params.source_wholebodyaim)=='1')then
  return(not m.pairInvalid and m.pair[m.pairIndex])or m.muzzle
 end
 return m and(m.passive and m.muzzle or m.yaw)or aimRoot
end
function script.BlockShot(n)
 if boomyAim and(n~=1 or not mounts[n]or mounts[n].boomyAimAllowed~=true or not boomyAim.BlockAllowed(Spring,Spring.UnitScript,unitID,n))then return true end
 if torso then
  local m=mounts[n]
  local ready,reason,turning,h,p,gx,gy,gz,error=torsoReady(n,m,true)
  -- Existing diagnostic only, max24 transition/90frame rows per actual mount.
  -- No normal-play log, new controller, mutation or native acceptance claim.
  if diagnostic and m and(m.torsoGateRows or 0)<24 and(m.torsoGateReason~=reason or m.torsoGateReady~=ready or not m.torsoGateFrame or now()-m.torsoGateFrame>=90)then
   m.torsoGateRows=(m.torsoGateRows or 0)+1;m.torsoGateReason=reason;m.torsoGateReady=ready;m.torsoGateFrame=now()
   Spring.Echo('40K_TORSO_ADMISSION actor='..unitID..' source='..source..' slot='..n..' frame='..now()..' ready='..tostring(ready)..' reason='..tostring(reason)..' turning='..tostring(turning)..' owner='..tostring(torso.owner)..' epoch='..torso.epoch..' mount_epoch='..tostring(m.torsoEpoch)..' target_local='..tostring(h)..','..tostring(p)..' gun_rotation='..tostring(gx)..','..tostring(gy)..','..tostring(gz)..' direction_error='..tostring(error)..' error_limit='..torsoTrackingError..' clearance_allowed='..tostring(m.clearanceAllowed)..' aim_enabled='..tostring(m.aimEnabled)..' validation_mount='..tostring(Spring.GetUnitRulesParam(unitID,'40k_validation_mount'))..' native_gate_overrides=false')
  end
  if not ready then return true end
 end
 if mounts[n]and(not mounts[n].clearanceAllowed or not clearance.FireAllowed(Spring,unitID,n,mounts[n].clearanceSide,mounts[n].clearanceLimits))then return true end
 if aircraftReview and GG.Recoil40KNukklearBombard and GG.Recoil40KNukklearBombard.Busy(unitID,Spring.GetGameFrame())then return true end
 if mounts[n]and mounts[n].params.source_minrange and primaryMinrange and primaryMinrange(Spring,unitID,n,tonumber(mounts[n].params.source_minrange))then return true end
 if wraithReview and not wraithAttackAllowed()then return true end
 if orkHQGate and not orkHQGate.WeaponAllowed(unitID,n)then return true end
 if dakkaRecoil and moving and mounts[n]and tostring(mounts[n].params.source_wholebodyaim)=='1'then return true end
 if mounts[n] and mounts[n].passive then return true end
 if diagnostic then local permit=Spring.GetUnitRulesParam(unitID,'40k_validation_mount');if permit~=nil and permit~=n then return true end end
 return jumpState()~=nil or transition(now())~=nil or weaponsBuilding()or (mounts[n] and not mounts[n].aimEnabled) or (currentMelee~=nil and not (mounts[n] and mounts[n].melee))
end
-- BAR's shield wrapper calls AimShield, separately from offensive AimWeapon.
if cp.prototype40k_commander_shield=='native_corgate_half_standard_cost_v2'then
 function script.AimShield(n)
  local m=mounts[n]
  return m~=nil and m.passive and m.enabled and Spring.GetUnitRulesParam(unitID,'40k_commander_shield_active')==1
 end
end
function script.AimWeapon(n,h,p)
 local clearanceMount=mounts[n]
 if torso and clearanceMount then clearanceMount.clearanceAllowed=false end
 if clearanceMount and not torso then
  if clearanceMount.clearanceSide then clearanceMount.clearanceRequest=(clearanceMount.clearanceRequest or 0)+1 end
  clearanceMount.clearanceAllowed=clearanceMount.clearanceSide==nil
  if not clearance.Allows(clearanceMount.clearanceSide,h,p,clearanceMount.clearanceLimits)then return false end
 end
 local clearanceRequest=clearanceMount and clearanceMount.clearanceRequest
 if wraithReview and not wraithAttackAllowed()then cancelMelee();return false end
 if orkHQGate and not orkHQGate.WeaponAllowed(unitID,n)then return false end
 if jumpState() then return false end
 local m=mounts[n]
 local boomyH,boomyX
 if boomyAim then
  if m then m.boomyAimAllowed=false end
  boomyH,boomyX=boomyAim.Resolve(n,h,p)
  if boomyH==nil then Signal(2^n);return false end
 end
 local ownedContact=source=='ork_slugga' or (source=='ork_kustim_hammer_candidate' and n==3 and cp.kustim_hammer_runtime_required=='kustim_completed_contact_reaim_v1' and m and m.params.source_contact_method=='literal_EBP_special_attack_02_area_effect_time' and m.contact==62 and m.clip and m.clip.source=='special_attack_2' and m.clip.source_fps==30)
 if m and m.passive then
  if cp.prototype40k_commander_shield then
   return m.enabled and Spring.GetUnitRulesParam(unitID,'40k_commander_shield_active')==1
  end
  return m.enabled
 end
 if diagnostic and testMount then return testMount==n end
 if not m or not m.aimEnabled or transition(now()) or weaponsBuilding()or (moving and(wholeBody or(dakkaRecoil and tostring(m.params.source_wholebodyaim)=='1'))) then return false end
 if currentMelee and currentMelee~=m then return false end
 -- Recoil re-aims during long source windups. A new callback must not
 -- cancel the live contact thread; movement/target checks still gate its result.
 if m.melee and currentMelee==m and m.pending then
  if not ownedContact then return false end
  -- BAR wraps every AimWeapon return in a native aimReady write. Preserve
  -- the completed contact hold on re-aim, without restarting its source clock.
  local targetType,_,targetID=Spring.GetUnitWeaponTarget(unitID,n)
  local age=(now()-m.pending)/30
  local contactAge=(m.contact-1)/fps(m.clip)
  local ready=m.enabled and not m.impact and m.contactReady==true and age<=contactAge+1.5 and targetType==1 and targetID==m.pendingTarget
  if diagnostic and (m.sluggaReadyLogs or 0)<24 and (m.sluggaReadyState~=ready or not m.sluggaReadyTrace or now()-m.sluggaReadyTrace>=30) then
   m.sluggaReadyState=ready;m.sluggaReadyTrace=now();m.sluggaReadyLogs=(m.sluggaReadyLogs or 0)+1
   Spring.Echo('40K SLUGGA CONTACT REAIM',unitID,n,'frame',now(),'pending',m.pending,'contactAge',contactAge,'target',targetID,'ownedTarget',m.pendingTarget,'ready',ready,'native_write_follows_return',true)
  end
  if targetType~=1 or targetID~=m.pendingTarget then cancelMelee();return false end
  return ready
 end
 local torsoEpoch
 if torso then torsoEpoch=claimTorso(n,m,h,p);if not torsoEpoch then return false end end
 Signal(2^n);SetSignalMask(2^n)
 if diagnostic and (not m.aimTrace or now()-m.aimTrace>90) then
  m.aimTrace=now();Spring.Echo('40K ROSTER AIM',unitID,n,'enter',now(),h,p)
 end
 local settle=now()>=m.readyUntil
 m.heading=h;m.pitchAngle=-p;m.readyUntil=now()+30
 if torso then updateTorsoOffsets(currentRow)else
  setOffset(m.yaw,y_axis,boomyH or h,tonumber(m.params.source_aimspeed) or 3)
  if m.pitch then setOffset(m.pitch,x_axis,boomyX or -p,2) end
  if boomyAim then setOffset(boomyAim.Barrel,x_axis,boomyAim.BarrelRestX,2)end
 end
 if aircraftAim and not aircraftAim.Aim(m,h,p)then return false end
 if settle and m.clip and not m.melee then
  m.preparingStart=now();wraithBoundary('preparation_started',n,m,m.pending)
  local preparation=(m.clip.shot_cue or 0)/fps(m.clip)
  m.readyUntil=now()+math.ceil(preparation*30)+30
  Sleep(math.max(200,math.ceil(preparation*1000)))
  m.preparingStart=nil
  if orkHQGate and not orkHQGate.WeaponAllowed(unitID,n)then return false end
  if wraithReview and not wraithAttackAllowed()then cancelMelee();return false end
  if jumpState() or transition(now()) or (moving and(wholeBody or(dakkaRecoil and tostring(m.params.source_wholebodyaim)=='1'))) then return false end
  local held=sample(m.clip,0,false,m.clip.shot_cue or 0)
  if m.bodyRecovery then apply(buffers.Overlay(m.clip,held,currentRow or zero,'settled'..n)) else apply(m.buffers.Arms(currentRow or zero,held,m.clip,'settled')) end
 elseif currentRow then apply(currentRow) end
 if torso then WaitForTurn(torso.piece,y_axis)end
 WaitForTurn(m.yaw,y_axis);if m.pitch then WaitForTurn(m.pitch,x_axis) end
 if torso and(torsoEpoch~=torso.epoch or not torsoReady(n,m,false))then return false end
 if clearanceRequest~=m.clearanceRequest then return false end
 m.clearanceAllowed=true
 if aircraftAim then aircraftAim.Wait(m)end
 if diagnostic then Spring.Echo('40K ROSTER AIM',unitID,n,'after_wait',now()) end
 if orkHQGate and not orkHQGate.WeaponAllowed(unitID,n)then return false end
 if wraithReview and not wraithAttackAllowed()then cancelMelee();return false end
 if jumpState() or transition(now()) or (moving and(wholeBody or(dakkaRecoil and tostring(m.params.source_wholebodyaim)=='1'))) then return false end
 if boomyAim then WaitForTurn(boomyAim.Barrel,x_axis);m.boomyAimAllowed=true end
 if m.melee then
  if not m.enabled or now()<m.nextWindup or m.impact then return false end
  if ownedContact then
   local targetType,_,targetID=Spring.GetUnitWeaponTarget(unitID,n)
   if targetType~=1 or type(targetID)~='number' then return false end
   m.pendingTarget=targetID;m.contactReady=nil
  end
  currentMelee=m;m.pending=m.pending or now();wraithBoundary('pending_melee',n,m,m.pending)
  local contactAge=(m.contact-1)/fps(m.clip)
  local remaining=contactAge-(now()-m.pending)/30
  if remaining>0 then Sleep(math.ceil(remaining*1000)) end
  if orkHQGate and not orkHQGate.WeaponAllowed(unitID,n)then cancelMelee();return false end
  local targetType,_,targetID=Spring.GetUnitWeaponTarget(unitID,n)
  if diagnostic and (not m.readyTrace or now()-m.readyTrace>90) then
   m.readyTrace=now();Spring.Echo("40K MELEE READY CHECK",unitID,n,"current",currentMelee==m,"pending",m.pending,"moving",moving,"transition",transition(now())~=nil,"targetType",targetType,"frame",now())
  end
  if wraithReview and not wraithAttackAllowed()then wraithCancelBoundary(n,m);return false end
  if currentMelee~=m or not m.pending or moving or jumpState() or transition(now()) or targetType~=1 then cancelMelee();return false end
  if ownedContact and (targetID~=m.pendingTarget or not m.enabled or not m.aimEnabled or weaponsBuilding()) then cancelMelee();return false end
  apply(buffers.Overlay(m.clip,m.clip.frames[m.contact],data.clips.idle and data.clips.idle.frames[1] or zero,'contact'))
  if ownedContact then m.contactReady=true end
  if source=='ork_slugga' and diagnostic and (m.sluggaReadyLogs or 0)<24 then m.sluggaReadyLogs=(m.sluggaReadyLogs or 0)+1;Spring.Echo('40K SLUGGA CONTACT COMPLETE',unitID,n,'frame',now(),'pending',m.pending,'target',targetID,'ready',true,'native_write_follows_return',true) end
 end
 return true
end
function script.FireWeapon(n)
 if orkHQGate and not orkHQGate.WeaponAllowed(unitID,n)then return end
 if wraithReview and not wraithAttackAllowed()then cancelMelee();return end
 local m=mounts[n]
 if not sustainedFactory or not m or not m.bodyRecovery or m.passive or m.melee or not m.clip or moving or weaponsBuilding()or jumpState()or transition(now())then return end
 -- Native readback includes actual XP reload scaling, in seconds. No timing
 -- guess from source clip length and no projectile/effect authorization here.
 local reload=Spring.GetUnitWeaponState and Spring.GetUnitWeaponState(unitID,n,'reloadTimeXP')
 if type(reload)~='number'or reload<=0 then warn('phase'..n,'Actual native reload unavailable; source phase review refused');return end
 local interval=math.max(1,math.ceil(reload*30))
 if not m.phaseClock then
  local reason;m.phaseClock,reason=sustainedFactory.New(m.clip,{kind='ranged',native_fire_interval_frames=interval})
  if not m.phaseClock then warn('phase'..n,'Source sustained phase refused: '..tostring(reason));return end
 end
 m.phaseClock.SetInterrupted(now(),false)
 m.phaseClock.OnFireWeapon(now(),interval)
end
function script.Shot(n)
 if orkHQGate and not orkHQGate.WeaponAllowed(unitID,n)then return end
 if wraithReview and not wraithAttackAllowed()then cancelMelee();return end
 if jumpState() then cancelMelee();return end
 local m=mounts[n];if not m or m.passive or m.pairInvalid then return end
 if gaitProbe then gaitProbe.Invalidate(unitID)end
 local f=now()
 if dakkaRecoil then dakkaRecoil.Shot(n,f)end
 if GG.Recoil40KStompaWeaponWitness then GG.Recoil40KStompaWeaponWitness.Shot(unitID,n,f)end
 if GG.Recoil40KSentinelWeaponWitness then GG.Recoil40KSentinelWeaponWitness.Shot(unitID,n,f)end
 -- Former lift Shot hook retired; mount4 now owns native pulse damage only.
 if m.melee then
  if currentMelee~=m or not m.enabled then return end
  m.impact=f;m.pending=nil;m.pendingTarget=nil;m.contactReady=nil
  local contactAge=(m.contact-1)/fps(m.clip)
  m.nextWindup=f+math.ceil(math.max(duration(m.clip)-contactAge,(m.def.reload or m.def.reloadtime or 2.4)-contactAge)*30)
  Spring.SetUnitRulesParam(unitID,'40k_melee_contact',f,{public=true})
  if diagnostic then Spring.SetUnitRulesParam(unitID,'40k_last_shot_'..n,f,{public=true}) end
  return -- Native Melee applies the sole damage; no scripted damage or flash.
 end
 -- Native engine order is Shot, QueryWeapon, vector update, projectile.
 -- Hold the selected barrel through all following queries; first Shot uses1.
 if #m.pair>0 then
  if m.pairHasFired and not m.pairSimultaneous then m.pairIndex=m.pairIndex%#m.pair+1 end
  m.pairHasFired=true;m.muzzle=m.pair[m.pairIndex];m.queriedMuzzle=m.muzzle
 end
 local x,y,z,dx,dy,dz=Spring.GetUnitWeaponVectors(unitID,n)
 local fired=m.muzzle
 if GG.Recoil40KWalkerBurstWitness then GG.Recoil40KWalkerBurstWitness.Shot(unitID,n,fired)end
 if #m.pair>0 and not m.pairInvalid and Spring.GetUnitPiecePosDir then
  local px,py,pz=Spring.GetUnitPiecePosDir(unitID,fired)
  if px and py and pz then x,y,z=px,py,pz end
 end
 if dx and dy and dz then
  local length=math.sqrt(dx*dx+dy*dy+dz*dz)
  if length>1e-9 then dx,dy,dz=dx/length,dy/length,dz/length end
 end
 local function flash(fx,fy,fz)
  if not fx then return end
  local effect=m.params.source_muzzlefx or cp.muzzlefx
  if tonumber(effect) then Spring.SpawnSFX(unitID,tonumber(effect),fx,fy,fz,dx,dy,dz,true)
  else
   local kind=m.def and (m.def.type or m.def.weapontype)
   local name=effect or (kind=='LaserCannon' and '40k_lasgun_muzzle' or (tonumber(m.def and (m.def.reload or m.def.reloadtime)) or 0)>=2.5 and '40k_battlecannon_muzzle' or '40k_shoota_muzzle')
   Spring.SpawnCEG(name,fx,fy,fz,dx,dy,dz)
  end
 end
 flash(x,y,z)
 -- One native hardpoint owns damage. Literal paired source flashes are
 -- simultaneous cosmetics on that same Shot, never extra projectiles/hits.
 if m.pairSimultaneous and #m.pair>1 and Spring.GetUnitPiecePosDir then
  for i=2,#m.pair do
   local px,py,pz=Spring.GetUnitPiecePosDir(unitID,m.pair[i])
   if px and py and pz then flash(px,py,pz)end
  end
 end
 if diagnostic then
  Spring.SetUnitRulesParam(unitID,'40k_last_muzzle_'..n,fired,{public=true})
  if x and (#m.pair>0 or sourceEvidence) then
   Spring.SetUnitRulesParam(unitID,'40k_last_flash_x_'..n,x)
   Spring.SetUnitRulesParam(unitID,'40k_last_flash_y_'..n,y)
   Spring.SetUnitRulesParam(unitID,'40k_last_flash_z_'..n,z)
  end
 end
 updateStockpile()
 m.lastShot=f;m.preparingStart=nil
 if not m.phaseClock and m.bodyRecovery and m.clip and (not bodyStarts[m.clip] or (f-bodyStarts[m.clip])/30>=duration(m.clip)) then bodyStarts[m.clip]=f end
 Spring.SetUnitRulesParam(unitID,'40k_last_shot',f,{public=true})
 if diagnostic then Spring.SetUnitRulesParam(unitID,'40k_last_shot_'..n,f,{public=true}) end
end
-- Opt-in fixture control: the normal actor never exposes test aim overrides.
if diagnostic then
 function TestRosterMount(n,h,p)
  if torso then return false end -- shared hip tests must use the real native target/aim path
  if n==nil then testMount=nil;return true end
  local m=mounts[n];if not m or not m.aimEnabled then return false end
  if m.passive then return true end -- a field has no active aiming/Shot fixture.
  testMount=n;setOffset(m.yaw,y_axis,h or 0,3)
  if m.pitch then setOffset(m.pitch,x_axis,-(p or 0),2) end
  if currentRow then apply(currentRow) end
  return true
 end
 function ReportTestNativePose()
  Spring.Echo("40K MELEE POSE GATE",unitID,"moving",moving,"building",building,"pending",currentMelee and currentMelee.pending,"impact",currentMelee and currentMelee.impact,"frame",now())
  for i,name in ipairs(data.bones) do
   local row=currentRow and currentRow[i]
   if row then
    local info=Spring.GetUnitPieceInfo(unitID,bones[i]) or {}
    local matrix={Spring.GetUnitPieceMatrix(unitID,bones[i])}
    Spring.Echo('40K POSE PROBE',unitID,name,'row',unpack(row))
    Spring.Echo('40K POSE MATRIX',unitID,name,unpack(matrix))
   end
  end
 end
 function ClearTestRosterMount() testMount=nil end
end
local function nanoPiece()
 return lookup(cp.source_nanopiece) or lookup(cp.nanopiece) or lookup('marker_grot_hammer_head') or lookup('marker_grot_wrench_head') or root
end
function script.QueryNanoPiece() return nanoPiece() end
function script.QueryBuildInfo()
 return lookup(cp.source_buildpiece) or lookup(cp.buildpiece) or lookup('marker_boyz_hut_door') or root
end
-- Native factories open their own yard and require readiness BEFORE StartBuilding.
-- Mobile builders use the ordinary StartBuilding/StopBuilding stance callbacks.
function script.Activate()
 if marineNative and marineNative.isFactory then marineNative.Activate(now())
 elseif ud.isFactory then SetUnitValue(COB.INBUILDSTANCE,1) end
 return 1
end
function script.Deactivate()
 if marineNative and marineNative.isFactory then building=false;marineNative.Deactivate(now())
 elseif ud.isFactory then building=false;SetUnitValue(COB.INBUILDSTANCE,0) end
 return 0
end
function script.StartBuilding(h,p)
 if transition(now()) then return end
 if marineNative and marineNative.isFactory and not marineNative.StartBuilding(now())then return end
 building=true;buildStart=now();cancelMelee()
 if wholeBody then setOffset(aimRoot,y_axis,h or 0,3) end
 SetUnitValue(COB.INBUILDSTANCE,1)
 if not ud.isFactory and COB.YARD_OPEN then SetUnitValue(COB.YARD_OPEN,1) end
end
function script.StopBuilding()
 if marineNative and marineNative.isFactory then marineNative.StopBuilding(now())end
 building=false
 -- Keep an opened factory ready between products. The native engine waits for
 -- egress and owns closing the yard; Deactivate then clears its build stance.
 if not ud.isFactory then
  SetUnitValue(COB.INBUILDSTANCE,0)
  if COB.YARD_OPEN then SetUnitValue(COB.YARD_OPEN,0) end
 end
 if wholeBody then setOffset(aimRoot,y_axis,0,3) end
end
function Recoil40KFactoryProductFinished(product)
 return marineNative and marineNative.isFactory and marineNative.ProductFinished(product,now())or false
end
function script.TransportPickup(passenger)
 if transition(now()) or attachments[passenger] then return end
 local used={};for _,entry in pairs(attachments) do used[entry.slot]=true end
 local capacity=VFS.Include('40k_configs/ork_trukk_actor_capacity.lua').ActorCapacity(ud,#slots)
 if GG.Recoil40KTrukkActorCapacity and not GG.Recoil40KTrukkActorCapacity.Permit(unitID,passenger) then return end
 local slot
 for i=1,capacity do if not used[i] then slot=i;break end end
 if not slot then return end
 local mount=slots[(slot-1)%#slots+1]
 Spring.UnitScript.AttachUnit(mount,passenger)
 if Spring.GetUnitTransporter(passenger)==unitID then attachments[passenger]={slot=slot,piece=mount}
 else warn('transport:'..passenger,'Native attachment refused for passenger '..passenger) end
end
function script.TransportDrop(passenger,x,y,z)
 -- Ground UnloadLand approves requested XZ, then delegates landing to this script.
 -- Detach alone retains the carried position; use native terrain placement after detach.
 if attachments[passenger] then
  -- TRANSPORT_NATIVE_DROP_EVIDENCE: diagnostic reads only; no placement change.
  local transportReview=Spring.GetModOptions and Spring.GetModOptions().prototype_diagnostic=='roster' and tostring(Spring.GetModOptions().prototype_transport_review)=='1'
  if transportReview then Spring.Echo('40K TRANSPORT DROP','REQUEST',unitID,passenger,tostring(x),tostring(y),tostring(z),Spring.GetGameFrame(),Spring.GetUnitPosition(passenger)) end
  if GG and GG.Recoil40KGroundLandings then GG.Recoil40KGroundLandings[passenger]=nil end
  if GG.Recoil40KTransportClearanceWitness then GG.Recoil40KTransportClearanceWitness.Drop('request',unitID,passenger,x,y,z)end
  Spring.UnitScript.DropUnit(passenger)
  if transportReview then Spring.Echo('40K TRANSPORT DROP','RESULT',unitID,passenger,Spring.GetUnitTransporter(passenger) or -1,Spring.GetGameFrame(),Spring.GetUnitPosition(passenger)) end
  -- TRANSPORT_NATIVE_LANDING_XZ: only an accepted native detach may land cargo.
  local cargoOwner=Spring.GetUnitTransporter(passenger)
  if cargoOwner~=unitID then
   attachments[passenger]=nil
   local validDrop=type(x)=='number' and type(z)=='number' and x==x and z==z and math.abs(x)<math.huge and math.abs(z)<math.huge
   if cargoOwner==nil and validDrop and Spring.SetUnitPosition then
    -- Three arguments select native terrain height; wanted y includes unload clearance.
    Spring.SetUnitPosition(passenger,x,z)
    if GG.Recoil40KTransportClearanceWitness then GG.Recoil40KTransportClearanceWitness.Drop('placed',unitID,passenger,x,y,z)end
    -- 40K_APPROVED_GROUND_LANDING: bridge only this completed native unload event.
    local landedX,landedY,landedZ=Spring.GetUnitPosition(passenger)
    if GG and source=='ork_trukk' and tostring(cp.prototype40k)=='1' and not ud.canFly and landedX==x and landedZ==z and Spring.GetUnitTransporter(passenger)==nil then
     GG.Recoil40KGroundLandings=GG.Recoil40KGroundLandings or {}
     GG.Recoil40KGroundLandings[passenger]={frame=Spring.GetGameFrame(),transport=unitID,x=landedX,y=landedY,z=landedZ}
    end
    if transportReview then Spring.Echo('40K TRANSPORT DROP','PLACED',unitID,passenger,x,z,Spring.GetGameFrame(),Spring.GetUnitPosition(passenger)) end
   elseif cargoOwner==nil then
    warn('transport-drop:'..passenger,'Native unload landing unavailable: invalid requested XZ or missing native position API')
   end
  end
 end
end
function script.Killed()
 if gaitProbe then gaitProbe.Clear(unitID)end
 if tostring(cp.prototype40k_dakka_reference_diagnostic)=='1'then
  return VFS.Include('40k_configs/ork_dakka_reference_diagnostic.lua').KilledReturn(Spring,cp,unitID)
 end
 if tostring(cp.prototype40k_fixed_artillery_native_wreck)=='1'then
  -- This stationary artillery has one native corpse and no infantry-remains
  -- owner. Never return a completed entitlement for unfinished construction.
  local _,_,_,_,progress=Spring.GetUnitHealth(unitID)
  return type(progress)=='number'and progress>=1 and 1 or 0
 end
 if GG.Recoil40KTacticalRemains then GG.Recoil40KTacticalRemains.Killed(unitID,unitDefID,Spring.GetUnitTeam(unitID))end
 return 0
end
