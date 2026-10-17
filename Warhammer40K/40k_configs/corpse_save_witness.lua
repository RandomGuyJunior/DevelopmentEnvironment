-- Read-only private diagnostic witness; existing remains owner is authoritative.
local M={Version=1}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function integer(v)return finite(v)and v>=0 and v%1==0 end
local function copy(v,seen)
 if type(v)~='table'then assert(type(v)=='string'or type(v)=='boolean'or type(v)=='nil'or finite(v),'unsupported_witness_value');return v end
 seen=seen or{};assert(not seen[v],'cyclic_witness');seen[v]=true;local out={};for k,x in pairs(v)do assert(type(k)=='string'or integer(k),'witness_key');out[k]=copy(x,seen)end;seen[v]=nil;return out
end
local function equal(a,b)
 if type(a)~=type(b)then return false end;if type(a)~='table'then return a==b end
 for k,v in pairs(a)do if not equal(v,b[k])then return false end end;for k in pairs(b)do if a[k]==nil then return false end end;return true
end
local function tuple(fn,id,n,boolean)
 local out={fn(id)};assert(#out==n,'native_feature_tuple_missing');for _,v in ipairs(out)do assert(boolean and type(v)=='boolean'or not boolean and finite(v),'native_feature_tuple_type')end;return out
end
function M.Capture(S,R,U,F,fid)
 for _,api in ipairs({'GetGameFrame','GetAllFeatures','ValidFeatureID','GetFeatureDefID','GetFeatureTeam','GetFeatureRulesParams','GetFeatureResources','GetFeaturePosition','GetFeatureVelocity','GetFeatureBlocking','GetFeatureDirection','GetFeatureRotation'})do assert(type(S[api])=='function','missing_native_api:'..api)end
 assert(integer(fid)and S.ValidFeatureID(fid),'actual_feature_identity_required')
 assert(type(R)=='table'and type(R.features)=='table'and type(R.flights)=='table'and type(R.entitlements)=='table'and type(R.AllowFeatureBuildStep)=='function','existing_single_owner_required')
 local row=R.features[fid];assert(row and row.actor=='imp_devastator','actual_owned_Heavy_required')
 local def=S.GetFeatureDefID(fid);local fd=F[def];local actor=U[row.def];assert(fd and fd.name=='40k_heavy_marine_corpse'and(fd.customParams or{}).parent_actor=='imp_devastator'and actor and(actor.customParams or{}).animsource=='imp_devastator','genuine_Heavy_native_definitions_required')
 for _,k in ipairs({'squad','slot','generation','team','def'})do assert(integer(row[k]),'native_Heavy_record_identity')end
 assert(row.generation>=1 and finite(row.metal)and row.metal>=0 and row.energy==0 and finite(row.work)and row.work>=1,'original_one_entitlement_bill_required')
 local key=row.squad..':'..row.slot..':'..row.generation;assert(R.entitlements[key]==true,'original_entitlement_reserved')
 local ownerCount,sameCount=0,0;for id,v in pairs(R.features)do ownerCount=ownerCount+1;assert(ownerCount<=512 and type(v)=='table','bounded_existing_owner_records');if v.squad==row.squad and v.slot==row.slot and v.generation==row.generation then sameCount=sameCount+1;assert(id==fid,'duplicate_owner_entitlement')end end;assert(sameCount==1,'one_original_owner_record')
 local ids=S.GetAllFeatures();assert(type(ids)=='table'and #ids<=128,'bounded_native_feature_list');local n=0;for k in pairs(ids)do n=n+1;assert(integer(k)and k>=1 and k<=#ids,'native_feature_list_array')end;assert(n==#ids,'native_feature_list_complete');local count=0;local seen={}
 for _,id in ipairs(ids)do assert(integer(id)and not seen[id],'native_feature_list_identity');seen[id]=true;local p=S.GetFeatureRulesParams(id);assert(type(p)=='table','native_feature_rules_missing')
  if p['40k_remains_version']==1 and p['40k_remains_squad']==row.squad and p['40k_remains_slot']==row.slot and p['40k_remains_generation']==row.generation then count=count+1;assert(id==fid,'duplicate_native_entitlement')end
 end;assert(count==1 and seen[fid],'exactly_one_real_native_feature')
 local rules=S.GetFeatureRulesParams(fid);assert(type(rules)=='table'and rules['40k_remains_version']==1,'actual_private_rules_required')
 for _,k in ipairs({'squad','slot','generation','metal','energy','work','team','def'})do assert(rules['40k_remains_'..k]==row[k],'private_identity_or_bill_changed:'..k)end
 assert(S.GetFeatureTeam(fid)==row.team,'feature_native_team_changed')
 local resources=tuple(S.GetFeatureResources,fid,6);local flight=R.flights[fid];local phase=flight and'airborne'or'landed';local allow=R.AllowFeatureBuildStep(nil,row.team,fid,def,-.1)
 if flight then
  assert(rules['40k_remains_flying']==1 and resources[1]==0 and resources[2]==0 and resources[3]==0 and resources[4]==0 and resources[5]==1 and allow==false,'zero_value_airborne_reclaim_block_required')
  for _,k in ipairs({'px','py','pz','vx','vy','vz','born','last'})do assert(finite(flight[k])and flight[k]%1==0 and rules['40k_remains_flight_'..k]==flight[k],'exact_private_flight_changed:'..k)end
 else assert(rules['40k_remains_flying']==0 and resources[1]==row.metal and resources[2]==row.metal and resources[3]==0 and resources[4]==0 and resources[5]==1 and resources[6]==row.work and allow==true,'single_unreclaimed_landed_entitlement_required')end
 return{schema=M.Version,frame=S.GetGameFrame(),fid=fid,featureDef=def,phase=phase,key=key,ownerRow=copy(row),flight=copy(flight),entitlement=true,rules=copy(rules),resources=resources,position=tuple(S.GetFeaturePosition,fid,3),velocity=tuple(S.GetFeatureVelocity,fid,4),blocking=tuple(S.GetFeatureBlocking,fid,7,true),direction=tuple(S.GetFeatureDirection,fid,9),rotation=tuple(S.GetFeatureRotation,fid,3),reclaimAllowed=allow}
end
function M.CompareExact(before,after)
 return{state=equal(before,after)and'EXACT_BYTES_MATCH_BOUNDARY_PROOF_PENDING'or'EXACT_BYTES_DIFFER',exactCheckpointPassed=false,nativeResumeAccepted=false}
end
function M.Landing(before,after)
 assert(before.phase=='airborne'and after.phase=='landed'and before.fid==after.fid and before.featureDef==after.featureDef and before.key==after.key and after.frame>before.frame,'same_original_native_feature_landing_required')
 for _,k in ipairs({'actor','def','team','squad','slot','generation','metal','energy','work'})do assert(before.ownerRow[k]==after.ownerRow[k],'original_entitlement_identity_changed:'..k)end
 return{state='SAME_ONE_ENTITLEMENT_LANDED_SOURCE_WITNESS',exactCheckpointPassed=false,nativeResumeAccepted=false,paidEconomyAccepted=false}
end
function M.FirstTick(enabled,Probe,Script,S,baseline,read,notify)
 assert(type(Probe)=='table'and type(Probe.Schedule)=='function','existing_serialized_precontroller_probe_required')
 return Probe.Schedule(enabled,Script,S,baseline,read,notify)
end
return M
