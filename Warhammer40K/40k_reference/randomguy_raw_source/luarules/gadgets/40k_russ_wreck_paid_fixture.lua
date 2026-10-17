function gadget:GetInfo()
 return{name='40K paid Russ native wreck fixture',desc='Ordinary Guard economy and T1 constructor T2 armour ladder',author='Local project',layer=159,enabled=true}
end
local options=Spring.GetModOptions()or{}
local function enabled(v)return v==true or v==1 or v=='1'end
if not enabled(options.prototype_russ_wreck_paid_fixture)then return false end
if not gadgetHandler:IsSyncedCode()then
 local closeAt,original,pending;local captured={};local attempts=0
 local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
 local function note(status,row,...)
  local fields={status,tostring(row.label),tostring(row.kind),tostring(row.id),tostring(row.source),tostring(Spring.GetGameFrame())}
  for i=1,select('#',...)do fields[#fields+1]=tostring(select(i,...))end
  fields[#fields+1]='fps_acceptance=false';Spring.Echo('40K_RUSS_WRECK_PAID PNG '..table.concat(fields,' '))
 end
 local function view(_,label,kind,id,source,x,y,z)
  if captured[label]or(label~='paid_russ'and label~='native_wreck')or attempts>=2 then return end
  if(kind~='unit'and kind~='feature')or not finite(id)or not finite(x)or not finite(y)or not finite(z)then return end
  local row={label=label,kind=kind,id=id,source=source,x=x,y=y,z=z,frame=Spring.GetGameFrame()}
  captured[label]=true;attempts=attempts+1
  if Spring.IsPosInLos(x,y,z)~=true then note('SKIP_NO_LOS',row);return end
  local minimum=Spring.GetConfigFloat('OverheadMinZoomDistance',60)
  if not finite(minimum)then note('SKIP_INVALID_NATIVE_CAMERA_MINIMUM',row);return end
  row.cameraHeight=math.max(180,minimum)
  if not original then original=Spring.GetCameraState()end
  Spring.SetCameraState({name='ta',mode=1,px=x,py=y,pz=z,height=row.cameraHeight,angle=.9,flipped=-1},0)
  note('CAMERA_PLAN',row,'requested_base_height=180','native_minimum='..minimum,'expected_height='..row.cameraHeight)
  pending=row;note('VIEW',row,x,y,z)
 end
 local function done(_,reason)Spring.Echo('40K_RUSS_WRECK_PAID owned_autoclose '..tostring(reason));closeAt=Spring.GetGameFrame()+90 end
 function gadget:Initialize()
  gadgetHandler:AddSyncAction('fortyk_russ_wreck_paid_done',done)
  gadgetHandler:AddSyncAction('fortyk_russ_wreck_paid_view',view)
 end
 function gadget:GameFrame(frame)
  if pending and frame-pending.frame>120 then note('SKIP_NO_RENDER_OR_LIMITED',pending);pending=nil end
  if closeAt and frame>=closeAt then closeAt=nil;Spring.SendCommands('quitforce')end
 end
 function gadget:DrawScreen()
  local row=pending;if not row or Spring.GetGameFrame()-row.frame<12 then return end
  pending=nil
  local x,y,z
  if row.kind=='unit'then x,y,z=Spring.GetUnitViewPosition(row.id,true)
  else local bx,by,bz,mx,my,mz=Spring.GetFeaturePosition(row.id,true);x,y,z=mx,my,mz end
  local c=Spring.GetCameraState()
  if not finite(x)or not finite(y)or not finite(z)or Spring.IsPosInLos(x,y,z)~=true then note('SKIP_LOST_OR_NO_LOS',row);return end
  if c.name~='ta'or not finite(c.height)or math.abs(c.height-row.cameraHeight)>.5 or not finite(c.px)or not finite(c.pz)or math.abs(c.px-row.x)>8 or math.abs(c.pz-row.z)>8 then note('SKIP_CAMERA_CHANGED',row,'expected_height='..row.cameraHeight,'actual_height='..tostring(c.height),'actual_name='..tostring(c.name));return end
  -- Conservative native selectable-object trace. A miss/custom-volume limitation
  -- skips capture; this is not a promise of pixel-perfect visual occlusion.
  local sx,sy=Spring.WorldToScreenCoords(x,y,z);local width,height=Spring.GetViewGeometry()
  if not finite(sx)or not finite(sy)or sx<0 or sy<0 or sx>=width or sy>=height then note('SKIP_OFFSCREEN',row);return end
  -- WorldToScreenCoords and TraceScreenRay share bottom-origin screen Y.
  local kind,id=Spring.TraceScreenRay(sx,sy,false,false,false,false)
  note('TRACE_READBACK',row,'screen_x='..sx,'screen_y='..sy,'viewport_width='..width,'viewport_height='..height,'trace_kind='..tostring(kind),'trace_id='..tostring(id))
  if kind~=row.kind or id~=row.id then note('SKIP_OCCLUDED_OR_TRACE_LIMITED',row,kind,id);return end
  Spring.SendCommands('screenshot png');note('CAPTURE_REQUEST',row,c.name,c.px,c.py,c.pz,c.height,c.angle,'native_los=true','trace_target=true')
 end
 function gadget:Shutdown()
  gadgetHandler:RemoveSyncAction('fortyk_russ_wreck_paid_done');gadgetHandler:RemoveSyncAction('fortyk_russ_wreck_paid_view')
  if original then Spring.SetCameraState(original,0)end
 end
 return
end
local S=Spring;local phase='initial';local start,stepStart;local team=0;local commander;local index=1
local ids={};local released={};local mexSites={};local economy={mex={},generator={}};local active,site,stance,def,builder;local incomeEntered,stableSince
local killedAt,deathPosition,featureID,featureCount,partial,removedAt;local wreckDef
local departureOrigin,viewStarted
local tasks={{'imp_mex','commander',60,300,600},{'imp_generator','commander',150,0,1400},
 {'imp_mex','commander',60,300,600},{'imp_generator','commander',150,0,1400},
 {'imp_tank_factory','commander',590,1550,5700},{'armcv','imp_tank_factory',135,1950,4050},
 {'armavp','armcv',2600,14000,27000},{'imp_russ','armavp',480,2400,4000}}
local function emit(event,...)local a={...};for i=1,#a do a[i]=tostring(a[i])end;S.Echo('40K_RUSS_WRECK_PAID '..event..' '..table.concat(a,' '))end
local function resources(event)
 local m,_,_,mi,me=S.GetTeamResources(team,'metal');local e,_,_,ei,ee=S.GetTeamResources(team,'energy')
 emit(event,'metal='..tostring(m),'energy='..tostring(e),'metal_income='..tostring(mi),'energy_income='..tostring(ei),'metal_expense='..tostring(me),'energy_expense='..tostring(ee),'income_net_delta_not_exact_credit=true');return m,e,mi,ei
end
local function finish(reason)if phase=='done'then return end;phase='done';resources('FINAL');emit('COMPLETE',reason,'scripted_damage_not_combat=true');SendToUnsynced('fortyk_russ_wreck_paid_done',reason)end
local function live(id)if not id or S.GetUnitIsDead(id)then return false end;local hp,_,_,_,p=S.GetUnitHealth(id);return hp and hp>0 and p and p>=1 end
local function has(d,id)for _,v in ipairs(d.buildOptions or{})do if v==id then return true end end;return false end
local function bill(d,m,e,w)return d and math.abs(d.metalCost-m)<.001 and math.abs(d.energyCost-e)<.001 and math.abs(d.buildTime-w)<.001 end
local function admitted(parent,target)return has(UnitDefs[S.GetUnitDefID(parent)],target)and GG.Recoil40KResearch and GG.Recoil40KResearch.CanBuild(team,target,parent,false)end
local function clear(id,x,z,parent)
 local d=UnitDefs[id];local hx,hz=d.xsize*4,d.zsize*4
 if x-hx<64 or z-hz<64 or x+hx>Game.mapSizeX-64 or z+hz>Game.mapSizeZ-64 then return false end
 for _,u in ipairs(S.GetUnitsInRectangle(x-hx-24,z-hz-24,x+hx+24,z+hz+24)or{})do
  if u~=parent then return false end
  local bx,_,bz=S.GetUnitPosition(u);local bd=UnitDefs[S.GetUnitDefID(u)]
  if math.abs(bx-x)<hx+bd.xsize*4+8 and math.abs(bz-z)<hz+bd.zsize*4+8 then return false end
 end
 return #(S.GetFeaturesInRectangle(x-hx-16,z-hz-16,x+hx+16,z+hz+16)or{})==0
end
local function atSite(parent,id,x,z)
 local x,y,z=S.Pos2BuildPos(id,x,S.GetGroundHeight(x,z),z,0);local status,f=S.TestBuildOrder(id,x,y,z,0)
 if y<0 or status~=2 or f or not clear(id,x,z,parent)then return end
 local pd=UnitDefs[S.GetUnitDefID(parent)];local fd=UnitDefs[id]
 for k=0,23 do
  local a=k*math.pi/12;local sx,sz=x+(pd.buildDistance-24)*math.cos(a),z+(pd.buildDistance-24)*math.sin(a);local sy=S.GetGroundHeight(sx,sz)
  local outside=math.abs(sx-x)>=fd.xsize*4+pd.xsize*4+8 or math.abs(sz-z)>=fd.zsize*4+pd.zsize*4+8
  if outside and sy>=0 and sx>32 and sz>32 and sx<Game.mapSizeX-32 and sz<Game.mapSizeZ-32 and S.TestMoveOrder(pd.id,sx,sy,sz,0,0,0,true,true,false)then return{x,y,z,0},{sx,sy,sz}end
 end
end
local function choose(parent,id,mex)
 local cx,_,cz=S.GetUnitPosition(commander)
 if mex then
  local api=GG.resource_spot_finder
  if not api or api.isMetalMap or type(api.metalSpotsList)~='table'or type(api.GetBuildingPositions)~='function'or type(api.IsMexPositionValid)~='function'then return end
  local candidates={}
  for _,spot in ipairs(api.metalSpotsList)do for _,pos in ipairs(api.GetBuildingPositions(spot,id,0,true)or{})do
   local distance=(pos.x-cx)^2+(pos.z-cz)^2
   if distance<=1200^2 then candidates[#candidates+1]={x=pos.x,z=pos.z,spot=spot,distance=distance}end
  end end
  table.sort(candidates,function(a,b)if a.distance~=b.distance then return a.distance<b.distance end;if a.x~=b.x then return a.x<b.x end;return a.z<b.z end)
  for _,c in ipairs(candidates)do
   local separate=true;for _,p in ipairs(mexSites)do if(c.x-p[1])^2+(c.z-p[3])^2<(2*(Game.extractorRadius or 96))^2 then separate=false end end
   if separate then local p,a=atSite(parent,id,c.x,c.z);if p and api.IsMexPositionValid(c.spot,p[1],p[3])then mexSites[#mexSites+1]=p;return p,a end end
  end
 else
  for ring=6,24 do for j=0,23 do local a=j*math.pi/12;local p,s=atSite(parent,id,cx+ring*32*math.cos(a),cz+ring*32*math.sin(a));if p then return p,s end end end
 end
end
-- Native endpoint legality is not path proof: MOVE arrival remains mandatory.
local function moveSite(id,x,z,excluded)
 local d=UnitDefs[S.GetUnitDefID(id)];local y=S.GetGroundHeight(x,z)
 local hx,hz=d.xsize*4,d.zsize*4
 if y<0 or x-hx<64 or z-hz<64 or x+hx>Game.mapSizeX-64 or z+hz>Game.mapSizeZ-64 then return end
 if excluded then
  local fx,_,fz=S.GetUnitPosition(excluded);local fd=UnitDefs[S.GetUnitDefID(excluded)]
  if not fx or not fd or(math.abs(x-fx)<hx+fd.xsize*4+24 and math.abs(z-fz)<hz+fd.zsize*4+24)then return end
 end
 if S.TestMoveOrder(d.id,x,y,z,0,0,0,true,true,false)==true then return{x,y,z}end
end
local function departureSite(id)
 local x,_,z=S.GetUnitPosition(id);local candidates=0
 for _,radius in ipairs({192,256,320,384,512})do for k=0,23 do
  local a=k*math.pi/12;candidates=candidates+1
  local p=moveSite(id,x+radius*math.cos(a),z+radius*math.sin(a),ids.armavp)
  if p then emit('DEPARTURE_SITE',id,p[1],p[2],p[3],'candidates='..candidates,'full_terrain_objects=true','path_unproven_until_arrival=true');return p end
 end end
 emit('DEPARTURE_SITE_REFUSED',id,'candidates='..candidates);return nil
end
local function reclaimSite(id,x,y,z)
 local d=UnitDefs[S.GetUnitDefID(id)]
 for _,radius in ipairs({d.buildDistance-24,d.buildDistance-48})do if radius>0 then for k=0,23 do
  local a=k*math.pi/12;local p=moveSite(id,x+radius*math.cos(a),z+radius*math.sin(a))
  if p and(p[1]-x)^2+(p[2]-y)^2+(p[3]-z)^2<=d.buildDistance^2 then return p end
 end end end
end
local function arrived()
 if not live(builder)then finish('FAIL builder_lost');return false end
 local x,y,z=S.GetUnitPosition(builder);if(x-stance[1])^2+(z-stance[3])^2>24^2 then return false end
 local status,f=S.TestBuildOrder(def,site[1],site[2],site[3],0);local range=UnitDefs[S.GetUnitDefID(builder)].buildDistance
 if status~=2 or f or not clear(def,site[1],site[3],builder)or(x-site[1])^2+(y-site[2])^2+(z-site[3])^2>range^2 then finish('INCONCLUSIVE changed_native_placement_or_range');return false end
 return true
end
function gadget:UnitCreated(id,d,t,parent)
 if t==team and phase=='building'and d==def then
  if active or parent~=builder then finish('FAIL paid_birth_owner');return end
  active=id;emit('PAID_BIRTH',tasks[index][1],id,parent)
 end
end
function gadget:UnitFromFactory(id,d,t,parent)
 if t==team and id==active and parent==builder then released[id]=S.GetGameFrame();emit('NATIVE_RELEASE',tasks[index][1],id,parent,released[id])end
end
function gadget:FeatureCreated(id)
 if not killedAt or S.GetFeatureDefID(id)~=wreckDef then return end
 featureCount=featureCount+1;featureID=id;local x,y,z=S.GetFeaturePosition(id)
 emit('NATIVE_FEATURE',id,S.GetFeatureTeam(id),x,y,z)
 if featureCount~=1 or S.GetFeatureTeam(id)~=team or not x or(x-deathPosition[1])^2+(z-deathPosition[3])^2>64^2 then finish('FAIL duplicate_or_wrong_native_wreck')end
end
function gadget:GameFrame(frame)
 if phase=='done'then return end;if not start then start=frame;stepStart=frame end
 if frame-start>1200*(Game.gameSpeed or 30)then finish('INCONCLUSIVE overall_ordinary_paid_timeout_'..phase);return end
 if phase=='initial'then
  for k,v in pairs(options)do if k:match('^prototype_.*fixture$')and k~='prototype_russ_wreck_paid_fixture'and enabled(v)then finish('FAIL conflicting_fixture');return end end
  if enabled(options.prototype_source_paid_match)or(options.prototype_source_acceptance and options.prototype_source_acceptance~='')or(options.prototype_diagnostic and options.prototype_diagnostic~='normal')then finish('FAIL funded_or_nonordinary_review');return end
  if not enabled(options.prototype_russ_wreck_pilot)or enabled(options.prototype_scale085_pilot)then finish('FAIL baseline_native_wreck_pilot_required');return end
  local m,e=resources('INITIAL');local units=S.GetTeamUnits(team)or{}
  if not m or not e or math.abs(m-1000)>5 or math.abs(e-1000)>5 or #units~=1 or not UnitDefNames.armcom or S.GetUnitDefID(units[1])~=UnitDefNames.armcom.id or not live(units[1])then finish('FAIL natural_Guard_1000_start');return end;commander=units[1]
  for _,row in ipairs(tasks)do local n=UnitDefNames[row[1]];if not n or not bill(UnitDefs[n.id],row[3],row[4],row[5])then finish('FAIL actual_bill_'..row[1]);return end end
  local russ=UnitDefs[UnitDefNames.imp_russ.id];local cp=russ.customParams or{};local fn=FeatureDefNames.imp_russ_native_wreck;local f=fn and FeatureDefs[fn.id]
  if not enabled(cp.prototype40k_russ_native_wreck)or not fn or not f or not f.reclaimable or f.resurrectable~=0 or f.metal~=120 or f.energy~=0 or f.reclaimTime~=1000 or not enabled((f.customParams or{}).prototype40k_russ_native_wreck)or(f.customParams or{}).parent_actor~='leman_russ' or russ.wreckName~='imp_russ_native_wreck'then finish('FAIL native_wreck_definition');return end;wreckDef=fn.id
  emit('BILLS','route=T1_factory590M1550E5700work armcv135M1950E4050work T2_factory2600M14000E27000work Russ480M2400E4000work','economy=2mex120M600E1200work 2generator300M0E2800work total4225M20500E44750work','wreck=120M0E1000work');phase='next'
 elseif phase=='next'then
  if index>#tasks then
   local russ=ids.imp_russ;local x,y,z=S.GetUnitPosition(russ);departureOrigin={x,y,z}
   stance=departureSite(russ);if not stance then finish('INCONCLUSIVE Russ_departure_site');return end
   stepStart=frame;phase='depart';S.GiveOrderToUnit(russ,CMD.MOVE,stance,0);return
  end
  local row=tasks[index];def=UnitDefNames[row[1]].id;builder=row[2]=='commander'and commander or ids[row[2]]
  if not live(builder)or not admitted(builder,def)then finish('FAIL actual_active_menu_or_gate_'..row[1]);return end
  active=nil;stepStart=frame
  if UnitDefs[S.GetUnitDefID(builder)].isFactory then phase='building';resources('PAID_ORDER_'..row[1]);S.GiveOrderToUnit(builder,-def,{},0)
  else site,stance=choose(builder,def,row[1]=='imp_mex');if not site then finish('INCONCLUSIVE native_economy_or_build_site_'..row[1]);return end;phase='approach';S.GiveOrderToUnit(builder,CMD.MOVE,stance,0)end
 elseif phase=='approach'then
  if frame-stepStart>120*30 then finish('INCONCLUSIVE approach_timeout');return end
  if arrived()then phase='building';resources('PAID_ORDER_'..tasks[index][1]);S.GiveOrderToUnit(builder,-def,site,0)end
 elseif phase=='building'then
  if frame-stepStart>450*30 then finish('INCONCLUSIVE ordinary_stage_timeout_'..tasks[index][1]);return end
  if active and live(active)and(not UnitDefs[S.GetUnitDefID(builder)].isFactory or released[active])then
   local name=tasks[index][1];ids[name]=active;if name=='imp_mex'then economy.mex[#economy.mex+1]=active elseif name=='imp_generator'then economy.generator[#economy.generator+1]=active end;emit('PAID_COMPLETE',name,active)
   if index==4 then phase='income';incomeEntered=frame;stableSince=nil else index=index+1;phase='next'end
  end
 elseif phase=='income'then
  local mi=select(4,S.GetTeamResources(team,'metal'));local ei=select(4,S.GetTeamResources(team,'energy'))
  if #economy.mex~=2 or #economy.generator~=2 then finish('FAIL genuine_paid_economy_count');return end
  local ready=mi and mi>=5 and ei and ei>=80
  for _,id in ipairs(economy.mex)do
   if not live(id)then finish('FAIL genuine_paid_mex_lost');return end
   local mm=S.GetUnitResources(id);if not mm or mm<=0 then ready=false end
   if frame%30==0 then emit('REAL_MEX_OUTPUT',id,mm)end
  end
  for _,id in ipairs(economy.generator)do
   if not live(id)then finish('FAIL genuine_paid_generator_lost');return end
   local _,_,em=S.GetUnitResources(id);if not em or em<=0 then ready=false end
   if frame%30==0 then emit('REAL_GENERATOR_OUTPUT',id,em)end
  end
  if frame%30==0 then resources('ACTUAL_ECONOMY')end
  -- Native team resPrevIncome and per-unit rolling resourcesMake lag birth.
  -- Any dip resets the continuous window; no economic mutation or skip.
  if ready then stableSince=stableSince or frame else stableSince=nil end
  if stableSince and frame-stableSince>=90 then emit('REAL_PAID_OUTPUT_STABLE',mi,ei,'frames='..(frame-stableSince),'all_four=true');index=index+1;phase='next'
  elseif frame-incomeEntered>=60*(Game.gameSpeed or 30)then finish('INCONCLUSIVE insufficient_actual_paid_income_after_settle')end
 elseif phase=='depart'then
  local id=ids.imp_russ;if not live(id)then finish('FAIL Russ_lost_before_scripted_damage');return end
  local x,y,z=S.GetUnitPosition(id)
  if frame-stepStart>120*(Game.gameSpeed or 30)then finish('INCONCLUSIVE Russ_departure_path_timeout');return end
  if(x-stance[1])^2+(z-stance[3])^2>24^2 then return end
  if(x-departureOrigin[1])^2+(z-departureOrigin[3])^2<128^2 then finish('FAIL Russ_departure_distance');return end
  emit('NATIVE_DEPARTURE_ARRIVED',id,x,y,z,frame)
  SendToUnsynced('fortyk_russ_wreck_paid_view','paid_russ','unit',id,'leman_russ',x,y,z)
  viewStarted=frame;phase='paid_view'
 elseif phase=='paid_view'then
  local id=ids.imp_russ;if not live(id)then finish('FAIL Russ_lost_before_scripted_damage');return end
  if frame-viewStarted<18 then return end
  local x,y,z=S.GetUnitPosition(id);local hp=S.GetUnitHealth(id);deathPosition={x,y,z};killedAt=frame;featureCount=0;phase='death'
  emit('SCRIPTED_NATIVE_DAMAGE_NOT_COMBAT',id,hp+1,frame);S.AddUnitDamage(id,hp+1,0,-1,-1)
 elseif phase=='death'then
  if frame-killedAt>300 then finish('FAIL native_wreck_missing_or_unsettled');return end
  if featureID and frame-killedAt>=30 then
   local m,mm,e,ee,left=S.GetFeatureResources(featureID);local x,y,z=S.GetFeaturePosition(featureID);local ground=S.GetGroundHeight(x,z)
   if m~=120 or mm~=120 or e~=0 or ee~=0 or left~=1 or y~=y or math.abs(y-ground)>8 then finish('FAIL native_entitlement_or_contact');return end
   emit('NATIVE_CONTACT',featureID,x,y,z,ground,m,left)
   SendToUnsynced('fortyk_russ_wreck_paid_view','native_wreck','feature',featureID,'leman_russ_die_1',x,y,z)
   viewStarted=frame;phase='wreck_view'
  end
 elseif phase=='wreck_view'then
  if frame-viewStarted<18 then return end
  local x,y,z=S.GetFeaturePosition(featureID)
  if not x then finish('FAIL feature_lost_before_reclaim');return end
  stance=reclaimSite(commander,x,y,z)
  if not stance then finish('INCONCLUSIVE reclaim_approach');return end
  stepStart=frame;phase='reclaim_approach';S.GiveOrderToUnit(commander,CMD.MOVE,stance,0)
 elseif phase=='reclaim_approach'then
  if frame-stepStart>120*(Game.gameSpeed or 30)then finish('INCONCLUSIVE reclaim_path_timeout');return end
  local x,y,z=S.GetUnitPosition(commander);local fx,fy,fz=S.GetFeaturePosition(featureID)
  if not fx then finish('FAIL feature_lost_before_reclaim');return end
  if(x-stance[1])^2+(z-stance[3])^2<=24^2 and(x-fx)^2+(y-fy)^2+(z-fz)^2<=UnitDefs[S.GetUnitDefID(commander)].buildDistance^2 then
   phase='reclaim';resources('RECLAIM_ORDER');emit('NORMAL_NATIVE_RECLAIM',commander,featureID+Game.maxUnits);S.GiveOrderToUnit(commander,CMD.RECLAIM,{featureID+Game.maxUnits},0)
  end
 elseif phase=='reclaim'then
  local m,mm,e,ee,left=S.GetFeatureResources(featureID)
  if m and left and left>0 and left<1 and m>=0 and m<=120 then if not partial then emit('NATIVE_PARTIAL_RECLAIM',featureID,m,left)end;partial=true end
  if not S.GetFeatureDefID(featureID)then if not partial then finish('FAIL no_native_partial_reclaim_observed');return end;removedAt=frame;phase='duplicate_watch';emit('NATIVE_RECLAIM_REMOVED',featureID)end
 elseif phase=='duplicate_watch'then
  if featureCount~=1 then finish('FAIL duplicate_native_feature');return end
  if frame-removedAt>=20 then finish('PASS ordinary_paid_ladder_one_native_wreck_partial_and_full_reclaim')end
 end
end
