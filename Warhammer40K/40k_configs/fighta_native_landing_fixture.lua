-- Native physical landing only. Existing source bank has no authored landing pose.
local M={}
function M.RemainsReady(d,features,names)
 if not d or type(d.wreckName)~='string'or d.wreckName==''then return false,'genuine_Fighta_native_remains_absent'end
 local fn=names and names[d.wreckName];local fd=fn and features and features[fn.id]
 if not fd or not fd.reclaimable or not fd.metal or fd.metal<=0 or(fd.customParams or{}).parent_actor~='ork_fighta_bomba'then return false,'genuine_Fighta_reclaim_entitlement_absent'end
 return true
end
function M.New(S,defs,actor,team,frame,emit)
 local definition=S.GetUnitDefID(actor);local d=defs[definition];local C={phase='approach',start=frame,actor=actor,definition=definition,team=team}
 local retired=false
 local function original()return not retired and S.GetUnitIsDead(actor)==false and S.GetUnitDefID(actor)==definition and S.GetUnitTeam(actor)==team end
 function C.Retire(id,reason)
  if id==actor then retired=true;C.since=nil;C.result='FAIL original_paid_Fighta_'..reason end
 end
 if not original()then C.result='FAIL original_paid_Fighta_identity_unavailable';return C end
 if not d or not d.canFly or(d.customParams or{}).animsource~='ork_fighta_bomba' then C.result='FAIL genuine_paid_Fighta_required';return C end
 local move=S.GetUnitMoveTypeData(actor)
 if not move or move.name~='gunship' or not move.aircraftState or not CMD.IDLEMODE or not S.FindUnitCmdDesc(actor,CMD.IDLEMODE)then C.result='INCONCLUSIVE native_hover_air_landing_command_unavailable';return C end
 -- Pinned gunship Lua field is legacy-misnamed: dontLand actually returns
 -- CHoverAirMoveType::GetAllowLanding(), not the internal dontLand member.
 emit('NATIVE_LANDING_PERMISSION','native_move=gunship','legacy_dontLand_field='..tostring(move.dontLand),'native_allowLanding='..tostring(move.dontLand),'native_field_maps_GetAllowLanding=true')
 if type(move.dontLand)~='boolean'then C.result='INCONCLUSIVE native_Fighta_landing_permission_unavailable';return C end
 if not move.dontLand then C.result='NOT_APPLICABLE_NATIVE_DONTLAND paid_Fighta_primary_proof_retained physical_landing_unaccepted source_landing_pose_absent';return C end
 local x,y,z=S.GetUnitPosition(actor);local radius=S.GetUnitRadius(actor)
 if not x or not radius or radius<=0 then C.result='FAIL native_aircraft_geometry_missing';return C end
 local f=d
 local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
 if not finite(x)or not finite(y)or not finite(z)or not finite(radius)or radius<=0 then C.result='INCONCLUSIVE actual_aircraft_native_geometry_required';return C end
 for _,name in ipairs({'GetGroundHeight','GetGroundNormal','TestBuildOrder','GetUnitsInRectangle','GetFeaturesInRectangle','GetUnitCommands','GetUnitVelocity','GetUnitPosition','GetUnitMoveTypeData','GetUnitRadius'})do
  if type(S[name])~='function'then C.result='INCONCLUSIVE native_site_API_required_'..name;return C end
 end
 local cv=f.collisionVolume
 if not finite(f.xsize)or f.xsize<=0 or f.xsize%1~=0 or not finite(f.zsize)or f.zsize<=0 or f.zsize%1~=0
  or not finite(f.radius)or f.radius<=0 or type(cv)~='table'
  or not finite(cv.scaleX)or cv.scaleX<=0 or not finite(cv.scaleZ)or cv.scaleZ<=0
  or not finite(cv.offsetX)or not finite(cv.offsetZ)then C.result='INCONCLUSIVE actual_aircraft_native_site_shape_required';return C end
 local airHX=math.max(f.xsize*4,f.radius,radius,math.abs(cv.offsetX)+cv.scaleX*.5)+16
 local airHZ=math.max(f.zsize*4,f.radius,radius,math.abs(cv.offsetZ)+cv.scaleZ*.5)+16
 -- Bounded pilot scan; oversized/invalid geometry is unavailable, never guessed.
 if airHX>256 or airHZ>256 then C.result='INCONCLUSIVE aircraft_site_shape_outside_bounded_pilot';return C end
 local function aircraftClear(x,z,actualLandingBody)
  if x<airHX+64 or z<airHZ+64 or x>Game.mapSizeX-airHX-64 or z>Game.mapSizeZ-airHZ-64 then return false end
  local low,high=math.huge,-math.huge
  local xs,zs={x-airHX,x+airHX},{z-airHZ,z+airHZ}
  -- Cover every native 8-unit grid vertex in whole cells intersecting the
  -- envelope, plus exact edges. Arbitrarily shifted samples can miss a shallow
  -- wet vertex. Outside rounding is conservative and remains within edge margins.
  for sx=math.floor((x-airHX)/8)*8,math.ceil((x+airHX)/8)*8,8 do xs[#xs+1]=sx end
  for sz=math.floor((z-airHZ)/8)*8,math.ceil((z+airHZ)/8)*8,8 do zs[#zs+1]=sz end
  for _,sx in ipairs(xs)do for _,sz in ipairs(zs)do
   local y=S.GetGroundHeight(sx,sz);local ax,ay,az,slope=S.GetGroundNormal(sx,sz,true)
   if not finite(y)or y<0 or not finite(ax)or not finite(ay)or not finite(az)or not finite(slope)
    or ay<=0 or ay>1.001 or slope<0 or slope>.1 then return false end
   low=math.min(low,y);high=math.max(high,y)
   if high-low>8 then return false end
  end end
  local y=S.GetGroundHeight(x,z);if not finite(y)then return false end
  -- Pinned API internally snaps BuildInfo and maps native OPEN(3) to Lua 2.
  -- Reclaimable obstruction also returns 2, but supplies a featureID. The extra
  -- 16-unit envelope covers native half-square snapping around this exact birth.
  if not actualLandingBody then
   local status,feature=S.TestBuildOrder(d.id,x,y,z,0)
   if status~=2 or feature~=nil then return false end
  end
  local units=S.GetUnitsInRectangle(x-airHX-32,z-airHZ-32,x+airHX+32,z+airHZ+32)
  local features=S.GetFeaturesInRectangle(x-airHX-32,z-airHZ-32,x+airHX+32,z+airHZ+32)
  if type(units)~='table'or type(features)~='table'or next(features)~=nil then return false end
  for _,id in pairs(units)do if id~=actor then return false end end
  return true
 end
 local target
 for ring=0,4 do for n=0,15 do
  local angle=n*math.pi/8;local tx,tz=x+ring*64*math.sin(angle),z+ring*64*math.cos(angle);local ty=S.GetGroundHeight(tx,tz)
  if aircraftClear(tx,tz)then target={tx,ty,tz};break end
 end;if target then break end end
 if not target then C.result='INCONCLUSIVE native_clear_dry_landing_site_missing';return C end
 S.GiveOrderToUnit(actor,CMD.STOP,{},0);S.GiveOrderToUnit(actor,CMD.MOVE,target,0)
 emit('LAND_SITE',actor,target[1],target[2],target[3],'native_MOVE=true source_landing_pose_absent=true render_quality_unaccepted=true')
 function C.Step(f)
  if C.result then return C.result end
  if not original()then C.result='FAIL original_paid_Fighta_lost_transferred_or_replaced';C.since=nil;return C.result end
  if f-C.start>1800 then return'INCONCLUSIVE native_Fighta_did_not_complete_real_landing'end
  local px,py,pz=S.GetUnitPosition(actor);local mt=S.GetUnitMoveTypeData(actor)
  if not px or not mt or mt.name~='gunship'then return'FAIL native_air_move_state_missing'end
  if C.lastStep and f~=C.lastStep+1 then C.since=nil end;C.lastStep=f
  if C.phase=='approach'then
   if(px-target[1])^2+(pz-target[3])^2<=24^2 then
    C.phase='landing';S.GiveOrderToUnit(actor,CMD.IDLEMODE,{1},0);S.GiveOrderToUnit(actor,CMD.STOP,{},0)
    emit('NATIVE_LAND_MODE','IDLEMODE=1 STOP=true no_position_or_height_override=true')
   end
  elseif C.phase=='landing'then
   local vx,vy,vz=S.GetUnitVelocity(actor);local ground=S.GetGroundHeight(px,pz)
   local sampleRadius=S.GetUnitRadius(actor)
   if not finite(sampleRadius)or sampleRadius<=0 or math.abs(sampleRadius-radius)>.001 then return'INCONCLUSIVE native_landing_radius_changed_or_missing'end
   local commands=S.GetUnitCommands(actor,1)
   if type(commands)~='table'then return'INCONCLUSIVE native_landing_queue_unavailable'end
   for index,command in pairs(commands)do if type(index)~='number'or index~=1 or type(command)~='table'or type(command.id)~='number'then return'INCONCLUSIVE native_landing_queue_shape_unavailable'end end
   if not finite(px)or not finite(py)or not finite(pz)or not finite(ground)or not finite(vx)or not finite(vy)or not finite(vz)or not finite(radius)then return'INCONCLUSIVE native_landing_sample_geometry_missing'end
   local settled=mt.aircraftState=='landed' and vx^2+vy^2+vz^2<=.01 and ground>=0 and py-ground>=-.01 and py-ground<=sampleRadius+1 and next(commands)==nil and aircraftClear(px,pz,true)
   if settled then
    C.since=C.since or f
    emit('NATIVE_LANDED_SAMPLE',f,actor,px,py,pz,'native_aircraftState=landed','source_landing_pose_absent=true','ground='..ground,'radius='..sampleRadius,'velocity='..vx..','..vy..','..vz,'queue_count='..#commands,'height_above_ground='..(py-ground))
    if f-C.since>=30 then return'PASS paid_Fighta_native_physical_landing_only source_landing_animation_render_death_reclaim_unaccepted'end
   else C.since=nil end
  end
 end
 return C
end
return M
