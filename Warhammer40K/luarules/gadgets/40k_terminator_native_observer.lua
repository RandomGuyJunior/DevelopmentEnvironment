-- Default-off read-only Terminator paired geometry/gait/remains observer.
function gadget:GetInfo()return{name='40K Terminator native observer',desc='No orders/births/damage/payment; explicit measurement only',author='Local project',layer=153,enabled=true}end
if not gadgetHandler:IsSyncedCode()then return false end
local S=Spring;local options=S.GetModOptions()or{}
local function yes(v)return v==true or v==1 or v=='1'end
if not yes(options.prototype_terminator_native_observer)then return false end
local required={'prototype_marine_terminator_squad','prototype_terminator_scale085_pair_pilot','prototype_scale085_pilot','prototype_scale_native_probe','prototype_source_progression'}
for _,key in ipairs(required)do assert(yes(options[key]),'Terminator observer missing '..key)end
local pair=VFS.Include('40k_configs/terminator_scale_pair.lua');pair.ValidateClosure(options,VFS)
local selected={'bip01','bip01 l foot','bip01 r foot','marker_terminator_storm_bolter_barrel','marker_terminator_storm_bolter_barrel_l'}
local start,startedCohort,seed,team,paidAcquired;local reclaimSteps={};local bodies={};local samples={};local featureSeen={};local birth={};local destroyed={};local release={};local stopped=false
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function near(a,b)return finite(a)and math.abs(a-b)<.001 end
local function log(event,...)local a={...};for i,v in ipairs(a)do a[i]=tostring(v)end;S.Echo('40K_TERM_NATIVE '..event..' '..table.concat(a,' '))end
local function close(reason)if stopped then return end;stopped=true;log('END',reason,'native_acceptance=false paid_economy_acceptance=false renderer_contact_animation_unaccepted=true')end
function gadget:Initialize()
 for _,name in ipairs({'GetUnitPieceMap','GetUnitDefID','GetUnitTeam','GetUnitIsDead','GetGameFrame','GetFeatureDefID','GetUnitPieceMatrix','GetUnitPiecePosDir','GetUnitCollisionVolumeData','GetUnitVectors','GetUnitCosts','GetUnitPosition','GetUnitVelocity','GetUnitHealth','GetGroundHeight','GetFeatureResources','GetFeatureRulesParam','GetAllFeatures','GetFeaturePosition','GetFeatureCollisionVolumeData'})do assert(type(S[name])=='function','Native measurement API '..name)end
 local found=0;for _,d in pairs(FeatureDefs)do local p=d.customParams or{};if d.name=='40k_terminator_corpse'and p.parent_actor=='imp_terminator'and tonumber(p.scale_pilot_factor)==.85 then found=found+1;assert(d.reclaimable and d.resurrectable==0 and d.metal==0 and d.energy==0,'Sole base-zero native feature contract')end end
 assert(found==1,'Exactly one returned paired FeatureDef required')
 start=S.GetGameFrame();log('SCHEMA',1,'factor=.85 full_capacity=3 body_metal=240 body_energy=1300 body_work=1900 source_terminal=die_1:46/47 source_visibility_parity=false visual_animation_unaccepted=true')
end
function gadget:UnitCreated(id,def,owner,builder)
 local d=UnitDefs[def];local p=d and d.customParams or{}
 if p.animsource=='imp_terminator'and p.prototype40k_squad_product=='marine_terminator'then
  local w,m,e=S.GetUnitCosts(id);birth[id]={builder=builder,frame=S.GetGameFrame(),team=owner};log('QUEUE_PRODUCT_BIRTH',id,builder or-1,w,m,e,'payment_origin_unverified=true')
 end
end
function gadget:UnitFromFactory(id,def,owner,factory)
 if birth[id]then if release[id]then close('REFUSAL duplicate_factory_release');return end;release[id]=S.GetGameFrame();log('NATIVE_RELEASE',id,factory,release[id])end
end
function gadget:UnitDestroyed(id)if bodies[id]then destroyed[id]=S.GetGameFrame();log('BODY_DESTROYED',S.GetGameFrame(),id,bodies[id].slot,bodies[id].generation)end end
local function cohort()
 local api=GG.Recoil40KSquads;if not api or not api.squads then return end
 local chosen
 for _,s in pairs(api.squads)do if s.profile=='marine_terminator'then
  if chosen and chosen.id~=s.id then close('REFUSAL multiple_terminator_cohorts');return end;chosen=s
 end end
 if not chosen then return end
 if seed and seed~=chosen.id then close('REFUSAL changed_cohort_identity');return end
 local n=0;local seen={};for slot,id in pairs(chosen.slots)do n=n+1;if type(slot)~='number'or slot%1~=0 or slot<1 or slot>3 or type(id)~='number'or id<=0 or id%1~=0 or seen[id]then close('REFUSAL malformed_full_three');return end;seen[id]=true end
 if not seed then
  if n~=3 then return end;seed=chosen.id;team=chosen.team;startedCohort=S.GetGameFrame()
  for slot=1,3 do local id=chosen.slots[slot];local w,m,e=S.GetUnitCosts(id);local d=UnitDefs[S.GetUnitDefID(id)];local p=d.customParams or{}
   if p.animsource~='imp_terminator'or tonumber(p.scale_pilot_factor)~=.85 or p.scale_animation_bank~='imp_terminator_scale085'or not near(m,240)or not near(e,1300)or not near(w,1900)then close('REFUSAL genuine_paired_body_or_cost');return end
   local inv=chosen.investments and chosen.investments[slot];if not inv or not near(inv.metal,240)or not near(inv.energy,1300)or not near(inv.work,1900)then close('REFUSAL body_investment');return end
   if type(chosen.generations[slot])~='number'or chosen.generations[slot]<1 or chosen.generations[slot]%1~=0 then close('REFUSAL native_paid_generation');return end
   bodies[id]={slot=slot,generation=chosen.generations[slot]};samples[id]=0;log('FULL_BODY',id,seed,slot,chosen.generations[slot],w,m,e)
  end
 end
 return chosen
end
-- Diagnostic gate edges only; never substitute a stale pose or change sampling.
local gaitGates={}
local function gaitGate(id,frame,reason)
 local g=gaitGates[id];if not g then g={count=0};gaitGates[id]=g end
 if g.reason==reason then return end;g.reason=reason
 if g.count>=12 then
  if not g.truncated then g.truncated=true;log('GAIT_GATE_TRUNCATED',frame,id,'edge_cap=12 native_acceptance=false')end
  return
 end
 g.count=g.count+1;log('GAIT_GATE',frame,id,'edge='..g.count,'reason='..reason,'same_frame_oracle_unchanged=true native_acceptance=false')
end
local function sample(id,frame)
 local getter=(GG.Recoil40KGaitPoseObservers or{})[id]
 if not getter then gaitGate(id,frame,'absent_registry');return end
 local pose,why=getter(frame,selected)
 if not pose then gaitGate(id,frame,'getter_'..tostring(why or'no_pose'):gsub('[^%w_%-]','_'):sub(1,80));return end
 if pose.frame~=frame then gaitGate(id,frame,'not_current_frame');return end
 if pose.mode~='walk'then gaitGate(id,frame,'not_walk');return end
 if pose.blendAge<6 then gaitGate(id,frame,'blend_age_below6');return end
 if pose.actor~='imp_terminator'or pose.bankKey~='scripts/40k_anim/imp_terminator_scale085.lua'or pose.factor~=.85 or pose.count~=27 or pose.fps~=30 or not near(pose.stride,20.1303545)then close('REFUSAL matched_native_gait_identity');return end
 local x,y,z,mx,my,mz=S.GetUnitPosition(id,true);local vx,vy,vz=S.GetUnitVelocity(id);local ground=S.GetGroundHeight(x,z)
 local cv={S.GetUnitCollisionVolumeData(id)};if #cv~=10 or type(cv[10])~='boolean'then close('REFUSAL native_unit_collision_shape');return end;for i=1,9 do if not finite(cv[i])then close('REFUSAL native_unit_collision_shape');return end end
 local sx,sy,sz,ox,oy,oz,vtype,ttype,axis,ignore=unpack(cv);local front,up,right=S.GetUnitVectors(id)
 local values={x,y,z,mx,my,mz,vx,vy,vz,ground,sx,sy,sz,ox,oy,oz};for i=1,16 do if not finite(values[i])then close('REFUSAL native_geometry_missing');return end end
 if sx<=0 or sy<=0 or sz<=0 then gaitGate(id,frame,'nonpositive_native_collider');return end
 if vx*vx+vz*vz<=1e-5 then gaitGate(id,frame,'zero_native_planar_velocity');return end
 for _,v in ipairs({front or{},up or{},right or{}})do for i=1,3 do if not finite(v[i])then close('REFUSAL native_vectors_missing');return end end end
 local cy=my-right[2]*ox+up[2]*oy+front[2]*oz;local low=cy-(math.abs(right[2])*sx+math.abs(up[2])*sy+math.abs(front[2])*sz)*.5
 gaitGate(id,frame,'eligible_current_native_walk')
 samples[id]=samples[id]+1
 log('LIVE_GEOMETRY',frame,id,'xyz='..x..','..y..','..z,'mid='..mx..','..my..','..mz,'velocity='..vx..','..vy..','..vz,'ground='..ground,'front='..table.concat(front,','),'up='..table.concat(up,','),'right='..table.concat(right,','),'native_collider='..sx..','..sy..','..sz..','..ox..','..oy..','..oz,'volume_type='..tostring(vtype),'native_ignore_hits='..tostring(ignore),'collider_AABB_lowY='..low,'mesh_world_floor_contact_unmeasured=true')
 log('PHASE',frame,id,pose.sampleSeconds,pose.fps,pose.count,pose.i,pose.j,pose.alpha,pose.stride,'same_frame=true bank=imp_terminator_scale085')
 local map=S.GetUnitPieceMap(id)or{}
 for _,name in ipairs(selected)do local handle=map[name];if handle==nil then close('REFUSAL missing_native_source_piece');return end
  local matrix={S.GetUnitPieceMatrix(id,handle)};if #matrix~=16 then close('REFUSAL native_piece_matrix_missing');return end
  local px,py,pz=S.GetUnitPiecePosDir(id,handle);if not finite(px)or not finite(py)or not finite(pz)then close('REFUSAL native_piece_world_position_missing');return end
  for _,v in ipairs(matrix)do if not finite(v)then close('REFUSAL native_piece_matrix_nonfinite');return end end
  log('PIECE',frame,id,'name='..name:gsub(' ','_'),'xyz='..px..','..py..','..pz,'ground='..S.GetGroundHeight(px,pz),'matrix='..table.concat(matrix,','),'bone_origin_not_skin_contact=true native_piece_matrix_not_calibrated_to_render=true')
 end
end
local function features(frame)
 for _,fid in ipairs(S.GetAllFeatures()or{})do local fd=FeatureDefs[S.GetFeatureDefID(fid)];local p=fd and fd.customParams or{}
  if p.parent_actor=='imp_terminator'then
   if fd.name~='40k_terminator_corpse'or tonumber(p.scale_pilot_factor)~=.85 then close('REFUSAL foreign_terminator_corpse');return end
   local squad=S.GetFeatureRulesParam(fid,'40k_remains_squad');local slot=S.GetFeatureRulesParam(fid,'40k_remains_slot');local generation=S.GetFeatureRulesParam(fid,'40k_remains_generation');local cap=S.GetFeatureRulesParam(fid,'40k_remains_metal');local work=S.GetFeatureRulesParam(fid,'40k_remains_work');local flying=S.GetFeatureRulesParam(fid,'40k_remains_flying')
   if squad==seed then
    local own;for id,body in pairs(bodies)do if body.slot==slot and body.generation==generation then own=id end end
    if not own or not destroyed[own]then close('REFUSAL unknown_remains_body_generation');return end
    if not near(cap,60)or not near(work,475)then close('REFUSAL sole_capped_entitlement');return end
    local key=squad..':'..slot..':'..generation
    if featureSeen[key]and featureSeen[key]~=fid then close('REFUSAL duplicate_generation_feature');return end;featureSeen[key]=fid
    if frame%15==0 then local x,y,z=S.GetFeaturePosition(fid);local m,dm,e,de,left,time=S.GetFeatureResources(fid);local cv={S.GetFeatureCollisionVolumeData(fid)};if #cv~=10 or type(cv[10])~='boolean'then close('REFUSAL native_feature_collision_shape');return end;if cv[1]<=0 or cv[2]<=0 or cv[3]<=0 then close('REFUSAL native_feature_collision_shape');return end;local ignored=cv[10];cv[10]=nil;for _,v in ipairs(cv)do if not finite(v)then close('REFUSAL native_feature_collision_shape');return end end
     log('REMAINS',frame,fid,key,'xyz='..tostring(x)..','..tostring(y)..','..tostring(z),'ground='..tostring(x and S.GetGroundHeight(x,z)),'flying='..tostring(flying),'resources='..table.concat({tostring(m),tostring(dm),tostring(e),tostring(de),tostring(left),tostring(time)},','),'native_feature_collider='..table.concat(cv,','),'native_ignore_hits='..tostring(ignored),'static_die_1_frame46 source_hiddenmesh_parity=false reclaim_acceptance_pending=true')
    end
   end
  end
 end
end
function gadget:AllowFeatureBuildStep(id,owner,fid,def,part)
 if part<0 then reclaimSteps[fid]={frame=S.GetGameFrame(),builder=id,team=owner};for key,feature in pairs(featureSeen)do if feature==fid then log('NATIVE_RECLAIM_STEP',S.GetGameFrame(),id,owner,fid,part,key)end end end
 return true -- exact same sole remains owner continues to decide accounting.
end
function gadget:FeatureDestroyed(fid)for key,feature in pairs(featureSeen)do if feature==fid then local step=reclaimSteps[fid];log('FEATURE_DESTROYED',S.GetGameFrame(),fid,key,'last_native_work_frame='..tostring(step and step.frame),'last_builder='..tostring(step and step.builder),'native_work_pair_required_no_payout_inference=true')end end end
function gadget:GameFrame(frame)
 if stopped then return end
 local paid=GG.Recoil40KTerminatorPaidContext
 if yes(options.prototype_terminator_paid_driver)then
  if not paid or paid.version~=1 then return end
  if paid.ready~=true then
   if finite(paid.startedFrame)and frame-paid.startedFrame>36000 then close('PAID_DRIVER_ACQUISITION_BOUND')end
   return
  end
  if not finite(paid.frame)or paid.frame%1~=0 or paid.frame<1 or paid.frame>frame then close('REFUSAL paired_paid_ready_clock');return end
  if not paidAcquired then paidAcquired=paid.frame;start=paid.frame
  elseif paidAcquired~=paid.frame then close('REFUSAL changed_paid_ready_clock');return end
 end
 if(startedCohort and frame-startedCohort>7200)or(not startedCohort and frame-start>36000)then close('BOUNDED_OBSERVER_END');return end
 local actual=cohort();if stopped or not seed then return end
 if yes(options.prototype_terminator_paid_driver)then
  if paid.squad~=seed or paid.team~=team or not bodies[paid.product]or bodies[paid.product].slot~=1 or not finite(paid.frame)or paid.frame>frame then close('REFUSAL paired_paid_ready_identity');return end
  if actual then for slot=1,3 do if(actual.slots[slot]and paid.slots[slot]~=actual.slots[slot])or(not actual.slots[slot]and not destroyed[paid.slots[slot]])then close('REFUSAL paired_paid_ready_identity');return end end
  else for id in pairs(bodies)do if not destroyed[id]then close('REFUSAL paired_paid_ready_identity');return end end end
 end
 for id in pairs(bodies)do if not destroyed[id]and not S.GetUnitIsDead(id)and S.GetUnitTeam(id)~=team then close('REFUSAL original_body_transferred');return end end
 if frame%3==0 then for id in pairs(bodies)do if not destroyed[id]and not S.GetUnitIsDead(id)and(samples[id]or 0)<48 then sample(id,frame)end end end
 features(frame)
end
