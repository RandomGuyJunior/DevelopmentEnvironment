-- Ordinary native factory production twice; no births/grants or weapon test.
local M={}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local physical=VFS.Include('40k_configs/guard_factory_egress_geometry.lua')
function M.New(S,D,team,factory,emit)
 local C={phase='queue',cycle=1,products={},seen={},retired={}}
 C.Created=function()end;C.Finished=function()end;C.Released=function()end;C.Step=function()return C.result end
 local function retire(id)if id~=nil and(id==factory or id==C.birth or C.seen[id])then C.retired[id]=true end end
 C.Destroyed=retire;C.Taken=retire;C.Given=retire
 local name=UnitDefNames.fortyk_ork_patrol_boat;local d=name and D[name.id];local fd
 local function fail(reason)C.result='INCONCLUSIVE '..reason;return C.result end
 local function live(id)return id~=nil and not C.retired[id] and S.ValidUnitID(id)==true and S.GetUnitIsDead(id)==false and S.GetUnitTeam(id)==team and select(5,S.GetUnitHealth(id))==1 and(S.GetUnitHealth(id)or 0)>0 end
 local function bill(id)local w,m,e=S.GetUnitCosts(id);return w==2500 and m==210 and e==1400 end
 for _,api in ipairs({'ValidUnitID','GetUnitIsDead','GetUnitTeam','GetUnitCosts','GetUnitHealth','GetUnitDefID','GetUnitPosition','GetUnitVelocity','GetUnitCurrentCommand','GetFactoryCommands','GetGroundHeight','TestMoveOrder','GetUnitsInCylinder','GetFeaturesInCylinder','GiveOrderToUnit','GetUnitCollisionVolumeData','GetUnitVectors','GetUnitBuildFacing'})do if type(S[api])~='function'then fail('native_api_'..api);return C end end
 local factoryDef=S.GetUnitDefID(factory);fd=D[factoryDef]
 if not d or not fd or not live(factory)or not fd.isFactory or(fd.customParams or{}).prototype40k_native_donor~='corsy'or(d.customParams or{}).prototype40k_native_donor~='corpt'or d.minWaterDepth~=6 or d.canFly or not d.canMove or not tostring(d.scriptName):lower():match('units/corpt%.cob$')or d.metalCost~=210 or d.energyCost~=1400 or d.buildTime~=2500 then fail('exact_ready_corpt_corsy_contract');return C end
 local menu=false;for _,id in ipairs(fd.buildOptions or{})do if id==name.id then menu=true end end
 if not menu then fail('actual_patrol_menu_missing');return C end;C.def=name.id
 local function envelope(id)
  local facing=S.GetUnitBuildFacing(id)
  if not finite(facing)or facing%1~=0 or facing<0 or facing>3 then return nil end
  local front,up,right=S.GetUnitVectors(id)
  for _,v in pairs({front=front,up=up,right=right})do if type(v)~='table'then return nil end;for i=1,3 do if not finite(v[i])then return nil end end end
  if type(front)~='table'or type(up)~='table'or type(right)~='table'then return nil end
  local e=physical.Envelope(S,D,id)
  if type(e)~='table'or not finite(e.minX)or not finite(e.maxX)or not finite(e.minZ)or not finite(e.maxZ)or e.minX>e.maxX or e.minZ>e.maxZ then return nil end
  return e
 end
 local function outside(parent,child)
  local p,c=envelope(parent),envelope(child);if not p or not c then return nil end
  return c.maxX<p.minX or c.minX>p.maxX or c.maxZ<p.minZ or c.minZ>p.maxZ
 end
 local function legal(x,z,actor)
  if not finite(x)or not finite(z)or not finite(Game.mapSizeX)or not finite(Game.mapSizeZ)then return false end
  local e=envelope(actor);local ax,_,az=S.GetUnitPosition(actor)
  if not e or not finite(ax)or not finite(az)then return false end
  -- Translate the actual current hull/yard union to the proposed destination.
  -- Live clearance checks use zero translation and the current native rotation.
  local dx,dz=x-ax,z-az
  local minX,maxX,minZ,maxZ=e.minX+dx-16,e.maxX+dx+16,e.minZ+dz-16,e.maxZ+dz+16
  local margin=math.max(x-minX,maxX-x,z-minZ,maxZ-z)
  if margin>256 or minX<64 or minZ<64 or maxX>Game.mapSizeX-64 or maxZ>Game.mapSizeZ-64 then return false end
  for gx=math.floor(minX/8)*8,math.ceil(maxX/8)*8,8 do for gz=math.floor(minZ/8)*8,math.ceil(maxZ/8)*8,8 do
   local h=S.GetGroundHeight(gx,gz);if not finite(h)or h>-d.minWaterDepth then return false end
  end end
  if S.TestMoveOrder(C.def,x,0,z,0,0,0,true,true,false)~=true then return false end
  local units,features=S.GetUnitsInCylinder(x,z,margin+32),S.GetFeaturesInCylinder(x,z,margin+32)
  if type(units)~='table'or type(features)~='table'then return false end
  for _,id in pairs(units)do if id~=actor then return false end end
  return next(features)==nil
 end
 local function destination(id)
  local fx,_,fz=S.GetUnitPosition(factory)
  if not finite(fx)or not finite(fz)then return nil end
  for ring=2,6 do for a=0,15 do local angle=a*math.pi/8;local x,z=math.floor(fx+ring*128*math.cos(angle)+.5),math.floor(fz+ring*128*math.sin(angle)+.5)
   if legal(x,z,id)then return{x,0,z}end
  end end
 end
 function C.Created(id,def,owner,builder)
  if C.result or def~=C.def then return end
  if C.phase~='building'or C.birth~=nil or owner~=team or builder~=factory or C.seen[id]or C.retired[id]or not bill(id)then fail('native_paid_product_birth_mismatch');return end
  C.birth=id;C.seen[id]=true;emit('PATROL_BIRTH',C.cycle,id,factory,'native_unit_bill=210,1400,2500 debit_proof=false')
 end
 function C.Finished(id,def,owner)
  if C.result or def~=C.def then return end
  if id~=C.birth or owner~=team or C.finished then fail('native_finish_mismatch');return end
  C.finished=true;emit('PATROL_FINISHED',C.cycle,id,'actual_callback=true')
 end
 function C.Released(id,def,owner,producer,producerDef,userOrders)
  if C.result or def~=C.def then return end
  if id~=C.birth or owner~=team or producer~=factory or producerDef~=S.GetUnitDefID(factory)or userOrders~=false or not C.finished or C.released then fail('native_release_mismatch');return end
  C.released=true;emit('PATROL_RELEASE',C.cycle,id,producer,'user_orders=false')
 end
 function C.Step(frame)
  if C.result then return C.result end
  if not live(factory)or S.GetUnitDefID(factory)~=factoryDef then return fail('paid_factory_lost')end
  for _,id in ipairs(C.products)do if not live(id)or S.GetUnitDefID(id)~=C.def or not bill(id)or outside(factory,id)~=true then return fail('earlier_product_not_retained_outside')end end
  if C.phase=='queue'then
   if not GG.Recoil40KResearch or not GG.Recoil40KResearch.CanBuild(team,C.def,factory,false)then return fail('ordinary_paid_patrol_gate')end
   local queue=S.GetFactoryCommands(factory,-1);if type(queue)~='table'or next(queue)~=nil then return fail('unowned_or_unknown_factory_queue')end
   C.phase='building'
   if S.GiveOrderToUnit(factory,-C.def,{},0)~=true then return fail('native_build_dispatch_refused')end
   emit('PATROL_ORDER',C.cycle,factory,'ordinary_native_dispatch=true grants=false AllowCommand_acceptance_not_inferred=true')
   return
  elseif C.phase=='building'then
   if not C.finished or not C.released then return end
   if not live(C.birth)or S.GetUnitDefID(C.birth)~=C.def or not bill(C.birth)then return fail('actual_complete_product_missing')end
   C.target=destination(C.birth);if not C.target then return fail('no_clear_full_draft_water_departure')end
   if S.GiveOrderToUnit(C.birth,CMD.MOVE,C.target,0)~=true then return fail('native_departure_dispatch_refused')end
   local cmd,_,_,x,y,z=S.GetUnitCurrentCommand(C.birth)
   if cmd~=CMD.MOVE or x~=C.target[1]or y~=C.target[2]or z~=C.target[3]then return fail('departure_queue_readback_mismatch')end
   C.phase='clear';emit('PATROL_MOVE',C.cycle,C.birth,unpack(C.target));return
  elseif C.phase=='clear'then
   if not live(C.birth)or S.GetUnitDefID(C.birth)~=C.def or not bill(C.birth)then return fail('released_product_lost')end
   local x,_,z=S.GetUnitPosition(C.birth);local vx,vy,vz=S.GetUnitVelocity(C.birth)
   local settled=type(vx)=='number'and type(vy)=='number'and type(vz)=='number'and vx*vx+vy*vy+vz*vz<.01
   if not settled or(x-C.target[1])^2+(z-C.target[3])^2>24^2 or not legal(x,z,C.birth)or outside(factory,C.birth)~=true then C.clearFrames=0;C.clearStart=nil;C.last=nil;return end
   C.clearFrames=C.last==frame-1 and(C.clearFrames or 0)+1 or 1;C.last=frame;if C.clearFrames==1 then C.clearStart=frame end
   if C.clearFrames<30 then return end
   emit('PATROL_CLEAR30',C.cycle,C.birth,C.clearStart,frame,'actual_native_union_outside=true full_footprint_draft=true')
   C.products[#C.products+1]=C.birth
   if C.cycle==2 then C.result='PASS two_distinct_ordinary_patrol_products_native_finish_release_settled_clear30 debit_economy_render_acceptance_pending';return C.result end
   C.cycle=2;C.birth=nil;C.finished=nil;C.released=nil;C.clearFrames=0;C.clearStart=nil;C.last=nil;C.phase='queue'
  end
 end
 return C
end
return M
