function gadget:GetInfo()return {name='40K paid AI build read-only witness',desc='Actual queue, gate and build-site receipts; never authorizes construction',author='Local project',layer=1000002,enabled=true}end
if not gadgetHandler:IsSyncedCode()then return false end
local o=Spring.GetModOptions()
if o.prototype_diagnostic~='expandedproduction'or not VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(o.prototype_source_progression)or tostring(o.prototype_source_paid_match)~='1'then return false end
local rows,serial,pending=0,0,{}
local bridge,technology
local function v(x)if x==nil then return 'UNKNOWN'end;return x end
local function log(...)if rows>=640 then return end;rows=rows+1;Spring.Echo('40K PAID BUILD WITNESS',...)end
local function overlap(x,z,hx,hz,ox,oz,sx,sz)return math.abs(x-ox)<hx+sx and math.abs(z-oz)<hz+sz end
local function snapshot(phase,id,def,team,p,token,nativeReturn)
 local d=UnitDefs[def];local builder=UnitDefs[Spring.GetUnitDefID(id)];if not d or not builder then log(phase,token,'definition_unreadable');return end
 local queue=Spring.GetUnitCommands(id,3);local head=queue and queue[1]
 local menu=false;for _,key in ipairs(builder.buildOptions or{})do if key==def then menu=true;break end end
 local descIndex=Spring.FindUnitCmdDesc and Spring.FindUnitCmdDesc(id,-def)
 local descs=descIndex and Spring.GetUnitCmdDescs(id,descIndex,descIndex);local desc=descs and descs[1]
 -- Controller CanBuild may initialize/refresh state or consume a permit; do not query here.
 local okay,canBuild
 local bx,by,bz=Spring.GetUnitPosition(id);local hp,maxhp,_,_,built=Spring.GetUnitHealth(id)
 log(phase,token,Spring.GetGameFrame(),id,team,def,d.name,'return',v(nativeReturn),'queueCount',queue and #queue or 'UNKNOWN','head',head and head.id or 'none','tag',head and head.tag or 'none',
  'nativeMenuContains',menu,'descriptorIndex',v(descIndex),'descriptorDisabled',v(desc and desc.disabled),'CanBuildReadSucceeded',v(okay),'CanBuild',v(canBuild),
  'builder',builder.name,'isBuilder',v(builder.isBuilder),'isFactory',v(builder.isFactory),'canMove',v(builder.canMove),'builderPos',v(bx),v(by),v(bz),'health',v(hp),'maxHealth',v(maxhp),'buildProgress',v(built),
  'targetFootprint',v(d.xsize),v(d.zsize),'maxThisUnit',v(d.maxThisUnit),'unitLimit',v(d.maxThisUnit),'targetMex',v(d.extractsMetal),'targetNeedGeo',v(d.needGeo),'no_mutation',true)
 if type(p)~='table'or type(p[1])~='number'or type(p[2])~='number'or type(p[3])~='number'then log('SITE',token,'params_unreadable');return end
 local facing=p[4]or 0;local x,y,z=p[1],p[2],p[3]
 if Spring.Pos2BuildPos then x,y,z=Spring.Pos2BuildPos(def,x,y,z,facing)end
 if not x or not y or not z then log('SITE',token,'native_snap_unreadable');return end
 local result,feature=Spring.TestBuildOrder(def,x,y,z,facing)
 local gh=Spring.GetGroundHeight(x,z);local gt,g1,metal=Spring.GetGroundInfo(x,z)
 log('SITE',token,phase,'supplied',p[1],p[2],p[3],facing,'nativeSnap',x,y,z,'nativeTest',v(result),'feature',v(feature),'ground',v(gh),'groundType',v(gt),'metal',v(metal),'inMap',x>=0 and x<Game.mapSizeX and z>=0 and z<Game.mapSizeZ)
 local hx,hz=(d.xsize or 0)*4,(d.zsize or 0)*4;if facing%2==1 then hx,hz=hz,hx end
 local count=0
 for _,other in ipairs(Spring.GetUnitsInRectangle(x-hx-256,z-hz-256,x+hx+256,z+hz+256)or{})do
  if count>=16 then log('BLOCKERS',token,'truncated',16);break end
  local ud=UnitDefs[Spring.GetUnitDefID(other)];local ox,oy,oz=Spring.GetUnitPosition(other)
  if ud and ox then local sx,sz=(ud.xsize or 0)*4,(ud.zsize or 0)*4;local f=Spring.GetUnitBuildFacing and Spring.GetUnitBuildFacing(other)or 0;if f%2==1 then sx,sz=sz,sx end
   if overlap(x,z,hx,hz,ox,oz,sx,sz)then count=count+1
    local cx,cy,cz,dx,dy,dz,kind,axis,test,disabled=Spring.GetUnitCollisionVolumeData(other)
    log('BLOCKER',token,phase,other,ud.name,'team',Spring.GetUnitTeam(other),'position',ox,oy,oz,'footprintHalf',sx,sz,'nativeVolume',v(cx),v(cy),v(cz),v(dx),v(dy),v(dz),v(kind),v(axis),v(test),v(disabled),'native_api_not_causal_verdict',true)
   end
  end
 end
 if Spring.GetFeaturesInRectangle and Spring.GetFeaturePosition then
  local fs=Spring.GetFeaturesInRectangle(x-hx-256,z-hz-256,x+hx+256,z+hz+256)or{}
  for i,featureID in ipairs(fs)do
   if i>8 then log('FEATURES',token,'truncated',8);break end
   local fx,fy,fz=Spring.GetFeaturePosition(featureID)
   local ax,ay,az,dx,dy,dz,kind,axis,test,disabled
   if Spring.GetFeatureCollisionVolumeData then ax,ay,az,dx,dy,dz,kind,axis,test,disabled=Spring.GetFeatureCollisionVolumeData(featureID)end
   log('NEARBY_FEATURE',token,phase,featureID,'position',v(fx),v(fy),v(fz),'nativeVolume',v(ax),v(ay),v(az),v(dx),v(dy),v(dz),v(kind),v(axis),v(test),v(disabled),'bounded_rectangle_not_exact_blocker',true)
  end
 else log('FEATURES',token,'native_inventory_unavailable')end

end
local function observe(phase,id,def,params,returned)
 local team=Spring.GetUnitTeam(id);if not team or not UnitDefs[def]then return end
 local r=pending[id]
 if phase=='BEFORE'or not r then serial=serial+1;if serial>64 then return end;r={token=serial,def=def,p=params,team=team,frame=Spring.GetGameFrame()};pending[id]=r end
 snapshot(phase,id,def,team,params or r.p,r.token,returned)
end
function gadget:Initialize()
 assert(not GG.Recoil40KPaidBuildWitness,'Duplicate build observer')
 technology=VFS.Include('40k_configs/paid_technology_dispatch_witness.lua').New(Spring,UnitDefs,function()return GG.Recoil40KResearch end,Game,Spring.Echo)
 bridge={Before=function(id,def,p)observe('BEFORE',id,def,p)end,After=function(id,def,p,returned)observe('AFTER',id,def,p,returned)end}
 bridge.ReadonlyCommandBefore=technology.ReadonlyCommandBefore
 bridge.ReadonlyCommandAfter=technology.ReadonlyCommandAfter
 bridge.ReadonlyNextFrameBuildAttempt=technology.ReadonlyNextFrameBuildAttempt
 GG.Recoil40KPaidBuildWitness=bridge
end
function gadget:AllowCommand(id,def,team,cmd,params)
 if technology and technology.Pending(id)then return true end
 if type(cmd)=='number'and cmd<0 and UnitDefs[-cmd]then observe('ALLOW_COMMAND_OBSERVED',id,-cmd,params)end
 return true -- Other handlers and native command admission still decide; never force a command.
end
function gadget:GameFrame(f)
 if technology then technology.ReadonlyNextFrameBuildAttempt(f)end
 for id,r in pairs(pending)do if f>r.frame then snapshot('NEXT_FRAME',id,r.def,r.team,r.p,r.token);pending[id]=nil end end
end
function gadget:UnitCreated(id,def,team,builder)
 if technology then technology.Created(id,def,team,builder)end
 local r=builder and pending[builder];if r and r.def==def then log('ACTUAL_CREATED',r.token,Spring.GetGameFrame(),id,def,team,builder)end
end
function gadget:UnitFinished(id,def,team)if technology then technology.Finished(id,def,team)end end
function gadget:UnitDestroyed(id)if technology then technology.Remove(id)end end
function gadget:UnitTaken(id)if technology then technology.Remove(id)end end
function gadget:UnitGiven(id)if technology then technology.Remove(id)end end
function gadget:Shutdown()if GG.Recoil40KPaidBuildWitness==bridge then GG.Recoil40KPaidBuildWitness=nil end end
