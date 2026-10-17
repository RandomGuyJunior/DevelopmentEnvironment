-- Default-off bounded model/placement observations. No new economy/salvage owner.
local M={Version=3,PaidSettleFrames=60,ReferenceSettleFrames=150,Option='prototype_generator_native_fixture',Timeout=3600}
local function yes(v)return v==true or v==1 or v=='1'end
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function near(a,b)return finite(a)and finite(b)and math.abs(a-b)<=.002 end
local function num(v)assert(finite(v),'finite native telemetry required');return string.format('%.17g',v)end
local function vec(v)local out={};for i=1,#v do out[i]=num(v[i])end;return table.concat(out,',')end
function M.Enabled(o)return o and yes(o[M.Option])or false end
function M.CloseHold(mode)return mode=='appearance'and 600 or 90 end
function M.SelectContract(contract,options)
 if contract and contract.schema==2 and contract.scopes then return contract.scopes[yes(options.prototype_extractor_fixed_tier_pilot)and'fixed-tier-model-qa'or'normal']end
 return contract
end
-- Exact current six-key land diagnostic; QA scope is required for optional tiers.
function M.Keys(contract,mode,key)
 if key=='land'then
  if mode~='appearance'or contract.scope~='fixed-tier-model-qa'then return nil,'FAIL exact_land_appearance_qa_required'end
  local keys={'imp_generator','imp_marine_generator','nec_generator','ork_generator','ork_generator_t2','ork_generator_t3'}
  for _,k in ipairs(keys)do local r=contract.rows[k];if not r or (r.referenceOriginalKey or r.referenceKey)=='wh40k_corgeo'then return nil,'FAIL exact_six_land_contract_required'end end
  return keys
 end
 local keys={};if key=='all'and mode=='appearance'then for k in pairs(contract.rows)do keys[#keys+1]=k end;table.sort(keys)
 elseif type(key)=='string'and contract.rows[key]then keys={key}
 else return nil,'FAIL exact_bound_generator_key'end
 return keys
end
-- Predict only the same-def cardinal build pose from already validated current
-- bind midpoint/collider data. Final actual native Outside() remains authoritative.
function M.NeighborEnvelope(row,p)
 local facing=p[4];if facing~=0 and facing~=1 then return nil end
 local mid=row.native_bind_midpoint;local c=row.collision
 local ox=mid[1]+c.offsets[1];local oz=mid[3]+c.offsets[3]
 local hx,hz=c.scales[1]/2,c.scales[3]/2;local yardX,yardZ=row.xsize*4,row.zsize*4
 if facing==1 then ox,oz=oz,-ox;hx,hz=hz,hx;yardX,yardZ=yardZ,yardX end
 return{minX=math.min(p[1]-yardX,p[1]+ox-hx),maxX=math.max(p[1]+yardX,p[1]+ox+hx),minZ=math.min(p[3]-yardZ,p[3]+oz-hz),maxZ=math.max(p[3]+yardZ,p[3]+oz+hz)}
end
function M.Separate(a,b)return a and b and(a.maxX<b.minX or a.minX>b.maxX or a.maxZ<b.minZ or a.minZ>b.maxZ)or false end
local function normalized(path,prefix)return tostring(path or''):gsub('\\','/'):gsub('^'..prefix..'/','')end
function M.ReferenceDefinition(r,N,U,emit)
 local n=N[r.key];local d=n and U[n.id];local cp=d and d.customParams or{}
 if emit then
  local failed={};local function check(name,pass)if not pass then failed[#failed+1]=name end end
  check('definition_present',d~=nil)
  if d then
   check('model',normalized(d.modelname,'objects3d')==r.model);check('script',normalized(d.scriptName or d.scriptPath,'scripts')==r.script)
   check('original_marker',cp.prototype40k_original_generator_reference==r.originalKey);check('profile',cp.original_reference_profile==r.key)
   check('model_sha',cp.original_bar_model_sha256==r.modelSHA256);check('script_sha',cp.original_bar_script_sha256==r.scriptSHA256)
   check('definition_sha',cp.original_bar_definition_sha256==r.sourceDefinitionSHA256);check('diagnostic_only',tostring(cp.diagnostic_only)=='1')
   check('isBuilding',not not d.isBuilding);check('isFactory',not d.isFactory);check('isBuilder',not d.isBuilder);check('canMove',not d.canMove);check('canAttack',not d.canAttack)
   check('xsize',d.xsize==r.xsize);check('zsize',d.zsize==r.zsize);check('metal',d.metalCost==r.metal);check('energy',d.energyCost==r.energy);check('work',d.buildTime==r.work);check('hp',d.health==r.hp)
  end
  local function value(v)
   local t=type(v);local s=tostring(v):gsub('[^%w_%.%-%/]',function(c)return string.format('%%%02X',string.byte(c))end)
   return t..':'..s
  end
  emit('key='..r.key..' original_key='..r.originalKey..' definition='..value(n and n.id)..' failed_fields='..(#failed==0 and'none'or table.concat(failed,','))
   ..' actual_model='..value(d and d.modelname)..' expected_model='..value(r.model)
   ..' scriptName='..value(d and d.scriptName)..' scriptPath='..value(d and d.scriptPath)..' actual_script_normalized='..value(d and normalized(d.scriptName or d.scriptPath,'scripts'))..' expected_script='..value(r.script)
   ..' isBuilding='..value(d and d.isBuilding)..' expected_isBuilding=boolean:true isFactory='..value(d and d.isFactory)..' expected_isFactory=boolean:false'
   ..' isBuilder='..value(d and d.isBuilder)..' expected_isBuilder=boolean:false canMove='..value(d and d.canMove)..' expected_canMove=boolean:false canAttack='..value(d and d.canAttack)..' expected_canAttack=boolean:false'
   ..' identity_accepted=false visual_accepted=false economy_accepted=false')
 end
 if not d or normalized(d.modelname,'objects3d')~=r.model or normalized(d.scriptName or d.scriptPath,'scripts')~=r.script
  or cp.prototype40k_original_generator_reference~=r.originalKey or cp.original_reference_profile~=r.key
  or cp.original_bar_model_sha256~=r.modelSHA256 or cp.original_bar_script_sha256~=r.scriptSHA256
  or cp.original_bar_definition_sha256~=r.sourceDefinitionSHA256 or tostring(cp.diagnostic_only)~='1'
  or not d.isBuilding or d.isFactory or d.isBuilder or d.canMove or d.canAttack
  or d.xsize~=r.xsize or d.zsize~=r.zsize or d.metalCost~=r.metal or d.energyCost~=r.energy or d.buildTime~=r.work or d.health~=r.hp then
  return nil,'FAIL original_reference_loaded_identity_'..tostring(r.key)
 end
 return d
end
function M.ReferenceDimensions(r,d)
 if type(d)~='table'then return false end
 for axis,n in ipairs({'x','y','z'})do
  if not near(d['min'..n],r.bind_bounds.min[axis])or not near(d['max'..n],r.bind_bounds.max[axis])or not near(d['mid'..n],r.native_bind_midpoint[axis])then return false end
 end
 return near(d.height,r.height)and near(d.radius,r.radius)
end
function M.New(S,U,N,F,GG,G,CMD,options,contract,site,geometry,emit,selection)
 local C={started=S.GetGameFrame(),phase='wait',tracked={},scene={},references={},owned={},created={},finished={}}
 local function referenceLoad(text)S.Echo('40K_GENERATOR_REFERENCE_LOAD '..text)end
 function C.Close()C.closed=true end
 local function stop(why)C.result=C.result or why;return C.result end
 local mode=options.prototype_generator_native_mode;local key=options.prototype_generator_native_key
 if mode~='appearance'and mode~='paid-neighbor'then stop('FAIL explicit_generator_mode');return C end
 if type(contract)~='table'or contract.schema~=1 or type(contract.rows)~='table'then stop('FAIL bound_generator_contract_required');return C end
 if contract.scope=='fixed-tier-model-qa'and mode~='appearance'then stop('FAIL fixed_tier_qa_model_only');return C end
 C.mode=mode;C.key=key
 local keys,why=M.Keys(contract,mode,key);if not keys then stop(why);return C end
 if #keys==0 or #keys>24 then stop('FAIL bounded_generator_target_count');return C end
 for _,k in ipairs(keys)do
  local r=contract.rows[k];local d=N[k]and U[N[k].id];local cp=d and d.customParams or{}
  for option,value in pairs(r.normalPresenceSourceOptions or{})do
   local actual=options[option];local matches=type(value)=='boolean'and yes(actual)==value or(type(value)~='boolean'and tostring(actual)==tostring(value))
   if not matches then stop('FAIL native_source_option_scope_'..option);return C end
  end
  if not d or r.key~=k or cp.prototype40k_visual_scale_profile~=r.profile or cp.animsource~=r.profile
   or tostring(d.modelname or''):gsub('\\','/'):gsub('^objects3d/','')~=r.model then stop('FAIL loaded_scaled_generator_identity_'..k);return C end
  if not(d.isBuilding and not d.isFactory)or d.xsize~=r.xsize or d.zsize~=r.zsize
   or d.metalCost~=r.metal or d.energyCost~=r.energy or d.buildTime~=r.work or d.health~=r.hp then stop('FAIL unchanged_bill_grid_or_life_'..k);return C end
  if r.corpse then
   local f;for _,definition in pairs(F)do if definition.name==r.corpse.name then f=definition;break end end
   if not f or f.metal~=r.corpse.metal or f.energy~=r.corpse.energy or f.resurrectable~=0 or not f.reclaimable then stop('FAIL unchanged_wreck_resources_'..k);return C end
  end
  r.def=d.id;C.tracked[d.id]=r
 end
 C.keys=keys
 if mode=='appearance'then
  if type(contract.referenceRows)~='table'then stop('FAIL exact_original_reference_contract_required');return C end
  for _,k in ipairs(keys)do local r=contract.rows[k];local ref=r.referenceKey and contract.referenceRows[r.referenceKey]
   if not ref or ref.originalKey~=r.referenceOriginalKey then stop('FAIL original_reference_mapping_'..k);return C end
   local def,why=M.ReferenceDefinition(ref,N,U,referenceLoad);if not def then stop(why);return C end
  end
 end
 local function health(id)local hp,_,_,_,progress=S.GetUnitHealth(id);return hp and hp>0 and progress and progress>=1 end
 local function lookup(id)local d=S.GetUnitDefID(id);return d and C.tracked[d]end
 local function envelope(id)return geometry.Envelope(S,U,id)end
 local function powerSample(id,r,paid,reason)
  local frame=S.GetGameFrame();local hp,_,_,_,progress=S.GetUnitHealth(id);local active=S.GetUnitIsActive(id)
  local disabled,stunned,built=S.GetUnitIsStunned(id);local make,use,power,powerUse=S.GetUnitResources(id)
  if not finite(progress)or type(active)~='boolean'or type(disabled)~='boolean'or type(stunned)~='boolean'or type(built)~='boolean'
   or not finite(make)or not finite(use)or not finite(power)or not finite(powerUse)then return stop('FAIL native_power_readiness_unreadable_'..r.key)end
  local finished=C.finished[id];local age=finished and frame-finished or -1
  emit('POWER_SAMPLE key='..r.key..' unit='..id..' tuple='..vec({make,use,power,powerUse})..' declared_power='..num(r.power)
   ..' progress='..num(progress)..' active='..tostring(active)..' disabled='..tostring(disabled)..' stunned='..tostring(stunned)..' being_built='..tostring(built)
   ..' finish_frame='..tostring(finished or -1)..' finish_age='..tostring(age)..' paid='..tostring(paid)..' reason='..reason..' nominal_output_accepted=false economy_accepted=false')
  return{make,use,power,powerUse,ready=progress>=1 and not disabled and not stunned and not built}
 end
 local function observe(id,paid)
  local r=lookup(id);if not r or not health(id)then return stop('FAIL finished_scaled_generator_required')end
  local dimensions=S.GetUnitDefDimensions(r.def)
  if type(dimensions)~='table'then return stop('FAIL actual_native_dimensions_required')end
  local fields={'minx','miny','minz','maxx','maxy','maxz','midx','midy','midz','height','radius'}
  for _,f in ipairs(fields)do if not finite(dimensions[f])then return stop('FAIL incomplete_native_dimensions_'..f)end end
  local v={S.GetUnitCollisionVolumeData(id)}
  if #v~=10 or v[10]~=false then return stop('FAIL actual_native_collision_required')end
  if v[7]~=r.collision.nativeType then return stop('FAIL native_collision_type_'..r.key)end
  if r.collision.nativeAxis and v[9]~=r.collision.nativeAxis then return stop('FAIL native_collision_axis_'..r.key)end
  for axis=1,3 do if not near(v[axis],r.collision.scales[axis])or not near(v[axis+3],r.collision.offsets[axis])then return stop('FAIL native_collision_scale_offset_'..r.key)end end
  for axis,f in ipairs({'midx','midy','midz'})do if not near(dimensions[f],r.native_bind_midpoint[axis])then return stop('FAIL current_bind_midpoint_'..r.key)end end
  local min={dimensions.minx,dimensions.miny,dimensions.minz};local max={dimensions.maxx,dimensions.maxy,dimensions.maxz}
  if r.bind_bounds then for axis=1,3 do if not near(min[axis],r.bind_bounds.min[axis])or not near(max[axis],r.bind_bounds.max[axis])then return stop('FAIL current_native_bind_bounds_'..r.key)end end end
  local x,y,z=S.GetUnitPosition(id);local ground=S.GetGroundHeight(x,z)
  if not finite(x)or not finite(y)or not finite(z)or not finite(ground)then return stop('FAIL actual_generator_position_required')end
  local clearance=y+r.bounds.min[2]-ground
  if clearance<-.5 or clearance>2 then return stop('FAIL grounded_generator_clearance_'..r.key)end
  local tuple=powerSample(id,r,paid,'admission');if C.result then return C.result end
  if not tuple.ready then return stop('FAIL native_output_readiness_'..r.key)end
  local make,use,power,powerUse=unpack(tuple)
  if not near(power,r.power)or not near(make,0)or not near(powerUse,r.energyUpkeep or 0)then return stop('FAIL native_output_changed_'..r.key)end
  local env,why=envelope(id);if not env then return stop('FAIL '..tostring(why))end
  emit('MODEL key='..r.key..' unit='..id..' profile='..r.profile..' model='..r.model..' model_sha256='..r.modelSHA256
   ..' min='..vec(min)..' max='..vec(max)..' midpoint='..vec({dimensions.midx,dimensions.midy,dimensions.midz})
   ..' collision='..vec({v[1],v[2],v[3],v[4],v[5],v[6]})..' collision_type='..v[7]..' facing='..env.facing
   ..' envelope='..vec({env.minX,env.maxX,env.minZ,env.maxZ})
   ..' xsize='..r.xsize..' zsize='..r.zsize..' position='..vec({x,y,z})..' ground='..num(ground)..' clearance='..num(clearance)
   ..' power='..num(power)..' metal='..num(r.metal)..' energy='..num(r.energy)..' work='..num(r.work)..' hp='..num(r.hp)
   ..' paid_birth='..tostring(paid)..' visual_accepted=false economy_accepted=false')
  selection(id,r.key)
  return env
 end
 local function flat(def,x,z,facing)
  local xx,yy,zz=S.Pos2BuildPos(def,x,0,z,facing);if not finite(xx)or not finite(zz)then return end
  yy=S.GetGroundHeight(xx,zz);local d=U[def];local hx,hz=d.xsize*4,d.zsize*4;if facing%2==1 then hx,hz=hz,hx end
  if xx<hx+32 or zz<hz+32 or xx>G.mapSizeX-hx-32 or zz>G.mapSizeZ-hz-32 then return end
  for _,p in ipairs({{0,0},{hx,hz},{hx,-hz},{-hx,hz},{-hx,-hz}})do if math.abs(S.GetGroundHeight(xx+p[1],zz+p[2])-yy)>.5 then return end end
  local status,feature=S.TestBuildOrder(def,xx,yy,zz,facing)
  if status~=2 or feature then return end
  if #(S.GetUnitsInRectangle(xx-hx-24,zz-hz-24,xx+hx+24,zz+hz+24)or{})>0 then return end
  return{xx,yy,zz,facing}
 end
 local function geo(def)
  for _,fid in ipairs(S.GetAllFeatures()or{})do local f=F[S.GetFeatureDefID(fid)]
   if f and f.geoThermal then local x,_,z=S.GetFeaturePosition(fid);local p=flat(def,x,z,0);if p then return p end end
  end
 end
 local function locate(def,facing,around)
  if U[def].needGeo then return geo(def)end
  local cx,cz=around and around[1]or G.mapSizeX/2,around and around[3]or G.mapSizeZ/2
  for ring=0,12 do for i=0,15 do local a=i*math.pi/8;local p=flat(def,cx+ring*160*math.cos(a),cz+ring*160*math.sin(a),facing);if p then return p end end end
 end
 local function witnessQueue()
  for _,q in ipairs(S.GetUnitCommands(C.builder,128)or{})do
   if q.id==-C.commandDef and q.params and #q.params>=3 and near(q.params[1],C.commandPos[1])and near(q.params[3],C.commandPos[3])then
    if not C.queueWitness then emit('NATIVE_QUEUE key='..key..' builder='..C.builder..' def='..C.commandDef..' tag='..q.tag..' native_paid_command=true')end
    C.queueWitness=true;if C.pending then C.created[C.pending].queue=true end
   end
  end
 end
 local function nativeCommand(def,p)
  C.commandDef=def;C.commandPos=p;C.commandAt=S.GetGameFrame();C.queueWitness=false
  emit('BUILD_ORDER key='..C.key..' builder='..C.builder..' def='..def..' at='..vec({p[1],p[2],p[3]})..' facing='..p[4]..' menu=true diagnostic_grants=false')
  if S.GiveOrderToUnit(C.builder,-def,p,0)==false then return stop('FAIL ordinary_native_build_order_rejected')end
  witnessQueue()
 end
 function C.Created(id,def,team,builder)
  if C.closed or C.result then return end
  if C.mode=='paid-neighbor'and team==0 and builder==C.builder and def==C.commandDef then
   if C.pending then return stop('FAIL duplicate_pending_paid_generator')end
   C.pending=id;C.created[id]={builder=builder,frame=S.GetGameFrame(),queue=C.queueWitness}
   emit('PAID_CREATED key='..C.key..' unit='..id..' builder='..builder..' original_native_command=true')
  end
 end
 function C.Finished(id,def,team)if C.mode=='paid-neighbor'and C.created[id]and team==0 then
  C.finished[id]=S.GetGameFrame();powerSample(id,contract.rows[key],true,'finished')
 end end
 function C.Step(frame)
  if C.closed or C.result then return C.result end
  if frame-C.started>M.Timeout then return stop('INCONCLUSIVE bounded_generator_timeout_'..C.phase)end
  if C.phase=='wait'then
   if frame<30 then return end
   if mode=='appearance'then
    for _,k in ipairs(keys)do local r=contract.rows[k];local p=locate(r.def,0)
     if not p then return stop('INCONCLUSIVE no_native_flat_or_geothermal_site_'..k)end
     local id=S.CreateUnit(k,p[1],p[2],p[3],p[4],0)
     if id==nil or S.GetUnitDefID(id)~=r.def then return stop('FAIL funded_model_birth_'..k)end
     C.owned[#C.owned+1]=id;C.scene[#C.scene+1]=id
     emit('FUNDED_MODEL_BIRTH key='..k..' unit='..id..' unpaid=true diagnostic_grants=false economy_accepted=false')
     if r.referenceKey then
      local n=N[r.referenceKey];if not n then return stop('INCONCLUSIVE actual_native_reference_missing_'..r.referenceKey)end
      local at=locate(n.id,0,{p[1]+math.max(U[r.def].xsize,U[n.id].xsize)*8+96,0,p[3]})
      if not at then return stop('INCONCLUSIVE no_native_reference_site_'..r.referenceKey)end
      local ref=S.CreateUnit(r.referenceKey,at[1],at[2],at[3],0,0)
      if ref==nil or S.GetUnitDefID(ref)~=n.id then return stop('INCONCLUSIVE actual_native_reference_birth_'..r.referenceKey)end
      C.references[#C.references+1]={unit=ref,key=r.referenceKey,forKey=k,born=frame};C.owned[#C.owned+1]=ref
     end
    end
    C.observeAt=frame+M.ReferenceSettleFrames;C.phase='scene'
   else
    local r=contract.rows[key];local units=S.GetTeamUnits(0)or{}
    if #units~=1 then return stop('FAIL isolated_original_constructor_required')end
    C.builder=units[1];local d=U[S.GetUnitDefID(C.builder)];local menu=false
    if not d or not d.isBuilder or d.isFactory then return stop('FAIL ordinary_native_mobile_constructor_required')end
    for _,def in ipairs(d.buildOptions or{})do if def==r.def then menu=true end end
    if not menu then return stop('INCONCLUSIVE original_constructor_lacks_legitimate_target_access')end
    if #(S.GetUnitCommands(C.builder,128)or{})>0 then return stop('FAIL preserve_existing_constructor_orders')end
    local p=site.Choose(S,U,GG,G,r.def,C.builder,false,function()end,function(x,y,z,facing)return flat(r.def,x,z,facing)~=nil end)
    if not p then return stop('INCONCLUSIVE no_ordinary_paid_site')end
    C.firstPos=p;C.phase='funds1'
   end
  elseif C.phase=='scene'and frame>=C.observeAt then
   for _,id in ipairs(C.scene)do observe(id,false);if C.result then return C.result end end
   for _,r in ipairs(C.references)do
    if not health(r.unit)then return stop('FAIL actual_completed_native_reference_required')end
    local expected=contract.referenceRows[r.key];local loaded,why=M.ReferenceDefinition(expected,N,U,referenceLoad)
    if not loaded or S.GetUnitDefID(r.unit)~=loaded.id then return stop(why or'FAIL original_reference_native_unit_identity')end
    local d=S.GetUnitDefDimensions(loaded.id)
    if not M.ReferenceDimensions(expected,d)then return stop('FAIL original_reference_native_bind_bounds_'..r.key)end
    local active=S.GetUnitIsActive(r.unit);if type(active)~='boolean'or(expected.requiresActive and not active)then return stop('FAIL original_reference_activation_'..r.key)end
    if frame-r.born<M.ReferenceSettleFrames then return stop('FAIL original_reference_settle_clock_'..r.key)end
    emit('REFERENCE key='..r.key..' original_key='..expected.originalKey..' for_key='..r.forKey..' unit='..r.unit..' native_def='..loaded.id
     ..' model='..normalized(loaded.modelname,'objects3d')..' model_sha256='..expected.modelSHA256..' script='..normalized(loaded.scriptName or loaded.scriptPath,'scripts')..' script_sha256='..expected.scriptSHA256..' source_definition_sha256='..expected.sourceDefinitionSHA256
     ..' min='..vec({d.minx,d.miny,d.minz})..' max='..vec({d.maxx,d.maxy,d.maxz})..' midpoint='..vec({d.midx,d.midy,d.midz})..' height='..num(d.height)..' radius='..num(d.radius)
     ..' xsize='..expected.xsize..' zsize='..expected.zsize..' born_frame='..r.born..' settle_frames='..(frame-r.born)..' active='..tostring(active)
     ..' funded=true actual_loaded=true original_identity_verified=true completed_pose_visual_accepted=false')
   end
   emit('PASS appearance_native_geometry_rows='..#C.scene..' funded_models=true visual_accepted=false economy_accepted=false')
   return stop('PASS generator_model_geometry_observed')
  elseif C.phase=='funds1'or C.phase=='funds2'then
   local r=contract.rows[key];local metal=S.GetTeamResources(0,'metal');local energy=S.GetTeamResources(0,'energy')
   if finite(metal)and finite(energy)and metal>=r.metal+1 and energy>=r.energy+1 then
    emit('ORDINARY_FUNDS key='..key..' metal='..num(metal)..' energy='..num(energy)..' diagnostic_grants=false exact_debit_accepted=false')
    nativeCommand(r.def,C.phase=='funds1'and C.firstPos or C.secondPos);C.phase=C.phase=='funds1'and'build1'or'build2'
   end
  elseif C.phase=='build1'or C.phase=='build2'then
   if S.GetUnitIsDead(C.builder)~=false or S.GetUnitTeam(C.builder)~=0 then return stop('FAIL original_paid_constructor_lost')end
   witnessQueue()
   if C.pending and C.finished[C.pending]then
    local age=frame-C.finished[C.pending]
    if age>0 and age%15==0 and age<M.PaidSettleFrames then powerSample(C.pending,contract.rows[key],true,'settling');if C.result then return C.result end end
   end
   if C.pending and C.finished[C.pending]and frame-C.finished[C.pending]>=M.PaidSettleFrames then
    local id=C.pending;local birth=C.created[id]
    if not birth or not birth.queue or not health(id)then return stop('FAIL native_queue_birth_finish_witness_required')end
    local env=observe(id,true);if C.result then return C.result end
    C.owned[#C.owned+1]=id;emit('PAID_FINISHED key='..key..' unit='..id..' builder='..C.builder..' created_frame='..birth.frame..' finished_frame='..C.finished[id]..' ordinary_command=true exact_debit_accepted=false')
    C.pending=nil
    if C.phase=='build1'then
     C.first=id;C.firstEnvelope=env;local r=contract.rows[key];local d=U[r.def];local x,_,z=S.GetUnitPosition(id)
     local candidates={};for _,facing in ipairs({0,1})do
      local rel=M.NeighborEnvelope(r,{0,0,0,facing})
      for _,axis in ipairs({'x','z'})do for _,sign in ipairs({1,-1})do for pad=1,4 do
       local px,pz=x,z
       if axis=='x'then local edge=sign==1 and C.firstEnvelope.maxX-rel.minX or C.firstEnvelope.minX-rel.maxX;px=edge+sign*pad*8
       else local edge=sign==1 and C.firstEnvelope.maxZ-rel.minZ or C.firstEnvelope.minZ-rel.maxZ;pz=edge+sign*pad*8 end
       local p=flat(r.def,px,pz,facing)
       if p and M.Separate(C.firstEnvelope,M.NeighborEnvelope(r,p))then candidates[#candidates+1]=p end
      end end end
     end
     local status
     for _,candidate in ipairs(candidates)do
      local admitted,feature=S.TestBuildOrder(r.def,candidate[1],candidate[2],candidate[3],candidate[4])
      if admitted==2 and not feature and flat(r.def,candidate[1],candidate[3],candidate[4])and M.Separate(C.firstEnvelope,M.NeighborEnvelope(r,candidate))then C.secondPos=candidate;status=admitted;break end
     end
     if not C.secondPos then return stop('INCONCLUSIVE no_native_neighboring_paid_site')end
     emit('NEIGHBOR_SITE key='..key..' first='..id..' at='..vec({C.secondPos[1],C.secondPos[2],C.secondPos[3]})..' facing='..C.secondPos[4]..' native_test='..status..' grid_snapped=true')
     C.phase='funds2'
    else
     local clear,detail=geometry.Outside(S,U,C.first,id)
     if not clear then return stop('FAIL finished_neighbor_native_yard_collision_overlap')end
     emit('PASS paid_neighbor_key='..key..' first='..C.first..' second='..id..' native_envelopes_separate=true paid_births=2 diagnostic_grants=false exact_debit_accepted=false economy_accepted=false')
     return stop('PASS generator_ordinary_neighbor_built')
    end
   end
  end
  return C.result
 end
 return C
end
return M
