function gadget:GetInfo()
 return {name='40K Trukk selected-site clearance witness',desc='Read-only native site, approach, drop and later primitive evidence',author='Local project',layer=100001,enabled=true}
end
if not gadgetHandler:IsSyncedCode()then return false end
local options=Spring.GetModOptions()or{}
if options.prototype_diagnostic~='roster' or tostring(options.prototype_transport_review)~='1'
 or tostring(options.prototype_transport_clearance_witness)~='1'then return false end
local P=VFS.Include('luarules/utilities/40k_transport_proof.lua')
local trucks,records={},{}
local count,serial,rows=0,0,0
local ages={1,2,15,60,120}
local moveAges={15,60,120}
local approachInterval,approachLimit=10,24
local bridge
local function value(v)if v==nil then return 'UNKNOWN' end return v end
local function log(...)
 if rows>=2048 then return end
 rows=rows+1;Spring.Echo('40K TRUKK CLEARANCE',...)
end
local function isTruck(id)
 if not Spring.ValidUnitID(id)then return false end
 local d=UnitDefs[Spring.GetUnitDefID(id)];local p=d and d.customParams or{}
 return p.animsource=='ork_trukk'and tostring(p.prototype40k)=='1'and not d.canFly
end
local function track(truck,passenger,newLoad)
 if not isTruck(truck)then return nil end
 trucks[truck]=true
 local r=records[passenger]
 if r and r.transport==truck and(not newLoad or not r.unloaded)then return r end
 if count>=12 then return nil end
 count=count+1;serial=serial+1
 r={transport=truck,passenger=passenger,sequence=serial};records[passenger]=r
 return r
end
local function snapshot(id,label,r)
 if not Spring.ValidUnitID(id)then log(label,'MISSING',r.sequence,id,Spring.GetGameFrame());return nil end
 local x,y,z,mx,my,mz=Spring.GetUnitPosition(id,true)
 local sx,sy,sz,ox,oy,oz,kind,testType,axis,disabled=Spring.GetUnitCollisionVolumeData(id)
 local front,up,right=Spring.GetUnitVectors(id)
 local heading=Spring.GetUnitHeading(id)
 local vx,vy,vz=Spring.GetUnitVelocity(id)
 local move=Spring.GetUnitMoveTypeData and Spring.GetUnitMoveTypeData(id)or{}
 log(label..'_NATIVE_MOVE_STATE',r.sequence,Spring.GetGameFrame(),id,r.transport,r.passenger,
  'loadingTransportId',value(move.loadingTransportId),'unloadingTransportId',value(move.unloadingTransportId),
  'requestRemoveUnloadTransportId',value(move.requestRemoveUnloadTransportId),'READ_ONLY_NATIVE_FIELDS')
 log(label,r.sequence,Spring.GetGameFrame(),id,r.transport,r.passenger,
  value(x),value(y),value(z),value(mx),value(my),value(mz),value(heading),
  value(sx),value(sy),value(sz),value(ox),value(oy),value(oz),value(kind),value(testType),value(axis),value(disabled),
  value(vx),value(vy),value(vz),value(Spring.GetUnitTransporter(id)))
 if not front or not up or not right or not P.finite(mx)or not P.finite(my)or not P.finite(mz)
  or not P.finite(sx)or not P.finite(sy)or not P.finite(sz)or not P.finite(ox)or not P.finite(oy)or not P.finite(oz)then return nil end
 local center={};for i=1,3 do center[i]=({mx,my,mz})[i]-right[i]*ox+up[i]*oy+front[i]*oz end
 local primitive={kind=kind,testType=testType,axis=axis,disabled=disabled,center=center,half={sx*.5,sy*.5,sz*.5},axes={{-right[1],-right[2],-right[3]},up,front}}
 log(label..'_AXES',r.sequence,id,-right[1],-right[2],-right[3],up[1],up[2],up[3],front[1],front[2],front[3],center[1],center[2],center[3])
 return {base={x,y,z},mid={mx,my,mz},primitive=primitive}
end
local function sample(label,r,hypothetical)
 local t=snapshot(r.transport,label..'_TRUCK',r)
 local p=snapshot(r.passenger,label..'_PASSENGER',r)
 if not t or not p then log(label..'_PAIR',r.sequence,'UNKNOWN','native_primitive_readback_missing');return end
 local primitive=p.primitive
 if hypothetical then
  if not r.wanted or not P.finite(r.wanted[1])or not P.finite(r.wanted[3])then log(label..'_PAIR',r.sequence,'UNKNOWN','wanted_site_missing');return end
  -- This is explicitly a translated current-pose prediction, never an actual
  -- placement. Preserve exact native shape/orientation and terrain landing Y.
  local target={r.wanted[1],Spring.GetGroundHeight(r.wanted[1],r.wanted[3]),r.wanted[3]}
  primitive={kind=primitive.kind,testType=primitive.testType,axis=primitive.axis,disabled=primitive.disabled,half=primitive.half,axes=primitive.axes,center={}}
  for i=1,3 do primitive.center[i]=p.primitive.center[i]+target[i]-p.base[i]end
 end
 local overlap,kind,metric,limit=P.overlap(primitive,t.primitive)
 log(label..'_PAIR',r.sequence,Spring.GetGameFrame(),value(overlap),kind,value(metric),value(limit),hypothetical and 'HYPOTHETICAL_CURRENT_POSE_AT_NATIVE_TERRAIN' or 'ACTUAL_NATIVE_READBACK')
end
local function wanted(label,r,x,y,z)
 r.wanted={x,y,z}
 log(label,r.sequence,Spring.GetGameFrame(),r.transport,r.passenger,value(x),value(y),value(z),value(r.selected),value(r.unloaded))
 sample(label,r,true)
end
function gadget:Initialize()
 bridge={Drop=function(stage,truck,passenger,x,y,z)
  local r=track(truck,passenger);if not r then return end
  if stage=='request'then wanted('SCRIPT_REQUEST',r,x,y,z)
  elseif stage=='placed'then log('SCRIPT_PLACED',r.sequence,Spring.GetGameFrame(),truck,passenger,value(x),value(y),value(z));sample('SCRIPT_PLACED',r,false)end
 end}
 GG.Recoil40KTransportClearanceWitness=bridge
 for _,id in ipairs(Spring.GetAllUnits())do if isTruck(id)then trucks[id]=true end end
 log('ENABLED','read_only','max_sequences',12,'max_log_rows',2048,'no_acceptance_result')
end
function gadget:Shutdown()
 if GG.Recoil40KTransportClearanceWitness==bridge then GG.Recoil40KTransportClearanceWitness=nil end
end
function gadget:UnitLoaded(id,def,team,transport)
 local r=track(transport,id,true);if not r then return end
 log('NATIVE_LOADED',r.sequence,Spring.GetGameFrame(),transport,id,def,team)
end
function gadget:AllowUnitTransportUnload(transport,transportDef,transportTeam,passenger,passengerDef,passengerTeam,x,y,z)
 local r=track(transport,passenger)
 if r then wanted('NATIVE_APPROACH_ALLOW_CALLBACK',r,x,y,z)end
 -- Other gadgets and the engine retain their policies; this observer never vetoes.
 return true
end
function gadget:UnitUnloaded(id,def,team,transport)
 local r=track(transport,id);if not r then return end
 r.unloaded=Spring.GetGameFrame();r.ageIndex=1
 log('NATIVE_UNLOADED',r.sequence,r.unloaded,transport,id,def,team)
 -- Native callback occurs during DropUnit, before the existing terrain placement.
 sample('DETACH_CALLBACK_BEFORE_SCRIPT_LANDING',r,false)
end
function gadget:GameFrame(frame)
 for truck in pairs(trucks)do
  if not isTruck(truck)then trucks[truck]=nil
  elseif Spring.GetUnitCurrentCommand then
   local cmd,opts,tag,x,y,z,passenger=Spring.GetUnitCurrentCommand(truck)
   if CMD.UNLOAD_UNIT and cmd==CMD.UNLOAD_UNIT and type(passenger)=='number'and Spring.GetUnitTransporter(passenger)==truck then
    local r=track(truck,passenger)
    if r and(not r.selected or r.tag~=tag or not r.wanted or r.wanted[1]~=x or r.wanted[3]~=z)then
     r.selected=frame;r.tag=tag;r.approachCount=0;r.nextApproach=frame+approachInterval;wanted('SELECTED_INTERNAL_UNLOAD_COMMAND',r,x,y,z)
    end
   end
  end
 end
 for _,r in pairs(records)do
  if r.selected and not r.unloaded and r.nextApproach and frame>=r.nextApproach then
   if (r.approachCount or 0)<approachLimit then
    r.approachCount=(r.approachCount or 0)+1;r.nextApproach=frame+approachInterval
    local cmd,opts,tag,x,y,z,passenger
    if Spring.GetUnitCurrentCommand then cmd,opts,tag,x,y,z,passenger=Spring.GetUnitCurrentCommand(r.transport)end
    local mt=Spring.GetUnitMoveTypeData and Spring.GetUnitMoveTypeData(r.transport)or{}
    log('APPROACH_STATE',r.sequence,frame,r.approachCount,r.transport,r.passenger,value(cmd),value(tag),value(x),value(y),value(z),value(passenger),value(mt.progressState),value(mt.goalx),value(mt.goaly),value(mt.goalz),'READ_ONLY_NO_ACCEPTANCE')
    sample('APPROACH',r,true)
   else
    log('APPROACH_SAMPLING_LIMIT',r.sequence,frame,approachLimit);r.nextApproach=nil
   end
  end
  if r.unloaded and Spring.GetUnitCurrentCommand then
   local cmd,opts,tag=Spring.GetUnitCurrentCommand(r.passenger)
   if CMD.MOVE and cmd==CMD.MOVE and type(tag)=='number'and r.moveTag~=tag then
    r.moveTag=tag;r.moveFrame=frame;r.moveAgeIndex=1
    log('POST_MOVE_SELECTED',r.sequence,frame,r.passenger,tag,'READ_ONLY_ACTUAL_NATIVE_MOVE')
    sample('POST_MOVE_SELECTED',r,false)
   end
  end
  if r.moveFrame and r.moveAgeIndex and frame-r.moveFrame==moveAges[r.moveAgeIndex]then
   log('POST_MOVE_AGE',r.sequence,frame-r.moveFrame,frame,r.passenger,r.moveTag)
   sample('POST_MOVE',r,false);r.moveAgeIndex=r.moveAgeIndex+1
   if not moveAges[r.moveAgeIndex]then r.moveAgeIndex=nil end
  end
  if r.unloaded and r.ageIndex and frame-r.unloaded==ages[r.ageIndex]then
   log('POST_DROP_AGE',r.sequence,frame-r.unloaded,frame)
   sample('POST_DROP',r,false);r.ageIndex=r.ageIndex+1
   if not ages[r.ageIndex]then r.ageIndex=nil end
  end
 end
end
