function gadget:GetInfo()return {name='40K native transport landing trajectory',desc='Read-only opted movement and physical radius evidence after real native unload',author='Local project',layer=100000,enabled=true}end
if not gadgetHandler:IsSyncedCode()then return end
local options=Spring.GetModOptions()
if options.prototype_diagnostic~='roster' or tostring(options.prototype_transport_review or '0')~='1' then return end
local pending,tracked={},0
local ages={1,2,15,30,60}
local function value(v)if v==nil then return 'UNKNOWN' end return v end
local function sample(id,transport,start,frame)
 if not Spring.ValidUnitID(id)then Spring.Echo('40K TRANSPORT TRAJECTORY','MISSING',id,transport,frame-start,frame);return end
 local x,y,z=Spring.GetUnitPosition(id)
 local vx,vy,vz=Spring.GetUnitVelocity(id)
 local mt=Spring.GetUnitMoveTypeData(id) or {}
 local cmd,opts,tag,p1,p2,p3=Spring.GetUnitCurrentCommand(id)
 local ud=UnitDefs[Spring.GetUnitDefID(id)] or {}
 local blockedType,blockedID
 if x and z and Spring.GetGroundBlocked then blockedType,blockedID=Spring.GetGroundBlocked(x,z)end
 Spring.Echo('40K TRANSPORT TRAJECTORY','PHYSICAL',id,transport,frame-start,frame,value(Spring.GetUnitTransporter(id)),value(Spring.GetUnitRadius(id)),value(Spring.GetUnitHeight(id)),value(ud.xsize),value(ud.zsize),value(ud.moveDef and ud.moveDef.name),value(blockedType),value(blockedID),value(x),value(y),value(z),value(vx),value(vy),value(vz))
 Spring.Echo('40K TRANSPORT TRAJECTORY','MOTION',id,transport,frame-start,frame,value(mt.name),value(mt.progressState),value(mt.goalx),value(mt.goaly),value(mt.goalz),value(mt.currwaypointx),value(mt.currwaypointy),value(mt.currwaypointz),value(mt.currentSpeed),value(mt.wantedSpeed),value(cmd),value(opts),value(tag),value(p1),value(p2),value(p3))
end
function gadget:UnitUnloaded(id,def,team,transport)
 local ud=UnitDefs[def];local truckDef=Spring.GetUnitDefID(transport);local td=truckDef and UnitDefs[truckDef]
 if tracked>=12 or not ud or not td or not ud.customParams or ud.customParams.animsource~='ork_slugga' or not td.customParams or td.customParams.animsource~='ork_trukk' then return end
 tracked=tracked+1;pending[id]={transport=transport,start=Spring.GetGameFrame(),index=1}
end
function gadget:GameFrame(frame)
 for id,p in pairs(pending)do
  local age=frame-p.start
  if age==ages[p.index]then sample(id,p.transport,p.start,frame);p.index=p.index+1 end
  if not ages[p.index] or age>ages[p.index]then pending[id]=nil end
 end
end
