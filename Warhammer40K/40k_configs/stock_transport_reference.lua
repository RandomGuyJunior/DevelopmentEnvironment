-- Read-only observer over unmodified stock bodies; never engine physics or orders.
local M={Donor='corhvytrans',Passenger='corak',DonorMD5='51e16dadeb1c0c55574fddc5287126a5'}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function count(t)local n=0;for _ in pairs(t or{})do n=n+1 end;return n end
function M.EightFits(carrier,bodies)
 local size,mass,maxSize=0,0,0
 if not carrier or not finite(carrier.transportCapacity)or not finite(carrier.transportSize)then return false,'native_limits_unreadable'end
 if #bodies~=8 then return false,'eight_actual_bodies_required'end
 for _,d in ipairs(bodies)do
  if not finite(d.size)or not finite(d.mass)or d.size<=0 or d.mass<=0 then return false,'body_native_limits_unreadable'end
  size=size+d.size;mass=mass+d.mass;maxSize=math.max(maxSize,d.size)
 end
 if size>carrier.transportCapacity or maxSize>carrier.transportSize or(finite(carrier.transportMass)and mass>carrier.transportMass)then
  return false,'unchanged_stock_donor_has_no_whole8_capacity',{size=size,mass=mass,nativeCapacity=carrier.transportCapacity,maxSize=maxSize}
 end
 return true
end
function M.New(c)
 local S,D,N=c.Spring,c.UnitDefs,c.UnitDefNames
 local R={result=nil,cycle=1,index=1,phase='ground_before',loaded={},unloaded={},snapshots={},groundFrames=0}
 function R.Step()return R.result end
 local function stop(why)R.result=R.result or why;return R.result end
 local function emit(e,...)if c.Emit then c.Emit('STOCK_TRANSPORT_'..e,...)end end
 local o=c.options or{}
 if tostring(o.prototype_stock_transport_reference)~='1'or o.prototype_diagnostic~='normal'
  or not(tostring(o.prototype_source_progression)=='0'or o.prototype_source_progression==false)
  or not(tostring(o.prototype_development_playtest)=='0'or o.prototype_development_playtest==false)then
  stop('REFUSED reference_requires_isolated_stock_definition_mode');return R
 end
 local apis={'GetUnitDefID','GetUnitTeam','GetUnitIsDead','GetUnitHealth','GetUnitMass','GetUnitPosition','GetUnitVelocity',
  'GetUnitIsTransporting','GetUnitTransporter','GetGroundHeight','GetUnitVectors','GetUnitCollisionVolumeData','GetGameFrame'}
 for _,name in ipairs(apis)do if type(S[name])~='function'then stop('INCONCLUSIVE reference_missing_api '..name);return R end end
 if not N or not N.corhvytrans or not N.corak or not c.carrier or type(c.bodies)~='table'or #c.bodies~=8 then stop('REFUSED stock_reference_requires_donor_and_eight_individuals');return R end
 local donor=D[N.corhvytrans.id]
 if not donor or S.GetUnitDefID(c.carrier)~=N.corhvytrans.id or donor.transportCapacity~=1 or donor.transportSize~=4 or donor.canFly~=true
  or c.donorMD5~=M.DonorMD5 then stop('REFUSED unchanged_pinned_stock_donor_contract');return R end
 local ids={};local defs={}
 for i,id in ipairs(c.bodies)do
  if ids[id]or id==c.carrier or S.GetUnitDefID(id)~=N.corak.id then stop('REFUSED eight_distinct_stock_corak_required');return R end
  local d=D[N.corak.id];local mass=S.GetUnitMass(id)
  if not d or not finite(d.xsize)or not finite(mass)or mass<=0 or d.canFly==true or d.cantBeTransported then stop('REFUSED stock_passenger_native_limits');return R end
  ids[id]=i;defs[i]={size=d.xsize/2,mass=mass};R.snapshots[id]={def=N.corak.id,team=S.GetUnitTeam(id)}
 end
 local fits,why,facts=M.EightFits(donor,defs)
 emit('CAPACITY_PREFLIGHT','whole8_fits='..tostring(fits),'reason='..tostring(why),'native_capacity=1','mode='..tostring(c.mode))
 if c.mode~='sequential'then stop('REFUSED '..tostring(why or'whole8_mode_requires_separate_review'));return R end
 if fits then stop('REFUSED sequential_reference_donor_capacity_drift');return R end
 local team=S.GetUnitTeam(c.carrier);R.snapshots[c.carrier]={def=N.corhvytrans.id,team=team}
 for _,v in pairs(R.snapshots)do if v.team~=team then stop('REFUSED stock_reference_team_mismatch');return R end end
 local function live()
  for id,v in pairs(R.snapshots)do
   local hp,_,_,_,p=S.GetUnitHealth(id)
   if S.GetUnitIsDead(id)or S.GetUnitDefID(id)~=v.def or S.GetUnitTeam(id)~=v.team or not hp or hp<=0 or p~=1 then return false end
  end;return true
 end
 if not live()then stop('REFUSED reference_bodies_not_finished_native_products');return R end
 local function nativeCargo()
  local a=S.GetUnitIsTransporting(c.carrier)
  if type(a)~='table'then stop('INCONCLUSIVE reference_native_cargo_unreadable');return end
  local set={};for _,id in ipairs(a)do
   if set[id]or not ids[id]then stop('FAIL reference_foreign_or_duplicate_cargo');return end
   set[id]=true
  end
  if count(set)>1 then stop('FAIL unchanged_stock_single_body_capacity_exceeded');return end
  return set,count(set)
 end
 local function ground(id,frame)
  local x,y,z,mx,my,mz=S.GetUnitPosition(id,true)
  local vx,vy,vz=S.GetUnitVelocity(id);local sx,sy,sz,ox,oy,oz,kind,test,axis,disabled=S.GetUnitCollisionVolumeData(id)
  local front,up,right=S.GetUnitVectors(id)
  local values={x,y,z,mx,my,mz,vx,vy,vz,sx,sy,sz,ox,oy,oz}
  for i=1,15 do if not finite(values[i])then return nil,'native_ground_geometry_unreadable'end end
  if not front or not up or not right or disabled==true then return nil,'native_collision_axes_unreadable'end
  for _,v in ipairs({front,up,right})do for i=1,3 do if not finite(v[i])then return nil,'native_collision_axes_unreadable'end end end
  local cy=my-right[2]*ox+up[2]*oy+front[2]*oz
  local hy=(math.abs(right[2])*sx+math.abs(up[2])*sy+math.abs(front[2])*sz)*.5
  local terrain=S.GetGroundHeight(x,z);local bottom=cy-hy
  if not finite(terrain)then return nil,'native_ground_unreadable'end
  emit('GROUND_GEOMETRY','frame='..frame,'cycle='..R.cycle,'index='..R.index,'body='..id,'base='..x..','..y..','..z,
   'ground='..terrain,'base_ground_delta='..(y-terrain),'collision_bottom='..bottom,'collision_ground_delta='..(bottom-terrain),
   'native_velocity='..vx..','..vy..','..vz,'primitive='..tostring(kind)..','..tostring(test)..','..tostring(axis),
   'geometry_readback_not_contact_callback=true')
  -- Ground reference is a bounded native settled pose, not an invented contact
  -- callback or proof that the mesh sole touches the terrain.
  return math.abs(y-terrain)<=4 and math.abs(vy)<=.05 and vx*vx+vz*vz<=.25
 end
 function R.Loaded(id,def,owner,carrier,carrierTeam)
  if R.result or not ids[id]then return end
  if carrier~=c.carrier or carrierTeam~=team or owner~=team or def~=N.corak.id or id~=c.bodies[R.index]
   or R.phase~='await_load'or R.loaded[id]then stop('FAIL unexpected_reference_load_callback');return end
  R.loaded[id]=true;R.phase='await_unload';R.groundFrames=0
  emit('LOADED','cycle='..R.cycle,'index='..R.index,'body='..id,'carrier='..carrier,'frame='..S.GetGameFrame())
 end
 function R.Unloaded(id,def,owner,carrier,carrierTeam)
  if R.result or not ids[id]then return end
  if carrier~=c.carrier or carrierTeam~=team or owner~=team or def~=N.corak.id or id~=c.bodies[R.index]
   or R.phase~='await_unload'or R.unloaded[id]then stop('FAIL unexpected_reference_unload_callback');return end
  R.unloaded[id]=true;R.phase='ground_after';R.groundFrames=0
  emit('UNLOADED','cycle='..R.cycle,'index='..R.index,'body='..id,'carrier='..carrier,'frame='..S.GetGameFrame())
 end
 function R.Step(frame)
  if R.result then return R.result end
  if not live()then return stop('FAIL stock_reference_identity_lost')end
  if frame%15~=0 then return end
  local set,n=nativeCargo();if not set then return R.result end
  local id=c.bodies[R.index]
  if R.phase=='ground_before'or R.phase=='ground_after'then
   if n~=0 or S.GetUnitTransporter(id)then return stop('FAIL stock_ground_reference_still_attached')end
   local grounded,why=ground(id,frame)
   if grounded==nil then return stop('INCONCLUSIVE '..why)end
   R.groundFrames=grounded and(R.groundFrames+15)or 0
   if R.groundFrames>=90 then
    if R.phase=='ground_before'then
     R.phase='await_load';emit('READY_NORMAL_PICKUP','cycle='..R.cycle,'index='..R.index,'carrier='..c.carrier,'body='..id)
    else
     emit('BODY_CYCLE_PASS','cycle='..R.cycle,'index='..R.index,'same_native_body=true grounded_pose_observed=true mesh_contact_acceptance=false')
     R.index=R.index+1;R.groundFrames=0;R.phase='ground_before'
     if R.index>8 then
      emit('CYCLE_PASS','cycle='..R.cycle,'eight_sequential_single_body_operations=true whole_squad_capacity_acceptance=false')
      if R.cycle==2 then return stop('PASS funded_stock_single_body_reference eight_individuals_twice native_callbacks_ground_geometry whole8_capacity_refused contact_mesh_and_economy_acceptance=false')end
      R.cycle=2;R.index=1;R.loaded={};R.unloaded={}
     end
    end
   end
  elseif R.phase=='await_load'then
   if n~=0 or S.GetUnitTransporter(id)then return stop('FAIL stock_cargo_without_matching_loaded_callback')end
  elseif R.phase=='await_unload'then
   if n~=1 or not set[id]or S.GetUnitTransporter(id)~=c.carrier then return stop('FAIL stock_loaded_native_cargo_mismatch')end
  end
  return R.result
 end
 emit('BEGIN','funded_isolated_physical_reference=true economy_acceptance=false whole8_capacity_acceptance=false orders_by_observer=false')
 return R
end
return M
