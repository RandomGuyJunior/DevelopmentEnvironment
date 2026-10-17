-- Exact Gunship factory/release/flight/weapon diagnostic, NOT ordinary economy.
-- Sole availability/menu owner remains ork_v13_build_graph; no runtime damage,
-- squad, repair or salvage owner is introduced here.
local M={Version=2,Option='prototype_ork_gunship_native_fixture'}
local function enabled(v)return v==true or v==1 or v=='1'end
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function contains(t,id)for _,v in ipairs(t or{})do if v==id then return true end end;return false end
local function path(v,prefix)return tostring(v or''):gsub('\\','/'):gsub('^'..prefix..'/','')end

-- Bounded read-only typed metadata before unchanged admission predicates.
local function typed(v)
 local k=type(v)
 if k=='nil'then return'nil~unavailable'end
 if k=='boolean'then return'boolean~'..tostring(v)end
 if k=='number'then return finite(v)and('number~'..string.format('%.17g',v))or'number~nonfinite'end
 if k=='string'then
  local b=v:sub(1,128);return'string~'..#v..'~'..b:gsub('.',function(c)return string.format('%02x',string.byte(c))end)..'~'..(#v>128 and'truncated'or'complete')
 end
 return k..'~unserialized'
end
function M.Observe(D,N,W,log)
 local function read(v,k)local ok,x=pcall(function()return v[k]end);if ok then return x end end
 local function row(owner,field,value)log('OBSERVED_FIELD','schema=1','owner='..owner,'field='..field,'value='..typed(value))end
 local function entity(key)local n=read(N,key);local id=read(n,'id');return id,read(D,id)end
 local fi,f=entity('fortyk_ork_super_air_factory');local pi,p=entity('ork_gunship');local ti,t=entity('ork_deff_dread')
 local menu=read(f,'buildOptions');local mounts=read(p,'weapons');local entry=read(mounts,1);local wi=read(entry,'weaponDef');local w=read(W,wi)
 local function count(v)local ok,n=pcall(function()return #v end);if ok then return n end end
 row('factory','definition',fi);row('product','definition',pi);row('target','definition',ti);row('weapon','definition',wi)
 for _,r in ipairs({{'factory',f},{'product',p},{'target',t}})do
  row(r[1],'model',read(r[2],'modelname'));row(r[1],'script',read(r[2],'scriptName'));row(r[1],'canFly',read(r[2],'canFly'))
 end
 for _,r in ipairs({{'factory',f},{'product',p}})do
  row(r[1],'metal',read(r[2],'metalCost'));row(r[1],'energy',read(r[2],'energyCost'));row(r[1],'work',read(r[2],'buildTime'))
 end
 row('factory','isFactory',read(f,'isFactory'));row('factory','labor',read(f,'buildSpeed'));row('factory','menuCount',count(menu));row('factory','menuProduct',read(menu,1))
 for _,k in ipairs({'canMove','canAttack','isBuilder'})do row('product',k,read(p,k))end
 local pc=read(p,'customParams');local tc=read(t,'customParams');local wc=read(w,'customParams')
 row('product','sourceAsset',read(pc,'prototype40k_source_asset'));row('product','recipe',read(pc,'prototype40k_ork_v13_recipe'))
 row('product','mountCount',count(mounts));row('product','weaponDef',wi)
 row('target','health',read(t,'health'));row('target','animsource',read(tc,'animsource'))
 for _,k in ipairs({'name','type','range','reload','salvoSize'})do row('weapon',k,read(w,k))end
 row('weapon','muzzle',read(wc,'source_muzzle'));row('weapon','aim',read(wc,'source_aimpiece'));row('weapon','pitch',read(wc,'source_pitchpiece'))
end

function M.Validate(D,N,W,o)
 assert(enabled((o or{})[M.Option]),'Explicit owned Gunship fixture required')
 assert(enabled(o.prototype_ork_advanced_air_development)and enabled(o.prototype_source_progression)and enabled(o.prototype_development_playtest),'Explicit existing advanced-air source graph required')
 assert(o.prototype_diagnostic=='normal'and tonumber(o.prototype_test_speed or 1)==1,'Normal simulation clock required')
 for key,v in pairs(o)do
  if enabled(v)and key~=M.Option and(key:match('_fixture$')or key:match('benchmark')or key:match('probe')or key=='prototype_burna_flame_combat')then error('Conflicting diagnostic '..key)end
 end
 local fn,pn,tn=N.fortyk_ork_super_air_factory,N.ork_gunship,N.ork_deff_dread
 assert(fn and pn and tn,'Exact AIR3/Gunship/hostile target definitions required')
 local f,p,t=D[fn.id],D[pn.id],D[tn.id];assert(f and p and t,'Native definitions absent')
 local fc,pc=f.customParams or{},p.customParams or{}
 assert(f.isFactory==true and not f.canFly and fc.prototype40k_ork_v13_recipe=='ORK-AIR-3'
  and path(f.scriptName,'scripts')=='40k_ork_static_factory.lua'and path(f.modelname,'objects3d')=='40k/fortyk_ork_super_air_factory.glb','Actual measured AIR3 factory required')
 assert(f.metalCost==4800 and f.energyCost==50000 and f.buildTime==85000 and finite(f.buildSpeed)and f.buildSpeed>0,'AIR3 real bill/labor changed')
 assert(#(f.buildOptions or{})==1 and contains(f.buildOptions,pn.id),'Sole actual AIR3 Gunship menu required')
 assert(p.canFly==true and p.canMove==true and p.canAttack==true and not p.isBuilder
  and pc.prototype40k_ork_v13_recipe=='ORK-AIR-3-GUNSHIP'and pc.prototype40k_source_asset=='MOW-02'
  and path(p.scriptName,'scripts')=='40k_ork_gunship.lua'and path(p.modelname,'objects3d')=='40k/ork_gunship.glb','Exact MOW-02 native Gunship required')
 assert(p.metalCost==4600 and p.energyCost==64000 and p.buildTime==60000,'Gunship real bill changed')
 assert(#(p.weapons or{})==1,'Exactly one actual nose mount required')
 local weapon=p.weapons[1].weaponDef;local w=W[weapon];local wc=w and w.customParams or{}
 assert(w and w.name=='ork_gunship_nose_kannon'and w.type=='Cannon'and w.range==1100
  and w.salvoSize==1 and finite(w.reload)and math.abs(w.reload-2.8)<.0001
  and wc.source_muzzle=='nose_muzzle'and wc.source_aimpiece=='nose_yaw'and wc.source_pitchpiece=='nose_pitch','Actual native processed Kannon contract required')
 assert(finite(t.health)and t.health>1360 and not t.canFly and(t.customParams or{}).animsource=='ork_deff_dread','Genuine existing Dread target must survive two unmodified nominal hits')
 return{factory=fn.id,product=pn.id,target=tn.id,weapon=weapon}
end
function M.New(S,D,N,W,G,Script,Game,CMD,options,geometry,emit,priorityCommand)
 local C={phase='initial',owned={},initial={},projectiles={},shots=0,hits=0,flightSamples=0}
 local function log(event,...)
  local a={...};a[#a+1]='funded_non_economy=true';a[#a+1]='ordinary_progression_accepted=false'
  a[#a+1]='visual_accepted=false';a[#a+1]='salvage_accepted=false';emit(event,unpack(a))
 end
 local function live(id,def,team,complete)
  if not id or not S.ValidUnitID(id)or S.GetUnitIsDead(id)or S.GetUnitDefID(id)~=def or S.GetUnitTeam(id)~=team then return false end
  local h,_,_,_,p=S.GetUnitHealth(id);return finite(h)and h>0 and(complete==false or p==1)
 end
 local function finish(reason)
  if C.result then return C.result end;C.result=reason;C.phase='done'
  for id,row in pairs(C.initial)do log('INITIAL_PRESERVED','actor='..id,'def='..row.def,'team='..row.team,'alive='..tostring(live(id,row.def,row.team)),'owned='..tostring(C.owned[id]==true))end
  log('COMPLETE',reason,'native_acceptance_requires_exact_bound_reader=true');return reason
 end
 local function fail(reason)return finish('FAIL '..reason)end
 local function queue()
  local total=0
  for _,row in ipairs(S.GetFullBuildQueue(C.factory)or{})do for def,count in pairs(row)do if def~=C.route.product then return nil end;total=total+count end end
  return total
 end
 local function productionObservation(frame,stage)
  -- Diagnostic observations only. API absence/errors remain explicitly typed;
  -- they do not change funding, queue ownership, build state or acceptance.
  local a={'schema=1','frame='..frame,'stage='..stage,'factory='..C.factory,'body='..tostring(C.product or'none')}
  local function read(name,...)
   local fn=S[name];if type(fn)~='function'then return{},'api_unavailable'end
   local ok,a,b,c,d,e,f,g,h,i=pcall(fn,...)
   if not ok then return{},'read_error'end
   return{a,b,c,d,e,f,g,h,i},'observed'
  end
  local function field(k,v)a[#a+1]=k..'='..typed(v)end
  local function values(prefix,name,id,names)
   if not id then field(prefix..'_status','actor_unset');for _,k in ipairs(names)do field(prefix..'_'..k,nil)end;return end
   local v,status=read(name,id);field(prefix..'_status',status)
   for i,k in ipairs(names)do field(prefix..'_'..k,v[i])end
  end
  values('factory_health','GetUnitHealth',C.factory,{'hp','max','paralyze','capture','build'})
  values('factory_active','GetUnitIsActive',C.factory,{'active'})
  values('factory_stun','GetUnitIsStunned',C.factory,{'disabled','stunned','being_built'})
  values('factory_building','GetUnitIsBuilding',C.factory,{'body'})
  values('factory_resource','GetUnitResources',C.factory,{'metal_make','metal_use','energy_make','energy_use'})
  values('product_health','GetUnitHealth',C.product,{'hp','max','paralyze','capture','build'})
  values('product_stun','GetUnitIsStunned',C.product,{'disabled','stunned','being_built'})
  values('product_build','GetUnitIsBeingBuilt',C.product,{'being_built','progress'})
  local q,status=read('GetFullBuildQueue',C.factory);field('queue_status',status)
  local count,foreign=0,false
  if type(q[1])=='table'then
   for _,r in ipairs(q[1])do for def,n in pairs(r)do
    if def~=C.route.product then foreign=true end
    if not finite(n)then count=nil;break end;if count then count=count+n end
   end end
  else count=nil end
  field('queue_count',count);field('queue_foreign',foreign)
  for _,resource in ipairs({'metal','energy'})do
   local v,status=read('GetTeamResources',0,resource);field(resource..'_status',status)
   for i,k in ipairs({'current','storage','pull','income','expense','share','sent','received','excess'})do field(resource..'_'..k,v[i])end
  end
  log('PRODUCTION_OBSERVATION',unpack(a))
 end
 local function findSite()
  local f=D[C.route.factory];local p=D[C.route.product];local t=D[C.route.target]
  local half=math.max(f.xsize,f.zsize)*4+math.max(p.xsize,p.zsize)*4
  local targetHalf=math.max(t.xsize,t.zsize)*4
  local candidate=0
  -- Initial actors stay outside the full diagnostic route. Features need only
  -- clear real factory/launch and target placement zones: flight still uses
  -- native movement and later actual union/airborne/projectile/HP acceptance.
  for _,xf in ipairs({.15,.325,.5,.675,.85})do for _,zf in ipairs({.15,.325,.5,.675,.85})do
   local x,y,z=S.Pos2BuildPos(C.route.factory,Game.mapSizeX*xf,0,Game.mapSizeZ*zf,0);y=S.GetGroundHeight(x,z)
   for direction,axis in ipairs({{0,1},{1,0},{0,-1},{-1,0}})do
    candidate=candidate+1
    local fx,fz=x+axis[1]*(half+512),z+axis[2]*(half+512)
    local tx,tz=fx+axis[1]*600,fz+axis[2]*600
    local bounds=x-half>128 and x+half<Game.mapSizeX-128 and z-half>128 and z+half<Game.mapSizeZ-128
     and tx-targetHalf>128 and tx+targetHalf<Game.mapSizeX-128 and tz-targetHalf>128 and tz+targetHalf<Game.mapSizeZ-128
    local status,feature=-1,nil;local units,factoryFeatures,targetFeatures=-1,-1,-1;local targetY=0;local targetMove=false
    if bounds then
     status,feature=S.TestBuildOrder(C.route.factory,x,y,z,0)
     units=#(S.GetUnitsInRectangle(math.min(x,tx)-half-128,math.min(z,tz)-half-128,math.max(x,tx)+half+128,math.max(z,tz)+half+128)or{})
     factoryFeatures=#(S.GetFeaturesInRectangle(x-half-32,z-half-32,x+half+32,z+half+32)or{})
     targetFeatures=#(S.GetFeaturesInRectangle(tx-targetHalf-32,tz-targetHalf-32,tx+targetHalf+32,tz+targetHalf+32)or{})
     targetY=S.GetGroundHeight(tx,tz)
     if targetY>=0 then targetMove=S.TestMoveOrder(C.route.target,tx,targetY,tz,0,0,0,true,true,false)end
    end
    local accepted=bounds and y>=0 and status==2 and not feature and units==0 and factoryFeatures==0 and targetFeatures==0 and targetY>=0 and targetMove
    local reason='accepted'
    if not bounds then reason='bounds'
    elseif y<0 then reason='factory_ground'
    elseif status~=2 or feature then reason='native_factory'
    elseif units~=0 then reason='initial_or_other_unit_corridor'
    elseif factoryFeatures~=0 then reason='factory_launch_features'
    elseif targetFeatures~=0 then reason='target_features'
    elseif targetY<0 then reason='target_ground'
    elseif not targetMove then reason='native_target_move'end
    log('SITE_CANDIDATE','schema=1','candidate='..candidate,'direction='..direction,'factory_x='..x,'factory_y='..y,'factory_z='..z,
     'flight_x='..fx,'flight_z='..fz,'target_x='..tx,'target_y='..targetY,'target_z='..tz,'half='..half,'target_half='..targetHalf,
     'bounds='..tostring(bounds),'factory_status='..status,'factory_feature='..tostring(feature or'none'),'corridor_units='..units,
     'factory_features='..factoryFeatures,'target_features='..targetFeatures,'target_move='..tostring(targetMove),'accepted='..tostring(accepted),'reason='..reason)
    if accepted then return{x,y,z,0},{fx,S.GetGroundHeight(fx,fz),fz},{tx,targetY,tz}end
   end
  end end
 end
 function C.Step(frame)
  if C.result then return C.result end
  if C.phase=='initial'then
   if frame==0 then return end
   if frame~=1 or Game.gameSpeed~=30 then return fail('fresh_frame1_native_clock30_required')end
   C.started=frame;M.Observe(D,N,W,log);local ok,r=pcall(M.Validate,D,N,W,options);if not ok then return fail('source_contract '..tostring(r))end;C.route=r
   for _,name in ipairs({'GetUnitCollisionVolumeData','GetUnitVectors','GetUnitVelocity','GetUnitPiecePosDir','GetUnitWeaponVectors','GetUnitWeaponState','GetProjectilePosition','GetUnitRulesParam'})do if type(S[name])~='function'then return fail('required_native_api_'..name)end end
   if not finite(priorityCommand)or priorityCommand<=0 or priorityCommand%1~=0 then return fail('actual_stock_priority_command_required')end
   if G.Recoil40KStompaWeaponWitness then return fail('existing_weapon_witness')end
   if not G.Recoil40KResearch or type(G.Recoil40KResearch.CanBuild)~='function'then return fail('sole_production_gate_absent')end
   if S.AreTeamsAllied(0,1)or S.GetGaiaTeamID()==1 then return fail('actual_hostile_team_1_required')end
   -- Use an existing genuine Ork target with the current empty O1 requirement.
   -- A Guard Russ would require its normal tank-factory chain. Never bypass
   -- that unrelated requirement merely to seed a diagnostic target.
   if not G.Recoil40KResearch.CanBuild(1,r.target,nil,false)then return fail('actual_hostile_target_creation_gate')end
   local initialCount=0
   for _,id in ipairs(S.GetAllUnits()or{})do
    C.initial[id]={def=S.GetUnitDefID(id),team=S.GetUnitTeam(id)};initialCount=initialCount+1
    log('INITIAL_ACTOR','actor='..id,'def='..C.initial[id].def,'team='..C.initial[id].team)
   end
   log('INITIAL_COUNT','count='..initialCount)
   local site;site,C.flight,C.targetSite=findSite();if not site then return finish('INCONCLUSIVE isolated_native_site_unavailable')end
   C.factory=S.CreateUnit('fortyk_ork_super_air_factory',site[1],site[2],site[3],0,0)
   if not live(C.factory,r.factory,0)then return fail('owned_exact_factory_birth')end;C.owned[C.factory]=true
   if not G.Recoil40KResearch.CanBuild(0,r.product,C.factory,false)then return fail('actual_factory_product_gate')end
   if queue()~=0 or S.GetUnitIsBuilding(C.factory)then return fail('owned_factory_not_idle')end
   -- Diagnostic only: the factory is explicitly spawned, and queue funding is
   -- explicitly granted. Neither can establish ordinary access/economy.
   productionObservation(frame,'before_grant')
   S.SetTeamResource(0,'ms',100000);S.SetTeamResource(0,'es',100000)
   S.SetTeamResource(0,'m',D[r.product].metalCost);S.SetTeamResource(0,'e',D[r.product].energyCost)
   productionObservation(frame,'after_grant')
   Script.SetWatchProjectile(r.weapon,true);C.watching=true;G.Recoil40KStompaWeaponWitness=C
   C.phase='production';C.stage=frame;S.GiveOrderToUnit(C.factory,-r.product,{},0)
   log('FUNDED_NATIVE_QUEUE','factory='..C.factory,'product='..r.product,'factory_spawned=true','metal_grant='..D[r.product].metalCost,'energy_grant='..D[r.product].energyCost)
   return
  end
  if C.phase=='production'and not C.released and(frame==C.started+1 or frame%300==0 or frame-C.started>9000)then productionObservation(frame,frame-C.started>9000 and'timeout'or'periodic')end
  if frame-C.started>9000 then return finish('INCONCLUSIVE bounded_native_timeout_'..C.phase)end
  if not live(C.factory,C.route.factory,0)then return fail('owned_factory_lost_or_transferred')end
  if queue()==nil then return fail('foreign_factory_queue')end
  if C.product and not live(C.product,C.route.product,0,false)then return fail('owned_product_lost_or_transferred')end
  if C.phase=='production'then
   -- Stock UI may classify a new factory as LOW after its creation callback.
   -- Wait for that actual native rule, then use its supported NORMAL1 command
   -- on this spawned diagnostic factory only. Grants and normal policy stay exact.
   local before=S.GetUnitRulesParam(C.factory,'builderPriority')
   if not C.priorityObserved then
    if before==nil then
     if frame-C.started>=30 then return finish('INCONCLUSIVE owned_factory_native_priority_unavailable')end
    elseif before~=0 and before~=1 then return fail('unexpected_owned_factory_native_priority')
    else
     S.GiveOrderToUnit(C.factory,priorityCommand,{1},0)
     local after=S.GetUnitRulesParam(C.factory,'builderPriority')
     if after~=1 then return fail('owned_factory_normal_priority_not_applied')end
     C.priorityObserved=true
     log('FUNDED_FACTORY_PRIORITY','schema=1','frame='..frame,'factory='..C.factory,'command='..priorityCommand,'before='..before,'after='..after,'owned_spawned_factory_only=true','native_rules_readback=true','grants_unchanged=true')
    end
   elseif before~=1 then return fail('owned_factory_normal_priority_changed')end
  end
  if C.phase=='production'and C.finished and C.released then
   if not live(C.product,C.route.product,0)or queue()~=0 or S.GetUnitIsBuilding(C.factory)then return fail('release_not_complete_idle_native')end
   C.origin={S.GetUnitPosition(C.product)};C.stage=frame;C.phase='flight'
   S.GiveOrderToUnit(C.product,CMD.MOVE,C.flight,0);log('FLIGHT_ORDER','body='..C.product,'native_release='..C.released,'native_finish='..C.finished,'origin_x='..C.origin[1],'origin_y='..C.origin[2],'origin_z='..C.origin[3])
  elseif C.phase=='flight'and frame%15==0 and frame-C.released>=90 then
   local outside,why=geometry.Outside(S,D,C.factory,C.product);if outside==nil then return fail('native_union_geometry_'..tostring(why))end
   local x,y,z=S.GetUnitPosition(C.product);local vx,vy,vz=S.GetUnitVelocity(C.product);local ground=S.GetGroundHeight(x,z)
   for _,v in ipairs({x,y,z,vx,vy,vz,ground})do if not finite(v)then return fail('nonfinite_native_flight')end end
   local travel=(x-C.origin[1])^2+(z-C.origin[3])^2;local good=outside and travel>=256^2 and y-ground>=40 and vx*vx+vy*vy+vz*vz>.01
   if C.lastFlightFrame and frame-C.lastFlightFrame~=15 then C.flightSamples=0 end;C.lastFlightFrame=frame
   C.flightSamples=good and C.flightSamples+1 or 0
   log('NATIVE_FLIGHT','frame='..frame,'union_clear='..tostring(outside),'travel='..math.sqrt(travel),'altitude='..(y-ground),'consecutive='..C.flightSamples,
    'x='..x,'y='..y,'z='..z,'ground='..ground,'vx='..vx,'vy='..vy,'vz='..vz,
    'parent_min_x='..why.parent.minX,'parent_max_x='..why.parent.maxX,'parent_min_z='..why.parent.minZ,'parent_max_z='..why.parent.maxZ,
    'child_min_x='..why.child.minX,'child_max_x='..why.child.maxX,'child_min_z='..why.child.minZ,'child_max_z='..why.child.maxZ)
   if C.flightSamples>=3 then
    local p=S.GetUnitPieceMap(C.product)or{};C.muzzle=p.nose_muzzle
    if not C.muzzle or not p.nose_axis or not p.nose_yaw or not p.nose_pitch then return fail('actual_nose_piece_map')end
    local s=C.targetSite;C.target=S.CreateUnit('ork_deff_dread',s[1],s[2],s[3],0,1)
    if not live(C.target,C.route.target,1)then return fail('owned_hostile_target_birth')end;C.owned[C.target]=true
    S.GiveOrderToUnit(C.target,CMD.FIRE_STATE,{0},0);S.GiveOrderToUnit(C.target,CMD.MOVE_STATE,{0},0)
    C.phase='visibility';C.stage=frame;log('FUNDED_HOSTILE_TARGET','actor='..C.target,'original_stats=true','direct_damage=false','def='..C.route.target)
   end
  elseif C.phase=='visibility'then
   if not live(C.target,C.route.target,1)then return fail('hostile_target_lost')end
   local los=S.GetUnitLosState(C.target,S.GetUnitAllyTeam(C.product),false)or{}
   if los.los==true then
    C.lastHP=S.GetUnitHealth(C.target);C.phase='combat';C.stage=frame
    S.GiveOrderToUnit(C.product,CMD.ATTACK,{C.target},0);log('NATIVE_ATTACK','body='..C.product,'target='..C.target,'initial_hp='..C.lastHP)
   elseif frame-C.stage>=300 then return finish('INCONCLUSIVE actual_target_not_naturally_visible')end
  elseif C.phase=='combat'then
   if C.hits>=2 then return finish('PASS diagnostic_exact_AIR3_native_queue_release_union_clear_flight_two_muzzle_projectile_HP_hits')end
   if not live(C.target,C.route.target,1)then return finish('INCONCLUSIVE target_lost_before_two_hits')end
   if frame-C.stage>=1800 then return finish('INCONCLUSIVE actual_Kannon_repeat_timeout')end
  end
 end
 function C.Created(id,def,team,builder)
  if C.result or C.phase~='production'or def~=C.route.product then return end
  if C.product or team~=0 or builder~=C.factory then return fail('foreign_or_duplicate_product_birth')end
  if C.initial[id]then return fail('native_product_reuses_initial_actor')end
  C.product=id;C.owned[id]=true;log('NATIVE_BIRTH','body='..id,'factory='..builder)
 end
 function C.Finished(id,def,team)
  if C.result or id~=C.product then return end
  if C.finished or def~=C.route.product or team~=0 then return fail('duplicate_or_foreign_finish')end
  C.finished=S.GetGameFrame();log('NATIVE_FINISHED','body='..id,'frame='..C.finished)
 end
 function C.Released(id,def,team,parent,parentDef,userOrders)
  if C.result or id~=C.product then return end
  if C.released or def~=C.route.product or team~=0 or parent~=C.factory or parentDef~=C.route.factory or userOrders then return fail('duplicate_or_foreign_native_release')end
  C.released=S.GetGameFrame();log('NATIVE_RELEASE','body='..id,'factory='..parent,'frame='..C.released)
 end
 function C.Query(id,n,piece)
  if C.result or C.phase~='combat'or id~=C.product or n~=1 then return end
  if piece~=C.muzzle then return fail('wrong_actual_nose_Query_piece')end
  local x,y,z=S.GetUnitPiecePosDir(id,piece);if not finite(x)or not finite(y)or not finite(z)then return fail('missing_actual_nose_position')end
  C.query={x=x,y=y,z=z,frame=S.GetGameFrame()};log('NATIVE_QUERY','frame='..C.query.frame,'piece='..piece,'body='..id,'x='..x,'y='..y,'z='..z)
 end
 function C.Shot(id,n,frame)
  if C.result or C.phase~='combat'or id~=C.product or n~=1 then return end
  if S.GetUnitWeaponState(id,1)~=true then return fail('native_angle_not_ready')end
  C.shots=C.shots+1;C.lastShot=frame;log('NATIVE_SHOT','frame='..frame,'count='..C.shots,'body='..id,'angle_ready=true')
 end
 function C.Projectile(pid,owner,weapon)
  if C.result or C.phase~='combat'or owner~=C.product or weapon~=C.route.weapon then return end
  local q=C.query;local x,y,z=S.GetProjectilePosition(pid);local mx,my,mz=S.GetUnitWeaponVectors(C.product,1)
  local speed=S.GetUnitWeaponState(C.product,1,'projectileSpeed')
  if not q or not finite(x)or not finite(y)or not finite(z)or not finite(mx)or not finite(my)or not finite(mz)
   or not C.lastShot or q.frame<C.lastShot or S.GetGameFrame()-C.lastShot>2 or not finite(speed)or speed<=0 then return fail('native_shot_query_projectile_chain_absent')end
  if (x-q.x)^2+(y-q.y)^2+(z-q.z)^2>math.max(16,speed+4)^2 or(mx-q.x)^2+(my-q.y)^2+(mz-q.z)^2>4^2 then return fail('projectile_not_actual_Query_muzzle')end
  if C.projectiles[pid]then return fail('duplicate_native_projectile')end
  C.projectiles[pid]={frame=S.GetGameFrame()};log('NATIVE_PROJECTILE','pid='..pid,'weapon='..weapon,'owner='..owner,'x='..x,'y='..y,'z='..z,'muzzle_x='..mx,'muzzle_y='..my,'muzzle_z='..mz,'speed='..speed,'query_frame='..q.frame,'shot_frame='..C.lastShot)
 end
 function C.Damaged(id,damage,para,weapon,pid,attacker)
  if C.result or C.phase~='combat'or id~=C.target or attacker~=C.product or weapon~=C.route.weapon or para or not finite(damage)or damage<=0 then return end
  local p=C.projectiles[pid];if not p or p.hit then return fail('target_damage_missing_unique_owned_projectile')end
  local hp=S.GetUnitHealth(id);if not finite(hp)or hp>=C.lastHP then return fail('target_damage_without_native_HP_loss')end
  p.hit=true;C.hits=C.hits+1;local before=C.lastHP;C.lastHP=hp;log('NATIVE_HP_HIT','pid='..pid,'damage='..damage,'health='..hp,'count='..C.hits,'health_before='..before,'target='..id,'attacker='..attacker,'weapon='..weapon)
 end
 function C.Close()
  if C.closed then return end;C.closed=true
  if G.Recoil40KStompaWeaponWitness==C then G.Recoil40KStompaWeaponWitness=nil end
  if C.watching then Script.SetWatchProjectile(C.route.weapon,false);C.watching=false end
  for id in pairs(C.owned)do
   local team=id==C.target and 1 or 0
   local def=id==C.target and C.route.target or(id==C.factory and C.route.factory or C.route.product)
   if S.ValidUnitID(id)and not S.GetUnitIsDead(id)then
    if S.GetUnitTeam(id)==team and S.GetUnitDefID(id)==def and not C.initial[id]then S.DestroyUnit(id,false,true)
    else log('CLEANUP_SKIPPED_CHANGED_OWNERSHIP','actor='..id)end
   end
  end
 end
 return C
end
return M
